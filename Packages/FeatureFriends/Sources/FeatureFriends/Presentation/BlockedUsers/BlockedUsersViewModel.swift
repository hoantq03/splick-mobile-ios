import Foundation
import Common

@MainActor
public final class BlockedUsersViewModel: ObservableObject {
    @Published var blockedUsers: [BlockedUser] = []
    @Published var state: LoadingState<[BlockedUser]> = .idle
    @Published var processingUserIds: Set<UUID> = []
    @Published var alertMessage: String?

    private let fetchBlockedUsersUseCase: FetchBlockedUsersUseCaseProtocol
    private let unblockUserUseCase: UnblockUserUseCaseProtocol

    public init(
        fetchBlockedUsersUseCase: FetchBlockedUsersUseCaseProtocol,
        unblockUserUseCase: UnblockUserUseCaseProtocol
    ) {
        self.fetchBlockedUsersUseCase = fetchBlockedUsersUseCase
        self.unblockUserUseCase = unblockUserUseCase
    }

    func load() async {
        state = .loading
        do {
            let items = try await fetchBlockedUsersUseCase.executeAll()
            blockedUsers = items
            state = .loaded(items)
        } catch {
            blockedUsers = []
            state = .failed(error.localizedDescription)
        }
    }

    func unblock(_ blocked: BlockedUser) async {
        let userId = blocked.user.id
        guard !processingUserIds.contains(userId) else { return }
        processingUserIds.insert(userId)
        defer { processingUserIds.remove(userId) }

        do {
            try await unblockUserUseCase.execute(userId: userId)
            blockedUsers.removeAll { $0.user.id == userId }
            state = blockedUsers.isEmpty ? .loaded([]) : .loaded(blockedUsers)
        } catch {
            alertMessage = error.localizedDescription
        }
    }
}
