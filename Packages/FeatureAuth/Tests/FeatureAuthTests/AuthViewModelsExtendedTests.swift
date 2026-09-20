import XCTest
import SwiftUI
import SplickDomain
import Common
import Storage
import Localization
import DesignSystem
@testable import FeatureAuth

@MainActor
final class AuthViewModelsExtendedTests: XCTestCase {

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

    private func createDummyUser(status: UserAccountStatus = .active) -> User {
        User(
            id: UUID(),
            email: "test@splick.app",
            username: "tester",
            displayName: "Test User",
            avatarURL: nil,
            status: status,
            preferredLocale: "vi",
            timezone: "Asia/Ho_Chi_Minh",
            dateOfBirth: nil,
            createdAt: Date()
        )
    }

    private func createDummySession(status: UserAccountStatus = .active) -> AuthSession {
        let user = createDummyUser(status: status)
        let token = AuthToken(
            accessToken: "access",
            refreshToken: "refresh",
            expiresIn: 3600,
            tokenType: "Bearer",
            sessionId: UUID()
        )
        return AuthSession(user: user, token: token, isNewUser: false)
    }

    // MARK: - ChangeUsernameSheetViewModel Tests

    func testChangeUsernameSheetViewModel_allBranches() async {
        let checkUsernameUC = CheckUsernameAvailabilityUseCase(repository: mockRepo)
        let updateProfileUC = UpdateProfileUseCase(repository: mockRepo, sessionManager: mockSession)

        let vm = ChangeUsernameSheetViewModel(
            currentUsername: "current_user",
            checkUsernameAvailabilityUseCase: checkUsernameUC,
            updateProfileUseCase: updateProfileUC,
            languageService: languageService
        )

        // 1. Initial & presentation reset
        vm.usernameDraft = "temp"
        vm.prepareForPresentation()
        XCTAssertEqual(vm.usernameDraft, "current_user")
        XCTAssertNil(vm.usernameError)
        XCTAssertNil(vm.saveError)
        XCTAssertFalse(vm.canSave)

        // 2. Format validation: empty
        vm.usernameDraft = ""
        vm.onUsernameChanged()
        XCTAssertNil(vm.usernameError)
        XCTAssertFalse(vm.canSave)

        // 3. Format validation: too short (< 3)
        vm.usernameDraft = "ab"
        vm.onUsernameChanged()
        XCTAssertNotNil(vm.usernameError)
        XCTAssertFalse(vm.canSave)

        // 4. Format validation: too long (> 50)
        vm.usernameDraft = String(repeating: "a", count: 55)
        vm.onUsernameChanged()
        XCTAssertNotNil(vm.usernameError)
        XCTAssertFalse(vm.canSave)

        // 5. Format validation: invalid characters (spaces / symbols)
        vm.usernameDraft = "user name!"
        vm.onUsernameChanged()
        XCTAssertNotNil(vm.usernameError)
        XCTAssertFalse(vm.canSave)

        // 6. Username equal to currentUsername -> valid but canSave is false
        vm.usernameDraft = "current_user"
        vm.onUsernameChanged()
        XCTAssertNil(vm.usernameError)
        XCTAssertFalse(vm.canSave)

        // 7. Valid username format, availability check returns true
        mockRepo.checkUsernameResult = .success(true)
        vm.usernameDraft = "available_user"
        vm.onUsernameChanged()
        // Wait for debounce (400ms) + async check
        try? await Task.sleep(nanoseconds: 500_000_000)
        XCTAssertNil(vm.usernameError)
        XCTAssertTrue(vm.canSave)

        // 8. Availability check returns false (taken)
        mockRepo.checkUsernameResult = .success(false)
        vm.usernameDraft = "taken_user"
        vm.onUsernameChanged()
        try? await Task.sleep(nanoseconds: 500_000_000)
        XCTAssertNotNil(vm.usernameError)
        XCTAssertFalse(vm.canSave)

        // 9. Availability check throws error
        mockRepo.checkUsernameResult = .failure(NetworkError.serverError(statusCode: 500))
        vm.usernameDraft = "error_user"
        vm.onUsernameChanged()
        try? await Task.sleep(nanoseconds: 500_000_000)
        XCTAssertNotNil(vm.usernameError)
        XCTAssertFalse(vm.canSave)

        // 10. save() when canSave is false -> returns nil
        let nilUser = await vm.save()
        XCTAssertNil(nilUser)

        // 11. save() success
        mockRepo.checkUsernameResult = .success(true)
        vm.usernameDraft = "new_valid_user"
        vm.onUsernameChanged()
        try? await Task.sleep(nanoseconds: 500_000_000)
        XCTAssertTrue(vm.canSave)

        let updatedUser = createDummyUser()
        mockRepo.updateProfileResult = .success(updatedUser)
        let savedUser = await vm.save()
        XCTAssertNotNil(savedUser)
        XCTAssertNil(vm.saveError)

        // 12. save() failure
        mockRepo.updateProfileResult = .failure(NetworkError.noConnection)
        let failedUser = await vm.save()
        XCTAssertNil(failedUser)
        XCTAssertNotNil(vm.saveError)
    }

    // MARK: - AccountClosureSheetViewModel Tests

