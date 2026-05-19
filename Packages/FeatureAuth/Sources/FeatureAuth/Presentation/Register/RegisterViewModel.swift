import Foundation
import SwiftUI
import Common
import DesignSystem
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
    @Published var otpInfoMessage: String?
    @Published var state: LoadingState<AuthSession> = .idle
    @Published var passwordStrength: PasswordStrengthResult = .empty
    @Published var showPasswordRequirements = false

    @Published private(set) var emailStatus: FieldValidationStatus = .neutral
    @Published private(set) var usernameStatus: FieldValidationStatus = .neutral
    @Published private(set) var passwordStatus: FieldValidationStatus = .neutral
    @Published private(set) var confirmPasswordStatus: FieldValidationStatus = .neutral

    private let registerUseCase: RegisterUseCaseProtocol
    private let requestEmailOtpUseCase: RequestEmailOtpUseCaseProtocol

    private static let minUsernameLength = 3

    public init(
        registerUseCase: RegisterUseCaseProtocol,
        requestEmailOtpUseCase: RequestEmailOtpUseCaseProtocol
    ) {
        self.registerUseCase = registerUseCase
        self.requestEmailOtpUseCase = requestEmailOtpUseCase
    }

    var canContinueAccountDetails: Bool {
        emailError == nil
            && usernameError == nil
            && passwordError == nil
            && confirmPasswordError == nil
            && !email.trimmed.isEmpty
            && !username.trimmed.isEmpty
            && passwordStrength.isStrong
            && password == confirmPassword
    }

    func validateEmailField() {
        let value = email.trimmed
        if value.isEmpty {
            emailError = nil
            emailStatus = .neutral
            return
        }
        if value.isValidEmail {
            emailError = nil
            emailStatus = .valid
        } else {
            emailError = "Please enter a valid email"
            emailStatus = .neutral
        }
    }

    func validateUsernameField() {
        let value = username.trimmed
        if value.isEmpty {
            usernameError = nil
            usernameStatus = .neutral
            return
        }
        if value.count < Self.minUsernameLength {
            usernameError = "Username must be at least \(Self.minUsernameLength) characters"
            usernameStatus = .neutral
        } else if value.count > AppConstants.Validation.maxUsernameLength {
            usernameError = "Username is too long"
            usernameStatus = .neutral
        } else if !value.isValidUsername {
            usernameError = "Letters, numbers, and underscores only"
            usernameStatus = .neutral
        } else {
            usernameError = nil
            usernameStatus = .valid
        }
    }

    func validatePasswordField() {
        passwordStrength = PasswordStrengthValidator.evaluate(password)
        if password.isEmpty {
            passwordError = nil
            passwordStatus = .neutral
            return
        }
        if passwordStrength.isStrong {
            passwordError = nil
            passwordStatus = .valid
        } else {
            passwordError = nil
            passwordStatus = .warning
        }
        validateConfirmPasswordField()
    }

    func validateConfirmPasswordField() {
        if confirmPassword.isEmpty {
            confirmPasswordError = nil
            confirmPasswordStatus = .neutral
            return
        }
        if confirmPassword == password, passwordStrength.isStrong {
            confirmPasswordError = nil
            confirmPasswordStatus = .valid
        } else if confirmPassword == password {
            confirmPasswordError = nil
            confirmPasswordStatus = .neutral
        } else {
            confirmPasswordError = "Passwords don't match"
            confirmPasswordStatus = .neutral
        }
    }

    func requestOtpAndContinue() async {
        validateEmailField()
        validateUsernameField()
        validatePasswordField()
        validateConfirmPasswordField()
        guard canContinueAccountDetails else { return }

        state = .loading
        otpError = nil
        otpInfoMessage = nil
        do {
            try await requestEmailOtpUseCase.execute(email: email.trimmed)
            step = .emailOtp
            otpCode = ""
            otpInfoMessage = "Verification code sent. Check your email."
            state = .idle
        } catch {
            applyRequestFailure(error, fallback: "Could not send verification code. Please try again.")
        }
    }

    func resendOtp() async {
        state = .loading
        otpError = nil
        otpInfoMessage = nil
        do {
            try await requestEmailOtpUseCase.execute(email: email.trimmed)
            otpCode = ""
            #if DEBUG
            otpInfoMessage = "A new code was sent. Check Mailpit at http://localhost:8025 or auth-service logs."
            #else
            otpInfoMessage = "A new code was sent. Check your email."
            #endif
            state = .idle
        } catch let error as NetworkError where error == .rateLimited {
            otpError = error.userMessage
            state = .idle
        } catch let error as NetworkError {
            if case .unknown(let message) = error {
                otpError = message
            } else {
                state = .failed(error.userMessage)
            }
            state = .idle
        } catch let error as AuthError {
            state = .failed(error.userMessage)
            state = .idle
        } catch {
            otpError = "Could not resend verification code."
            state = .idle
        }
    }

    func register() async {
        guard validateOtp() else { return }

        otpError = nil
        otpInfoMessage = nil
        state = .loading
        do {
            let session = try await registerUseCase.execute(
                email: email.trimmed,
                username: username.trimmed,
                password: password,
                otpCode: otpCode,
                displayName: displayName.trimmed
            )
            state = .loaded(session)
            Log.info("Registration successful for \(session.user.username)", category: .auth)
        } catch let error as AuthError {
            switch error {
            case .invalidOtp(let message):
                otpError = message
                state = .idle
            case .emailAlreadyExists:
                state = .failed(error.userMessage)
            default:
                state = .failed(error.userMessage)
            }
        } catch let error as NetworkError {
            if case .decodingFailed = error {
                state = .failed(error.userMessage)
            } else {
                otpError = error.userMessage
                state = .idle
            }
        } catch {
            state = .failed("An unexpected error occurred.")
            Log.error(error, category: .auth)
        }
    }

    func goBackToAccountDetails() {
        step = .accountDetails
        otpCode = ""
        otpError = nil
        otpInfoMessage = nil
        if case .failed = state {
            state = .idle
        }
    }

    private func validateOtp() -> Bool {
        otpError = nil
        if otpCode.count != 6 {
            otpError = "Enter the 6-digit code from your email"
            return false
        }
        return true
    }

    private func applyRequestFailure(_ error: Error, fallback: String) {
        if let authError = error as? AuthError {
            state = .failed(authError.userMessage)
            return
        }
        if let networkError = error as? NetworkError {
            if case .unknown(let message) = networkError {
                applyValidationMessage(message)
                return
            }
            state = .failed(networkError.userMessage)
            return
        }
        state = .failed(fallback)
        Log.error(error, category: .auth)
    }

    private func applyValidationMessage(_ message: String) {
        let parts = message.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        var applied = false

        for part in parts {
            let segments = part.split(separator: ":", maxSplits: 1).map(String.init)
            guard segments.count == 2 else { continue }
            let field = segments[0].lowercased()
            let detail = segments[1].trimmingCharacters(in: .whitespaces)

            switch field {
            case "email":
                emailError = detail
                emailStatus = .neutral
                applied = true
            case "username":
                usernameError = detail
                usernameStatus = .neutral
                applied = true
            case "password":
                passwordError = detail
                passwordStatus = .warning
                applied = true
            default:
                break
            }
        }

        state = applied ? .idle : .failed(message)
    }
}
