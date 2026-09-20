import XCTest
import SplickDomain
import Networking
import Localization
@testable import FeatureAuth

final class AuthEndpointAndMappersTests: XCTestCase {

    // MARK: - AuthEndpoint Tests

    func testAuthEndpoint_paths() {
        let dummyUUID = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!

        XCTAssertEqual(AuthEndpoint.checkIdentifier(.init(email: "a@b.com", phoneNumber: nil)).path, "/v1/auth/identifier/check")
        XCTAssertEqual(AuthEndpoint.checkUsername(.init(username: "test")).path, "/v1/auth/username/check")
        XCTAssertEqual(AuthEndpoint.googleSignIn(.init(idToken: "tok", deviceInfo: nil, deviceName: nil, loginLocation: nil)).path, "/v1/auth/google")
        XCTAssertEqual(AuthEndpoint.appleSignIn(.init(idToken: "tok", deviceInfo: nil, deviceName: nil, loginLocation: nil)).path, "/v1/auth/apple")
        XCTAssertEqual(AuthEndpoint.login(.init(email: "e", password: "p", deviceInfo: nil, deviceName: nil, loginLocation: nil)).path, "/v1/auth/login")
        XCTAssertEqual(AuthEndpoint.requestEmailOtp(.init(email: "e")).path, "/v1/auth/email/otp/request")
        XCTAssertEqual(AuthEndpoint.requestPhoneOtp(.init(phoneNumber: "p")).path, "/v1/auth/phone/otp/request")
        XCTAssertEqual(AuthEndpoint.verifyPhoneOtp(.init(phoneNumber: "p", otpCode: "123456", deviceInfo: nil, deviceName: nil, loginLocation: nil)).path, "/v1/auth/phone/otp/verify")
        XCTAssertEqual(AuthEndpoint.registerEmail(.init(email: "e", username: "u", password: "p", otpCode: "1", displayName: nil, dateOfBirth: nil, deviceInfo: nil, deviceName: nil, loginLocation: nil)).path, "/v1/auth/register")
        XCTAssertEqual(AuthEndpoint.registerPhone(.init(phoneNumber: "p", username: "u", password: "p", otpCode: "1", displayName: nil, dateOfBirth: nil, deviceInfo: nil, deviceName: nil, loginLocation: nil)).path, "/v1/auth/register")
        XCTAssertEqual(AuthEndpoint.refreshToken(.init(refreshToken: "ref")).path, "/v1/auth/refresh")
        XCTAssertEqual(AuthEndpoint.forgotPassword(.init(email: "e")).path, "/v1/auth/password/forgot")
        XCTAssertEqual(AuthEndpoint.verifyResetPasswordOtp(.init(email: "e", otpCode: "123456")).path, "/v1/auth/password/reset/verify")
        XCTAssertEqual(AuthEndpoint.resetPassword(.init(email: "e", otpCode: "1", newPassword: "n", deviceInfo: nil, deviceName: nil, loginLocation: nil)).path, "/v1/auth/password/reset")
        XCTAssertEqual(AuthEndpoint.changePassword(.init(currentPassword: "c", otpCode: nil, newPassword: "n", deviceInfo: nil, deviceName: nil, loginLocation: nil)).path, "/v1/auth/password/change")
        XCTAssertEqual(AuthEndpoint.verifyPasswordChange(.init(currentPassword: "c", otpCode: nil)).path, "/v1/auth/password/verify")
        XCTAssertEqual(AuthEndpoint.logout(.init(refreshToken: "ref")).path, "/v1/auth/logout")
        XCTAssertEqual(AuthEndpoint.me.path, "/v1/auth/me")
        XCTAssertEqual(AuthEndpoint.patchMe(.init(displayName: nil, username: nil, avatarUrl: nil, preferredLocale: nil, timezone: nil, dateOfBirth: nil)).path, "/v1/auth/me")
        XCTAssertEqual(AuthEndpoint.paymentProfile.path, "/v1/auth/me/payment-profile")
        XCTAssertEqual(AuthEndpoint.upsertPaymentProfile(.init(qrImageUrl: nil, accountName: nil, accountNumber: nil, bankName: nil)).path, "/v1/auth/me/payment-profile")
        XCTAssertEqual(AuthEndpoint.deletePaymentProfile.path, "/v1/auth/me/payment-profile")
        XCTAssertEqual(AuthEndpoint.listSessions.path, "/v1/auth/sessions")
        XCTAssertEqual(AuthEndpoint.revokeAllSessions.path, "/v1/auth/sessions/revoke-all")
        XCTAssertEqual(AuthEndpoint.revokeSession(dummyUUID).path, "/v1/auth/sessions/11111111-2222-3333-4444-555555555555")
        XCTAssertEqual(AuthEndpoint.deactivateAccount(.init(currentPassword: nil, otpCode: nil)).path, "/v1/auth/account/deactivate")
        XCTAssertEqual(AuthEndpoint.reactivateAccount(.init(reactivationToken: "tok", deviceInfo: nil, deviceName: nil, loginLocation: nil)).path, "/v1/auth/account/reactivate")
        XCTAssertEqual(AuthEndpoint.deleteAccount(.init(currentPassword: nil, otpCode: nil)).path, "/v1/auth/account")
        XCTAssertEqual(AuthEndpoint.connectedAccounts.path, "/v1/auth/connected-accounts")
        XCTAssertEqual(AuthEndpoint.linkGoogle(.init(idToken: "tok")).path, "/v1/auth/connected-accounts/google")
        XCTAssertEqual(AuthEndpoint.unlinkGoogle(.init(currentPassword: nil, otpCode: nil)).path, "/v1/auth/connected-accounts/google")
        XCTAssertEqual(AuthEndpoint.requestLinkPhoneOtp(.init(phoneNumber: "p")).path, "/v1/auth/connected-accounts/phone/otp/request")
        XCTAssertEqual(AuthEndpoint.linkPhone(.init(phoneNumber: "p", otpCode: "123456")).path, "/v1/auth/connected-accounts/phone")
        XCTAssertEqual(AuthEndpoint.requestLinkEmailOtp(.init(email: "e")).path, "/v1/auth/connected-accounts/email/otp/request")
        XCTAssertEqual(AuthEndpoint.linkEmail(.init(email: "e", otpCode: "123456", password: "p")).path, "/v1/auth/connected-accounts/email")
    }

