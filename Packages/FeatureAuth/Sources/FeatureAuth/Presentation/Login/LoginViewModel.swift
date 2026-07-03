import Foundation
import SwiftUI
import Common
import DesignSystem
import Localization
import SplickDomain

@MainActor
public final class LoginViewModel: ObservableObject {
    enum Step {
        case credentials
        case phoneOtp
        case registerOtp
    }

    enum IdentifierLookupState: Equatable {
        case pending
        case existingUser
        case newUser
    }

    enum LoadingAction: Equatable {
        case credentials
        case apple
        case google
    }

    @Published var step: Step = .credentials
    @Published var identifier = ""
    @Published var password = ""
    @Published var confirmPassword = ""
    @Published var username = ""
    @Published var displayName = ""
    @Published var dateOfBirth = Calendar.current.date(byAdding: .year, value: -18, to: Date()) ?? Date()
    @Published var phoneNumber = ""
    @Published var otpCode = ""
    @Published var identifierError: String?
    @Published var passwordError: String?
    @Published var confirmPasswordError: String?
    @Published var usernameError: String?
    @Published var displayNameError: String?
    @Published var dateOfBirthError: String?
    @Published var otpErrorKey: L10nKey?
    @Published var otpInfoMessageKey: L10nKey?
    @Published var state: LoadingState<AuthSession> = .idle
    @Published private(set) var loadingAction: LoadingAction?
    @Published var passwordStrength: PasswordStrengthResult = .empty
    @Published var showPasswordRequirements = false
    @Published var showErrorAlert = false
    @Published var hasAcceptedLegalTerms = false
    @Published var legalConsentError: String?

    @Published private(set) var lookupState: IdentifierLookupState = .pending
    @Published private(set) var identifierStatus: FieldValidationStatus = .neutral
    @Published private(set) var usernameStatus: FieldValidationStatus = .neutral
    @Published private(set) var passwordStatus: FieldValidationStatus = .neutral
    @Published private(set) var confirmPasswordStatus: FieldValidationStatus = .neutral

    private let checkIdentifierUseCase: CheckIdentifierUseCaseProtocol
    private let loginUseCase: LoginUseCaseProtocol
    private let registerUseCase: RegisterUseCaseProtocol
    private let requestEmailOtpUseCase: RequestEmailOtpUseCaseProtocol
    private let requestPhoneOtpUseCase: RequestPhoneOtpUseCaseProtocol
    private let verifyPhoneOtpUseCase: VerifyPhoneOtpUseCaseProtocol
    private let googleSignInUseCase: GoogleSignInUseCaseProtocol
    private let appleSignInUseCase: AppleSignInUseCaseProtocol
    private weak var googleSignInPresenter: GoogleSignInPresenting?
    private weak var appleSignInPresenter: AppleSignInPresenting?

    private static let minUsernameLength = 3
    private static let minimumRegistrationAgeYears = 13

    var detectedKind: LoginIdentifierKind {
        identifier.detectedLoginIdentifierKind
    }

    var showsPasswordField: Bool {
        lookupState == .existingUser && detectedKind == .email
    }

    var showsRegistrationFields: Bool {
        lookupState == .newUser
    }

    var showsForgotPassword: Bool {
        showsPasswordField
    }

    var submitTitleKey: L10nKey {
        switch lookupState {
        case .pending:
            return .authContinue
        case .existingUser:
            return detectedKind == .phone ? .authSendCode : .authSignIn
        case .newUser:
            return .authSignUp
        }
    }

    private var normalizedPhone: String { identifier.normalizedE164Phone }

    public var isAppleSignInAvailable: Bool {
        appleSignInPresenter?.isAvailable == true
    }

    public var isGoogleSignInAvailable: Bool {
        googleSignInPresenter?.isAvailable == true
    }

    public init(
        checkIdentifierUseCase: CheckIdentifierUseCaseProtocol,
        loginUseCase: LoginUseCaseProtocol,
        registerUseCase: RegisterUseCaseProtocol,
        requestEmailOtpUseCase: RequestEmailOtpUseCaseProtocol,
        requestPhoneOtpUseCase: RequestPhoneOtpUseCaseProtocol,
        verifyPhoneOtpUseCase: VerifyPhoneOtpUseCaseProtocol,
        googleSignInUseCase: GoogleSignInUseCaseProtocol,
        appleSignInUseCase: AppleSignInUseCaseProtocol,
        googleSignInPresenter: GoogleSignInPresenting? = nil,
        appleSignInPresenter: AppleSignInPresenting? = nil
    ) {
        self.checkIdentifierUseCase = checkIdentifierUseCase
        self.loginUseCase = loginUseCase
        self.registerUseCase = registerUseCase
        self.requestEmailOtpUseCase = requestEmailOtpUseCase
        self.requestPhoneOtpUseCase = requestPhoneOtpUseCase
        self.verifyPhoneOtpUseCase = verifyPhoneOtpUseCase
        self.googleSignInUseCase = googleSignInUseCase
        self.appleSignInUseCase = appleSignInUseCase
        self.googleSignInPresenter = googleSignInPresenter
        self.appleSignInPresenter = appleSignInPresenter
    }