    func testAccountClosureSheetViewModel_allBranches() async {
        let verifyPasswordUC = VerifyPasswordChangeUseCase(repository: mockRepo)
        let requestEmailOtpUC = RequestEmailOtpUseCase(repository: mockRepo)
        let deactivateUC = DeactivateAccountUseCase(repository: mockRepo, sessionManager: mockSession)
        let deleteUC = DeleteAccountUseCase(repository: mockRepo, sessionManager: mockSession)

        var completedDeactivate = false
        let vm = AccountClosureSheetViewModel(
            action: .deactivate,
            accountEmail: "user@example.com",
            canUseEmailVerification: true,
            verifyPasswordChangeUseCase: verifyPasswordUC,
            requestEmailOtpUseCase: requestEmailOtpUC,
            deactivateAccountUseCase: deactivateUC,
            deleteAccountUseCase: deleteUC,
            languageService: languageService,
            onCompleted: { completedDeactivate = true }
        )

        // Initial setup
        XCTAssertEqual(vm.action.id, .deactivate)
        XCTAssertEqual(vm.accountEmail, "user@example.com")
        XCTAssertTrue(vm.canUseEmailVerification)

        // Execute action before verified -> returns false with sheetError
        let earlyResult = await vm.executeAction()
        XCTAssertFalse(earlyResult)
        XCTAssertNotNil(vm.sheetError)

        // Verify password - empty -> shows passwordError
        vm.password = ""
        await vm.verifyIdentity()
        XCTAssertFalse(vm.isVerified)
        XCTAssertNotNil(vm.passwordError)

        // Verify password - invalid credentials error
        mockRepo.verifyPasswordChangeResult = .failure(AuthError.invalidCredentials)
        vm.password = "wrongpass"
        await vm.verifyIdentity()
        XCTAssertFalse(vm.isVerified)
        XCTAssertNotNil(vm.passwordError)

        // Verify password - unauthorized network error
        mockRepo.verifyPasswordChangeResult = .failure(NetworkError.unauthorized)
        await vm.verifyIdentity()
        XCTAssertFalse(vm.isVerified)
        XCTAssertNotNil(vm.passwordError)

        // Verify password - generic network error
        mockRepo.verifyPasswordChangeResult = .failure(NetworkError.noConnection)
        await vm.verifyIdentity()
        XCTAssertFalse(vm.isVerified)
        XCTAssertNotNil(vm.passwordError)

        // onPasswordChanged clears errors and un-verifies
        vm.onPasswordChanged()
        XCTAssertNil(vm.passwordError)

        // Verify password - success
        mockRepo.verifyPasswordChangeResult = .success(())
        vm.password = "correctpass"
        await vm.verifyIdentity()
        XCTAssertTrue(vm.isVerified)

        // Execute action - deactivate failure
        mockRepo.deactivateAccountResult = .failure(AuthError.invalidCredentials)
        let failedDeact = await vm.executeAction()
        XCTAssertFalse(failedDeact)
        XCTAssertNotNil(vm.sheetError)

        // Re-verify
        await vm.verifyIdentity()
        XCTAssertTrue(vm.isVerified)

        // Execute action - deactivate success
        mockRepo.deactivateAccountResult = .success(())
        let okDeact = await vm.executeAction()
        XCTAssertTrue(okDeact)
        XCTAssertTrue(completedDeactivate)

        // Switch to email code method
        vm.method = .emailCode
        vm.onMethodChanged()
        XCTAssertFalse(vm.isVerified)
        XCTAssertFalse(vm.hasSentEmailCode)

        // Request email code - success
        mockRepo.requestEmailOtpResult = .success(())
        await vm.requestEmailCode()
        XCTAssertTrue(vm.hasSentEmailCode)
        XCTAssertNotNil(vm.otpInfoMessage)
        XCTAssertFalse(vm.sendCodeFailed)

        // Calling requestEmailCode again while cooldown is active -> does nothing
        await vm.requestEmailCode()

        // Reset clears countdown
        vm.reset()
        XCTAssertEqual(vm.otpResendSecondsRemaining, 0)

        // Request email code - failure with otpRateLimited
        mockRepo.requestEmailOtpResult = .failure(AuthError.otpRateLimited)
        await vm.resendEmailCode()
        XCTAssertTrue(vm.sendCodeFailed)
        XCTAssertNotNil(vm.otpError)

        // Request email code - failure with unauthorized
        mockRepo.requestEmailOtpResult = .failure(NetworkError.unauthorized)
        vm.reset()
        vm.method = .emailCode
        await vm.requestEmailCode()
        XCTAssertTrue(vm.sendCodeFailed)

        // Verify email code - invalid length (< 6)
        vm.otpCode = "123"
        await vm.verifyIdentity()
        XCTAssertFalse(vm.isVerified)
        XCTAssertNotNil(vm.otpError)

        // onOtpCodeChanged clears error
        vm.onOtpCodeChanged()
        XCTAssertNil(vm.otpError)

        // Verify email code - failure
        mockRepo.verifyPasswordChangeResult = .failure(AuthError.invalidCredentials)
        vm.otpCode = "123456"
        await vm.verifyIdentity()
        XCTAssertFalse(vm.isVerified)
        XCTAssertNotNil(vm.otpError)

        // Verify email code - success
        mockRepo.verifyPasswordChangeResult = .success(())
        await vm.verifyIdentity()
        XCTAssertTrue(vm.isVerified)

        // Test delete action
        var completedDelete = false
        let deleteVm = AccountClosureSheetViewModel(
            action: .delete,
            accountEmail: "user@example.com",
            canUseEmailVerification: false,
            verifyPasswordChangeUseCase: verifyPasswordUC,
            requestEmailOtpUseCase: requestEmailOtpUC,
            deactivateAccountUseCase: deactivateUC,
            deleteAccountUseCase: deleteUC,
            languageService: languageService,
            onCompleted: { completedDelete = true }
        )
        XCTAssertEqual(deleteVm.method, .password)

        deleteVm.password = "pass"
        await deleteVm.verifyIdentity()
        XCTAssertTrue(deleteVm.isVerified)

        mockRepo.deleteAccountResult = .success(())
        let okDelete = await deleteVm.executeAction()
        XCTAssertTrue(okDelete)
        XCTAssertTrue(completedDelete)
    }

