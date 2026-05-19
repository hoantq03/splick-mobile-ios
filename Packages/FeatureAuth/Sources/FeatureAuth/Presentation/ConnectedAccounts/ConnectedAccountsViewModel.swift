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
    @Published public var unlinkPassword = ""
    @Published public var unlinkOtpCode = ""
    @Published public var unlinkMethod: VerificationMethod = .password

    public enum VerificationMethod: String, CaseIterable {
        case password = "Password"
        case emailCode = "Email code"
    }

    private let getConnectedAccountsUseCase: GetConnectedAccountsUseCaseProtocol
    private let linkGoogleAccountUseCase: LinkGoogleAccountUseCaseProtocol
    private let unlinkGoogleAccountUseCase: UnlinkGoogleAccountUseCaseProtocol
    private let requestEmailOtpUseCase: RequestEmailOtpUseCaseProtocol
    private let googleSignInPresenter: GoogleSignInPresenting?
    private let accountEmail: String

    public var isGoogleLinkAvailable: Bool {
        googleSignInPresenter?.isAvailable == true
    }

    public init(
        accountEmail: String,
        getConnectedAccountsUseCase: GetConnectedAccountsUseCaseProtocol,
        linkGoogleAccountUseCase: LinkGoogleAccountUseCaseProtocol,
        unlinkGoogleAccountUseCase: UnlinkGoogleAccountUseCaseProtocol,
        requestEmailOtpUseCase: RequestEmailOtpUseCaseProtocol,
        googleSignInPresenter: GoogleSignInPresenting?
    ) {
        self.accountEmail = accountEmail
        self.getConnectedAccountsUseCase = getConnectedAccountsUseCase
        self.linkGoogleAccountUseCase = linkGoogleAccountUseCase
        self.unlinkGoogleAccountUseCase = unlinkGoogleAccountUseCase
        self.requestEmailOtpUseCase = requestEmailOtpUseCase
        self.googleSignInPresenter = googleSignInPresenter
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