    func onIdentifierChanged() {
        validateIdentifierField()
        if lookupState != .pending {
            resetLookupState()
        }
    }

    func validateIdentifierField() {
        let value = identifier.trimmed
        if value.isEmpty {
            identifierError = nil
            identifierStatus = .neutral
            return
        }

        switch detectedKind {
        case .email, .phone:
            identifierError = nil
            identifierStatus = .valid
        case .unknown:
            if value.contains("@") {
                identifierError = "Please enter a valid email"
            } else {
                identifierError = "Use international format, e.g. +84901234567"
            }
            identifierStatus = .neutral
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
            usernameError = "Letters, numbers, _ and . only"
            usernameStatus = .neutral
        } else {
            usernameError = nil
            usernameStatus = .valid
        }
    }

    func validateDisplayNameField() {
        let value = displayName.trimmed
        if value.isEmpty {
            displayNameError = "Name is required"
            return
        }
        if value.count > 150 {
            displayNameError = "Name is too long"
            return
        }
        displayNameError = nil
    }

    func validateDateOfBirthField() {
        let minimumBirthDate = Calendar.current.date(
            byAdding: .year,
            value: -Self.minimumRegistrationAgeYears,
            to: Date()
        ) ?? Date()
        if dateOfBirth > minimumBirthDate {
            dateOfBirthError = "You must be at least \(Self.minimumRegistrationAgeYears) years old"
            return
        }
        dateOfBirthError = nil
    }