    // MARK: - RegisterViewModel Tests

    func testRegisterViewModel_phoneAndValidationFlows() async {
        let registerUC = RegisterUseCase(repository: mockRepo, sessionManager: mockSession)
        let reqEmailUC = RequestEmailOtpUseCase(repository: mockRepo)
        let reqPhoneUC = RequestPhoneOtpUseCase(repository: mockRepo)

        let vm = RegisterViewModel(
            registerUseCase: registerUC,
            requestEmailOtpUseCase: reqEmailUC,
            requestPhoneOtpUseCase: reqPhoneUC,
            languageService: languageService
        )

        // 1. Email suggestion
        vm.email = "john.doe@example.com"
        vm.suggestUsernameFromEmailIfNeeded()
        XCTAssertEqual(vm.username, "john.doe")

        // 2. Phone validation: empty, valid E164, invalid
        vm.channel = .phone
        vm.phoneNumber = ""
        vm.validatePhoneField()
        XCTAssertNil(vm.phoneError)

        vm.phoneNumber = "+84901234567"
        vm.validatePhoneField()
        XCTAssertNil(vm.phoneError)
        XCTAssertEqual(vm.registrationIdentifier, "+84901234567")

        vm.phoneNumber = "invalid_phone"
        vm.validatePhoneField()
        XCTAssertNotNil(vm.phoneError)

        // 3. Username validation: short, long, invalid, valid
        vm.username = "ab"
        vm.validateUsernameField()
        XCTAssertNotNil(vm.usernameError)

        vm.username = String(repeating: "x", count: 55)
        vm.validateUsernameField()
        XCTAssertNotNil(vm.usernameError)

        vm.username = "user name"
        vm.validateUsernameField()
        XCTAssertNotNil(vm.usernameError)

        vm.username = "valid_user"
        vm.validateUsernameField()
        XCTAssertNil(vm.usernameError)

        // 4. Password mismatch
        vm.password = "StrongPassword123!"
        vm.confirmPassword = "DifferentPassword123!"
        vm.validatePasswordField()
        XCTAssertNotNil(vm.confirmPasswordError)

        // Matching passwords
        vm.confirmPassword = "StrongPassword123!"
        vm.validateConfirmPasswordField()
        XCTAssertNil(vm.confirmPasswordError)

        // 5. Request phone OTP - success
        vm.phoneNumber = "+84901234567"
        mockRepo.requestPhoneOtpResult = .success(())
        await vm.requestOtpAndContinue()
        XCTAssertEqual(vm.step, .otpVerification)
        XCTAssertNotNil(vm.otpInfoMessage)

        // 6. Resend OTP
        await vm.resendOtp()
        XCTAssertEqual(vm.step, .otpVerification)

        // 7. Register OTP validation - invalid length
        vm.otpCode = "12"
        await vm.register()
        XCTAssertNotNil(vm.otpError)

        // 8. Register failure with network error
        vm.otpCode = "123456"
        mockRepo.registerPhoneResult = .failure(NetworkError.serverError(statusCode: 500))
        await vm.register()
        XCTAssertNotNil(vm.otpError)

        // 9. Register failure with decodingFailed network error
        mockRepo.registerPhoneResult = .failure(NetworkError.decodingFailed)
        await vm.register()
        if case .failed = vm.state {} else {
            XCTFail("Expected .failed state on decodingFailed")
        }

        // 10. Register failure with AuthError phoneAlreadyExists
        mockRepo.registerPhoneResult = .failure(AuthError.phoneAlreadyExists)
        await vm.register()
        XCTAssertEqual(vm.step, .accountDetails)
        XCTAssertNotNil(vm.phoneError)

        // 11. Back to account details
        vm.step = .otpVerification
        vm.goBackToAccountDetails()
        XCTAssertEqual(vm.step, .accountDetails)

        // 12. Switch to email channel and test validation message parsing
        vm.channel = .email
        vm.email = "test@example.com"
        vm.username = "tester"
        vm.password = "StrongPassword123!"
        vm.confirmPassword = "StrongPassword123!"
        mockRepo.requestEmailOtpResult = .failure(NetworkError.unknown("email: already in use, username: invalid"))
        await vm.requestOtpAndContinue()
        XCTAssertEqual(vm.emailError, "already in use")
        XCTAssertEqual(vm.usernameError, "invalid")
    }

    // MARK: - EditProfileViewModel Tests

    func testEditProfileViewModel_extended() async {
        let dummy = createDummyUser()
        let updateUC = UpdateProfileUseCase(repository: mockRepo, sessionManager: mockSession)

        var uploadedAvatar: UIImage?
        let mockUploader: UserAvatarUploader = { image in
            uploadedAvatar = image
            return URL(string: "https://example.com/uploaded.png")!
        }

        let vm = EditProfileViewModel(
            user: dummy,
            updateProfileUseCase: updateUC,
            languageService: languageService,
            uploadAvatar: mockUploader
        )

        // Photo item changed to nil
        vm.selectedPhotoItem = nil
        await vm.onPhotoItemChanged()
        XCTAssertNil(vm.previewImage)

        // Save with preview image & avatar uploader
        let dummyImage = UIImage()
        vm.previewImage = dummyImage
        vm.displayName = "Uploaded Name"
        mockRepo.updateProfileResult = .success(dummy)

        let saved = await vm.save()
        XCTAssertNotNil(saved)
        XCTAssertNotNil(uploadedAvatar)

        // Save failure
        mockRepo.updateProfileResult = .failure(NetworkError.serverError(statusCode: 500))
        let failed = await vm.save()
        XCTAssertNil(failed)
        XCTAssertNotNil(vm.errorMessage)
    }

