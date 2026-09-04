import Foundation
import Common
import SplickDomain

@MainActor
public final class OutgoingFriendRequestsViewModel: ObservableObject {
    @Published var requests: [OutgoingFriendRequest] = []
    @Published var state: LoadingState<[OutgoingFriendRequest]> = .idle
    @Published var processingRequestIds: Set<UUID> = []
    @Published var alertMessage: String?

    private let fetchOutgoingUseCase: FetchOutgoingFriendRequestsUseCaseProtocol
    private let cancelUseCase: CancelFriendRequestUseCaseProtocol
    private let onRelationshipChanged: (UUID, FriendRelationStatus) -> Void

    public init(
        fetchOutgoingUseCase: FetchOutgoingFriendRequestsUseCaseProtocol,
        cancelUseCase: CancelFriendRequestUseCaseProtocol,
        onRelationshipChanged: @escaping (UUID, FriendRelationStatus) -> Void
    ) {
        self.fetchOutgoingUseCase = fetchOutgoingUseCase
        self.cancelUseCase = cancelUseCase
        self.onRelationshipChanged = onRelationshipChanged
    }

    func load() async {
        if requests.isEmpty {
            state = .loading
        }
        do {
            let items = try await fetchOutgoingUseCase.executeAll()
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

    func cancel(_ request: OutgoingFriendRequest) async {
        guard !processingRequestIds.contains(request.id) else { return }
        processingRequestIds.insert(request.id)

        let userId = request.addressee.id
        removeRequestLocally(request)
        onRelationshipChanged(userId, .none)

        defer { processingRequestIds.remove(request.id) }

        do {
            try await cancelUseCase.execute(requestId: request.id)
        } catch {
            restoreRequestLocally(request)
            onRelationshipChanged(userId, .requestSent)
            alertMessage = error.localizedDescription
        }
    }

    private func removeRequestLocally(_ request: OutgoingFriendRequest) {
        requests.removeAll { $0.id == request.id }
        state = .loaded(requests)
    }

    private func restoreRequestLocally(_ request: OutgoingFriendRequest) {
        guard !requests.contains(where: { $0.id == request.id }) else { return }
        requests.append(request)
        requests.sort { $0.addressee.displayName < $1.addressee.displayName }
        state = .loaded(requests)
    }
}
