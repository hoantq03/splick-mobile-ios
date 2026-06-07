import Foundation
import UIKit
import DesignSystem
import Common
import SplickDomain
import AVFoundation

public enum ComposeBillSplitMode: String, CaseIterable, Identifiable {
    case equal
    case percentage
    case exact

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .equal: return "Chia đều"
        case .percentage: return "Theo %"
        case .exact: return "Từng người"
        }
    }
}

@MainActor
public final class CreatePostComposeViewModel: ObservableObject {
    @Published var caption = ""
    @Published var location = ""
    @Published var friendSearchQuery = ""
    @Published private(set) var friendSearchResults: [UserSummary] = []
    @Published private(set) var selectedCompanions: [UserSummary] = []
    @Published var enableBillSplit = false
    @Published var autoReminderEnabled = false
    @Published var billTotalText = ""
    @Published var splitMode: ComposeBillSplitMode = .equal
    @Published var percentageTexts: [UUID: String] = [:]
    @Published var exactAmountTexts: [UUID: String] = [:]
    @Published private(set) var isSearchingFriends = false
    @Published private(set) var hasMoreFriendSearch = true
    @Published private(set) var isFriendSearchActive = false
    @Published private(set) var submitState: LoadingState<Post> = .idle
    @Published private(set) var selectedMediaItems: [ComposeMediaDraft] = []
    @Published private(set) var mentionPickerViewModel: MentionFriendsViewModel?

    private let createPostUseCase: CreatePostUseCaseProtocol
    private let fetchFriendsUseCase: FetchFriendsUseCaseProtocol
    private let currentUser: UserSummary?
    private let currentUserId: UUID?
    private var friendSearchTask: Task<Void, Never>?
    private var activeMentionQuery = ""
    private var friendSearchPage = 0
    private var friendSearchActiveQuery = ""

    private let friendSearchPageSize = 10

    var shouldShowFriendSuggestions: Bool {
        isFriendSearchActive
            || !friendSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private let maxImages = 5
    private let maxVideos = 3

    public init(
        previewImages: [UIImage] = [],
        videoURL: URL? = nil,
        mediaType: PostMediaType = .image,
        createPostUseCase: CreatePostUseCaseProtocol,
        fetchFriendsUseCase: FetchFriendsUseCaseProtocol,
        currentUser: UserSummary?,
        currentUserId: UUID?
    ) {
        self.createPostUseCase = createPostUseCase
        self.fetchFriendsUseCase = fetchFriendsUseCase
        self.currentUser = currentUser
        self.currentUserId = currentUserId ?? currentUser?.id

        if mediaType == .video,
           let videoURL,
           let data = try? Data(contentsOf: videoURL) {
            selectedMediaItems = [
                ComposeMediaDraft(
                    previewImage: Self.videoThumbnail(videoURL),
                    mediaType: .video,
                    data: data,
                    mimeType: "video/mp4",
                    videoDurationSeconds: Self.videoDurationSeconds(from: videoURL)
                )
            ]
        } else {
            selectedMediaItems = previewImages.compactMap(Self.makeImageDraft)
        }
    }

    var remainingImageSlots: Int {
        max(0, maxImages - selectedMediaItems.filter { $0.mediaType == .image }.count)
    }

    var remainingVideoSlots: Int {
        max(0, maxVideos - selectedMediaItems.filter { $0.mediaType == .video }.count)
    }

    func addImages(_ images: [UIImage]) {
        for image in images {
            guard remainingImageSlots > 0 else { break }
            guard let draft = Self.makeImageDraft(from: image) else { continue }
            selectedMediaItems.append(draft)
        }
    }

    var selectedCompanionIds: Set<UUID> {
        Set(selectedCompanions.map(\.id))
    }

    var billSplitParticipants: [UserSummary] {
        guard let currentUser else { return selectedCompanions }
        let others = selectedCompanions.filter { $0.id != currentUser.id }
        return [currentUser] + others
    }

    func isCurrentUser(_ user: UserSummary) -> Bool {
        user.id == currentUserId
    }

    func participantDisplayName(_ user: UserSummary) -> String {
        isCurrentUser(user) ? "Tôi" : user.displayName
    }

    var parsedBillTotal: Decimal? {
        VNDMoneyFormat.parse(billTotalText)
    }

    var equalShareAmount: Decimal? {
        guard let total = parsedBillTotal, !billSplitParticipants.isEmpty else { return nil }
        return total / Decimal(billSplitParticipants.count)
    }

    var equalSharePreview: String? {
        guard let total = parsedBillTotal,
              let share = equalShareAmount
        else { return nil }
        return "\(VNDMoneyFormat.formatDisplay(total)) ÷ \(billSplitParticipants.count) người = \(VNDMoneyFormat.formatDisplay(share)) / người"
    }

    func amountForPercentage(userId: UUID) -> Decimal? {
        guard let total = parsedBillTotal,
              let pct = VNDMoneyFormat.parsePercent(percentageTexts[userId] ?? "")
        else { return nil }
        return total * pct / 100
    }

    func clearSubmitError() {
        if case .failed = submitState {
            submitState = .idle
        }
    }

    var canAddMoreMedia: Bool {
        selectedMediaItems.count < maxImages + maxVideos
    }

    func removeMediaItem(id: UUID) {
        selectedMediaItems.removeAll { $0.id == id }
    }

    func updateMediaImage(id: UUID, image: UIImage) {
        guard let index = selectedMediaItems.firstIndex(where: { $0.id == id }),
              selectedMediaItems[index].mediaType == .image,
              let draft = Self.makeImageDraft(from: image)
        else { return }

        let existingId = selectedMediaItems[index].id
        selectedMediaItems[index] = ComposeMediaDraft(
            id: existingId,
            previewImage: draft.previewImage,
            mediaType: draft.mediaType,
            data: draft.data,
            mimeType: draft.mimeType,
            videoDurationSeconds: draft.videoDurationSeconds
        )
    }

    func addMediaDraft(_ media: ComposeMediaDraft) {
        guard canAddMoreMedia else { return }
        if media.mediaType == .video,
           selectedMediaItems.filter({ $0.mediaType == .video }).count >= maxVideos {
            return
        }
        if media.mediaType == .image,
           selectedMediaItems.filter({ $0.mediaType == .image }).count >= maxImages {
            return
        }
        selectedMediaItems.append(media)
    }

    func setFriendSearchActive(_ active: Bool) {
        isFriendSearchActive = active
        if active {
            scheduleFriendSearch(reset: true)
        } else if friendSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            cancelFriendSearch()
        }
    }