    // MARK: - ForgotPasswordViewModel Tests

    func testForgotPasswordViewModel_extended() async {
        let forgotUC = ForgotPasswordUseCase(repository: mockRepo)
        let verifyUC = VerifyResetPasswordOtpUseCase(repository: mockRepo)
        let resetUC = ResetPasswordUseCase(repository: mockRepo, sessionManager: mockSession)

        let vm = ForgotPasswordViewModel(
            forgotPasswordUseCase: forgotUC,
            verifyResetPasswordOtpUseCase: verifyUC,
            resetPasswordUseCase: resetUC,
            languageService: languageService
        )

        // 1. Password field error formatting
        XCTAssertNil(vm.passwordFieldError)
        vm.password = "weak"
        vm.validatePasswordField()
        XCTAssertNil(vm.passwordFieldError)

        // 2. Identifier validation: phone detected
        vm.identifier = "+84901234567"
        await vm.requestResetCode()
        XCTAssertEqual(vm.identifierErrorKey, .authForgotPasswordPhoneUnsupported)

        // 3. Request reset code - network error
        vm.identifier = "user@example.com"
        mockRepo.forgotPasswordResult = .failure(NetworkError.serverError(statusCode: 500))
        await vm.requestResetCode()
        XCTAssertTrue(vm.showErrorAlert)

        // 4. Request reset code - success
        mockRepo.forgotPasswordResult = .success(())
        await vm.requestResetCode()
        XCTAssertEqual(vm.step, .otp)

        // 5. Verify code - short code (< 6)
        vm.otpCode = "123"
        await vm.verifyResetCode()
        XCTAssertEqual(vm.otpErrorKey, .changePasswordOtpRequired)

        // 6. Verify code - AuthError with shouldShowOnOtpStep
        vm.otpCode = "123456"
        mockRepo.verifyResetPasswordOtpResult = .failure(AuthError.invalidOtp("Invalid code"))
        await vm.verifyResetCode()
        XCTAssertEqual(vm.otpErrorKey, .errorAuthInvalidOtpDefault)

        // 7. Verify code - success
        mockRepo.verifyResetPasswordOtpResult = .success(())
        await vm.verifyResetCode()
        XCTAssertEqual(vm.step, .newPassword)
        XCTAssertTrue(vm.isOtpVerified)

        // 8. Reset password - weak password returns early
        vm.password = "weak"
        vm.confirmPassword = "weak"
        await vm.resetPassword()

        // 9. Reset password - invalid otp code resets step to otp
        vm.password = "StrongPassword123!"
        vm.confirmPassword = "StrongPassword123!"
        vm.otpCode = "12"
        await vm.resetPassword()
        XCTAssertEqual(vm.step, .otp)
        XCTAssertFalse(vm.isOtpVerified)

        // 10. Reset password - failure with network error
        vm.otpCode = "123456"
        mockRepo.verifyResetPasswordOtpResult = .success(())
        await vm.verifyResetCode()
        XCTAssertTrue(vm.isOtpVerified)

        mockRepo.resetPasswordResult = .failure(NetworkError.serverError(statusCode: 500))
        await vm.resetPassword()
        XCTAssertTrue(vm.showErrorAlert)

        // 11. Navigation helpers: goBackToIdentifier & goBackToOtp
        vm.goBackToOtp()
        XCTAssertEqual(vm.step, .otp)
        XCTAssertFalse(vm.isOtpVerified)

        vm.goBackToIdentifier()
        XCTAssertEqual(vm.step, .identifier)
    }

    // MARK: - PaymentProfileManageViewModel Tests

