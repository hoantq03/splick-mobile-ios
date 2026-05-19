import Foundation
import Common
import SplickDomain

@MainActor
public final class ConnectedAccountsViewModel: ObservableObject {
    @Published public private(set) var accounts: ConnectedAccounts?
    @Published public private(set) var isLoading = false
    @Published public var errorMessage: String?
    @Published public var infoMessage: String?
    @Published public var isLinkingGoogle = false
    @Published public var isUnlinkingGoogle = false
    @Published public var showUnlinkSheet = false
    @Published public var showConnectPhoneSheet = false
    @Published public var showConnectEmailSheet = false
    @Published public var unlinkPassword = ""
    @Published public var unlinkOtpCode = ""
    @Published public var unlinkMethod: VerificationMethod = .password
    @Published public var connectPhoneNumber = ""
    @Published public var connectPhoneOtp = ""
    @Published public var connectEmail = ""
    @Published public var connectEmailOtp = ""
    @Published public var connectEmailPassword = ""
    @Published public var connectEmailConfirm = ""
    @Published public var isConnectingPhone = false
    @Published public var isConnectingEmail = false

    public enum VerificationMethod: String, CaseIterable {
        case password = "Password"
        case emailCode = "Email code"
    }

    private let getConnectedAccountsUseCase: GetConnectedAccountsUseCaseProtocol
    private let linkGoogleAccountUseCase: LinkGoogleAccountUseCaseProtocol
    private let unlinkGoogleAccountUseCase: UnlinkGoogleAccountUseCaseProtocol
    private let linkPhoneAccountUseCase: LinkPhoneAccountUseCaseProtocol
    private let linkEmailAccountUseCase: LinkEmailAccountUseCaseProtocol
    private let requestEmailOtpUseCase: RequestEmailOtpUseCaseProtocol
    private let googleSignInPresenter: GoogleSignInPresenting?
    private let accountEmail: String

    public var isGoogleLinkAvailable: Bool {
        googleSignInPresenter?.isAvailable == true
    }

    public var isPhoneOnlyAccount: Bool {
        accountEmail.lowercased().hasSuffix("@phone.splick.local")
    }

    public var linkEmailAddress: String {
        isPhoneOnlyAccount ? connectEmail : accountEmail
    }

    public init(
        accountEmail: String,
        getConnectedAccountsUseCase: GetConnectedAccountsUseCaseProtocol,
        linkGoogleAccountUseCase: LinkGoogleAccountUseCaseProtocol,
        unlinkGoogleAccountUseCase: UnlinkGoogleAccountUseCaseProtocol,
        linkPhoneAccountUseCase: LinkPhoneAccountUseCaseProtocol,
        linkEmailAccountUseCase: LinkEmailAccountUseCaseProtocol,
        requestEmailOtpUseCase: RequestEmailOtpUseCaseProtocol,
        googleSignInPresenter: GoogleSignInPresenting?
    ) {
        self.accountEmail = accountEmail
        self.getConnectedAccountsUseCase = getConnectedAccountsUseCase
        self.linkGoogleAccountUseCase = linkGoogleAccountUseCase
        self.unlinkGoogleAccountUseCase = unlinkGoogleAccountUseCase
        self.linkPhoneAccountUseCase = linkPhoneAccountUseCase
        self.linkEmailAccountUseCase = linkEmailAccountUseCase
        self.requestEmailOtpUseCase = requestEmailOtpUseCase
        self.googleSignInPresenter = googleSignInPresenter
        if !isPhoneOnlyAccount {
            connectEmail = accountEmail
        }
    }

