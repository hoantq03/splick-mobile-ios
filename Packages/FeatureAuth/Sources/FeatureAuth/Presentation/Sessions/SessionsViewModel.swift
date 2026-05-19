import Foundation
import Common
import SplickDomain

@MainActor
public final class SessionsViewModel: ObservableObject {
    @Published public private(set) var sessions: [UserSession] = []
    @Published public private(set) var loadingState: LoadingState<[UserSession]> = .idle
    @Published public var errorMessage: String?

    private let listSessionsUseCase: ListSessionsUseCaseProtocol
    private let revokeSessionUseCase: RevokeSessionUseCaseProtocol
    private let revokeAllSessionsUseCase: RevokeAllSessionsUseCaseProtocol
    private let onSignedOutEverywhere: () -> Void

    public init(
        listSessionsUseCase: ListSessionsUseCaseProtocol,
        revokeSessionUseCase: RevokeSessionUseCaseProtocol,
        revokeAllSessionsUseCase: RevokeAllSessionsUseCaseProtocol,
        onSignedOutEverywhere: @escaping () -> Void
    ) {
        self.listSessionsUseCase = listSessionsUseCase
        self.revokeSessionUseCase = revokeSessionUseCase
        self.revokeAllSessionsUseCase = revokeAllSessionsUseCase
        self.onSignedOutEverywhere = onSignedOutEverywhere
    }

    public func load() async {
        loadingState = .loading
        errorMessage = nil
        do {
            let loaded = try await listSessionsUseCase.execute()
            sessions = loaded
            loadingState = .loaded(loaded)
        } catch {
            loadingState = .failed("Could not load devices.")
            errorMessage = (error as? AuthError)?.userMessage ?? "Could not load devices."
        }
    }

    public func revoke(session: UserSession) async {
        guard !session.isCurrent else { return }
        errorMessage = nil
        do {
            try await revokeSessionUseCase.execute(sessionId: session.id)
            await load()
        } catch {
            errorMessage = "Could not sign out that device."
        }
    }

    public func revokeAll() async {
        errorMessage = nil
        do {
            try await revokeAllSessionsUseCase.execute()
            onSignedOutEverywhere()
        } catch {
            errorMessage = "Could not sign out all devices."
        }
    }
}
