import XCTest
import SwiftUI
import SplickDomain
import Common
import Storage
import Localization
import DesignSystem
@testable import FeatureAuth

@MainActor
final class AuthViewModelsTests: XCTestCase {

    private var mockRepo: MockAuthRepository!
    private var mockSession: MockSessionManager!
    private var languageService: LanguageService!

    override func setUp() {
        super.setUp()
        mockRepo = MockAuthRepository()
        mockSession = MockSessionManager()
        let mockDefaults = MockUserDefaultsService()
        languageService = LanguageService(userDefaults: mockDefaults)
    }

    private func createDummySession() -> AuthSession {
        let user = User(
            id: UUID(),
            email: "test@splick.app",
            username: "tester",
            displayName: "Test User",
            avatarURL: nil,
            status: .active,
            preferredLocale: "vi",
            timezone: "Asia/Ho_Chi_Minh",
            dateOfBirth: nil,
            createdAt: Date()
        )
        let token = AuthToken(
            accessToken: "access",
            refreshToken: "refresh",
            expiresIn: 3600,
            tokenType: "Bearer",
            sessionId: UUID()
        )
        return AuthSession(user: user, token: token, isNewUser: false)
    }

    // MARK: - LoginViewModel Tests

    private func makeLoginViewModel() -> LoginViewModel {
        LoginViewModel(
            checkIdentifierUseCase: CheckIdentifierUseCase(repository: mockRepo),
            loginUseCase: LoginUseCase(repository: mockRepo, sessionManager: mockSession),
            registerUseCase: RegisterUseCase(repository: mockRepo, sessionManager: mockSession),
            requestEmailOtpUseCase: RequestEmailOtpUseCase(repository: mockRepo),
            requestPhoneOtpUseCase: RequestPhoneOtpUseCase(repository: mockRepo),
            verifyPhoneOtpUseCase: VerifyPhoneOtpUseCase(repository: mockRepo, sessionManager: mockSession),
            googleSignInUseCase: GoogleSignInUseCase(repository: mockRepo, sessionManager: mockSession),
            appleSignInUseCase: AppleSignInUseCase(repository: mockRepo, sessionManager: mockSession),
            reactivateAccountUseCase: ReactivateAccountUseCase(repository: mockRepo, sessionManager: mockSession),
            languageService: languageService
        )
    }

    func testLoginViewModel_identifierDetection() {
        let vm = makeLoginViewModel()

        vm.identifier = ""
        XCTAssertEqual(vm.detectedKind, .unknown)
        XCTAssertEqual(vm.identifierIntent, .unknown)

        vm.identifier = "user@example.com"
        XCTAssertEqual(vm.detectedKind, .email)
        XCTAssertEqual(vm.identifierIntent, .email)

        vm.identifier = "0901234567"
        XCTAssertEqual(vm.detectedKind, .phone)
        XCTAssertEqual(vm.identifierIntent, .phone)

        vm.selectPhoneRegion(.vietnam)
        XCTAssertEqual(vm.selectedPhoneRegion, .vietnam)
    }

    func testLoginViewModel_validationFields() {
        let vm = makeLoginViewModel()

        // Identifier validation
        vm.identifier = ""
        vm.validateIdentifierField()
        XCTAssertNil(vm.identifierError)
        XCTAssertEqual(vm.identifierStatus, .neutral)

        vm.identifier = "notanemail"
        vm.validateIdentifierField()
        XCTAssertEqual(vm.identifierStatus, .neutral)

        vm.identifier = "user@example.com"
        vm.validateIdentifierField()
        XCTAssertNil(vm.identifierError)
        XCTAssertEqual(vm.identifierStatus, .valid)

        // Username validation
        vm.username = "ab"
        vm.onUsernameChanged()
        XCTAssertNotNil(vm.usernameError)

        vm.username = "valid_user"
        vm.onUsernameChanged()
        XCTAssertNil(vm.usernameError)
        XCTAssertEqual(vm.usernameStatus, .valid)

        // Display name validation
        vm.displayName = String(repeating: "a", count: 160)
        vm.validateDisplayNameField()
        XCTAssertNotNil(vm.displayNameError)

        vm.displayName = "Nice Name"
        vm.validateDisplayNameField()
        XCTAssertNil(vm.displayNameError)

        // Date of birth
        vm.prepareDateOfBirthPicker()
        vm.confirmDateOfBirth()
        XCTAssertNotNil(vm.dateOfBirth)
        vm.clearDateOfBirth()
        XCTAssertNil(vm.dateOfBirth)

        // Password validation
        vm.password = "Weak"
        vm.validatePasswordField()
        XCTAssertNotNil(vm.passwordError)
        XCTAssertEqual(vm.passwordStatus, .warning)

        vm.password = "StrongPassword123!"
        vm.validatePasswordField()
        XCTAssertNil(vm.passwordError)
        XCTAssertEqual(vm.passwordStatus, .valid)

        // Confirm password
        vm.confirmPassword = "DifferentPassword123!"
        vm.validateConfirmPasswordField()
        XCTAssertNotNil(vm.confirmPasswordError)

        vm.confirmPassword = "StrongPassword123!"
        vm.validateConfirmPasswordField()
        XCTAssertNil(vm.confirmPasswordError)
    }

