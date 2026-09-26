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
    @Published var selectedPhoneRegion: PhoneCallingRegion = .vietnam
    @Published var password = ""
    @Published var confirmPassword = ""
    @Published var username = ""
    @Published var displayName = ""
    @Published var dateOfBirth: Date?
    @Published var dateOfBirthDraft = LoginViewModel.defaultDateOfBirthDraft
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
    @Published var showErrorAlert = false
    @Published var hasAcceptedLegalTerms = true
    @Published var legalConsentError: String?
    @Published var deactivatedAccount: DeactivatedAccountInfo?
    @Published var deactivatedAccountError: String?

    @Published private(set) var lookupState: IdentifierLookupState = .pending
    @Published private(set) var identifierStatus: FieldValidationStatus = .neutral
    @Published private(set) var usernameStatus: FieldValidationStatus = .neutral
    @Published private(set) var passwordStatus: FieldValidationStatus = .neutral
    @Published private(set) var confirmPasswordStatus: FieldValidationStatus = .neutral

    private(set) var shouldCompleteOAuthProfile = false

    private let checkIdentifierUseCase: CheckIdentifierUseCaseProtocol
    private let loginUseCase: LoginUseCaseProtocol
    private let registerUseCase: RegisterUseCaseProtocol
    private let requestEmailOtpUseCase: RequestEmailOtpUseCaseProtocol
    private let requestPhoneOtpUseCase: RequestPhoneOtpUseCaseProtocol
    private let verifyPhoneOtpUseCase: VerifyPhoneOtpUseCaseProtocol
    private let googleSignInUseCase: GoogleSignInUseCaseProtocol
    private let appleSignInUseCase: AppleSignInUseCaseProtocol
    private let reactivateAccountUseCase: ReactivateAccountUseCaseProtocol
    private let languageService: LanguageService
    private weak var googleSignInPresenter: GoogleSignInPresenting?
    private weak var appleSignInPresenter: AppleSignInPresenting?

    private static let minUsernameLength = 3
    private static let minimumRegistrationAgeYears = 13
    private static var defaultDateOfBirthDraft: Date {
        Calendar.current.date(byAdding: .year, value: -18, to: Date()) ?? Date()
    }

    private var usernameManuallyEdited = false
    private var lastAutoFilledUsername = ""
    private var identifierLookupTask: Task<Void, Never>?

    private static let identifierLookupDebounce: Duration = .milliseconds(450)

    var detectedKind: LoginIdentifierKind {
        let value = identifier.trimmed
        if value.isEmpty { return .unknown }
        if value.contains("@") || value.contains(where: \.isLetter) {
            return value.isValidEmail ? .email : .unknown
        }
        guard PhoneNumberParser.looksLikePhone(value) else { return .unknown }
        return PhoneNumberParser.parse(normalizedPhone, defaultRegion: selectedPhoneRegion)?
            .completeness == .complete ? .phone : .unknown
    }

    var identifierIntent: LoginIdentifierKind {
        let value = identifier.trimmed
        if value.isEmpty { return .unknown }
        if value.contains("@") || value.contains(where: \.isLetter) {
            return .email
        }
        return PhoneNumberParser.looksLikePhone(value) ? .phone : .unknown
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

    func onIdentifierChanged() {
        applyPhoneInputNormalization()
        validateIdentifierField()
        if lookupState != .pending {
            resetLookupState()
        }
        suggestUsernameFromEmailIfNeeded()
        scheduleIdentifierLookup()
    }

    func selectPhoneRegion(_ region: PhoneCallingRegion) {
        selectedPhoneRegion = region
        onIdentifierChanged()
    }

    private func applyPhoneInputNormalization() {
        guard let normalized = PhoneNumberParser.normalizeTypedIdentifier(
            identifier,
            selectedRegion: selectedPhoneRegion
        ) else { return }
        if selectedPhoneRegion != normalized.region {
            selectedPhoneRegion = normalized.region
        }
        if identifier != normalized.displayText {
            identifier = normalized.displayText
        }
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

    private var normalizedPhone: String {
        "+" + selectedPhoneRegion.callingCode + identifier.filter(\.isNumber)
    }

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
        reactivateAccountUseCase: ReactivateAccountUseCaseProtocol,
        languageService: LanguageService,
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
        self.reactivateAccountUseCase = reactivateAccountUseCase
        self.languageService = languageService
        self.googleSignInPresenter = googleSignInPresenter
        self.appleSignInPresenter = appleSignInPresenter
    }

    func onUsernameChanged() {
        if username != lastAutoFilledUsername {
            usernameManuallyEdited = true
        }
        validateUsernameField()
    }

    func validateIdentifierField() {
        let value = identifier.trimmed
        if value.isEmpty {
            identifierError = nil
            identifierStatus = .neutral
            return
        }

        if value.contains("@") || value.contains(where: \.isLetter) {
            if value.isValidEmail {
                identifierError = nil
                identifierStatus = .valid
            } else if value.contains("@") {
                identifierError = languageService.text(.authValidationInvalidEmail)
                identifierStatus = .neutral
            } else {
                identifierError = nil
                identifierStatus = .neutral
            }
            return
        }

        guard let parsed = PhoneNumberParser.parse(normalizedPhone, defaultRegion: selectedPhoneRegion) else {
            identifierError = nil
            identifierStatus = .neutral
            return
        }
        switch parsed.completeness {
        case .complete:
            identifierError = nil
            identifierStatus = .valid
        case .incomplete:
            identifierError = nil
            identifierStatus = .neutral
        case .invalid:
            identifierError = languageService.text(.authValidationInvalidPhone)
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
            usernameError = languageService.text(.profileUsernameTooShort)
            usernameStatus = .neutral
        } else if value.count > AppConstants.Validation.maxUsernameLength {
            usernameError = languageService.text(.profileUsernameTooLong)
            usernameStatus = .neutral
        } else if !value.isValidUsername {
            usernameError = languageService.text(.profileUsernameInvalid)
            usernameStatus = .neutral
        } else {
            usernameError = nil
            usernameStatus = .valid
        }
    }

    func validateDisplayNameField() {
        let value = displayName.trimmed
        if value.isEmpty {
            displayNameError = nil
            return
        }
        if value.count > 150 {
            displayNameError = languageService.text(.authDisplayNameTooLong)
            return
        }
        displayNameError = nil
    }

    func prepareDateOfBirthPicker() {
        dateOfBirthDraft = dateOfBirth ?? Self.defaultDateOfBirthDraft
    }

    func confirmDateOfBirth() {
        dateOfBirth = dateOfBirthDraft
        validateDateOfBirthField()
    }

    func clearDateOfBirth() {
        dateOfBirth = nil
        dateOfBirthError = nil
    }

    func validateDateOfBirthField() {
        guard let dateOfBirth else {
            dateOfBirthError = nil
            return
        }
        let minimumBirthDate = Calendar.current.date(
            byAdding: .year,
            value: -Self.minimumRegistrationAgeYears,
            to: Date()
        ) ?? Date()
        if dateOfBirth > minimumBirthDate {
            dateOfBirthError = languageService.text(.profileBirthdayAgeError)
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
            confirmPasswordError = languageService.text(.authPasswordsMismatch)
            confirmPasswordStatus = .warning
        }
    }

    func submitIdentifierFromKeyboard() async {
        identifierLookupTask?.cancel()
        guard lookupState == .pending else { return }
        await checkIdentifier(showsButtonLoading: true)
    }

    func submit() async {
        identifierLookupTask?.cancel()
        switch lookupState {
        case .pending:
            await checkIdentifier(showsButtonLoading: true)
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
        await checkIdentifier(showsButtonLoading: true)
    }

    private func scheduleIdentifierLookup() {
        identifierLookupTask?.cancel()
        guard !state.isLoading else { return }
        guard identifierError == nil, detectedKind != .unknown else { return }

        let snapshot = identifierLookupSnapshot
        identifierLookupTask = Task { [weak self] in
            try? await Task.sleep(for: Self.identifierLookupDebounce)
            guard !Task.isCancelled else { return }
            await self?.checkIdentifier(showsButtonLoading: false, expectedSnapshot: snapshot)
        }
    }

    private var identifierLookupSnapshot: String {
        switch detectedKind {
        case .email:
            return "email:\(identifier.trimmed.lowercased())"
        case .phone:
            return "phone:\(normalizedPhone)"
        case .unknown:
            return ""
        }
    }

    private func checkIdentifier(
        showsButtonLoading: Bool,
        expectedSnapshot: String? = nil
    ) async {
        validateIdentifierField()
        guard identifierError == nil, detectedKind != .unknown else { return }
        guard lookupState == .pending else { return }

        let snapshot = expectedSnapshot ?? identifierLookupSnapshot
        guard snapshot == identifierLookupSnapshot else { return }

        if showsButtonLoading {
            setState(.loading, loadingAction: .credentials)
        } else {
            identifierStatus = .loading
        }

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

            guard snapshot == identifierLookupSnapshot else {
                if showsButtonLoading { setState(.idle) }
                return
            }

            lookupState = exists ? .existingUser : .newUser
            identifierStatus = .valid
            if exists {
                hasAcceptedLegalTerms = true
                legalConsentError = nil
            } else {
                hasAcceptedLegalTerms = false
                legalConsentError = nil
                suggestUsernameFromEmailIfNeeded()
            }
            setState(.idle)
        } catch let error as NetworkError {
            guard snapshot == identifierLookupSnapshot else { return }
            identifierStatus = .neutral
            setState(.failed(error.userMessage))
        } catch {
            guard snapshot == identifierLookupSnapshot else { return }
            identifierStatus = .neutral
            setState(.failed(languageService.text(.authVerifyIdentifierFailed)))
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
            otpCode = ""
            await revealButtonResultThen {
                step = .registerOtp
            }
        } catch let error as AuthError {
            setState(.failed(error.userMessage))
        } catch let error as NetworkError {
            setState(.failed(error.userMessage))
        } catch {
            setState(.failed(languageService.text(.authSendCodeFailedRetry)))
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
            let resolvedUsername = username.trimmed
            let trimmedDisplayName = displayName.trimmed
            let session = try await registerUseCase.execute(
                channel: channel,
                identifier: registrationIdentifier,
                username: resolvedUsername,
                password: password,
                otpCode: otpCode,
                displayName: trimmedDisplayName.isEmpty ? resolvedUsername : trimmedDisplayName,
                dateOfBirth: dateOfBirth
            )
            await presentAuthenticatedSession(session)
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
            otpCode = ""
            #if DEBUG
            otpInfoMessageKey = .authOtpPhoneHintDebug
            #else
            otpInfoMessageKey = .authOtpPhoneHint
            #endif
            await revealButtonResultThen {
                step = .phoneOtp
            }
        } catch let error as AuthError {
            applyOtpRequestError(error)
        } catch let error as NetworkError {
            setState(.failed(error.userMessage))
        } catch {
            setState(.failed(languageService.text(.authSendCodeFailedRetry)))
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
            await presentAuthenticatedSession(session)
        } catch let error as AuthError {
            if case .accountInactive = error {
                applySignInFailure(error)
            } else {
                applyOtpVerifyError(error)
            }
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
            setState(.failed(languageService.text(.authGoogleNotConfigured)))
            return
        }

        setState(.loading, loadingAction: .google)
        do {
            let idToken = try await googleSignInPresenter.fetchIdToken()
            let session = try await googleSignInUseCase.execute(idToken: idToken)
            shouldCompleteOAuthProfile = session.isNewUser
            await presentAuthenticatedSession(session)
            Log.info("Google sign-in successful for \(session.user.username)", category: .auth)
        } catch {
            let nsError = error as NSError
            if nsError.domain == "com.google.GIDSignIn" && nsError.code == -5 {
                setState(.idle)
            } else {
                applySignInFailure(error)
            }
        }
    }

    func signInWithApple() async {
        guard let appleSignInPresenter, appleSignInPresenter.isAvailable else {
            setState(.failed(languageService.text(.authAppleUnavailable)))
            return
        }

        setState(.loading, loadingAction: .apple)
        do {
            let idToken = try await appleSignInPresenter.fetchIdToken()
            let session = try await appleSignInUseCase.execute(idToken: idToken)
            shouldCompleteOAuthProfile = session.isNewUser
            await presentAuthenticatedSession(session)
            Log.info("Apple sign-in successful for \(session.user.username)", category: .auth)
        } catch AppleSignInError.cancelled {
            setState(.idle)
        } catch {
            applySignInFailure(error)
        }
    }

    func consumeShouldCompleteOAuthProfile() -> Bool {
        let value = shouldCompleteOAuthProfile
        shouldCompleteOAuthProfile = false
        return value
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
            && passwordStrength.isStrong
            && password == confirmPassword
    }

    private func resetLookupState() {
        identifierLookupTask?.cancel()
        lookupState = .pending
        password = ""
        confirmPassword = ""
        username = ""
        displayName = ""
        dateOfBirth = nil
        dateOfBirthDraft = Self.defaultDateOfBirthDraft
        usernameManuallyEdited = false
        lastAutoFilledUsername = ""
        passwordError = nil
        confirmPasswordError = nil
        usernameError = nil
        displayNameError = nil
        dateOfBirthError = nil
        passwordStrength = .empty
        passwordStatus = .neutral
        confirmPasswordStatus = .neutral
        usernameStatus = .neutral
        hasAcceptedLegalTerms = true
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
            await presentAuthenticatedSession(session)
            Log.info("Login successful for \(session.user.username)", category: .auth)
        } catch {
            applySignInFailure(error)
        }
    }

    func reactivateDeactivatedAccount() async {
        guard let token = deactivatedAccount?.reactivationToken, !token.isEmpty else { return }
        deactivatedAccountError = nil
        setState(.loading, loadingAction: .credentials)
        do {
            let session = try await reactivateAccountUseCase.execute(reactivationToken: token)
            deactivatedAccount = nil
            await presentAuthenticatedSession(session)
        } catch {
            loadingAction = nil
            state = .idle
            let message = languageService.localizedMessage(for: error)
            deactivatedAccountError = message.isEmpty
                ? languageService.text(.deactivatedAccountReactivateFailed)
                : message
        }
    }

    func useAnotherAccount() {
        deactivatedAccount = nil
        deactivatedAccountError = nil
        resetLookupState()
        identifier = ""
        selectedPhoneRegion = .vietnam
        password = ""
        step = .credentials
        state = .idle
        loadingAction = nil
    }

    private func applySignInFailure(_ error: Error) {
        if let authError = error as? AuthError, case .accountInactive(let info) = authError {
            deactivatedAccount = info
            deactivatedAccountError = nil
            loadingAction = nil
            state = .idle
            return
        }
        if let authError = error as? AuthError {
            setState(.failed(authError.userMessage))
            return
        }
        if let networkError = error as? NetworkError {
            setState(.failed(networkError.userMessage))
            return
        }
        setState(.failed(AuthError.invalidCredentials.userMessage))
    }

    private func presentAuthenticatedSession(_ session: AuthSession) async {
        await revealButtonResultThen {
            setState(.loaded(session))
        }
    }

    private func revealButtonResultThen(_ work: () -> Void) async {
        setState(.idle)
        try? await Task.sleep(nanoseconds: SplickButton.successHoldNanoseconds)
        work()
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
            hasAcceptedLegalTerms = true
            legalConsentError = nil
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
            identifierError = languageService.text(.authIdentifierRequired)
            isValid = false
        } else if detectedKind != .email {
            identifierError = languageService.text(.authValidationInvalidEmail)
            isValid = false
        }

        if password.isEmpty {
            passwordError = languageService.text(.authPasswordRequired)
            isValid = false
        }

        return isValid
    }

    private func suggestUsernameFromEmailIfNeeded() {
        guard !usernameManuallyEdited else { return }
        guard detectedKind == .email else { return }
        let suggested = identifier.suggestedUsernameFromEmail
        username = suggested
        lastAutoFilledUsername = suggested
        validateUsernameField()
    }
}
