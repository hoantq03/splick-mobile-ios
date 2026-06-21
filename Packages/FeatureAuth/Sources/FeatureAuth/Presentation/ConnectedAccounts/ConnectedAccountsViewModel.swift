import Foundation
import Common
import DesignSystem
import Localization
import SplickDomain

@MainActor
public final class ConnectedAccountsViewModel: ObservableObject {
    @Published public private(set) var accounts: ConnectedAccounts?
    @Published public private(set) var isLoading = false
    @Published public var listErrorMessage: String?
    @Published public var listInfoMessage: String?
    @Published public var isLinkingGoogle = false
    @Published public var isUnlinkingGoogle = false
    @Published public var showUnlinkSheet = false
    @Published public var showConnectPhoneSheet = false
    @Published public var showConnectEmailSheet = false

    // Phone connect sheet
    @Published public var connectPhoneNumber = ""
    @Published public var connectPhoneOtp = ""
    @Published public var phoneSheetError: String?
    @Published public var phoneSheetOtpError: String?
    @Published public var phoneSheetInfo: String?
    @Published public private(set) var hasSentPhoneCode = false
    @Published public private(set) var isRequestingPhoneCode = false
    @Published public private(set) var isConnectingPhone = false
    @Published public private(set) var phoneResendSecondsRemaining = 0

    // Email connect sheet
    @Published public var connectEmail = ""
    @Published public var connectEmailOtp = ""
    @Published public var connectEmailPassword = ""
    @Published public var connectEmailConfirm = ""
    @Published public var emailSheetError: String?
    @Published public var emailSheetOtpError: String?
    @Published public var emailSheetPasswordError: String?
    @Published public var emailSheetConfirmPasswordError: String?
    @Published public var emailSheetInfo: String?
    @Published public private(set) var hasSentEmailCode = false
    @Published public private(set) var isRequestingEmailCode = false
    @Published public private(set) var isConnectingEmail = false
    @Published public private(set) var emailResendSecondsRemaining = 0

    // Unlink Google sheet
    @Published public var unlinkPassword = ""
    @Published public var unlinkOtpCode = ""
    @Published public var unlinkSheetError: String?
    @Published public var unlinkSheetOtpError: String?
    @Published public var unlinkSheetPasswordError: String?
    @Published public var unlinkSheetInfo: String?
    @Published public var unlinkMethod: VerificationMethod = .password
    @Published public private(set) var hasSentUnlinkCode = false
    @Published public private(set) var isRequestingUnlinkCode = false
    @Published public private(set) var unlinkResendSecondsRemaining = 0

    public enum VerificationMethod: String, CaseIterable {
        case password
        case emailCode
    }

    private let getConnectedAccountsUseCase: GetConnectedAccountsUseCaseProtocol
    private let linkGoogleAccountUseCase: LinkGoogleAccountUseCaseProtocol
    private let unlinkGoogleAccountUseCase: UnlinkGoogleAccountUseCaseProtocol
    private let linkPhoneAccountUseCase: LinkPhoneAccountUseCaseProtocol
    private let linkEmailAccountUseCase: LinkEmailAccountUseCaseProtocol
    private let requestEmailOtpUseCase: RequestEmailOtpUseCaseProtocol
    private let googleSignInPresenter: GoogleSignInPresenting?
    private let languageService: LanguageService
    private let accountEmail: String

    private var phoneResendTask: Task<Void, Never>?
    private var emailResendTask: Task<Void, Never>?
    private var unlinkResendTask: Task<Void, Never>?

    private static let otpResendCooldownSeconds = 60

    public var isGoogleLinkAvailable: Bool {
        googleSignInPresenter?.isAvailable == true
    }

    public var isPhoneOnlyAccount: Bool {
        accountEmail.lowercased().hasSuffix("@phone.splick.local")
    }

    public var linkEmailAddress: String {
        isPhoneOnlyAccount ? connectEmail.trimmingCharacters(in: .whitespacesAndNewlines) : accountEmail
    }

