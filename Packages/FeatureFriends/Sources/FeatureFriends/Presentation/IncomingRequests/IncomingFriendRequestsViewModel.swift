import Foundation
import Common

@MainActor
public final class IncomingFriendRequestsViewModel: ObservableObject {
    @Published var requests: [IncomingFriendRequest] = []
    @Published var state: LoadingState<[IncomingFriendRequest]> = .idle
    @Published var processingRequestIds: Set<UUID> = []
    @Published var alertMessage: String?

    private let fetchIncomingUseCase: FetchIncomingFriendRequestsUseCaseProtocol
    private let acceptUseCase: AcceptFriendRequestUseCaseProtocol
    private let rejectUseCase: RejectFriendRequestUseCaseProtocol
    private let onFriendshipChanged: () -> Void

    public init(
        fetchIncomingUseCase: FetchIncomingFriendRequestsUseCaseProtocol,
        acceptUseCase: AcceptFriendRequestUseCaseProtocol,
        rejectUseCase: RejectFriendRequestUseCaseProtocol,
        onFriendshipChanged: @escaping () -> Void
    ) {
        self.fetchIncomingUseCase = fetchIncomingUseCase
        self.acceptUseCase = acceptUseCase
        self.rejectUseCase = rejectUseCase
        self.onFriendshipChanged = onFriendshipChanged
    }

    func load() async {
        state = .loading
        do {
            let items = try await fetchIncomingUseCase.execute(page: 0, size: 50)
            requests = items
            state = .loaded(items)
        } catch {
            requests = []
            state = .failed(error.localizedDescription)
        }
    }

    func accept(_ request: IncomingFriendRequest) async {
        let accepted = await respond(to: request) {
            try await acceptUseCase.execute(requestId: request.id)
        }
        if accepted {
            onFriendshipChanged()
        }
    }

    func reject(_ request: IncomingFriendRequest) async {
        await respond(to: request) {
            try await rejectUseCase.execute(requestId: request.id)
        }
    }

    @discardableResult
    private func respond(to request: IncomingFriendRequest, action: () async throws -> Void) async -> Bool {
        guard !processingRequestIds.contains(request.id) else { return false }
        processingRequestIds.insert(request.id)
        defer { processingRequestIds.remove(request.id) }

        do {
            try await action()
            requests.removeAll { $0.id == request.id }
            state = .loaded(requests)
            return true
        } catch {
            alertMessage = error.localizedDescription
            return false
        }
    }
}
