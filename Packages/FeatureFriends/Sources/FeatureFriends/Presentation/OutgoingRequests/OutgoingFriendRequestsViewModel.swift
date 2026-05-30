import Foundation
import Common

@MainActor
public final class OutgoingFriendRequestsViewModel: ObservableObject {
    @Published var requests: [OutgoingFriendRequest] = []
    @Published var state: LoadingState<[OutgoingFriendRequest]> = .idle
    @Published var processingRequestIds: Set<UUID> = []
    @Published var alertMessage: String?

    private let fetchOutgoingUseCase: FetchOutgoingFriendRequestsUseCaseProtocol
    private let cancelUseCase: CancelFriendRequestUseCaseProtocol
    private let onFriendshipChanged: () -> Void

    public init(
        fetchOutgoingUseCase: FetchOutgoingFriendRequestsUseCaseProtocol,
        cancelUseCase: CancelFriendRequestUseCaseProtocol,
        onFriendshipChanged: @escaping () -> Void
    ) {
        self.fetchOutgoingUseCase = fetchOutgoingUseCase
        self.cancelUseCase = cancelUseCase
        self.onFriendshipChanged = onFriendshipChanged
    }

    func load() async {
        state = .loading
        do {
            let items = try await fetchOutgoingUseCase.executeAll()
            requests = items
            state = .loaded(items)
        } catch {
            requests = []
            state = .failed(error.localizedDescription)
        }
    }

    func cancel(_ request: OutgoingFriendRequest) async {
        guard !processingRequestIds.contains(request.id) else { return }
        processingRequestIds.insert(request.id)
        defer { processingRequestIds.remove(request.id) }

        do {
            try await cancelUseCase.execute(requestId: request.id)
            requests.removeAll { $0.id == request.id }
            state = .loaded(requests)
            onFriendshipChanged()
        } catch {
            alertMessage = error.localizedDescription
        }
    }
}