    public func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            accounts = try await getConnectedAccountsUseCase.execute()
        } catch {
            errorMessage = "Could not load connected accounts."
        }
    }

    public func linkGoogle() async {
        guard let googleSignInPresenter, googleSignInPresenter.isAvailable else {
            errorMessage = "Google Sign-In is not available on this device."
            return
        }
        isLinkingGoogle = true
        errorMessage = nil
        infoMessage = nil
        defer { isLinkingGoogle = false }
        do {
            let idToken = try await googleSignInPresenter.fetchIdToken()
            try await linkGoogleAccountUseCase.execute(idToken: idToken)
            infoMessage = "Google account linked."
            await load()
        } catch let error as AuthError {
            errorMessage = error.userMessage
        } catch {
            errorMessage = "Could not link Google account."
        }
    }

    public func requestPhoneConnectCode() async {
        errorMessage = nil
        do {
            try await linkPhoneAccountUseCase.requestOtp(phoneNumber: connectPhoneNumber)
            infoMessage = "Verification code sent to \(connectPhoneNumber)."
        } catch let error as AuthError {
            errorMessage = error.userMessage
        } catch {
            errorMessage = "Could not send verification code."
        }
    }

    public func linkPhone() async -> Bool {
        isConnectingPhone = true
        errorMessage = nil
        defer { isConnectingPhone = false }
        do {
            try await linkPhoneAccountUseCase.execute(
                phoneNumber: connectPhoneNumber,
                otpCode: connectPhoneOtp
            )
            connectPhoneNumber = ""
            connectPhoneOtp = ""
            showConnectPhoneSheet = false
            infoMessage = "Phone number connected."
            await load()
            return true
        } catch let error as AuthError {
            errorMessage = error.userMessage
            return false
        } catch {
            errorMessage = "Could not connect phone number."
            return false
        }
    }

    public func requestEmailConnectCode() async {
        errorMessage = nil
        let email = linkEmailAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !email.isEmpty else {
            errorMessage = "Enter an email address."
            return
        }
        do {
            try await linkEmailAccountUseCase.requestOtp(email: isPhoneOnlyAccount ? email : nil)
            infoMessage = "Verification code sent to \(email)."
        } catch let error as AuthError {
            errorMessage = error.userMessage
        } catch {
            errorMessage = "Could not send verification code."
        }
    }

    public func linkEmail() async -> Bool {
        guard connectEmailPassword == connectEmailConfirm else {
            errorMessage = "Passwords do not match."
            return false
        }
        guard connectEmailPassword.count >= AppConstants.Validation.minPasswordLength else {
            errorMessage = "Password must be at least \(AppConstants.Validation.minPasswordLength) characters."
            return false
        }
        isConnectingEmail = true
        errorMessage = nil
        defer { isConnectingEmail = false }
        let email = isPhoneOnlyAccount ? linkEmailAddress.trimmingCharacters(in: .whitespacesAndNewlines) : nil
        do {
            try await linkEmailAccountUseCase.execute(
                email: email,
                otpCode: connectEmailOtp,
                password: connectEmailPassword
            )
            connectEmailOtp = ""
            connectEmailPassword = ""
            connectEmailConfirm = ""
            showConnectEmailSheet = false
            infoMessage = "Email and password connected."
            await load()
            return true
        } catch let error as AuthError {
            errorMessage = error.userMessage
            return false
        } catch {
            errorMessage = "Could not connect email."
            return false
        }
    }

    public func requestUnlinkCode() async {
        errorMessage = nil
        do {
            try await requestEmailOtpUseCase.execute(email: accountEmail)
            infoMessage = "Verification code sent to \(accountEmail)."
        } catch let error as AuthError {
            errorMessage = error.userMessage
        } catch {
            errorMessage = "Could not send verification code."
        }
    }

    public func unlinkGoogle() async -> Bool {
        isUnlinkingGoogle = true
        errorMessage = nil
        defer { isUnlinkingGoogle = false }
        do {
            let password = unlinkMethod == .password ? unlinkPassword : nil
            let otp = unlinkMethod == .emailCode ? unlinkOtpCode : nil
            try await unlinkGoogleAccountUseCase.execute(currentPassword: password, otpCode: otp)
            unlinkPassword = ""
            unlinkOtpCode = ""
            showUnlinkSheet = false
            infoMessage = "Google account unlinked."
            await load()
            return true
        } catch let error as AuthError {
            errorMessage = error.userMessage
            return false
        } catch {
            errorMessage = "Could not unlink Google account."
            return false
        }
    }
}
