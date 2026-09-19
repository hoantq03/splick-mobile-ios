import Foundation
import Common
import SplickDomain

@MainActor
public final class IncomingFriendRequestsViewModel: ObservableObject {
    @Published var requests: [IncomingFriendRequest] = []
    @Published var state: LoadingState<[IncomingFriendRequest]> = .idle
    @Published var processingRequestIds: Set<UUID> = []
    @Published var alertMessage: String?

    private let fetchIncomingUseCase: FetchIncomingFriendRequestsUseCaseProtocol
    private let acceptUseCase: AcceptFriendRequestUseCaseProtocol
    private let rejectUseCase: RejectFriendRequestUseCaseProtocol
    private let onRelationshipChanged: (UUID, FriendRelationStatus) -> Void

    public init(
        fetchIncomingUseCase: FetchIncomingFriendRequestsUseCaseProtocol,
        acceptUseCase: AcceptFriendRequestUseCaseProtocol,
        rejectUseCase: RejectFriendRequestUseCaseProtocol,
        onRelationshipChanged: @escaping (UUID, FriendRelationStatus) -> Void
    ) {
        self.fetchIncomingUseCase = fetchIncomingUseCase
        self.acceptUseCase = acceptUseCase
        self.rejectUseCase = rejectUseCase
        self.onRelationshipChanged = onRelationshipChanged
    }

    func load() async {
        if requests.isEmpty {
            state = .loading
        }
        do {
            let items = try await fetchIncomingUseCase.executeAll()
            requests = items
            state = .loaded(items)
        } catch {
            if requests.isEmpty {
                requests = []
                state = .failed(error.localizedDescription)
            } else {
                state = .loaded(requests)
            }
        }
    }

    func accept(_ request: IncomingFriendRequest) async {
        await respond(to: request, successStatus: .friends) {
            try await acceptUseCase.execute(requestId: request.id)
        }
    }

    func reject(_ request: IncomingFriendRequest) async {
        await respond(to: request, successStatus: .none) {
            try await rejectUseCase.execute(requestId: request.id)
        }
    }

    private func respond(
        to request: IncomingFriendRequest,
        successStatus: FriendRelationStatus,
        action: () async throws -> Void
    ) async {
        guard !processingRequestIds.contains(request.id) else { return }
        processingRequestIds.insert(request.id)

        let userId = request.requester.id
        removeRequestLocally(request)
        onRelationshipChanged(userId, successStatus)

        defer { processingRequestIds.remove(request.id) }

        do {
            try await action()
        } catch {
            restoreRequestLocally(request)
            onRelationshipChanged(userId, .requestReceived)
            alertMessage = error.localizedDescription
        }
    }

    private func removeRequestLocally(_ request: IncomingFriendRequest) {
        requests.removeAll { $0.id == request.id }
        state = .loaded(requests)
    }

    private func restoreRequestLocally(_ request: IncomingFriendRequest) {
        guard !requests.contains(where: { $0.id == request.id }) else { return }
        requests.append(request)
        requests.sort { $0.requester.displayName < $1.requester.displayName }
        state = .loaded(requests)
    }
}