    func testAuthEndpoint_httpMethodsAndHeaders() {
        let dummyUUID = UUID()
        XCTAssertEqual(AuthEndpoint.me.method, .get)
        XCTAssertEqual(AuthEndpoint.listSessions.method, .get)
        XCTAssertEqual(AuthEndpoint.connectedAccounts.method, .get)
        XCTAssertEqual(AuthEndpoint.paymentProfile.method, .get)
        XCTAssertEqual(AuthEndpoint.patchMe(.init(displayName: nil, username: nil, avatarUrl: nil, preferredLocale: nil, timezone: nil, dateOfBirth: nil)).method, .patch)
        XCTAssertEqual(AuthEndpoint.upsertPaymentProfile(.init(qrImageUrl: nil, accountName: nil, accountNumber: nil, bankName: nil)).method, .put)
        XCTAssertEqual(AuthEndpoint.revokeSession(dummyUUID).method, .delete)
        XCTAssertEqual(AuthEndpoint.deleteAccount(.init(currentPassword: nil, otpCode: nil)).method, .delete)
        XCTAssertEqual(AuthEndpoint.unlinkGoogle(.init(currentPassword: nil, otpCode: nil)).method, .delete)
        XCTAssertEqual(AuthEndpoint.deletePaymentProfile.method, .delete)
        XCTAssertEqual(AuthEndpoint.login(.init(email: "e", password: "p", deviceInfo: nil, deviceName: nil, loginLocation: nil)).method, .post)

        XCTAssertNil(AuthEndpoint.me.headers)
        XCTAssertTrue(AuthEndpoint.listSessions.sendsRefreshTokenHeader)
        XCTAssertFalse(AuthEndpoint.login(.init(email: "e", password: "p", deviceInfo: nil, deviceName: nil, loginLocation: nil)).sendsRefreshTokenHeader)

        // requiresAuth tests
        XCTAssertFalse(AuthEndpoint.login(.init(email: "e", password: "p", deviceInfo: nil, deviceName: nil, loginLocation: nil)).requiresAuth)
        XCTAssertFalse(AuthEndpoint.checkIdentifier(.init(email: "e", phoneNumber: nil)).requiresAuth)
        XCTAssertFalse(AuthEndpoint.googleSignIn(.init(idToken: "t", deviceInfo: nil, deviceName: nil, loginLocation: nil)).requiresAuth)
        XCTAssertTrue(AuthEndpoint.checkUsername(.init(username: "u")).requiresAuth)
        XCTAssertTrue(AuthEndpoint.me.requiresAuth)
        XCTAssertTrue(AuthEndpoint.revokeSession(dummyUUID).requiresAuth)
    }

    // MARK: - AuthMapper Tests