    func testPaymentProfileManageViewModel_extended() async {
        let fetchUC = FetchMyPaymentProfileUseCase(repository: mockRepo)
        let upsertUC = UpsertMyPaymentProfileUseCase(repository: mockRepo)
        let deleteUC = DeleteMyPaymentProfileUseCase(repository: mockRepo)

        var uploadedImage: UIImage?
        let uploadQr: (UIImage) async throws -> URL = { image in
            uploadedImage = image
            return URL(string: "https://example.com/qr.png")!
        }

        var profileChanged: PaymentProfile?
        let vm = PaymentProfileManageViewModel(
            fetchMyPaymentProfileUseCase: fetchUC,
            upsertMyPaymentProfileUseCase: upsertUC,
            deleteMyPaymentProfileUseCase: deleteUC,
            uploadPaymentQr: uploadQr,
            onProfileChanged: { profileChanged = $0 }
        )

        // 1. Upload QR image
        let dummyImg = UIImage()
        await vm.uploadQrImage(dummyImg)
        XCTAssertNotNil(uploadedImage)
        XCTAssertEqual(vm.qrImageURL?.absoluteString, "https://example.com/qr.png")
        XCTAssertNil(vm.errorMessage)

        // 2. Remove QR image
        vm.removeQrImage()
        XCTAssertNil(vm.qrImageURL)

        // 3. Save with invalid bank details -> PaymentProfileFormError
        vm.accountName = "A"
        vm.accountNumber = "" // Incomplete bank set
        vm.bankName = ""
        let failedValidation = await vm.save()
        XCTAssertFalse(failedValidation)
        XCTAssertNotNil(vm.errorMessage)

        // 4. Save with valid bank details, upsert failure
        vm.accountNumber = "123456789"
        vm.bankName = "Bank"
        mockRepo.upsertPaymentProfileResult = .failure(NetworkError.serverError(statusCode: 500))
        let failedSave = await vm.save()
        XCTAssertFalse(failedSave)
        XCTAssertNotNil(vm.errorMessage)

        // 5. Save with valid bank details, upsert success
        let dummyProfile = PaymentProfile(
            userId: UUID(),
            qrImageURL: nil,
            accountName: "A",
            accountNumber: "123456789",
            bankName: "Bank",
            updatedAt: Date()
        )
        mockRepo.upsertPaymentProfileResult = .success(dummyProfile)
        let okSave = await vm.save()
        XCTAssertTrue(okSave)
        XCTAssertNotNil(profileChanged)
        XCTAssertTrue(vm.hasSavedProfile)
        XCTAssertFalse(vm.hasUnsavedChanges)

        // Modifying account name triggers unsaved changes
        vm.accountName = "B"
        XCTAssertTrue(vm.hasUnsavedChanges)

        // 6. Delete profile failure
        mockRepo.deletePaymentProfileResult = .failure(NetworkError.serverError(statusCode: 500))
        let failedDelete = await vm.deleteProfile()
        XCTAssertFalse(failedDelete)
        XCTAssertNotNil(vm.errorMessage)

        // 7. Delete profile success
        mockRepo.deletePaymentProfileResult = .success(())
        let okDelete = await vm.deleteProfile()
        XCTAssertTrue(okDelete)
        XCTAssertFalse(vm.hasSavedProfile)
    }

    // MARK: - SessionsViewModel Tests

    func testSessionsViewModel_extended() async {
        let listUC = ListSessionsUseCase(repository: mockRepo)
        let revokeUC = RevokeSessionUseCase(repository: mockRepo)
        let revokeAllUC = RevokeAllSessionsUseCase(repository: mockRepo, sessionManager: mockSession)

        var signedOutEverywhere = false
        let vm = SessionsViewModel(
            listSessionsUseCase: listUC,
            revokeSessionUseCase: revokeUC,
            revokeAllSessionsUseCase: revokeAllUC,
            languageService: languageService,
            onSignedOutEverywhere: { signedOutEverywhere = true }
        )

        // 1. Load with sorting (current session first, then by date descending)
        let now = Date()
        let session1 = UserSession(id: UUID(), deviceInfo: "d1", deviceName: "n1", loginIp: nil, loginLocation: nil, createdAt: now.addingTimeInterval(-100), expiresAt: now, isCurrent: false)
        let session2 = UserSession(id: UUID(), deviceInfo: "d2", deviceName: "n2", loginIp: nil, loginLocation: nil, createdAt: now.addingTimeInterval(-50), expiresAt: now, isCurrent: false)
        let sessionCurrent = UserSession(id: UUID(), deviceInfo: "d3", deviceName: "n3", loginIp: nil, loginLocation: nil, createdAt: now.addingTimeInterval(-200), expiresAt: now, isCurrent: true)

        mockRepo.sessionsResult = .success([session1, session2, sessionCurrent])
        await vm.load()
        XCTAssertEqual(vm.sessions.count, 3)
        XCTAssertTrue(vm.sessions.first?.isCurrent == true)
        XCTAssertEqual(vm.sessions[1].id, session2.id)

        // 2. Revoke current session -> does nothing (guard !session.isCurrent)
        await vm.revoke(session: sessionCurrent)

        // 3. Revoke other session failure
        mockRepo.revokeSessionResult = .failure(NetworkError.serverError(statusCode: 500))
        await vm.revoke(session: session1)
        XCTAssertNotNil(vm.errorMessage)

        // 4. Revoke other session success
        mockRepo.revokeSessionResult = .success(())
        await vm.revoke(session: session1)

        // 5. Revoke all failure
        mockRepo.revokeAllSessionsResult = .failure(NetworkError.serverError(statusCode: 500))
        await vm.revokeAll()
        XCTAssertNotNil(vm.errorMessage)

        // 6. Revoke all success
        mockRepo.revokeAllSessionsResult = .success(())
        await vm.revokeAll()
        XCTAssertTrue(signedOutEverywhere)
    }

    // MARK: - LoginViewModel Extended Tests