    func testLoginViewModel_submitTitlesAndVisibility() {
        let vm = makeLoginViewModel()

        XCTAssertEqual(vm.submitTitleKey, .authContinue)
        XCTAssertFalse(vm.showsPasswordField)
        XCTAssertFalse(vm.showsRegistrationFields)
        XCTAssertFalse(vm.showsForgotPassword)

        XCTAssertTrue(vm.credentialsSubmitDisabled)
        vm.identifier = "valid@example.com"
        XCTAssertFalse(vm.credentialsSubmitDisabled)

        vm.goBackToCredentials()
        XCTAssertEqual(vm.step, .credentials)
        XCTAssertEqual(vm.otpCode, "")
    }

    func testLoginViewModel_useAnotherAccount() {
        let vm = makeLoginViewModel()
        vm.identifier = "test@example.com"
        vm.password = "pass"
        vm.useAnotherAccount()

        XCTAssertEqual(vm.identifier, "")
        XCTAssertEqual(vm.password, "")
        XCTAssertEqual(vm.step, .credentials)
    }

    // MARK: - RegisterViewModel Tests

    private func makeRegisterViewModel() -> RegisterViewModel {
        RegisterViewModel(
            registerUseCase: RegisterUseCase(repository: mockRepo, sessionManager: mockSession),
            requestEmailOtpUseCase: RequestEmailOtpUseCase(repository: mockRepo),
            requestPhoneOtpUseCase: RequestPhoneOtpUseCase(repository: mockRepo),
            languageService: languageService
        )
    }

    func testRegisterViewModel_validationAndChannel() {
        let vm = makeRegisterViewModel()

        vm.channel = .email
        vm.email = "hello@splick.app"
        XCTAssertEqual(vm.registrationIdentifier, "hello@splick.app")

        vm.validateEmailField()
        XCTAssertNil(vm.emailError)
        XCTAssertEqual(vm.emailStatus, .valid)

        vm.suggestUsernameFromEmailIfNeeded()
        XCTAssertFalse(vm.username.isEmpty)

        vm.channel = .phone
        vm.phoneNumber = "+84901234567"
        vm.validatePhoneField()
        XCTAssertNil(vm.phoneError)
        XCTAssertEqual(vm.phoneStatus, .valid)

        vm.password = "StrongPassword123!"
        vm.confirmPassword = "StrongPassword123!"
        vm.validatePasswordField()
        vm.validateConfirmPasswordField()

        vm.goBackToAccountDetails()
        XCTAssertEqual(vm.step, .accountDetails)
        XCTAssertEqual(vm.otpCode, "")
    }

    // MARK: - ForgotPasswordViewModel Tests

    private func makeForgotPasswordViewModel() -> ForgotPasswordViewModel {
        ForgotPasswordViewModel(
            forgotPasswordUseCase: ForgotPasswordUseCase(repository: mockRepo),
            verifyResetPasswordOtpUseCase: VerifyResetPasswordOtpUseCase(repository: mockRepo),
            resetPasswordUseCase: ResetPasswordUseCase(repository: mockRepo, sessionManager: mockSession),
            languageService: languageService
        )
    }

    func testForgotPasswordViewModel_flow() {
        let vm = makeForgotPasswordViewModel()

        vm.identifier = "test@splick.app"
        XCTAssertEqual(vm.detectedKind, .email)
        XCTAssertEqual(vm.normalizedEmail, "test@splick.app")

        vm.validateIdentifierField()
        XCTAssertNil(vm.identifierErrorKey)

        vm.password = "StrongPassword123!"
        vm.confirmPassword = "StrongPassword123!"
        vm.validatePasswordField()
        vm.validateConfirmPasswordField()
        XCTAssertNil(vm.passwordErrorKey)
        XCTAssertNil(vm.confirmPasswordErrorKey)

        vm.goBackToOtp()
        XCTAssertEqual(vm.step, .otp)

        vm.goBackToIdentifier()
        XCTAssertEqual(vm.step, .identifier)

        vm.reset()
        XCTAssertEqual(vm.identifier, "")
        XCTAssertEqual(vm.step, .identifier)
    }