    public init(
        accountEmail: String,
        getConnectedAccountsUseCase: GetConnectedAccountsUseCaseProtocol,
        linkGoogleAccountUseCase: LinkGoogleAccountUseCaseProtocol,
        unlinkGoogleAccountUseCase: UnlinkGoogleAccountUseCaseProtocol,
        linkPhoneAccountUseCase: LinkPhoneAccountUseCaseProtocol,
        linkEmailAccountUseCase: LinkEmailAccountUseCaseProtocol,
        requestEmailOtpUseCase: RequestEmailOtpUseCaseProtocol,
        googleSignInPresenter: GoogleSignInPresenting?,
        languageService: LanguageService
    ) {
        self.accountEmail = accountEmail
        self.getConnectedAccountsUseCase = getConnectedAccountsUseCase
        self.linkGoogleAccountUseCase = linkGoogleAccountUseCase
        self.unlinkGoogleAccountUseCase = unlinkGoogleAccountUseCase
        self.linkPhoneAccountUseCase = linkPhoneAccountUseCase
        self.linkEmailAccountUseCase = linkEmailAccountUseCase
        self.requestEmailOtpUseCase = requestEmailOtpUseCase
        self.googleSignInPresenter = googleSignInPresenter
        self.languageService = languageService
        if !accountEmail.lowercased().hasSuffix("@phone.splick.local") {
            connectEmail = accountEmail
        }
    }

    public func load() async {
        isLoading = true
        listErrorMessage = nil
        defer { isLoading = false }
        do {
            accounts = try await getConnectedAccountsUseCase.execute()
        } catch {
            guard !error.isRequestCancellation else { return }
            listErrorMessage = languageService.text(.connectedAccountsLoadFailed)
        }
    }

    public func preparePhoneSheet() {
        resetPhoneSheetState()
    }

    public func prepareEmailSheet() {
        resetEmailSheetState()
        if !isPhoneOnlyAccount {
            connectEmail = accountEmail
        }
    }

    public func prepareUnlinkSheet() {
        resetUnlinkSheetState()
    }

    public func linkGoogle() async {
        guard let googleSignInPresenter, googleSignInPresenter.isAvailable else {
            listErrorMessage = languageService.text(.connectedAccountsGoogleUnavailable)
            return
        }
        isLinkingGoogle = true
        listErrorMessage = nil
        listInfoMessage = nil
        defer { isLinkingGoogle = false }
        do {
            let idToken = try await googleSignInPresenter.fetchIdToken()
            try await linkGoogleAccountUseCase.execute(idToken: idToken)
            listInfoMessage = languageService.text(.connectedAccountsGoogleLinked)
            await load()
        } catch let error as AuthError {
            listErrorMessage = error.userMessage
        } catch {
            listErrorMessage = languageService.text(.connectedAccountsGoogleLinkFailed)
        }
    }

    public func requestPhoneConnectCode() async {
        guard phoneResendSecondsRemaining == 0 else { return }

        let phone = connectPhoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !phone.isEmpty else {
            phoneSheetError = languageService.text(.connectedAccountsPhoneRequired)
            return
        }

        isRequestingPhoneCode = true
        phoneSheetError = nil
        phoneSheetOtpError = nil
        defer { isRequestingPhoneCode = false }

        do {
            try await linkPhoneAccountUseCase.requestOtp(phoneNumber: phone)
            hasSentPhoneCode = true
            phoneSheetInfo = languageService.format(.connectedAccountsCodeSentPhone, phone)
            startResendCountdown(for: .phone)
        } catch let error as AuthError {
            phoneSheetError = error.userMessage
        } catch let error as NetworkError {
            phoneSheetError = error.userMessage
        } catch {
            phoneSheetError = languageService.text(.connectedAccountsSendCodeFailed)
        }
    }

    public func resendPhoneConnectCode() async {
        await requestPhoneConnectCode()
    }

    public func linkPhone() async -> Bool {
        guard connectPhoneOtp.count == SplickOtpField.defaultLength else {
            phoneSheetOtpError = languageService.text(.changePasswordOtpRequired)
            return false
        }

        isConnectingPhone = true
        phoneSheetOtpError = nil
        defer { isConnectingPhone = false }

        do {
            try await linkPhoneAccountUseCase.execute(
                phoneNumber: connectPhoneNumber.trimmingCharacters(in: .whitespacesAndNewlines),
                otpCode: connectPhoneOtp
            )
            showConnectPhoneSheet = false
            resetPhoneSheetState()
            listInfoMessage = languageService.text(.connectedAccountsPhoneLinked)
            await load()
            return true
        } catch let error as AuthError {
            phoneSheetOtpError = error.userMessage
            return false
        } catch let error as NetworkError {
            phoneSheetOtpError = error.userMessage
            return false
        } catch {
            phoneSheetOtpError = languageService.text(.connectedAccountsPhoneLinkFailed)
            return false
        }
    }