    func testAuthMapper_toUser() {
        let id = UUID()
        let now = Date()
        let dto1 = UserDTO(
            id: id,
            email: "test@example.com",
            username: "tester",
            displayName: "Test User",
            avatarUrl: "https://example.com/avatar.jpg",
            status: "active",
            preferredLocale: "en",
            timezone: "America/New_York",
            dateOfBirth: "2000-01-15",
            createdAt: now
        )

        let user1 = AuthMapper.toUser(dto1)
        XCTAssertEqual(user1.id, id)
        XCTAssertEqual(user1.email, "test@example.com")
        XCTAssertEqual(user1.username, "tester")
        XCTAssertEqual(user1.displayName, "Test User")
        XCTAssertEqual(user1.avatarURL?.absoluteString, "https://example.com/avatar.jpg")
        XCTAssertEqual(user1.status, .active)
        XCTAssertEqual(user1.preferredLocale, "en")
        XCTAssertEqual(user1.timezone, "America/New_York")
        XCTAssertEqual(user1.createdAt, now)

        // Fallback display name when displayName is empty or whitespaces
        let dto2 = UserDTO(
            id: id,
            email: "test@example.com",
            username: "default_user",
            displayName: "   ",
            avatarUrl: nil,
            status: nil,
            preferredLocale: nil,
            timezone: nil,
            dateOfBirth: nil,
            createdAt: now
        )
        let user2 = AuthMapper.toUser(dto2)
        XCTAssertEqual(user2.displayName, "default_user")
        XCTAssertNil(user2.avatarURL)
        XCTAssertEqual(user2.status, .unknown)
        XCTAssertEqual(user2.preferredLocale, "vi")
        XCTAssertEqual(user2.timezone, "Asia/Ho_Chi_Minh")
        XCTAssertNil(user2.dateOfBirth)
    }

    func testAuthMapper_toAuthToken() {
        let sessionId = UUID()
        let dto = AuthResponseDTO(
            accessToken: "acc_token",
            refreshToken: "ref_token",
            expiresIn: 3600,
            tokenType: "Bearer",
            sessionId: sessionId,
            user: UserDTO(
                id: UUID(),
                email: "a@b.com",
                username: "ab",
                displayName: nil,
                avatarUrl: nil,
                status: nil,
                preferredLocale: nil,
                timezone: nil,
                dateOfBirth: nil,
                createdAt: Date()
            ),
            newUser: true
        )

        let token = AuthMapper.toAuthToken(dto)
        XCTAssertEqual(token.accessToken, "acc_token")
        XCTAssertEqual(token.refreshToken, "ref_token")
        XCTAssertEqual(token.expiresIn, 3600)
        XCTAssertEqual(token.tokenType, "Bearer")
        XCTAssertEqual(token.sessionId, sessionId)

        let authSession = AuthMapper.toAuthSession(dto)
        XCTAssertTrue(authSession.isNewUser)
        XCTAssertEqual(authSession.token.accessToken, "acc_token")
    }

    func testAuthMapper_toUserSession() {
        let id = UUID()
        let now = Date()
        let exp = now.addingTimeInterval(86400)
        let dto = SessionDTO(
            id: id,
            deviceInfo: "iPhone 16",
            deviceName: "My iPhone",
            loginIp: "127.0.0.1",
            loginLocation: "Hanoi, Vietnam",
            createdAt: now,
            expiresAt: exp,
            current: true
        )

        let session = AuthMapper.toUserSession(dto)
        XCTAssertEqual(session.id, id)
        XCTAssertEqual(session.deviceInfo, "iPhone 16")
        XCTAssertEqual(session.deviceName, "My iPhone")
        XCTAssertEqual(session.loginIp, "127.0.0.1")
        XCTAssertEqual(session.loginLocation, "Hanoi, Vietnam")
        XCTAssertEqual(session.createdAt, now)
        XCTAssertEqual(session.expiresAt, exp)
        XCTAssertTrue(session.isCurrent)
    }

    func testAuthMapper_toConnectedAccounts() {
        let dto = ConnectedAccountsDTO(
            google: .init(linked: true, detail: "google@gmail.com"),
            emailPassword: .init(linked: true, detail: "me@splick.app"),
            phone: .init(linked: false, detail: nil)
        )

        let accounts = AuthMapper.toConnectedAccounts(dto)
        XCTAssertTrue(accounts.google.isLinked)
        XCTAssertEqual(accounts.google.detail, "google@gmail.com")
        XCTAssertTrue(accounts.emailPassword.isLinked)
        XCTAssertFalse(accounts.phone.isLinked)
        XCTAssertNil(accounts.phone.detail)
    }

    func testAuthMapper_toPaymentProfile() {
        let userId = UUID()
        let now = Date()
        let dto = PaymentProfileResponseDTO(
            userId: userId,
            qrImageUrl: "https://example.com/qr.jpg",
            accountName: "TRAN QUANG HOAN",
            accountNumber: "9876543210",
            bankName: "Techcombank",
            updatedAt: now
        )

        let profile = AuthMapper.toPaymentProfile(dto)
        XCTAssertEqual(profile.userId, userId)
        XCTAssertEqual(profile.qrImageURL?.absoluteString, "https://example.com/qr.jpg")
        XCTAssertEqual(profile.accountName, "TRAN QUANG HOAN")
        XCTAssertEqual(profile.accountNumber, "9876543210")
        XCTAssertEqual(profile.bankName, "Techcombank")
        XCTAssertEqual(profile.updatedAt, now)
    }