    // MARK: - ChangeUsernameSheetViewModel Tests

    func testChangeUsernameSheetViewModel_validationAndSave() async {
        let vm = ChangeUsernameSheetViewModel(
            currentUsername: "current_user",
            checkUsernameAvailabilityUseCase: CheckUsernameAvailabilityUseCase(repository: mockRepo),
            updateProfileUseCase: UpdateProfileUseCase(repository: mockRepo, sessionManager: mockSession),
            languageService: languageService
        )

        vm.prepareForPresentation()
        XCTAssertEqual(vm.usernameDraft, "current_user")
        XCTAssertNil(vm.usernameError)
        XCTAssertFalse(vm.canSave)

        // Invalid length
        vm.usernameDraft = "a"
        vm.onUsernameChanged()
        XCTAssertNotNil(vm.usernameError)

        // Current username
        vm.usernameDraft = "current_user"
        vm.onUsernameChanged()
        XCTAssertNil(vm.usernameError)
        XCTAssertEqual(vm.usernameStatus, .valid)
        XCTAssertFalse(vm.canSave) // Cannot save same username

        // Valid new username
        let updatedUser = User(
            id: UUID(),
            email: "user@example.com",
            username: "new_username",
            displayName: "Name",
            avatarURL: nil,
            status: .active,
            preferredLocale: "vi",
            timezone: "Asia/Ho_Chi_Minh",
            dateOfBirth: nil,
            createdAt: Date()
        )
        mockRepo.updateProfileResult = .success(updatedUser)
        mockRepo.checkUsernameResult = .success(true)

        vm.usernameDraft = "new_username"
        vm.onUsernameChanged()
    }

    // MARK: - SessionsViewModel Tests

    func testSessionsViewModel_loadAndRevoke() async {
        var signedOut = false
        let dummySession1 = UserSession(
            id: UUID(),
            deviceInfo: "iPhone 15",
            deviceName: "Device 1",
            loginIp: "127.0.0.1",
            loginLocation: "Hanoi",
            createdAt: Date().addingTimeInterval(-100),
            expiresAt: Date().addingTimeInterval(3600),
            isCurrent: true
        )
        let dummySession2 = UserSession(
            id: UUID(),
            deviceInfo: "iPad Air",
            deviceName: "Device 2",
            loginIp: "127.0.0.1",
            loginLocation: "Danang",
            createdAt: Date(),
            expiresAt: Date().addingTimeInterval(3600),
            isCurrent: false
        )
        mockRepo.sessionsResult = .success([dummySession2, dummySession1])

        let vm = SessionsViewModel(
            listSessionsUseCase: ListSessionsUseCase(repository: mockRepo),
            revokeSessionUseCase: RevokeSessionUseCase(repository: mockRepo),
            revokeAllSessionsUseCase: RevokeAllSessionsUseCase(repository: mockRepo, sessionManager: mockSession),
            languageService: languageService,
            onSignedOutEverywhere: { signedOut = true }
        )

        await vm.load()
        XCTAssertEqual(vm.sessions.count, 2)
        XCTAssertTrue(vm.sessions.first?.isCurrent == true) // Current is sorted first

        // Revoking current does nothing
        await vm.revoke(session: dummySession1)

        // Revoking non-current calls repo
        await vm.revoke(session: dummySession2)

        // Revoke all
        await vm.revokeAll()
        XCTAssertTrue(signedOut)
    }

    // MARK: - PaymentProfileManageViewModel Tests