    public func requestEmailConnectCode() async {
        guard emailResendSecondsRemaining == 0 else { return }

        let email = linkEmailAddress
        guard !email.isEmpty else {
            emailSheetError = languageService.text(.connectedAccountsEmailRequired)
            return
        }

        isRequestingEmailCode = true
        emailSheetError = nil
        emailSheetOtpError = nil
        defer { isRequestingEmailCode = false }

        do {
            try await linkEmailAccountUseCase.requestOtp(email: isPhoneOnlyAccount ? email : nil)
            hasSentEmailCode = true
            emailSheetInfo = languageService.format(.changePasswordCodeSent, email)
            startResendCountdown(for: .email)
        } catch let error as AuthError {
            emailSheetError = error.userMessage
        } catch let error as NetworkError {
            emailSheetError = error.userMessage
        } catch {
            emailSheetError = languageService.text(.connectedAccountsSendCodeFailed)
        }
    }

    public func resendEmailConnectCode() async {
        await requestEmailConnectCode()
    }

    public func validateEmailPasswordFields() {
        if connectEmailPassword.isEmpty {
            emailSheetPasswordError = nil
        } else if connectEmailPassword.count < AppConstants.Validation.minPasswordLength {
            emailSheetPasswordError = languageService.format(
                .connectedAccountsPasswordTooShort,
                AppConstants.Validation.minPasswordLength
            )
        } else {
            emailSheetPasswordError = nil
        }

        if connectEmailConfirm.isEmpty {
            emailSheetConfirmPasswordError = nil
        } else if connectEmailPassword != connectEmailConfirm {
            emailSheetConfirmPasswordError = languageService.text(.changePasswordPasswordsMismatch)
        } else {
            emailSheetConfirmPasswordError = nil
        }
    }

    public func linkEmail() async -> Bool {
        validateEmailPasswordFields()
        guard connectEmailPassword == connectEmailConfirm else {
            emailSheetConfirmPasswordError = languageService.text(.changePasswordPasswordsMismatch)
            return false
        }
        guard connectEmailPassword.count >= AppConstants.Validation.minPasswordLength else {
            emailSheetPasswordError = languageService.format(
                .connectedAccountsPasswordTooShort,
                AppConstants.Validation.minPasswordLength
            )
            return false
        }
        guard connectEmailOtp.count == SplickOtpField.defaultLength else {
            emailSheetOtpError = languageService.text(.changePasswordOtpRequired)
            return false
        }

        isConnectingEmail = true
        emailSheetOtpError = nil
        defer { isConnectingEmail = false }

        let email = isPhoneOnlyAccount ? linkEmailAddress : nil
        do {
            try await linkEmailAccountUseCase.execute(
                email: email,
                otpCode: connectEmailOtp,
                password: connectEmailPassword
            )
            showConnectEmailSheet = false
            resetEmailSheetState()
            listInfoMessage = languageService.text(.connectedAccountsEmailLinked)
            await load()
            return true
        } catch let error as AuthError {
            if error.shouldShowOnOtpStep {
                emailSheetOtpError = error.userMessage
            } else {
                emailSheetError = error.userMessage
            }
            return false
        } catch let error as NetworkError {
            emailSheetError = error.userMessage
            return false
        } catch {
            emailSheetError = languageService.text(.connectedAccountsEmailLinkFailed)
            return false
        }
    }

    public func requestUnlinkCode() async {
        guard unlinkResendSecondsRemaining == 0 else { return }

        isRequestingUnlinkCode = true
        unlinkSheetError = nil
        unlinkSheetOtpError = nil
        defer { isRequestingUnlinkCode = false }

        do {
            try await requestEmailOtpUseCase.execute(email: accountEmail)
            hasSentUnlinkCode = true
            unlinkSheetInfo = languageService.format(.changePasswordCodeSent, accountEmail)
            startResendCountdown(for: .unlink)
        } catch let error as AuthError {
            unlinkSheetOtpError = error.userMessage
        } catch let error as NetworkError {
            unlinkSheetError = error.userMessage
        } catch {
            unlinkSheetError = languageService.text(.connectedAccountsSendCodeFailed)
        }
    }

    public func resendUnlinkCode() async {
        await requestUnlinkCode()
    }

