import Foundation
import SwiftUI
import Common
import SplickDomain

@MainActor
public final class RegisterViewModel: ObservableObject {
    enum Step {
        case accountDetails
        case emailOtp
    }

    @Published var step: Step = .accountDetails
    @Published var email = ""
    @Published var username = ""
    @Published var displayName = ""
    @Published var password = ""
    @Published var confirmPassword = ""
    @Published var otpCode = ""
    @Published var emailError: String?
    @Published var usernameError: String?
    @Published var passwordError: String?
    @Published var confirmPasswordError: String?
    @Published var otpError: String?
    @Published var state: LoadingState<AuthSession> = .idle

    private let registerUseCase: RegisterUseCaseProtocol
    private let requestEmailOtpUseCase: RequestEmailOtpUseCaseProtocol

    public init(
        registerUseCase: RegisterUseCaseProtocol,
        requestEmailOtpUseCase: RequestEmailOtpUseCaseProtocol
    ) {
        self.registerUseCase = registerUseCase
        self.requestEmailOtpUseCase = requestEmailOtpUseCase
    }

    func requestOtpAndContinue() async {
        guard AppConstants.Dev.useMockData || validateAccountDetails() else { return }

        state = .loading
        otpError = nil
        do {
            if !AppConstants.Dev.useMockData {
                try await requestEmailOtpUseCase.execute(email: email.trimmed)
            }
            step = .emailOtp
            state = .idle
        } catch let error as NetworkError {
            state = .failed(error.userMessage)
        } catch {
            state = .failed("Could not send verification code. Please try again.")
            Log.error(error, category: .auth)
        }
    }

    func resendOtp() async {
        guard !AppConstants.Dev.useMockData else { return }
        state = .loading
        otpError = nil
        do {
            try await requestEmailOtpUseCase.execute(email: email.trimmed)
            state = .idle
        } catch let error as NetworkError {
            state = .failed(error.userMessage)
        } catch {
            state = .failed("Could not resend verification code.")
        }
    }

    func register() async {
        guard AppConstants.Dev.useMockData || validateOtp() else { return }

        state = .loading
        do {
            let session = try await registerUseCase.execute(
                email: email.trimmed,
                username: username.trimmed,
                password: password,
                otpCode: AppConstants.Dev.useMockData ? "000000" : otpCode,
                displayName: displayName.trimmed
            )
            state = .loaded(session)
            Log.info("Registration successful for \(session.user.username)", category: .auth)
        } catch let error as NetworkError {
            state = .failed(error.userMessage)
        } catch let error as AuthError {
            state = .failed(error.userMessage)
        } catch {
            state = .failed("An unexpected error occurred.")
            Log.error(error, category: .auth)
        }
    }

    func goBackToAccountDetails() {
        step = .accountDetails
        otpCode = ""
        otpError = nil
        if case .failed = state {
            state = .idle
        }
    }

    private func validateAccountDetails() -> Bool {
        var isValid = true
        emailError = nil
        usernameError = nil
        passwordError = nil
        confirmPasswordError = nil

        if email.trimmed.isEmpty {
            emailError = "Email is required"
            isValid = false
        } else if !email.trimmed.isValidEmail {
            emailError = "Please enter a valid email"
            isValid = false
        }

        if username.trimmed.isEmpty {
            usernameError = "Username is required"
            isValid = false
        } else if username.trimmed.count > AppConstants.Validation.maxUsernameLength {
            usernameError = "Username is too long"
            isValid = false
        }

        if password.isEmpty {
            passwordError = "Password is required"
            isValid = false
        } else if password.count < AppConstants.Validation.minPasswordLength {
            passwordError = "Password must be at least \(AppConstants.Validation.minPasswordLength) characters"
            isValid = false
        }

        if confirmPassword != password {
            confirmPasswordError = "Passwords don't match"
            isValid = false
        }

        return isValid
    }

    private func validateOtp() -> Bool {
        otpError = nil
        if otpCode.count != 6 {
            otpError = "Enter the 6-digit code from your email"
            return false
        }
        return true
    }
}