    func testPaymentProfileManageViewModel_lifecycle() async {
        var notifiedProfile: PaymentProfile?
        let expectedProfile = PaymentProfile(
            userId: UUID(),
            qrImageURL: URL(string: "https://example.com/qr.png"),
            accountName: "NGUYEN VAN A",
            accountNumber: "1234567890",
            bankName: "Techcombank",
            updatedAt: Date()
        )
        mockRepo.paymentProfileResult = .success(expectedProfile)
        mockRepo.upsertPaymentProfileResult = .success(expectedProfile)

        let vm = PaymentProfileManageViewModel(
            fetchMyPaymentProfileUseCase: FetchMyPaymentProfileUseCase(repository: mockRepo),
            upsertMyPaymentProfileUseCase: UpsertMyPaymentProfileUseCase(repository: mockRepo),
            deleteMyPaymentProfileUseCase: DeleteMyPaymentProfileUseCase(repository: mockRepo),
            uploadPaymentQr: { _ in URL(string: "https://example.com/uploaded.png")! },
            onProfileChanged: { notifiedProfile = $0 }
        )

        await vm.load()
        XCTAssertEqual(vm.accountName, "NGUYEN VAN A")
        XCTAssertEqual(vm.accountNumber, "1234567890")
        XCTAssertEqual(vm.bankName, "Techcombank")
        XCTAssertTrue(vm.hasSavedProfile)
        XCTAssertFalse(vm.hasUnsavedChanges)

        vm.accountName = "NGUYEN VAN B"
        XCTAssertTrue(vm.hasUnsavedChanges)

        let saveSuccess = await vm.save()
        XCTAssertTrue(saveSuccess)
        XCTAssertNotNil(notifiedProfile)

        vm.removeQrImage()
        XCTAssertNil(vm.qrImageURL)

        let deleteSuccess = await vm.deleteProfile()
        XCTAssertTrue(deleteSuccess)
        XCTAssertEqual(vm.accountName, "")
    }

    // MARK: - AccountClosureSheetViewModel Tests

    func testAccountClosureSheetViewModel_flows() async {
        var completed = false
        let vm = AccountClosureSheetViewModel(
            action: .deactivate,
            accountEmail: "user@example.com",
            canUseEmailVerification: true,
            verifyPasswordChangeUseCase: VerifyPasswordChangeUseCase(repository: mockRepo),
            requestEmailOtpUseCase: RequestEmailOtpUseCase(repository: mockRepo),
            deactivateAccountUseCase: DeactivateAccountUseCase(repository: mockRepo, sessionManager: mockSession),
            deleteAccountUseCase: DeleteAccountUseCase(repository: mockRepo, sessionManager: mockSession),
            languageService: languageService,
            onCompleted: { completed = true }
        )

        XCTAssertEqual(vm.action, .deactivate)
        XCTAssertEqual(vm.method, .password)
        XCTAssertFalse(vm.isVerified)

        vm.onMethodChanged()
        vm.password = "secret"
        vm.onPasswordChanged()
        XCTAssertFalse(vm.isVerified)

        // Cannot execute before verification
        let prematureResult = await vm.executeAction()
        XCTAssertFalse(prematureResult)
        XCTAssertNotNil(vm.sheetError)

        // Verify password
        await vm.verifyIdentity()
        XCTAssertTrue(vm.isVerified)

        // Execute action
        let success = await vm.executeAction()
        XCTAssertTrue(success)
        XCTAssertTrue(completed)

        vm.reset()
        XCTAssertFalse(vm.isVerified)
        XCTAssertEqual(vm.password, "")
    }

    // MARK: - OAuthDisplayName Tests

    func testOAuthDisplayName_resolution() {
        XCTAssertEqual(OAuthDisplayName.emailLocalPart("hello@world.com"), "hello")
        XCTAssertEqual(OAuthDisplayName.emailLocalPart(""), "user")
        XCTAssertEqual(OAuthDisplayName.emailLocalPart("   "), "user")

        XCTAssertEqual(OAuthDisplayName.resolved(current: "Custom Name", email: "user@domain.com"), "Custom Name")
        XCTAssertEqual(OAuthDisplayName.resolved(current: "Splick User", email: "john.doe@domain.com"), "john.doe")
        XCTAssertEqual(OAuthDisplayName.resolved(current: "", email: "alice@domain.com"), "alice")
    }

    // MARK: - EditProfileViewModel Tests

    func testEditProfileViewModel_flows() async {
        let dummy = createDummySession().user
        mockRepo.updateProfileResult = .success(dummy)

        let vm = EditProfileViewModel(
            user: dummy,
            updateProfileUseCase: UpdateProfileUseCase(repository: mockRepo, sessionManager: mockSession),
            languageService: languageService
        )

        XCTAssertEqual(vm.displayName, dummy.displayName)

        // Empty display name with no image fails validation
        vm.displayName = ""
        let failedSave = await vm.save()
        XCTAssertNil(failedSave)
        XCTAssertNotNil(vm.errorMessage)

        // Valid update
        vm.displayName = "Brand New Name"
        let saved = await vm.save()
        XCTAssertNotNil(saved)
    }