    func updateFriendSearch(_ query: String) {
        friendSearchQuery = query
        guard shouldShowFriendSuggestions else {
            cancelFriendSearch()
            return
        }
        scheduleFriendSearch(reset: true, debounce: true)
    }

    func loadMoreFriendSearchIfNeeded(currentFriend: UserSummary?) {
        guard let currentFriend, currentFriend.id == friendSearchResults.last?.id else { return }
        guard hasMoreFriendSearch, !isSearchingFriends else { return }
        friendSearchTask?.cancel()
        friendSearchTask = Task {
            await fetchFriendSearchPage(page: friendSearchPage + 1, reset: false)
        }
    }

    func syncMentionPicker(with text: String) {
        guard let context = MentionContext.active(in: text) else {
            activeMentionQuery = ""
            mentionPickerViewModel = nil
            return
        }

        let openingPicker = mentionPickerViewModel == nil
        if openingPicker {
            mentionPickerViewModel = MentionFriendsViewModel(
                useCase: fetchFriendsUseCase,
                pageSize: friendSearchPageSize
            )
        }

        if openingPicker || context.query != activeMentionQuery {
            activeMentionQuery = context.query
            mentionPickerViewModel?.reset(query: context.query)
        }
    }

    func insertMention(_ user: UserSummary) {
        guard let context = MentionContext.active(in: caption) else { return }
        let mention = "@\(user.username) "
        caption.replaceSubrange(context.replaceRange, with: mention)
        activeMentionQuery = ""
        mentionPickerViewModel = nil
    }

    func addCompanion(_ user: UserSummary) {
        guard !selectedCompanionIds.contains(user.id) else { return }
        selectedCompanions.append(user)
        friendSearchResults.removeAll { $0.id == user.id }
        friendSearchQuery = ""
        if isFriendSearchActive {
            scheduleFriendSearch(reset: true)
        } else {
            friendSearchResults = []
        }
    }

    func removeCompanion(_ user: UserSummary) {
        selectedCompanions.removeAll { $0.id == user.id }
        percentageTexts.removeValue(forKey: user.id)
        exactAmountTexts.removeValue(forKey: user.id)
    }

    func submit() async -> Post? {
        guard !selectedMediaItems.isEmpty else {
            submitState = .failed("Chọn ít nhất một ảnh hoặc video.")
            return nil
        }

        if enableBillSplit {
            guard buildBillSplit() != nil else {
                submitState = .failed("Kiểm tra lại thông tin chia bill.")
                return nil
            }
            if billSplitParticipants.isEmpty {
                submitState = .failed("Chọn ít nhất một người để chia bill.")
                return nil
            }
        }

        let input = CreatePostInput(
            mediaItems: selectedMediaItems.map {
                CreatePostMediaInput(
                    data: $0.data,
                    mimeType: $0.mimeType,
                    mediaType: $0.mediaType,
                    videoDurationSeconds: $0.videoDurationSeconds
                )
            },
            caption: caption.nilIfBlank,
            companionIds: selectedCompanions.map(\.id),
            checkInPlace: location.nilIfBlank,
            feedKind: enableBillSplit ? .shareBill : .checkIn,
            billSplit: enableBillSplit ? buildBillSplit() : nil,
            billSplitType: enableBillSplit ? splitMode.apiSplitType : nil,
            autoReminderEnabled: enableBillSplit && autoReminderEnabled
        )

        submitState = .loading
        do {
            let post = try await createPostUseCase.execute(input)
            submitState = .loaded(post)
            return post
        } catch {
            submitState = .failed(error.localizedDescription)
            return nil
        }
    }

