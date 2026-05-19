import Foundation
import SwiftUI
import Common
import DesignSystem
import SplickDomain

@MainActor
public final class LoginViewModel: ObservableObject {
    enum Step {
        case credentials
        case phoneOtp
    }

    @Published var signInMethod: AuthSignInMethod = .email
    @Published var step: Step = .credentials
    @Published var email = ""
    @Published var password = ""
    @Published var phoneNumber = ""
    @Published var otpCode = ""
    @Published var emailError: String?
    @Published var passwordError: String?
    @Published var phoneError: String?
    @Published var otpError: String?
    @Published var otpInfoMessage: String?
    @Published var state: LoadingState<AuthSession> = .idle
    @Published var showRegistration = false

    @Published private(set) var phoneStatus: FieldValidationStatus = .neutral

    private let loginUseCase: LoginUseCaseProtocol
    private let requestPhoneOtpUseCase: RequestPhoneOtpUseCaseProtocol
    private let verifyPhoneOtpUseCase: VerifyPhoneOtpUseCaseProtocol
    private let googleSignInUseCase: GoogleSignInUseCaseProtocol
    private weak var googleSignInPresenter: GoogleSignInPresenting?

    private var normalizedPhone: String { phoneNumber.normalizedE164Phone }

    public var isGoogleSignInAvailable: Bool {
        googleSignInPresenter?.isAvailable == true
    }

    public init(
        loginUseCase: LoginUseCaseProtocol,
        requestPhoneOtpUseCase: RequestPhoneOtpUseCaseProtocol,
        verifyPhoneOtpUseCase: VerifyPhoneOtpUseCaseProtocol,
        googleSignInUseCase: GoogleSignInUseCaseProtocol,
        googleSignInPresenter: GoogleSignInPresenting? = nil
    ) {
        self.loginUseCase = loginUseCase
        self.requestPhoneOtpUseCase = requestPhoneOtpUseCase
        self.verifyPhoneOtpUseCase = verifyPhoneOtpUseCase
        self.googleSignInUseCase = googleSignInUseCase
        self.googleSignInPresenter = googleSignInPresenter
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

    func requestPhoneOtpAndContinue() async {
        validatePhoneField()
        guard phoneError == nil, !normalizedPhone.isEmpty else { return }

        state = .loading
        otpError = nil
        otpInfoMessage = nil
        do {
            try await requestPhoneOtpUseCase.execute(phoneNumber: normalizedPhone)
            phoneNumber = normalizedPhone
            step = .phoneOtp
            otpCode = ""
            #if DEBUG
            otpInfoMessage = "Code sent via SMS. Check auth-service logs for [MockTwilio]."
            #else
            otpInfoMessage = "Verification code sent to your phone."
            #endif
            state = .idle
        } catch let error as AuthError {
            applyOtpRequestError(error)
        } catch let error as NetworkError {
            state = .failed(error.userMessage)
        } catch {
            state = .failed("Could not send verification code.")
        }
    }

    func resendPhoneOtp() async {
        await requestPhoneOtpAndContinue()
    }

    func verifyPhoneOtp() async {
        guard otpCode.count == 6 else {
            otpError = "Enter the 6-digit code from SMS"
            return
        }

        otpError = nil
        state = .loading
        do {
            let session = try await verifyPhoneOtpUseCase.execute(
                phoneNumber: normalizedPhone,
                otpCode: otpCode
            )
            state = .loaded(session)
        } catch let error as AuthError {
            applyOtpVerifyError(error)
        } catch let error as NetworkError where error.isConnectivityIssue {
            state = .failed(error.userMessage)
        } catch {
            otpError = AuthError.invalidCredentials.userMessage
            state = .idle
        }
    }

    func goBackToCredentials() {
        step = .credentials
        otpCode = ""
        otpError = nil
        otpInfoMessage = nil
        if case .failed = state {
            state = .idle
        }
    }

    func signInWithGoogle() async {
        guard let googleSignInPresenter, googleSignInPresenter.isAvailable else {
            state = .failed("Google Sign-In is not configured.")
            return
        }

        state = .loading
        do {
            let idToken = try await googleSignInPresenter.fetchIdToken()
            let session = try await googleSignInUseCase.execute(idToken: idToken)
            state = .loaded(session)
            Log.info("Google sign-in successful for \(session.user.username)", category: .auth)
        } catch let error as NetworkError where error.isConnectivityIssue {
            state = .failed(error.userMessage)
        } catch let error as NetworkError {
            state = .failed(error.userMessage)
        } catch let error as AuthError {
            state = .failed(error.userMessage)
        } catch {
            let nsError = error as NSError
            if nsError.domain == "com.google.GIDSignIn" && nsError.code == -5 {
                state = .failed("Google sign-in was cancelled.")
            } else {
                state = .failed(error.localizedDescription)
            }
        }
    }

    func login() async {
        guard validateEmailLogin() else { return }

        state = .loading
        do {
            let session = try await loginUseCase.execute(
                email: email.trimmed,
                password: password
            )
            state = .loaded(session)
            Log.info("Login successful for \(session.user.username)", category: .auth)
        } catch let error as AuthError {
            state = .failed(error.userMessage)
        } catch let error as NetworkError where error.isConnectivityIssue {
            state = .failed(error.userMessage)
        } catch {
            state = .failed(AuthError.invalidCredentials.userMessage)
        }
    }

    private func applyOtpRequestError(_ error: AuthError) {
        if error.shouldShowOnOtpStep {
            otpError = error.userMessage
            state = .idle
        } else {
            state = .failed(error.userMessage)
        }
    }

    private func applyOtpVerifyError(_ error: AuthError) {
        if error.shouldShowOnOtpStep {
            otpError = error.userMessage
            state = .idle
        } else {
            state = .failed(error.userMessage)
        }
    }

    private func validateEmailLogin() -> Bool {
        var isValid = true
        emailError = nil
        passwordError = nil

        if email.trimmed.isEmpty {
            emailError = "Email is required"
            isValid = false
        } else if !email.trimmed.isValidEmail {
            emailError = "Please enter a valid email"
            isValid = false
        }

        if password.isEmpty {
            passwordError = "Password is required"
            isValid = false
        }

        return isValid
    }
}
