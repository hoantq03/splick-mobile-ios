import Foundation
import Common
import SplickDomain

@MainActor
public final class BlockedUsersViewModel: ObservableObject {
    @Published var blockedUsers: [BlockedUser] = []
    @Published var state: LoadingState<[BlockedUser]> = .idle
    @Published var processingUserIds: Set<UUID> = []
    @Published var alertMessage: String?

    private let fetchBlockedUsersUseCase: FetchBlockedUsersUseCaseProtocol
    private let unblockUserUseCase: UnblockUserUseCaseProtocol
    private let onRelationshipChanged: (UUID, FriendRelationStatus) -> Void

    public init(
        fetchBlockedUsersUseCase: FetchBlockedUsersUseCaseProtocol,
        unblockUserUseCase: UnblockUserUseCaseProtocol,
        onRelationshipChanged: @escaping (UUID, FriendRelationStatus) -> Void = { _, _ in }
    ) {
        self.fetchBlockedUsersUseCase = fetchBlockedUsersUseCase
        self.unblockUserUseCase = unblockUserUseCase
        self.onRelationshipChanged = onRelationshipChanged
    }

    func load() async {
        if blockedUsers.isEmpty {
            state = .loading
        }
        do {
            let items = try await fetchBlockedUsersUseCase.executeAll()
            blockedUsers = items
            state = .loaded(items)
        } catch {
            if blockedUsers.isEmpty {
                blockedUsers = []
                state = .failed(error.localizedDescription)
            } else {
                state = .loaded(blockedUsers)
            }
        }
    }

    func unblock(_ blocked: BlockedUser) async {
        let userId = blocked.user.id
        guard !processingUserIds.contains(userId) else { return }
        processingUserIds.insert(userId)

        removeBlockedUserLocally(blocked)
        onRelationshipChanged(userId, .none)

        defer { processingUserIds.remove(userId) }

        do {
            try await unblockUserUseCase.execute(userId: userId)
        } catch {
            restoreBlockedUserLocally(blocked)
            onRelationshipChanged(userId, .blocked)
            alertMessage = error.localizedDescription
        }
    }

    private func removeBlockedUserLocally(_ blocked: BlockedUser) {
        blockedUsers.removeAll { $0.user.id == blocked.user.id }
        state = blockedUsers.isEmpty ? .loaded([]) : .loaded(blockedUsers)
    }

    private func restoreBlockedUserLocally(_ blocked: BlockedUser) {
        guard !blockedUsers.contains(where: { $0.user.id == blocked.user.id }) else { return }
        blockedUsers.append(blocked)
        blockedUsers.sort { $0.user.displayName < $1.user.displayName }
        state = .loaded(blockedUsers)
    }
}