    func validatePasswordField() {
        passwordStrength = PasswordStrengthValidator.evaluate(password)
        if password.isEmpty {
            passwordError = nil
            passwordStatus = .neutral
            validateConfirmPasswordField()
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

    func submit() async {
        switch lookupState {
        case .pending:
            await checkIdentifier()
        case .existingUser:
            switch detectedKind {
            case .email:
                await loginWithEmail()
            case .phone:
                phoneNumber = normalizedPhone
                await requestPhoneOtpAndContinue()
            case .unknown:
                break
            }
        case .newUser:
            await beginRegistration()
        }
    }

    func checkIdentifier() async {
        validateIdentifierField()
        guard identifierError == nil, detectedKind != .unknown else { return }

        setState(.loading, loadingAction: .credentials)
        do {
            let exists: Bool
            switch detectedKind {
            case .email:
                exists = try await checkIdentifierUseCase.execute(
                    email: identifier.trimmed,
                    phoneNumber: nil
                )
            case .phone:
                exists = try await checkIdentifierUseCase.execute(
                    email: nil,
                    phoneNumber: normalizedPhone
                )
            case .unknown:
                setState(.idle)
                return
            }
            lookupState = exists ? .existingUser : .newUser
            setState(.idle)
        } catch let error as NetworkError {
            setState(.failed(error.userMessage))
        } catch {
            setState(.failed("Could not verify your email or phone number."))
        }
    }

    func beginRegistration() async {
        validateUsernameField()
        validateDisplayNameField()
        validateDateOfBirthField()
        validatePasswordField()
        validateConfirmPasswordField()
        guard hasAcceptedLegalTerms else {
            legalConsentError = "required"
            return
        }
        legalConsentError = nil
        guard canSubmitRegistration else { return }

        setState(.loading, loadingAction: .credentials)
        otpErrorKey = nil
        otpInfoMessageKey = nil
        phoneNumber = normalizedPhone

        do {
            switch detectedKind {
            case .email:
                try await requestEmailOtpUseCase.execute(email: identifier.trimmed)
                otpInfoMessageKey = .authOtpEmailHint
            case .phone:
                try await requestPhoneOtpUseCase.execute(phoneNumber: phoneNumber)
                #if DEBUG
                otpInfoMessageKey = .authOtpPhoneHintDebug
                #else
                otpInfoMessageKey = .authOtpPhoneHint
                #endif
            case .unknown:
                setState(.idle)
                return
            }
            step = .registerOtp
            otpCode = ""
            setState(.idle)
        } catch let error as AuthError {
            setState(.failed(error.userMessage))
        } catch let error as NetworkError {
            setState(.failed(error.userMessage))
        } catch {
            setState(.failed("Could not send verification code."))
        }
    }

    func completeRegistration() async {
        guard otpCode.count == 6 else {
            otpErrorKey = detectedKind == .email
                ? .errorAuthInvalidOtpPrompt
                : .authOtpSmsCodeRequired
            return
        }

        otpErrorKey = nil
        setState(.loading)
        do {
            let channel: AuthRegistrationChannel = detectedKind == .email ? .email : .phone
            let registrationIdentifier = detectedKind == .email ? identifier.trimmed : phoneNumber
            let session = try await registerUseCase.execute(
                channel: channel,
                identifier: registrationIdentifier,
                username: username.trimmed,
                password: password,
                otpCode: otpCode,
                displayName: displayName.trimmed
            )
            setState(.loaded(session))
            Log.info("Registration successful for \(session.user.username)", category: .auth)
        } catch let error as AuthError {
            applyRegistrationError(error)
        } catch let error as NetworkError where error.isConnectivityIssue {
            setState(.failed(error.userMessage))
        } catch {
            otpErrorKey = .errorAuthInvalidOtpDefault
            setState(.idle)
        }
    }

    func resendRegistrationOtp() async {
        await beginRegistration()
    }

    func requestPhoneOtpAndContinue() async {
        validateIdentifierField()
        guard detectedKind == .phone, identifierError == nil else { return }

        setState(.loading, loadingAction: .credentials)
        otpErrorKey = nil
        otpInfoMessageKey = nil
        phoneNumber = normalizedPhone
        Log.info("Requesting phone OTP", category: .auth)
        do {
            try await requestPhoneOtpUseCase.execute(phoneNumber: phoneNumber)
            step = .phoneOtp
            otpCode = ""
            #if DEBUG
            otpInfoMessageKey = .authOtpPhoneHintDebug
            #else
            otpInfoMessageKey = .authOtpPhoneHint
            #endif
            setState(.idle)
        } catch let error as AuthError {
            applyOtpRequestError(error)
        } catch let error as NetworkError {
            setState(.failed(error.userMessage))
        } catch {
            setState(.failed("Could not send verification code."))
        }
    }

    func resendPhoneOtp() async {
        await requestPhoneOtpAndContinue()
    }

    func verifyPhoneOtp() async {
        guard otpCode.count == 6 else {
            otpErrorKey = .authOtpSmsCodeRequired
            return
        }

        otpErrorKey = nil
        setState(.loading)
        do {
            let session = try await verifyPhoneOtpUseCase.execute(
                phoneNumber: phoneNumber,
                otpCode: otpCode
            )
            setState(.loaded(session))
        } catch let error as AuthError {
            applyOtpVerifyError(error)
        } catch let error as NetworkError where error.isConnectivityIssue {
            setState(.failed(error.userMessage))
        } catch {
            otpErrorKey = .errorAuthInvalidOtpDefault
            setState(.idle)
        }
    }

    func goBackToCredentials() {
        step = .credentials
        otpCode = ""
        otpErrorKey = nil
        otpInfoMessageKey = nil
    }

    func goBackFromRegisterOtp() {
        goBackToCredentials()
    }

    func signInWithGoogle() async {
        guard let googleSignInPresenter, googleSignInPresenter.isAvailable else {
            setState(.failed("Google Sign-In is not configured."))
            return
        }

        setState(.loading, loadingAction: .google)
        do {
            let idToken = try await googleSignInPresenter.fetchIdToken()
            let session = try await googleSignInUseCase.execute(idToken: idToken)
            setState(.loaded(session))
            Log.info("Google sign-in successful for \(session.user.username)", category: .auth)
        } catch let error as NetworkError where error.isConnectivityIssue {
            setState(.failed(error.userMessage))
        } catch let error as NetworkError {
            setState(.failed(error.userMessage))
        } catch let error as AuthError {
            setState(.failed(error.userMessage))
        } catch {
            let nsError = error as NSError
            if nsError.domain == "com.google.GIDSignIn" && nsError.code == -5 {
                setState(.idle)
            } else {
                setState(.failed(error.localizedDescription))
            }
        }
    }

    func signInWithApple() async {
        guard let appleSignInPresenter, appleSignInPresenter.isAvailable else {
            setState(.failed("Sign in with Apple is not available."))
            return
        }

        setState(.loading, loadingAction: .apple)
        do {
            let idToken = try await appleSignInPresenter.fetchIdToken()
            let session = try await appleSignInUseCase.execute(idToken: idToken)
            setState(.loaded(session))
            Log.info("Apple sign-in successful for \(session.user.username)", category: .auth)
        } catch AppleSignInError.cancelled {
            setState(.idle)
        } catch let error as NetworkError where error.isConnectivityIssue {
            setState(.failed(error.userMessage))
        } catch let error as NetworkError {
            setState(.failed(error.userMessage))
        } catch let error as AuthError {
            setState(.failed(error.userMessage))
        } catch {
            setState(.failed(error.localizedDescription))
        }
    }

    var credentialsSubmitDisabled: Bool {
        guard !state.isLoading else { return true }

        switch lookupState {
        case .pending:
            return identifier.trimmed.isEmpty || identifierError != nil || detectedKind == .unknown
        case .existingUser:
            switch detectedKind {
            case .email:
                return password.isEmpty
            case .phone:
                return false
            case .unknown:
                return true
            }
        case .newUser:
            return !canSubmitRegistration
        }
    }

    private var canSubmitRegistration: Bool {
        hasAcceptedLegalTerms
            && usernameError == nil
            && displayNameError == nil
            && dateOfBirthError == nil
            && passwordError == nil
            && confirmPasswordError == nil
            && !username.trimmed.isEmpty
            && !displayName.trimmed.isEmpty
            && passwordStrength.isStrong
            && password == confirmPassword
    }

    private func resetLookupState() {
        lookupState = .pending
        password = ""
        confirmPassword = ""
        username = ""
        displayName = ""
        dateOfBirth = Calendar.current.date(byAdding: .year, value: -18, to: Date()) ?? Date()
        passwordError = nil
        confirmPasswordError = nil
        usernameError = nil
        displayNameError = nil
        dateOfBirthError = nil
        passwordStrength = .empty
        passwordStatus = .neutral
        confirmPasswordStatus = .neutral
        usernameStatus = .neutral
        hasAcceptedLegalTerms = false
        legalConsentError = nil
    }

    private func loginWithEmail() async {
        guard validateEmailLogin() else { return }

        setState(.loading, loadingAction: .credentials)
        Log.info("Logging in with email", category: .auth)
        do {
            let session = try await loginUseCase.execute(
                email: identifier.trimmed,
                password: password
            )
            setState(.loaded(session))
            Log.info("Login successful for \(session.user.username)", category: .auth)
        } catch let error as AuthError {
            setState(.failed(error.userMessage))
        } catch let error as NetworkError where error.isConnectivityIssue {
            setState(.failed(error.userMessage))
        } catch {
            setState(.failed(AuthError.invalidCredentials.userMessage))
        }
    }

    private func setState(_ newState: LoadingState<AuthSession>, loadingAction action: LoadingAction? = nil) {
        switch newState {
        case .loading:
            self.loadingAction = action
            state = .loading
        case .failed(let detail):
            Log.warning("Login failed: \(detail)", category: .auth)
            showErrorAlert = true
            self.loadingAction = nil
            state = .idle
        default:
            self.loadingAction = nil
            state = newState
        }
    }

    private func applyOtpRequestError(_ error: AuthError) {
        if error.shouldShowOnOtpStep {
            otpErrorKey = otpErrorKey(for: error)
            setState(.idle)
        } else {
            setState(.failed(error.userMessage))
        }
    }

    private func applyOtpVerifyError(_ error: AuthError) {
        if error.shouldShowOnOtpStep {
            otpErrorKey = otpErrorKey(for: error)
            setState(.idle)
        } else {
            setState(.failed(error.userMessage))
        }
    }

    private func applyRegistrationError(_ error: AuthError) {
        if error.shouldShowOnOtpStep {
            otpErrorKey = otpErrorKey(for: error)
            setState(.idle)
            return
        }

        switch error {
        case .emailAlreadyExists, .phoneAlreadyExists:
            lookupState = .existingUser
            step = .credentials
            otpCode = ""
            setState(.failed(error.userMessage))
        case .usernameAlreadyExists:
            step = .credentials
            usernameError = error.userMessage
            usernameStatus = .neutral
            otpCode = ""
            setState(.idle)
        default:
            setState(.failed(error.userMessage))
        }
    }

    private func otpErrorKey(for error: AuthError) -> L10nKey {
        switch error {
        case .otpRateLimited:
            return .errorAuthOtpRateLimited
        case .invalidOtp:
            return .errorAuthInvalidOtpDefault
        default:
            return .errorAuthInvalidOtpDefault
        }
    }

    private func validateEmailLogin() -> Bool {
        var isValid = true
        identifierError = nil
        passwordError = nil

        if identifier.trimmed.isEmpty {
            identifierError = "Email or phone number is required"
            isValid = false
        } else if detectedKind != .email {
            identifierError = "Please enter a valid email"
            isValid = false
        }

        if password.isEmpty {
            passwordError = "Password is required"
            isValid = false
        }

        return isValid
    }
}
