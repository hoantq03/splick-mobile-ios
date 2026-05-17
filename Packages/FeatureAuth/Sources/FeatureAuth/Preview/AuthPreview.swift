import Foundation
import SwiftUI
import SplickDomain

#if DEBUG

// MARK: - Mock Use Cases

final class MockLoginUseCase: LoginUseCaseProtocol, Sendable {
    func execute(email: String, password: String) async throws -> AuthSession {
        try await Task.sleep(for: .seconds(1))
        return AuthSession(
            user: PreviewData.currentUser,
            token: AuthToken(accessToken: "mock-token", refreshToken: "mock-refresh", expiresIn: 3600)
        )
    }
}

final class MockRegisterUseCase: RegisterUseCaseProtocol, Sendable {
    func execute(email: String, username: String, password: String) async throws -> AuthSession {
        try await Task.sleep(for: .seconds(1))
        return AuthSession(
            user: PreviewData.currentUser,
            token: AuthToken(accessToken: "mock-token", refreshToken: "mock-refresh", expiresIn: 3600)
        )
    }
}

// MARK: - Previews

#Preview("Login") {
    LoginView(viewModel: LoginViewModel(loginUseCase: MockLoginUseCase()))
}

#Preview("Register") {
    NavigationStack {
        RegisterView(viewModel: RegisterViewModel(registerUseCase: MockRegisterUseCase()))
    }
}

#endif
