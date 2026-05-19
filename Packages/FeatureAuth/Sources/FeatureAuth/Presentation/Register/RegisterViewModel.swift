import Foundation
import SwiftUI
import Common
import DesignSystem
import SplickDomain

@MainActor
public final class RegisterViewModel: ObservableObject {
    enum Step {
        case accountDetails
        case otpVerification
    }

    @Published var channel: AuthRegistrationChannel = .email
    @Published var step: Step = .accountDetails
    @Published var email = ""
    @Published var phoneNumber = ""
    @Published var username = ""
    @Published var displayName = ""
    @Published var password = ""
    @Published var confirmPassword = ""
    @Published var otpCode = ""
    @Published var emailError: String?
    @Published var phoneError: String?
    @Published var usernameError: String?
    @Published var passwordError: String?
    @Published var confirmPasswordError: String?
    @Published var otpError: String?
    @Published var otpInfoMessage: String?
    @Published var state: LoadingState<AuthSession> = .idle
    @Published var passwordStrength: PasswordStrengthResult = .empty
    @Published var showPasswordRequirements = false

    @Published private(set) var emailStatus: FieldValidationStatus = .neutral
    @Published private(set) var phoneStatus: FieldValidationStatus = .neutral
    @Published private(set) var usernameStatus: FieldValidationStatus = .neutral
    @Published private(set) var passwordStatus: FieldValidationStatus = .neutral
    @Published private(set) var confirmPasswordStatus: FieldValidationStatus = .neutral

    private let registerUseCase: RegisterUseCaseProtocol
    private let requestEmailOtpUseCase: RequestEmailOtpUseCaseProtocol
    private let requestPhoneOtpUseCase: RequestPhoneOtpUseCaseProtocol

    private static let minUsernameLength = 3

    private var normalizedPhone: String { phoneNumber.normalizedE164Phone }

    var registrationIdentifier: String {
        switch channel {
        case .email: return email.trimmed
        case .phone: return normalizedPhone
        }
    }

    public init(
        registerUseCase: RegisterUseCaseProtocol,
        requestEmailOtpUseCase: RequestEmailOtpUseCaseProtocol,
        requestPhoneOtpUseCase: RequestPhoneOtpUseCaseProtocol
    ) {
        self.registerUseCase = registerUseCase
        self.requestEmailOtpUseCase = requestEmailOtpUseCase
        self.requestPhoneOtpUseCase = requestPhoneOtpUseCase
    }

    var canContinueAccountDetails: Bool {
        usernameError == nil
            && passwordError == nil
            && confirmPasswordError == nil
            && !username.trimmed.isEmpty
            && passwordStrength.isStrong
            && password == confirmPassword
            && identifierIsValid
    }

    private var identifierIsValid: Bool {
        switch channel {
        case .email:
            return emailError == nil && !email.trimmed.isEmpty
        case .phone:
            return phoneError == nil && !normalizedPhone.isEmpty
        }
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

    func validatePhoneField() {
        let value = normalizedPhone
        if value.isEmpty {
            phoneError = nil
            phoneStatus = .neutral
            return
        }
        if value.isValidE164Phone {
            phoneError = nil
            phoneStatus = .valid
        } else {
            phoneError = "Use international format, e.g. +84901234567"
            phoneStatus = .neutral
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
        switch channel {
        case .email: validateEmailField()
        case .phone:
            validatePhoneField()
            phoneNumber = normalizedPhone
        }
        validateUsernameField()
        validatePasswordField()
        validateConfirmPasswordField()
        guard canContinueAccountDetails else { return }

        state = .loading
        otpError = nil
        otpInfoMessage = nil
        do {
            switch channel {
            case .email:
                try await requestEmailOtpUseCase.execute(email: email.trimmed)
                otpInfoMessage = "Verification code sent. Check your email."
            case .phone:
                try await requestPhoneOtpUseCase.execute(phoneNumber: normalizedPhone)
                #if DEBUG
                otpInfoMessage = "Code sent via SMS. Check auth-service logs for [MockTwilio]."
                #else
                otpInfoMessage = "Verification code sent to your phone."
                #endif
            }
            step = .otpVerification
            otpCode = ""
            state = .idle
        } catch {
            applyRequestFailure(error, fallback: "Could not send verification code. Please try again.")
        }
    }

    func resendOtp() async {
        await requestOtpAndContinue()
    }

    func register() async {
        guard validateOtp() else { return }

        otpError = nil
        otpInfoMessage = nil
        state = .loading
        do {
            let session = try await registerUseCase.execute(
                channel: channel,
                identifier: registrationIdentifier,
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
            otpError = channel == .email
                ? "Enter the 6-digit code from your email"
                : "Enter the 6-digit code from SMS"
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
            case "phonenumber":
                phoneError = detail
                phoneStatus = .neutral
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
