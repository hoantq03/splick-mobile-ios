import Foundation
import UIKit
import Common
import SplickDomain

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
    @Published var billTotalText = ""
    @Published var splitMode: ComposeBillSplitMode = .equal
    @Published var percentageTexts: [UUID: String] = [:]
    @Published var exactAmountTexts: [UUID: String] = [:]
    @Published private(set) var isSearchingFriends = false
    @Published private(set) var submitState: LoadingState<Post> = .idle

    public let previewImage: UIImage?
    public let videoURL: URL?
    public let mediaType: PostMediaType

    private let createPostUseCase: CreatePostUseCaseProtocol
    private let fetchFriendsUseCase: FetchFriendsUseCaseProtocol
    private let currentUser: UserSummary?
    private let currentUserId: UUID?
    private var friendSearchTask: Task<Void, Never>?

    public init(
        previewImage: UIImage?,
        videoURL: URL?,
        mediaType: PostMediaType,
        createPostUseCase: CreatePostUseCaseProtocol,
        fetchFriendsUseCase: FetchFriendsUseCaseProtocol,
        currentUser: UserSummary?,
        currentUserId: UUID?
    ) {
        self.previewImage = previewImage
        self.videoURL = videoURL
        self.mediaType = mediaType
        self.createPostUseCase = createPostUseCase
        self.fetchFriendsUseCase = fetchFriendsUseCase
        self.currentUser = currentUser
        self.currentUserId = currentUserId ?? currentUser?.id
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

    func updateFriendSearch(_ query: String) {
        friendSearchQuery = query
        friendSearchTask?.cancel()

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            friendSearchResults = []
            isSearchingFriends = false
            return
        }

        isSearchingFriends = true
        friendSearchTask = Task {
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else { return }
            do {
                let results = try await fetchFriendsUseCase.execute(query: trimmed, page: 0, limit: 12)
                guard !Task.isCancelled else { return }
                friendSearchResults = results.filter { !selectedCompanionIds.contains($0.id) }
            } catch {
                friendSearchResults = []
            }
            isSearchingFriends = false
        }
    }

    func addCompanion(_ user: UserSummary) {
        guard !selectedCompanionIds.contains(user.id) else { return }
        selectedCompanions.append(user)
        friendSearchResults.removeAll { $0.id == user.id }
        friendSearchQuery = ""
        friendSearchResults = []
    }

    func removeCompanion(_ user: UserSummary) {
        selectedCompanions.removeAll { $0.id == user.id }
        percentageTexts.removeValue(forKey: user.id)
        exactAmountTexts.removeValue(forKey: user.id)
    }

    func submit() async -> Bool {
        guard let imageData = imagePayload else {
            submitState = .failed("Không thể xử lý ảnh/video.")
            return false
        }

        if enableBillSplit {
            guard buildBillSplit() != nil else {
                submitState = .failed("Kiểm tra lại thông tin chia bill.")
                return false
            }
            if billSplitParticipants.isEmpty {
                submitState = .failed("Chọn ít nhất một người để chia bill.")
                return false
            }
        }

        let input = CreatePostInput(
            imageData: imageData,
            mediaType: mediaType,
            videoURL: videoURL,
            caption: caption.nilIfBlank,
            companionIds: selectedCompanions.map(\.id),
            checkInPlace: location.nilIfBlank,
            feedKind: enableBillSplit ? .shareBill : .checkIn,
            billSplit: enableBillSplit ? buildBillSplit() : nil
        )

        submitState = .loading
        do {
            let post = try await createPostUseCase.execute(input)
            submitState = .loaded(post)
            return true
        } catch {
            submitState = .failed(error.localizedDescription)
            return false
        }
    }

    private var imagePayload: Data? {
        if let previewImage,
           let data = previewImage.jpegData(compressionQuality: AppConstants.Media.compressionQuality) {
            return data
        }
        if mediaType == .video, let videoURL,
           let data = try? Data(contentsOf: videoURL) {
            return data
        }
        return nil
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
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