    func testLoginViewModel_extended() async {
        let vm = LoginViewModel(
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

        // 1. Date of birth picker
        vm.prepareDateOfBirthPicker()
        XCTAssertNotNil(vm.dateOfBirthDraft)

        vm.confirmDateOfBirth()
        XCTAssertNotNil(vm.dateOfBirth)

        vm.clearDateOfBirth()
        XCTAssertNil(vm.dateOfBirth)

        // 2. selectPhoneRegion
        vm.selectPhoneRegion(.vietnam)
        XCTAssertEqual(vm.selectedPhoneRegion, .vietnam)

        // 3. goBackToCredentials & goBackFromRegisterOtp
        vm.goBackToCredentials()
        vm.goBackFromRegisterOtp()

        // 4. reactivateDeactivatedAccount failure
        vm.deactivatedAccount = .init(deactivatedAt: nil, scheduledDeletionAt: nil, reactivationToken: "tok")
        mockRepo.reactivateAccountResult = .failure(NetworkError.serverError(statusCode: 500))
        await vm.reactivateDeactivatedAccount()
        XCTAssertNotNil(vm.deactivatedAccountError)

        // 5. reactivateDeactivatedAccount success
        let dummySession = createDummySession()
        mockRepo.reactivateAccountResult = .success(dummySession)
        await vm.reactivateDeactivatedAccount()
        XCTAssertNil(vm.deactivatedAccount)
    }

    // MARK: - ChangePasswordViewModel Extended Tests

    func testChangePasswordViewModel_extendedBranches() async {
        let changePasswordUC = ChangePasswordUseCase(repository: mockRepo, sessionManager: mockSession)
        let verifyPasswordUC = VerifyPasswordChangeUseCase(repository: mockRepo)
        let requestEmailOtpUC = RequestEmailOtpUseCase(repository: mockRepo)

        let vm = ChangePasswordViewModel(
            accountEmail: "user@example.com",
            initialHasPassword: true,
            changePasswordUseCase: changePasswordUC,
            verifyPasswordChangeUseCase: verifyPasswordUC,
            requestEmailOtpUseCase: requestEmailOtpUC,
            languageService: languageService
        )

        // 1. loadPasswordLoginState keeps initial hasPasswordLogin
        await vm.loadPasswordLoginState()
        XCTAssertTrue(vm.hasPasswordLogin)

        // 2. initialHasPassword false sets method to .emailCode
        let noPasswordVm = ChangePasswordViewModel(
            accountEmail: "user@example.com",
            initialHasPassword: false,
            changePasswordUseCase: changePasswordUC,
            verifyPasswordChangeUseCase: verifyPasswordUC,
            requestEmailOtpUseCase: requestEmailOtpUC,
            languageService: languageService
        )
        await noPasswordVm.loadPasswordLoginState()
        XCTAssertFalse(noPasswordVm.hasPasswordLogin)
        XCTAssertEqual(noPasswordVm.method, .emailCode)

        // 3. verifyCurrentPassword failure with invalidCredentials
        vm.method = .currentPassword
        vm.currentPassword = "wrong"
        mockRepo.verifyPasswordChangeResult = .failure(AuthError.invalidCredentials)
        await vm.verifyCurrentPassword()
        XCTAssertFalse(vm.isCurrentPasswordVerified)
        XCTAssertNotNil(vm.currentPasswordError)

        // 4. verifyCurrentPassword failure with unauthorized
        mockRepo.verifyPasswordChangeResult = .failure(NetworkError.unauthorized)
        await vm.verifyCurrentPassword()
        XCTAssertFalse(vm.isCurrentPasswordVerified)

        // 5. verifyCurrentPassword failure with generic error
        mockRepo.verifyPasswordChangeResult = .failure(NetworkError.serverError(statusCode: 500))
        await vm.verifyCurrentPassword()
        XCTAssertFalse(vm.isCurrentPasswordVerified)

        // 6. verifyEmailCodeStep - code count != 6
        vm.method = .emailCode
        vm.otpCode = "123"
        await vm.verifyEmailCodeStep()
        XCTAssertFalse(vm.isEmailCodeVerified)
        XCTAssertNotNil(vm.otpError)

        // 7. verifyEmailCodeStep - failure
        vm.otpCode = "123456"
        mockRepo.verifyPasswordChangeResult = .failure(AuthError.invalidOtp("wrong code"))
        await vm.verifyEmailCodeStep()
        XCTAssertFalse(vm.isEmailCodeVerified)
        XCTAssertNotNil(vm.otpError)

        // 8. verifyEmailCodeStep - success
        mockRepo.verifyPasswordChangeResult = .success(())
        await vm.verifyEmailCodeStep()
        XCTAssertTrue(vm.isEmailCodeVerified)
        XCTAssertNil(vm.otpError)

        // 9. requestEmailCode failure with otpRateLimited
        mockRepo.requestEmailOtpResult = .failure(AuthError.otpRateLimited)
        await vm.resendEmailCode()
        XCTAssertTrue(vm.sendCodeFailed)
        XCTAssertNotNil(vm.otpError)

        // 10. changePassword with unverified password
        vm.method = .currentPassword
        vm.isCurrentPasswordVerified = false
        vm.newPassword = "StrongPassword123!"
        vm.confirmPassword = "StrongPassword123!"
        await vm.changePassword()
        XCTAssertNotNil(vm.currentPasswordError)

        // 11. changePassword with unverified email code
        vm.method = .emailCode
        vm.isEmailCodeVerified = false
        await vm.changePassword()
        XCTAssertNotNil(vm.otpError)

        // 12. changePassword failure with shouldShowOnOtpStep error
        vm.isEmailCodeVerified = true
        mockRepo.changePasswordResult = .failure(AuthError.invalidOtp("expired"))
        await vm.changePassword()
        XCTAssertFalse(vm.isEmailCodeVerified)

        // 13. changePassword failure with network error
        vm.isEmailCodeVerified = true
        mockRepo.changePasswordResult = .failure(NetworkError.serverError(statusCode: 500))
        await vm.changePassword()
        if case .failed = vm.state {} else {
            XCTFail("Expected failed state")
        }
    }

    // MARK: - CompleteOAuthProfileViewModel Extended Tests

    func testCompleteOAuthProfileViewModel_extendedBranches() async {
        let dummy = createDummyUser()
        let updateUC = UpdateProfileUseCase(repository: mockRepo, sessionManager: mockSession)

        var uploadedAvatar: UIImage?
        let mockUploader: UserAvatarUploader = { image in
            uploadedAvatar = image
            return URL(string: "https://example.com/oauth_avatar.png")!
        }

        let vm = CompleteOAuthProfileViewModel(
            user: dummy,
            updateProfileUseCase: updateUC,
            languageService: languageService,
            uploadAvatar: mockUploader
        )

        // 1. Display name validation: too long (> 100)
        vm.displayName = String(repeating: "D", count: 105)
        let nilUserLongName = await vm.save()
        XCTAssertNil(nilUserLongName)
        XCTAssertNotNil(vm.displayNameError)

        // 2. Birthday validation: age < 13
        vm.displayName = "Valid Name"
        vm.dateOfBirth = Date() // Today, age 0
        let nilUserUnderage = await vm.save()
        XCTAssertNil(nilUserUnderage)
        XCTAssertNotNil(vm.dateOfBirthError)

        // 3. Valid save with uploaded avatar
        vm.dateOfBirth = Calendar.current.date(byAdding: .year, value: -20, to: Date())
        vm.previewImage = UIImage()
        mockRepo.updateProfileResult = .success(dummy)
        let saved = await vm.save()
        XCTAssertNotNil(saved)
        XCTAssertNotNil(uploadedAvatar)

        // 4. Save failure
        mockRepo.updateProfileResult = .failure(NetworkError.serverError(statusCode: 500))
        let failed = await vm.save()
        XCTAssertNil(failed)
        XCTAssertNotNil(vm.errorMessage)
    }

    // MARK: - LoginViewModel Error Paths & Uncovered Branches

    private func makeLoginVMForExtended(
        googlePresenter: (any GoogleSignInPresenting)? = nil,
        applePresenter: (any AppleSignInPresenting)? = nil
    ) -> LoginViewModel {
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
            languageService: languageService,
            googleSignInPresenter: googlePresenter,
            appleSignInPresenter: applePresenter
        )
    }

