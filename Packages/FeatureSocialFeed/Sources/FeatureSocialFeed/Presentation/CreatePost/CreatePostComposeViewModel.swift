import Foundation
import UIKit
import DesignSystem
import Common
import SplickDomain
import AVFoundation
import FeatureFriends

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

public struct PreparedPostSubmit: Sendable {
    public let optimisticPost: Post
    public let input: CreatePostInput

    public init(optimisticPost: Post, input: CreatePostInput) {
        self.optimisticPost = optimisticPost
        self.input = input
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
    @Published var audienceMode: PostAudienceMode = .friends
    @Published var audienceGroupSearchQuery = ""
    @Published var audienceUserSearchQuery = ""
    @Published private(set) var availableAudienceGroups: [Group] = []
    @Published private(set) var selectedAudienceGroups: [Group] = []
    @Published private(set) var selectedAudienceUsers: [UserSummary] = []
    @Published private(set) var audienceFriendOptions: [UserSummary] = []
    @Published private(set) var audienceGroupsState: LoadingState<[Group]> = .idle
    @Published private(set) var isLoadingAudienceFriends = false
    @Published private(set) var submitState: LoadingState<Post> = .idle
    @Published private(set) var selectedMediaItems: [ComposeMediaDraft] = []
    @Published private(set) var mentionPickerViewModel: MentionFriendsViewModel?

    private let fetchFriendsUseCase: FetchFriendsUseCaseProtocol
    private let fetchMyGroupsUseCase: FetchMyGroupsUseCaseProtocol
    private let currentUser: UserSummary?
    private let currentUserId: UUID?
    private var friendSearchTask: Task<Void, Never>?
    private var audienceFriendSearchTask: Task<Void, Never>?
    private var activeMentionQuery = ""
    private var friendSearchPage = 0
    private var friendSearchActiveQuery = ""
    private var hasLoadedAudienceGroups = false
    private var hasLoadedAudienceFriends = false

    private let friendSearchPageSize = 20
    private let audienceFriendPageSize = 10

    var shouldShowFriendSuggestions: Bool {
        isFriendSearchActive
            || isSearchingFriends
            || !friendSearchResults.isEmpty
            || !friendSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private let maxImages = 5
    private let maxVideos = 3

    public init(
        previewImages: [UIImage] = [],
        videoURL: URL? = nil,
        mediaType: PostMediaType = .image,
        fetchFriendsUseCase: FetchFriendsUseCaseProtocol,
        fetchMyGroupsUseCase: FetchMyGroupsUseCaseProtocol,
        currentUser: UserSummary?,
        currentUserId: UUID?
    ) {
        self.fetchFriendsUseCase = fetchFriendsUseCase
        self.fetchMyGroupsUseCase = fetchMyGroupsUseCase
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

    var selectedAudienceGroupIds: Set<UUID> {
        Set(selectedAudienceGroups.map(\.id))
    }

    var selectedAudienceUserIds: Set<UUID> {
        Set(selectedAudienceUsers.map(\.id))
    }

    var filteredAudienceGroups: [Group] {
        let query = audienceGroupSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return Array(availableAudienceGroups.prefix(10)) }
        return availableAudienceGroups.filter {
            $0.name.localizedCaseInsensitiveContains(query)
                || $0.inviteCode.localizedCaseInsensitiveContains(query)
                || ($0.description?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    var audienceSummaryTitle: String {
        switch audienceMode {
        case .friends:
            return "Bạn bè"
        case .groups:
            return selectedAudienceGroups.isEmpty ? "Nhóm" : "\(selectedAudienceGroups.count) nhóm"
        case .specificUsers:
            return selectedAudienceUsers.isEmpty ? "Người dùng cụ thể" : "\(selectedAudienceUsers.count) người dùng"
        case .friendsExcept:
            return selectedAudienceUsers.isEmpty ? "Bạn bè ngoại trừ" : "Bạn bè ngoại trừ \(selectedAudienceUsers.count) người"
        }
    }

    var audienceSummarySubtitle: String {
        switch audienceMode {
        case .friends:
            return "Chỉ bạn bè của bạn có thể xem bài viết này."
        case .groups:
            if selectedAudienceGroups.isEmpty {
                return "Chỉ thành viên trong các nhóm bạn chọn mới xem được."
            }
            return selectedAudienceGroups.prefix(2).map(\.name).joined(separator: ", ")
        case .specificUsers:
            if selectedAudienceUsers.isEmpty {
                return "Chỉ những người bạn chọn mới xem được."
            }
            return selectedAudienceUsers.prefix(2).map(\.displayName).joined(separator: ", ")
        case .friendsExcept:
            if selectedAudienceUsers.isEmpty {
                return "Bạn bè đều xem được, trừ những người bạn loại ra."
            }
            return selectedAudienceUsers.prefix(2).map(\.displayName).joined(separator: ", ")
        }
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

    func preloadFriendSuggestionsIfNeeded() async {
        guard friendSearchResults.isEmpty else { return }
        guard friendSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        await fetchFriendSearchPage(page: 0, reset: true)
    }

    func setFriendSearchActive(_ active: Bool) {
        isFriendSearchActive = active
        if active {
            scheduleFriendSearch(reset: true)
        } else if friendSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            friendSearchTask?.cancel()
            isSearchingFriends = false
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
        scheduleFriendSearch(reset: true)
    }

    func removeCompanion(_ user: UserSummary) {
        selectedCompanions.removeAll { $0.id == user.id }
        percentageTexts.removeValue(forKey: user.id)
        exactAmountTexts.removeValue(forKey: user.id)
    }

    func loadAudienceGroupsIfNeeded() async {
        guard !hasLoadedAudienceGroups else { return }
        audienceGroupsState = .loading
        do {
            let groups = try await fetchMyGroupsUseCase.execute().sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
            availableAudienceGroups = groups
            audienceGroupsState = .loaded(groups)
            hasLoadedAudienceGroups = true
        } catch {
            audienceGroupsState = .failed(error.localizedDescription)
        }
    }

    func loadAudienceFriendsIfNeeded() async {
        guard !hasLoadedAudienceFriends else { return }
        await fetchAudienceFriends(query: "")
    }

    func selectAudienceMode(_ mode: PostAudienceMode) {
        guard audienceMode != mode else { return }
        audienceMode = mode
        selectedAudienceGroups = []
        selectedAudienceUsers = []
        audienceGroupSearchQuery = ""
        audienceUserSearchQuery = ""
        audienceFriendOptions = []
        audienceFriendSearchTask?.cancel()
        isLoadingAudienceFriends = false
        hasLoadedAudienceFriends = false

        Task {
            switch mode {
            case .friends:
                break
            case .groups:
                await loadAudienceGroupsIfNeeded()
            case .specificUsers, .friendsExcept:
                await loadAudienceFriendsIfNeeded()
            }
        }
    }

    func isAudienceGroupSelected(_ group: Group) -> Bool {
        selectedAudienceGroupIds.contains(group.id)
    }

    func toggleAudienceGroup(_ group: Group) {
        if isAudienceGroupSelected(group) {
            selectedAudienceGroups.removeAll { $0.id == group.id }
        } else {
            selectedAudienceGroups.append(group)
            selectedAudienceGroups.sort {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        }
    }

    func removeAudienceGroup(_ group: Group) {
        selectedAudienceGroups.removeAll { $0.id == group.id }
    }

    func isAudienceUserSelected(_ user: UserSummary) -> Bool {
        selectedAudienceUserIds.contains(user.id)
    }

    func toggleAudienceUser(_ user: UserSummary) {
        if isAudienceUserSelected(user) {
            selectedAudienceUsers.removeAll { $0.id == user.id }
        } else {
            selectedAudienceUsers.append(user)
            selectedAudienceUsers.sort {
                $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
            }
        }
    }

    func removeAudienceUser(_ user: UserSummary) {
        selectedAudienceUsers.removeAll { $0.id == user.id }
    }

    func updateAudienceUserSearch(_ query: String) {
        audienceUserSearchQuery = query
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            audienceFriendSearchTask?.cancel()
            Task { await fetchAudienceFriends(query: "") }
            return
        }
        scheduleAudienceFriendSearch()
    }

    func prepareSubmit() -> PreparedPostSubmit? {
        guard let input = buildCreatePostInput() else { return nil }
        guard let author = currentUser else {
            submitState = .failed("Không xác định được tài khoản.")
            return nil
        }

        do {
            let optimisticPost = try OptimisticPostBuilder.build(
                author: author,
                input: input,
                mediaDrafts: selectedMediaItems,
                companions: selectedCompanions
            )
            submitState = .idle
            return PreparedPostSubmit(optimisticPost: optimisticPost, input: input)
        } catch {
            submitState = .failed(error.localizedDescription)
            return nil
        }
    }

    private func buildCreatePostInput() -> CreatePostInput? {
        guard !selectedMediaItems.isEmpty else {
            submitState = .failed("Chọn ít nhất một ảnh hoặc video.")
            return nil
        }

        let audience = buildAudience()
        if audience.requiresSelection {
            submitState = .failed(audienceValidationMessage(for: audience.mode))
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

        return CreatePostInput(
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
            autoReminderEnabled: enableBillSplit && autoReminderEnabled,
            audience: audience
        )
    }

    private func buildAudience() -> PostAudience {
        switch audienceMode {
        case .friends:
            return .friends
        case .groups:
            return PostAudience(mode: .groups, allowedGroupIds: selectedAudienceGroups.map(\.id))
        case .specificUsers:
            return PostAudience(mode: .specificUsers, allowedUserIds: selectedAudienceUsers.map(\.id))
        case .friendsExcept:
            return PostAudience(mode: .friendsExcept, excludedUserIds: selectedAudienceUsers.map(\.id))
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

    private func audienceValidationMessage(for mode: PostAudienceMode) -> String {
        switch mode {
        case .friends:
            return ""
        case .groups:
            return "Chọn ít nhất một nhóm."
        case .specificUsers:
            return "Chọn ít nhất một người dùng cụ thể."
        case .friendsExcept:
            return "Chọn ít nhất một người để loại khỏi danh sách bạn bè."
        }
    }

    private func scheduleAudienceFriendSearch() {
        audienceFriendSearchTask?.cancel()
        let query = audienceUserSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            Task { await fetchAudienceFriends(query: "") }
            return
        }

        isLoadingAudienceFriends = true
        audienceFriendSearchTask = Task {
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else { return }
            await fetchAudienceFriends(query: query)
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

    private func fetchAudienceFriends(query: String) async {
        isLoadingAudienceFriends = true
        defer { isLoadingAudienceFriends = false }

        do {
            let results = try await fetchFriendsUseCase.execute(
                query: query,
                page: 0,
                limit: audienceFriendPageSize
            )
            guard !Task.isCancelled else { return }
            audienceFriendOptions = results
                .sorted {
                    $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
                }
            if query.isEmpty {
                hasLoadedAudienceFriends = true
            }
        } catch {
            guard !Task.isCancelled else { return }
            audienceFriendOptions = []
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
