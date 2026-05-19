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

final class MockRequestEmailOtpUseCase: RequestEmailOtpUseCaseProtocol, Sendable {
    func execute(email: String) async throws {
        try await Task.sleep(for: .milliseconds(300))
    }
}

final class MockRegisterUseCase: RegisterUseCaseProtocol, Sendable {
    func execute(
        email: String,
        username: String,
        password: String,
        otpCode: String,
        displayName: String?
    ) async throws -> AuthSession {
        try await Task.sleep(for: .seconds(1))
        return AuthSession(
            user: PreviewData.currentUser,
            token: AuthToken(accessToken: "mock-token", refreshToken: "mock-refresh", expiresIn: 3600)
        )
    }
}

// MARK: - Previews

#Preview("Login") {
    NavigationStack {
        LoginView(
            viewModel: LoginViewModel(loginUseCase: MockLoginUseCase()),
            registerViewModelFactory: {
                RegisterViewModel(
                    registerUseCase: MockRegisterUseCase(),
                    requestEmailOtpUseCase: MockRequestEmailOtpUseCase()
                )
            }
        )
    }
}

#Preview("Register") {
    NavigationStack {
        RegisterView(
            viewModel: RegisterViewModel(
                registerUseCase: MockRegisterUseCase(),
                requestEmailOtpUseCase: MockRequestEmailOtpUseCase()
            )
        )
    }
}

#endif
