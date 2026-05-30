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

final class MockRequestPhoneOtpUseCase: RequestPhoneOtpUseCaseProtocol, Sendable {
    func execute(phoneNumber: String) async throws {
        try await Task.sleep(for: .milliseconds(300))
    }
}

final class MockVerifyPhoneOtpUseCase: VerifyPhoneOtpUseCaseProtocol, Sendable {
    func execute(phoneNumber: String, otpCode: String) async throws -> AuthSession {
        try await Task.sleep(for: .seconds(1))
        return AuthSession(
            user: PreviewData.currentUser,
            token: AuthToken(accessToken: "mock-token", refreshToken: "mock-refresh", expiresIn: 3600)
        )
    }
}

final class MockGoogleSignInUseCase: GoogleSignInUseCaseProtocol, Sendable {
    func execute(idToken: String) async throws -> AuthSession {
        try await Task.sleep(for: .seconds(1))
        return AuthSession(
            user: PreviewData.currentUser,
            token: AuthToken(accessToken: "mock-token", refreshToken: "mock-refresh", expiresIn: 3600)
        )
    }
}

final class MockForgotPasswordUseCase: ForgotPasswordUseCaseProtocol, Sendable {
    func execute(email: String) async throws {
        try await Task.sleep(for: .milliseconds(300))
    }
}

final class MockResetPasswordUseCase: ResetPasswordUseCaseProtocol, Sendable {
    func execute(email: String, otpCode: String, newPassword: String) async throws -> AuthSession {
        try await Task.sleep(for: .seconds(1))
        return AuthSession(
            user: PreviewData.currentUser,
            token: AuthToken(accessToken: "mock-token", refreshToken: "mock-refresh", expiresIn: 3600)
        )
    }
}

final class MockRegisterUseCase: RegisterUseCaseProtocol, Sendable {
    func execute(
        channel: AuthRegistrationChannel,
        identifier: String,
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
            viewModel: LoginViewModel(
                loginUseCase: MockLoginUseCase(),
                requestPhoneOtpUseCase: MockRequestPhoneOtpUseCase(),
                verifyPhoneOtpUseCase: MockVerifyPhoneOtpUseCase(),
                googleSignInUseCase: MockGoogleSignInUseCase()
            ),
            registerViewModelFactory: {
                RegisterViewModel(
                    registerUseCase: MockRegisterUseCase(),
                    requestEmailOtpUseCase: MockRequestEmailOtpUseCase(),
                    requestPhoneOtpUseCase: MockRequestPhoneOtpUseCase()
                )
            },
            forgotPasswordViewModelFactory: {
                ForgotPasswordViewModel(
                    forgotPasswordUseCase: MockForgotPasswordUseCase(),
                    resetPasswordUseCase: MockResetPasswordUseCase()
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
                requestEmailOtpUseCase: MockRequestEmailOtpUseCase(),
                requestPhoneOtpUseCase: MockRequestPhoneOtpUseCase()
            )
        )
    }
}

#endif