    func testLoginViewModel_resendAndApplyErrorBranches() async {
        let vm = makeLoginVMForExtended()

        // --- resendRegistrationOtp re-calls beginRegistration ---
        // Need a newUser in email channel to exercise resendRegistrationOtp
        mockRepo.checkIdentifierResult = .success(false)
        vm.identifier = "new@example.com"
        await vm.checkIdentifier()
        XCTAssertEqual(vm.lookupState, .newUser)

        vm.username = "valid_user"
        vm.password = "StrongPassword123!"
        vm.confirmPassword = "StrongPassword123!"
        vm.hasAcceptedLegalTerms = true

        // resendRegistrationOtp success path (requestEmailOtp succeeds)
        mockRepo.requestEmailOtpResult = .success(())
        await vm.resendRegistrationOtp()
        XCTAssertEqual(vm.step, .registerOtp)

        // --- resendPhoneOtp: use a fresh VM to avoid stale lookupState ---
        let vmPhone = makeLoginVMForExtended()
        mockRepo.checkIdentifierResult = .success(true)
        vmPhone.identifier = "0901234567"
        await vmPhone.checkIdentifier()
        XCTAssertEqual(vmPhone.lookupState, .existingUser)

        mockRepo.requestPhoneOtpResult = .success(())
        await vmPhone.resendPhoneOtp()
        XCTAssertEqual(vmPhone.step, .phoneOtp)

        // --- applySignInFailure paths via Apple Sign In ---
        // accountInactive → sets deactivatedAccount (uses applySignInFailure)
        let inactiveInfo = DeactivatedAccountInfo(deactivatedAt: nil, scheduledDeletionAt: nil, reactivationToken: "tok")
        let mockApple = MockApplePresenterForExtended()
        let vmApple = makeLoginVMForExtended(applePresenter: mockApple)
        mockRepo.signInWithAppleResult = .failure(AuthError.accountInactive(inactiveInfo))
        await vmApple.signInWithApple()
        XCTAssertNotNil(vmApple.deactivatedAccount)
        XCTAssertFalse(vmApple.showErrorAlert)

        // AuthError (non-inactive) via Apple → showErrorAlert
        mockRepo.signInWithAppleResult = .failure(AuthError.accountLocked)
        vmApple.showErrorAlert = false
        await vmApple.signInWithApple()
        XCTAssertTrue(vmApple.showErrorAlert)

        // NetworkError via Apple → showErrorAlert
        mockRepo.signInWithAppleResult = .failure(NetworkError.serverError(statusCode: 503))
        vmApple.showErrorAlert = false
        await vmApple.signInWithApple()
        XCTAssertTrue(vmApple.showErrorAlert)

        // Generic unknown error via Apple → showErrorAlert (default message)
        struct UnknownSignInError: Error {}
        mockRepo.signInWithAppleResult = .failure(UnknownSignInError())
        vmApple.showErrorAlert = false
        await vmApple.signInWithApple()
        XCTAssertTrue(vmApple.showErrorAlert)
    }