    // MARK: - Device & Session Metadata Tests

    func testDeviceMetadata_marketingNameLookup() {
        XCTAssertEqual(DeviceMetadata.marketingName(forMachineIdentifier: "iPhone17,1"), "iPhone 16 Pro")
        XCTAssertEqual(DeviceMetadata.marketingName(forMachineIdentifier: "iPhone17,2"), "iPhone 16 Pro Max")
        XCTAssertEqual(DeviceMetadata.marketingName(forMachineIdentifier: "iPhone16,1"), "iPhone 15 Pro")
        XCTAssertEqual(DeviceMetadata.marketingName(forMachineIdentifier: "i386"), "Simulator")
        XCTAssertEqual(DeviceMetadata.marketingName(forMachineIdentifier: "x86_64"), "Simulator")
        XCTAssertEqual(DeviceMetadata.marketingName(forMachineIdentifier: "arm64"), "Simulator")
        XCTAssertNil(DeviceMetadata.marketingName(forMachineIdentifier: "NonExistentDevice999"))

        XCTAssertFalse(DeviceMetadata.marketingName.isEmpty)
        XCTAssertFalse(DeviceMetadata.platformLine.isEmpty)
        XCTAssertFalse(DeviceMetadata.machineIdentifier.isEmpty)
    }

    func testSessionMetadata_current() {
        let payload = SessionMetadata.current
        XCTAssertFalse(payload.deviceInfo.isEmpty)
        XCTAssertFalse(payload.deviceName.isEmpty)
        XCTAssertEqual(payload.deviceInfo, SessionMetadata.deviceInfo)
        XCTAssertEqual(payload.deviceName, SessionMetadata.deviceName)
        XCTAssertEqual(payload.loginLocation, SessionMetadata.loginLocation)
    }

    @MainActor
    func testPasswordRequirementGuideItems() {
        let mockDefaults = MockUserDefaultsService()
        let languageService = LanguageService(userDefaults: mockDefaults)
        let items = passwordRequirementGuideItems(for: "Weak", languageService: languageService)
        XCTAssertFalse(items.isEmpty)
    }

    func testAuthPreviewMockUseCases() async throws {
        let checkId = MockCheckIdentifierUseCase()
        let exists1 = try await checkId.execute(email: "existing@example.com", phoneNumber: nil)
        XCTAssertTrue(exists1)
        let exists2 = try await checkId.execute(email: nil, phoneNumber: "0999")
        XCTAssertTrue(exists2)
        let exists3 = try await checkId.execute(email: "other@example.com", phoneNumber: "0111")
        XCTAssertFalse(exists3)

        let login = MockLoginUseCase()
        let session = try await login.execute(email: "a@b.com", password: "p")
        XCTAssertEqual(session.token.accessToken, "mock-token")

        let reqEmail = MockRequestEmailOtpUseCase()
        try await reqEmail.execute(email: "a@b.com")

        let reqPhone = MockRequestPhoneOtpUseCase()
        try await reqPhone.execute(phoneNumber: "+84901234567")

        let verifyPhone = MockVerifyPhoneOtpUseCase()
        let vpSession = try await verifyPhone.execute(phoneNumber: "+84901234567", otpCode: "123456")
        XCTAssertEqual(vpSession.token.accessToken, "mock-token")

        let google = MockGoogleSignInUseCase()
        let gSession = try await google.execute(idToken: "tok")
        XCTAssertEqual(gSession.token.accessToken, "mock-token")

        let apple = MockAppleSignInUseCase()
        let aSession = try await apple.execute(idToken: "tok")
        XCTAssertEqual(aSession.token.accessToken, "mock-token")

        let reactivate = MockReactivateAccountUseCase()
        let rSession = try await reactivate.execute(reactivationToken: "tok")
        XCTAssertEqual(rSession.token.accessToken, "mock-token")

        let forgot = MockForgotPasswordUseCase()
        try await forgot.execute(email: "a@b.com")

        let verifyReset = MockVerifyResetPasswordOtpUseCase()
        try await verifyReset.execute(email: "a@b.com", otpCode: "123456")

        let reset = MockResetPasswordUseCase()
        let resetSession = try await reset.execute(email: "a@b.com", otpCode: "123456", newPassword: "p")
        XCTAssertEqual(resetSession.token.accessToken, "mock-token")

        let register = MockRegisterUseCase()
        let regSession = try await register.execute(
            channel: .email,
            identifier: "a@b.com",
            username: "u",
            password: "p",
            otpCode: "123456",
            displayName: "D",
            dateOfBirth: nil
        )
        XCTAssertEqual(regSession.token.accessToken, "mock-token")
    }
}
