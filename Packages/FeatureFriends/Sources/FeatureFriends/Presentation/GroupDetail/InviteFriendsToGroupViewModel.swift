import Foundation
import SplickDomain

@MainActor
final class InviteFriendsToGroupViewModel: ObservableObject {
    enum State: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
        case submitting
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var friends: [UserSummary] = []
    @Published var selectedIds: Set<UUID> = []
    @Published var alertMessage: String?
    @Published var successMessage: String?

    private let groupId: UUID
    private let fetchMyFriendsUseCase: FetchMyFriendsUseCaseProtocol
    private let inviteFriendsUseCase: InviteFriendsToGroupUseCaseProtocol
    private let onInvited: () -> Void

    init(
        groupId: UUID,
        fetchMyFriendsUseCase: FetchMyFriendsUseCaseProtocol,
        inviteFriendsUseCase: InviteFriendsToGroupUseCaseProtocol,
        onInvited: @escaping () -> Void
    ) {
        self.groupId = groupId
        self.fetchMyFriendsUseCase = fetchMyFriendsUseCase
        self.inviteFriendsUseCase = inviteFriendsUseCase
        self.onInvited = onInvited
    }

    func load() async {
        state = .loading
        do {
            friends = try await fetchMyFriendsUseCase.execute()
            state = .loaded
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func toggleSelection(_ userId: UUID) {
        if selectedIds.contains(userId) {
            selectedIds.remove(userId)
        } else {
            selectedIds.insert(userId)
        }
    }

    func submit() async {
        guard !selectedIds.isEmpty else {
            alertMessage = "Chọn ít nhất một bạn bè."
            return
        }
        state = .submitting
        do {
            let result = try await inviteFriendsUseCase.execute(
                groupId: groupId,
                userIds: Array(selectedIds)
            )
            let invitedCount = result.invited.count
            let skippedCount = result.skipped.count
            if invitedCount > 0 {
                successMessage = "Đã mời \(invitedCount) người vào nhóm."
                onInvited()
            } else if skippedCount > 0 {
                alertMessage = "Không thể mời các bạn đã chọn (có thể đã trong nhóm hoặc chưa kết bạn)."
            } else {
                alertMessage = "Không có ai được mời."
            }
            selectedIds.removeAll()
            state = .loaded
        } catch {
            alertMessage = error.localizedDescription
            state = .loaded
        }
    }
}