    private func buildBillSplit() -> PostBillSplit? {
        guard let total = parsedBillTotal, total > 0 else { return nil }

        let participants = billSplitParticipants
        guard !participants.isEmpty else { return nil }

        let splits: [PostBillSplitLine]
        switch splitMode {
        case .equal:
            let share = total / Decimal(participants.count)
            splits = participants.map {
                PostBillSplitLine(user: $0, amount: share, isPaid: $0.id == currentUserId)
            }
        case .percentage:
            splits = participants.map { user in
                let pct = VNDMoneyFormat.parsePercent(percentageTexts[user.id] ?? "") ?? 0
                let amount = total * pct / 100
                return PostBillSplitLine(user: user, amount: amount, isPaid: user.id == currentUserId)
            }
        case .exact:
            splits = participants.map { user in
                let amount = VNDMoneyFormat.parse(exactAmountTexts[user.id] ?? "") ?? 0
                return PostBillSplitLine(user: user, amount: amount, isPaid: user.id == currentUserId)
            }
        }

        return PostBillSplit(totalAmount: total, currency: "VND", splits: splits)
    }

    private func cancelFriendSearch() {
        friendSearchTask?.cancel()
        friendSearchResults = []
        friendSearchPage = 0
        friendSearchActiveQuery = ""
        hasMoreFriendSearch = true
        isSearchingFriends = false
    }

    private func scheduleFriendSearch(reset: Bool, debounce: Bool = false) {
        friendSearchTask?.cancel()
        let trimmed = friendSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        friendSearchActiveQuery = trimmed.replacingOccurrences(of: "@", with: "")
        if reset {
            friendSearchPage = 0
            hasMoreFriendSearch = true
        }
        isSearchingFriends = true
        friendSearchTask = Task {
            if debounce {
                try? await Task.sleep(nanoseconds: 250_000_000)
            }
            guard !Task.isCancelled else { return }
            await fetchFriendSearchPage(page: reset ? 0 : friendSearchPage + 1, reset: reset)
        }
    }

    private func fetchFriendSearchPage(page: Int, reset: Bool) async {
        isSearchingFriends = true
        defer { isSearchingFriends = false }

        do {
            let results = try await fetchFriendsUseCase.execute(
                query: friendSearchActiveQuery,
                page: page,
                limit: friendSearchPageSize
            )
            guard !Task.isCancelled else { return }
            let filtered = results
                .filter { !selectedCompanionIds.contains($0.id) }
                .sorted {
                    $0.displayName.localizedCaseInsensitiveCompare($1.displayName)
                        == .orderedAscending
                }
            if reset {
                friendSearchResults = filtered
            } else {
                let existingIds = Set(friendSearchResults.map(\.id))
                friendSearchResults.append(contentsOf: filtered.filter { !existingIds.contains($0.id) })
                friendSearchResults.sort {
                    $0.displayName.localizedCaseInsensitiveCompare($1.displayName)
                        == .orderedAscending
                }
            }
            friendSearchPage = page
            hasMoreFriendSearch = results.count == friendSearchPageSize
        } catch {
            if reset {
                friendSearchResults = []
            }
            hasMoreFriendSearch = false
        }
    }

    private static func makeImageDraft(from previewImage: UIImage) -> ComposeMediaDraft? {
        let jpegData = previewImage.jpegData(compressionQuality: AppConstants.Media.compressionQuality)
        let pngData = jpegData == nil ? previewImage.pngData() : nil
        guard let data = jpegData ?? pngData else { return nil }
        return ComposeMediaDraft(
            previewImage: previewImage,
            mediaType: .image,
            data: data,
            mimeType: jpegData != nil ? "image/jpeg" : "image/png",
            videoDurationSeconds: nil
        )
    }

    private static func videoDurationSeconds(from url: URL) -> Int? {
        let asset = AVURLAsset(url: url)
        let seconds = CMTimeGetSeconds(asset.duration)
        guard seconds.isFinite else { return nil }
        return Int(seconds.rounded())
    }

    private static func videoThumbnail(_ url: URL) -> UIImage? {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        guard let cgImage = try? generator.copyCGImage(at: .zero, actualTime: nil) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }
}

public struct ComposeMediaDraft: Identifiable {
    public let id: UUID
    public let previewImage: UIImage?
    public let mediaType: PostMediaType
    public let data: Data
    public let mimeType: String
    public let videoDurationSeconds: Int?

    public init(
        id: UUID = UUID(),
        previewImage: UIImage?,
        mediaType: PostMediaType,
        data: Data,
        mimeType: String,
        videoDurationSeconds: Int?
    ) {
        self.id = id
        self.previewImage = previewImage
        self.mediaType = mediaType
        self.data = data
        self.mimeType = mimeType
        self.videoDurationSeconds = videoDurationSeconds
    }
}

private extension ComposeBillSplitMode {
    var apiSplitType: String {
        switch self {
        case .equal: return "EQUAL"
        case .percentage: return "PERCENTAGE"
        case .exact: return "EXACT"
        }
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