    func testLoginViewModel_otpErrorBranchesAndDateOfBirth() async {
        let vm = makeLoginVMForExtended()

        // --- applyOtpRequestError via requestPhoneOtpAndContinue ---
        mockRepo.checkIdentifierResult = .success(true)
        vm.identifier = "0901234567"
        await vm.checkIdentifier()
        XCTAssertEqual(vm.lookupState, .existingUser)

        // shouldShowOnOtpStep = true (otpRateLimited)
        mockRepo.requestPhoneOtpResult = .failure(AuthError.otpRateLimited)
        vm.step = .phoneOtp
        // trigger via requestPhoneOtpAndContinue
        await vm.requestPhoneOtpAndContinue()
        XCTAssertNotNil(vm.otpErrorKey)

        // shouldShowOnOtpStep = false (accountLocked)
        mockRepo.requestPhoneOtpResult = .failure(AuthError.accountLocked)
        await vm.requestPhoneOtpAndContinue()
        XCTAssertTrue(vm.showErrorAlert)

        // --- applyOtpVerifyError via verifyPhoneOtp ---
        mockRepo.requestPhoneOtpResult = .success(())
        await vm.requestPhoneOtpAndContinue()
        XCTAssertEqual(vm.step, .phoneOtp)

        // otpRateLimited on verifyPhoneOtp → shouldShowOnOtpStep
        mockRepo.verifyPhoneOtpResult = .failure(AuthError.otpRateLimited)
        vm.otpCode = "123456"
        await vm.verifyPhoneOtp()
        XCTAssertNotNil(vm.otpErrorKey)

        // accountLocked (not shouldShowOnOtpStep) on verifyPhoneOtp
        mockRepo.verifyPhoneOtpResult = .failure(AuthError.accountLocked)
        vm.otpCode = "123456"
        await vm.verifyPhoneOtp()
        XCTAssertTrue(vm.showErrorAlert)

        // --- applyRegistrationError via completeRegistration ---
        let vm2 = makeLoginVMForExtended()
        mockRepo.checkIdentifierResult = .success(false)
        vm2.identifier = "new@example.com"
        await vm2.checkIdentifier()
        XCTAssertEqual(vm2.lookupState, .newUser)
        vm2.username = "new_user"
        vm2.password = "StrongPassword123!"
        vm2.confirmPassword = "StrongPassword123!"
        vm2.hasAcceptedLegalTerms = true
        mockRepo.requestEmailOtpResult = .success(())
        await vm2.beginRegistration()
        XCTAssertEqual(vm2.step, .registerOtp)

        // shouldShowOnOtpStep = true (invalidOtp) → otpErrorKey set
        mockRepo.registerEmailResult = .failure(AuthError.invalidOtp("bad"))
        vm2.otpCode = "123456"
        await vm2.completeRegistration()
        XCTAssertNotNil(vm2.otpErrorKey)

        // emailAlreadyExists → lookupState = existingUser, step = credentials
        mockRepo.registerEmailResult = .failure(AuthError.emailAlreadyExists)
        vm2.otpCode = "123456"
        await vm2.completeRegistration()
        XCTAssertEqual(vm2.lookupState, .existingUser)
        XCTAssertEqual(vm2.step, .credentials)

        // usernameAlreadyExists → sets usernameError, step = credentials
        vm2.step = .registerOtp
        mockRepo.registerEmailResult = .failure(AuthError.usernameAlreadyExists)
        vm2.otpCode = "123456"
        await vm2.completeRegistration()
        XCTAssertNotNil(vm2.usernameError)
        XCTAssertEqual(vm2.step, .credentials)

        // generic error → otpErrorKey default
        vm2.step = .registerOtp
        struct RegError: Error {}
        mockRepo.registerEmailResult = .failure(RegError())
        vm2.otpCode = "123456"
        await vm2.completeRegistration()
        XCTAssertEqual(vm2.otpErrorKey, .errorAuthInvalidOtpDefault)

        // --- defaultDateOfBirthDraft closure (implicit) ---
        let vm3 = makeLoginVMForExtended()
        // prepareDateOfBirthPicker triggers defaultDateOfBirthDraft when dateOfBirth is nil
        vm3.dateOfBirth = nil
        vm3.prepareDateOfBirthPicker()
        XCTAssertNotNil(vm3.dateOfBirthDraft)

        // --- showsPasswordField getter closure ---
        let vm4 = makeLoginVMForExtended()
        // showsPasswordField = true when existingUser + email
        mockRepo.checkIdentifierResult = .success(true)
        vm4.identifier = "user@example.com"
        await vm4.checkIdentifier()
        XCTAssertTrue(vm4.showsPasswordField)

        // --- validateDateOfBirthField closure (minimumBirthDate fallback) ---
        vm4.dateOfBirth = Date() // today = underage
        vm4.validateDateOfBirthField()
        XCTAssertNotNil(vm4.dateOfBirthError)

        // valid age
        vm4.dateOfBirth = Calendar.current.date(byAdding: .year, value: -20, to: Date())
        vm4.validateDateOfBirthField()
        XCTAssertNil(vm4.dateOfBirthError)

        // --- signInWithGoogle error path (non-GIDSignIn error) ---
        struct GoogleFailure: Error {}
        let mockGooglePresenter = MockGooglePresenterForExtended()
        mockGooglePresenter.errorToThrow = GoogleFailure()
        let vm5 = makeLoginVMForExtended(googlePresenter: mockGooglePresenter)
        await vm5.signInWithGoogle()
        XCTAssertTrue(vm5.showErrorAlert)

        // GIDSignIn user-cancelled (code -5) → idle, no alert
        let cancelledError = NSError(domain: "com.google.GIDSignIn", code: -5, userInfo: nil)
        mockGooglePresenter.errorToThrow = cancelledError
        vm5.showErrorAlert = false
        await vm5.signInWithGoogle()
        XCTAssertFalse(vm5.showErrorAlert)
        XCTAssertEqual(vm5.state, .idle)
    }
}

// MARK: - Test Helpers for Extended LoginViewModel Tests

@MainActor
private final class MockGooglePresenterForExtended: GoogleSignInPresenting {
    var isAvailable = true
    var token = "mock_gid"
    var errorToThrow: Error?
    func fetchIdToken() async throws -> String {
        if let error = errorToThrow { throw error }
        return token
    }
}

@MainActor
private final class MockApplePresenterForExtended: AppleSignInPresenting {
    var isAvailable = true
    var token = "mock_aid"
    var errorToThrow: Error?
    func fetchIdToken() async throws -> String {
        if let error = errorToThrow { throw error }
        return token
    }
}
