import Foundation
import Common
import Localization
import SplickDomain

@MainActor
public final class SessionsViewModel: ObservableObject {
    @Published public private(set) var sessions: [UserSession] = []
    @Published public private(set) var loadingState: LoadingState<[UserSession]> = .idle
    @Published public var errorMessage: String?

    private let listSessionsUseCase: ListSessionsUseCaseProtocol
    private let revokeSessionUseCase: RevokeSessionUseCaseProtocol
    private let revokeAllSessionsUseCase: RevokeAllSessionsUseCaseProtocol
    private let languageService: LanguageService
    private let onSignedOutEverywhere: () -> Void
    private var isRefreshing = false

    public init(
        listSessionsUseCase: ListSessionsUseCaseProtocol,
        revokeSessionUseCase: RevokeSessionUseCaseProtocol,
        revokeAllSessionsUseCase: RevokeAllSessionsUseCaseProtocol,
        languageService: LanguageService,
        onSignedOutEverywhere: @escaping () -> Void
    ) {
        self.listSessionsUseCase = listSessionsUseCase
        self.revokeSessionUseCase = revokeSessionUseCase
        self.revokeAllSessionsUseCase = revokeAllSessionsUseCase
        self.languageService = languageService
        self.onSignedOutEverywhere = onSignedOutEverywhere
    }

    public func load(isPullToRefresh: Bool = false) async {
        if isPullToRefresh {
            guard !isRefreshing else { return }
            isRefreshing = true
            defer { isRefreshing = false }
        } else if sessions.isEmpty {
            loadingState = .loading
        }

        errorMessage = nil
        do {
            let loaded = try await listSessionsUseCase.execute()
            sessions = loaded.sorted { lhs, rhs in
                if lhs.isCurrent != rhs.isCurrent {
                    return lhs.isCurrent
                }
                return lhs.createdAt > rhs.createdAt
            }
            loadingState = .loaded(sessions)
        } catch {
            guard !error.isRequestCancellation else { return }
            if isPullToRefresh, !sessions.isEmpty {
                loadingState = .loaded(sessions)
            } else {
                let message = (error as? AuthError)?.userMessage ?? languageService.text(.sessionsLoadFailed)
                loadingState = .failed(message)
                errorMessage = message
            }
        }
    }

    public func revoke(session: UserSession) async {
        guard !session.isCurrent else { return }
        errorMessage = nil
        do {
            try await revokeSessionUseCase.execute(sessionId: session.id)
            await load()
        } catch {
            errorMessage = languageService.text(.sessionsRevokeFailed)
        }
    }

    public func revokeAll() async {
        errorMessage = nil
        do {
            try await revokeAllSessionsUseCase.execute()
            onSignedOutEverywhere()
        } catch {
            errorMessage = languageService.text(.sessionsRevokeAllFailed)
        }
    }
}