    public func unlinkGoogle() async -> Bool {
        isUnlinkingGoogle = true
        unlinkSheetError = nil
        unlinkSheetPasswordError = nil
        defer { isUnlinkingGoogle = false }

        do {
            let password = unlinkMethod == .password ? unlinkPassword : nil
            let otp = unlinkMethod == .emailCode ? unlinkOtpCode : nil
            if unlinkMethod == .password, (password ?? "").isEmpty {
                unlinkSheetPasswordError = languageService.text(.changePasswordCurrentRequired)
                return false
            }
            if unlinkMethod == .emailCode, unlinkOtpCode.count != SplickOtpField.defaultLength {
                unlinkSheetOtpError = languageService.text(.changePasswordOtpRequired)
                return false
            }
            try await unlinkGoogleAccountUseCase.execute(currentPassword: password, otpCode: otp)
            showUnlinkSheet = false
            resetUnlinkSheetState()
            listInfoMessage = languageService.text(.connectedAccountsGoogleUnlinked)
            await load()
            return true
        } catch let error as AuthError {
            if unlinkMethod == .password, error == .invalidCredentials {
                unlinkSheetPasswordError = languageService.text(.changePasswordInvalidCurrent)
            } else if error.shouldShowOnOtpStep {
                unlinkSheetOtpError = error.userMessage
            } else {
                unlinkSheetError = error.userMessage
            }
            return false
        } catch let error as NetworkError {
            unlinkSheetError = error.userMessage
            return false
        } catch {
            unlinkSheetError = languageService.text(.connectedAccountsUnlinkFailed)
            return false
        }
    }

    private enum ResendTarget {
        case phone, email, unlink
    }

    private func startResendCountdown(for target: ResendTarget) {
        stopResendCountdown(for: target)
        setResendSeconds(target, value: Self.otpResendCooldownSeconds)

        let task = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled, let self else { return }
                let remaining = resendSeconds(for: target)
                if remaining > 0 {
                    setResendSeconds(target, value: remaining - 1)
                } else {
                    break
                }
            }
        }

        switch target {
        case .phone: phoneResendTask = task
        case .email: emailResendTask = task
        case .unlink: unlinkResendTask = task
        }
    }

    private func stopResendCountdown(for target: ResendTarget) {
        switch target {
        case .phone:
            phoneResendTask?.cancel()
            phoneResendTask = nil
            phoneResendSecondsRemaining = 0
        case .email:
            emailResendTask?.cancel()
            emailResendTask = nil
            emailResendSecondsRemaining = 0
        case .unlink:
            unlinkResendTask?.cancel()
            unlinkResendTask = nil
            unlinkResendSecondsRemaining = 0
        }
    }

    private func resendSeconds(for target: ResendTarget) -> Int {
        switch target {
        case .phone: return phoneResendSecondsRemaining
        case .email: return emailResendSecondsRemaining
        case .unlink: return unlinkResendSecondsRemaining
        }
    }

    private func setResendSeconds(_ target: ResendTarget, value: Int) {
        switch target {
        case .phone: phoneResendSecondsRemaining = value
        case .email: emailResendSecondsRemaining = value
        case .unlink: unlinkResendSecondsRemaining = value
        }
    }

    private func resetPhoneSheetState() {
        stopResendCountdown(for: .phone)
        connectPhoneNumber = ""
        connectPhoneOtp = ""
        phoneSheetError = nil
        phoneSheetOtpError = nil
        phoneSheetInfo = nil
        hasSentPhoneCode = false
    }

    private func resetEmailSheetState() {
        stopResendCountdown(for: .email)
        connectEmailOtp = ""
        connectEmailPassword = ""
        connectEmailConfirm = ""
        emailSheetError = nil
        emailSheetOtpError = nil
        emailSheetPasswordError = nil
        emailSheetConfirmPasswordError = nil
        emailSheetInfo = nil
        hasSentEmailCode = false
        if isPhoneOnlyAccount {
            connectEmail = ""
        }
    }

    private func resetUnlinkSheetState() {
        stopResendCountdown(for: .unlink)
        unlinkPassword = ""
        unlinkOtpCode = ""
        unlinkMethod = .password
        unlinkSheetError = nil
        unlinkSheetOtpError = nil
        unlinkSheetPasswordError = nil
        unlinkSheetInfo = nil
        hasSentUnlinkCode = false
    }
}