    // MARK: - CompleteOAuthProfileViewModel Tests

    func testCompleteOAuthProfileViewModel_flows() async {
        let dummy = createDummySession().user
        mockRepo.updateProfileResult = .success(dummy)

        let vm = CompleteOAuthProfileViewModel(
            user: dummy,
            updateProfileUseCase: UpdateProfileUseCase(repository: mockRepo, sessionManager: mockSession),
            languageService: languageService
        )

        XCTAssertEqual(vm.setupLater().id, dummy.id)

        vm.prepareDateOfBirthPicker()
        vm.confirmDateOfBirth()
        XCTAssertNotNil(vm.dateOfBirth)

        vm.clearDateOfBirth()
        XCTAssertNil(vm.dateOfBirth)

        // Save
        let user = await vm.save()
        XCTAssertNotNil(user)
    }

    // MARK: - ChangePasswordViewModel Tests

    func testChangePasswordViewModel_flows() async {
        let dummy = createDummySession()
        mockRepo.changePasswordResult = .success(dummy)
        mockRepo.connectedAccountsResult = .success(ConnectedAccounts(
            google: .init(isLinked: false, detail: nil),
            emailPassword: .init(isLinked: true, detail: "user@example.com"),
            phone: .init(isLinked: false, detail: nil)
        ))

        let vm = ChangePasswordViewModel(
            accountEmail: "user@example.com",
            changePasswordUseCase: ChangePasswordUseCase(repository: mockRepo, sessionManager: mockSession),
            verifyPasswordChangeUseCase: VerifyPasswordChangeUseCase(repository: mockRepo),
            requestEmailOtpUseCase: RequestEmailOtpUseCase(repository: mockRepo),
            getConnectedAccountsUseCase: GetConnectedAccountsUseCase(repository: mockRepo),
            languageService: languageService
        )

        await vm.loadPasswordLoginState()
        XCTAssertTrue(vm.hasPasswordLogin)

        vm.onMethodChanged()
        vm.currentPassword = "old_password"
        vm.onCurrentPasswordChanged()
        vm.otpCode = "123456"
        vm.onOtpCodeChanged()

        vm.newPassword = "Weak"
        vm.validatePasswordField()
        XCTAssertNotNil(vm.passwordError)

        vm.newPassword = "StrongPassword123!"
        vm.confirmPassword = "StrongPassword123!"
        vm.validatePasswordField()
        vm.validateConfirmPasswordField()
        XCTAssertNil(vm.confirmPasswordError)

        // Verify current password empty
        vm.currentPassword = ""
        await vm.verifyCurrentPassword()
        XCTAssertFalse(vm.isCurrentPasswordVerified)
        XCTAssertNotNil(vm.currentPasswordError)

        // Verify current password valid
        vm.currentPassword = "old_password"
        await vm.verifyCurrentPassword()
        XCTAssertTrue(vm.isCurrentPasswordVerified)

        // Change password
        await vm.changePassword()
        if case .loaded = vm.state {
            // Success
        } else {
            XCTFail("Expected loaded state, got \(vm.state)")
        }

        // Email OTP step
        vm.method = .emailCode
        await vm.requestEmailCode()
        XCTAssertTrue(vm.hasSentEmailCode)
    }

    // MARK: - AuthChannel Tests

    func testAuthChannel_properties() {
        XCTAssertEqual(AuthSignInMethod.email.id, "email")
        XCTAssertEqual(AuthSignInMethod.email.title, "Email")
        XCTAssertEqual(AuthSignInMethod.phone.id, "phone")
        XCTAssertEqual(AuthSignInMethod.phone.title, "Phone")

        XCTAssertEqual(AuthRegistrationChannel.email.id, "email")
        XCTAssertEqual(AuthRegistrationChannel.email.title, "Email")
        XCTAssertEqual(AuthRegistrationChannel.phone.id, "phone")
        XCTAssertEqual(AuthRegistrationChannel.phone.title, "Phone")

        let emailStr = "test@example.com"
        XCTAssertEqual(emailStr.detectedLoginIdentifierKind, .email)
        XCTAssertEqual(emailStr.loginIdentifierIntent, .email)

        let emptyStr = ""
        XCTAssertEqual(emptyStr.detectedLoginIdentifierKind, .unknown)
        XCTAssertEqual(emptyStr.loginIdentifierIntent, .unknown)
    }
}



