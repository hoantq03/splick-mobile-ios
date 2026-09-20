import XCTest
import SplickDomain
import Common
import Storage
import Networking
@testable import FeatureAuth

final class AuthDTOAndUseCasesExtendedTests: XCTestCase {

    // MARK: - AuthEndpoint.body Tests

    func testAuthEndpoint_allBodyCases() {
        let dummyUUID = UUID()
        let encoder = JSONEncoder()

        let endpoints: [AuthEndpoint] = [
            .checkIdentifier(.init(email: "a@b.com", phoneNumber: nil)),
            .checkUsername(.init(username: "user")),
            .googleSignIn(.init(idToken: "tok", deviceInfo: "d", deviceName: "n", loginLocation: "l")),
            .appleSignIn(.init(idToken: "tok", deviceInfo: "d", deviceName: "n", loginLocation: "l")),
            .login(.init(email: "e", password: "p", deviceInfo: nil, deviceName: nil, loginLocation: nil)),
            .requestEmailOtp(.init(email: "e")),
            .requestPhoneOtp(.init(phoneNumber: "+84901234567")),
            .verifyPhoneOtp(.init(phoneNumber: "+84901234567", otpCode: "123456", deviceInfo: nil, deviceName: nil, loginLocation: nil)),
            .registerEmail(.init(email: "e", username: "u", password: "p", otpCode: "123456", displayName: "d", dateOfBirth: nil, deviceInfo: nil, deviceName: nil, loginLocation: nil)),
            .registerPhone(.init(phoneNumber: "p", username: "u", password: "p", otpCode: "123456", displayName: "d", dateOfBirth: nil, deviceInfo: nil, deviceName: nil, loginLocation: nil)),
            .refreshToken(.init(refreshToken: "ref")),
            .forgotPassword(.init(email: "e")),
            .verifyResetPasswordOtp(.init(email: "e", otpCode: "123456")),
            .resetPassword(.init(email: "e", otpCode: "123456", newPassword: "p", deviceInfo: nil, deviceName: nil, loginLocation: nil)),
            .changePassword(.init(currentPassword: "c", otpCode: nil, newPassword: "n", deviceInfo: nil, deviceName: nil, loginLocation: nil)),
            .verifyPasswordChange(.init(currentPassword: "c", otpCode: nil)),
            .logout(.init(refreshToken: "ref")),
            .patchMe(.init(displayName: "D", username: "U", avatarUrl: "https://example.com/a.jpg", preferredLocale: "vi", timezone: "UTC", dateOfBirth: nil)),
            .upsertPaymentProfile(.init(qrImageUrl: "url", accountName: "name", accountNumber: "123", bankName: "bank")),
            .deactivateAccount(.init(currentPassword: "c", otpCode: nil)),
            .reactivateAccount(.init(reactivationToken: "tok", deviceInfo: nil, deviceName: nil, loginLocation: nil)),
            .deleteAccount(.init(currentPassword: "c", otpCode: nil)),
            .linkGoogle(.init(idToken: "tok")),
            .unlinkGoogle(.init(currentPassword: "c", otpCode: nil)),
            .requestLinkPhoneOtp(.init(phoneNumber: "p")),
            .linkPhone(.init(phoneNumber: "p", otpCode: "123456")),
            .requestLinkEmailOtp(.init(email: "e")),
            .linkEmail(.init(email: "e", otpCode: "123456", password: "p"))
        ]

        for ep in endpoints {
            XCTAssertNotNil(ep.body, "Endpoint \(ep.path) should have non-nil body")
            // Ensure body can be encoded
            if let encodable = ep.body {
                let wrapper = AnyEncodable(encodable)
                XCTAssertNoThrow(try encoder.encode(wrapper))
            }
        }

        let nilBodyEndpoints: [AuthEndpoint] = [
            .me,
            .paymentProfile,
            .deletePaymentProfile,
            .listSessions,
            .revokeAllSessions,
            .revokeSession(dummyUUID),
            .connectedAccounts
        ]

        for ep in nilBodyEndpoints {
            XCTAssertNil(ep.body, "Endpoint \(ep.path) should have nil body")
        }
    }

    // MARK: - AuthDTOs Codable Tests

    func testAuthDTOs_encodingAndDecoding() throws {
        let decoder = JSONDecoder()
        let encoder = JSONEncoder()

        // CheckIdentifierResponseDTO
        let checkIdJson = #"{"exists": true}"#.data(using: .utf8)!
        let checkIdDto = try decoder.decode(CheckIdentifierResponseDTO.self, from: checkIdJson)
        XCTAssertTrue(checkIdDto.exists)

        // CheckUsernameResponseDTO
        let checkUserJson = #"{"available": false}"#.data(using: .utf8)!
        let checkUserDto = try decoder.decode(CheckUsernameResponseDTO.self, from: checkUserJson)
        XCTAssertFalse(checkUserDto.available)

        // AuthResponseDTO & UserDTO
        let userId = UUID()
        let sessionId = UUID()
        let authRespJson = """
        {
            "accessToken": "acc",
            "refreshToken": "ref",
            "expiresIn": 7200,
            "tokenType": "Bearer",
            "sessionId": "\(sessionId.uuidString)",
            "newUser": true,
            "user": {
                "id": "\(userId.uuidString)",
                "email": "user@example.com",
                "username": "tester",
                "displayName": "Test",
                "avatarUrl": "https://example.com/avatar.png",
                "status": "active",
                "preferredLocale": "vi",
                "timezone": "Asia/Ho_Chi_Minh",
                "dateOfBirth": "1995-05-20",
                "createdAt": 1716200000
            }
        }
        """.data(using: .utf8)!

        let customDecoder = JSONDecoder()
        customDecoder.dateDecodingStrategy = .secondsSince1970
        let authRespDto = try customDecoder.decode(AuthResponseDTO.self, from: authRespJson)
        XCTAssertEqual(authRespDto.accessToken, "acc")
        XCTAssertEqual(authRespDto.refreshToken, "ref")
        XCTAssertEqual(authRespDto.expiresIn, 7200)
        XCTAssertEqual(authRespDto.tokenType, "Bearer")
        XCTAssertEqual(authRespDto.sessionId, sessionId)
        XCTAssertEqual(authRespDto.newUser, true)
        XCTAssertEqual(authRespDto.user.id, userId)
        XCTAssertEqual(authRespDto.user.email, "user@example.com")
        XCTAssertEqual(authRespDto.user.username, "tester")
        XCTAssertEqual(authRespDto.user.displayName, "Test")
        XCTAssertEqual(authRespDto.user.avatarUrl, "https://example.com/avatar.png")
        XCTAssertEqual(authRespDto.user.status, "active")
        XCTAssertEqual(authRespDto.user.preferredLocale, "vi")
        XCTAssertEqual(authRespDto.user.timezone, "Asia/Ho_Chi_Minh")
        XCTAssertEqual(authRespDto.user.dateOfBirth, "1995-05-20")

        // PaymentProfileResponseDTO
        let payProfileJson = """
        {
            "userId": "\(userId.uuidString)",
            "qrImageUrl": "https://example.com/qr.png",
            "accountName": "NGUYEN VAN A",
            "accountNumber": "1234567890",
            "bankName": "MBBank",
            "updatedAt": 1716200000
        }
        """.data(using: .utf8)!
        let payProfileDto = try customDecoder.decode(PaymentProfileResponseDTO.self, from: payProfileJson)
        XCTAssertEqual(payProfileDto.userId, userId)
        XCTAssertEqual(payProfileDto.qrImageUrl, "https://example.com/qr.png")
        XCTAssertEqual(payProfileDto.accountName, "NGUYEN VAN A")
        XCTAssertEqual(payProfileDto.accountNumber, "1234567890")
        XCTAssertEqual(payProfileDto.bankName, "MBBank")

        // UpsertPaymentProfileRequestDTO custom encode
        let upsertDto = UpsertPaymentProfileRequestDTO(qrImageUrl: "url", accountName: "name", accountNumber: "num", bankName: "bank")
        let upsertData = try encoder.encode(upsertDto)
        XCTAssertFalse(upsertData.isEmpty)

        // SessionDTO
        let sessionItemJson = """
        {
            "id": "\(sessionId.uuidString)",
            "deviceInfo": "iOS 17.5",
            "deviceName": "iPhone",
            "loginIp": "1.1.1.1",
            "loginLocation": "Hanoi",
            "createdAt": 1716200000,
            "expiresAt": 1716300000,
            "current": true
        }
        """.data(using: .utf8)!
        let sessionDto = try customDecoder.decode(SessionDTO.self, from: sessionItemJson)
        XCTAssertEqual(sessionDto.id, sessionId)
        XCTAssertEqual(sessionDto.deviceInfo, "iOS 17.5")
        XCTAssertEqual(sessionDto.deviceName, "iPhone")
        XCTAssertEqual(sessionDto.loginIp, "1.1.1.1")
        XCTAssertEqual(sessionDto.loginLocation, "Hanoi")
        XCTAssertTrue(sessionDto.current)

        // ConnectedAccountsDTO
        let connJson = """
        {
            "google": { "linked": true, "detail": "google@gmail.com" },
            "emailPassword": { "linked": true, "detail": "me@example.com" },
            "phone": { "linked": false, "detail": null }
        }
        """.data(using: .utf8)!
        let connDto = try decoder.decode(ConnectedAccountsDTO.self, from: connJson)
        XCTAssertTrue(connDto.google.linked)
        XCTAssertEqual(connDto.google.detail, "google@gmail.com")
        XCTAssertTrue(connDto.emailPassword.linked)
        XCTAssertEqual(connDto.emailPassword.detail, "me@example.com")
        XCTAssertFalse(connDto.phone.linked)
        XCTAssertNil(connDto.phone.detail)
    }

    // MARK: - UpdateProfileUseCase Overloads & Session Update

    func testUpdateProfileUseCase_extended() async throws {
        let mockRepo = MockAuthRepository()
        let mockSession = MockSessionManager()

        let dummyUser = User(
            id: UUID(),
            email: "updated@splick.app",
            username: "updated_user",
            displayName: "Updated User",
            avatarURL: nil,
            status: .active,
            preferredLocale: "vi",
            timezone: "Asia/Ho_Chi_Minh",
            dateOfBirth: nil,
            createdAt: Date()
        )
        mockRepo.updateProfileResult = .success(dummyUser)

        let useCase: UpdateProfileUseCaseProtocol = UpdateProfileUseCase(
            repository: mockRepo,
            sessionManager: mockSession
        )

        // When current session exists, sessionManager.setSession is called with updated user
        let initialSession = AuthSession(
            user: User(id: dummyUser.id, email: "old@splick.app", username: "old", displayName: "Old"),
            token: AuthToken(accessToken: "tok", refreshToken: "ref", expiresIn: 3600, tokenType: "Bearer", sessionId: nil)
        )
        await mockSession.setSession(initialSession)

        let result1 = try await useCase.execute(displayName: "Updated User", avatarUrl: nil, preferredLocale: "vi")
        XCTAssertEqual(result1.displayName, "Updated User")
        let updatedSession = await mockSession.currentSession()
        XCTAssertEqual(updatedSession?.user.username, "updated_user")

        // Overload with dateOfBirth
        let result2 = try await useCase.execute(
            displayName: "Updated User 2",
            avatarUrl: nil,
            preferredLocale: "vi",
            dateOfBirth: Date()
        )
        XCTAssertEqual(result2.displayName, "Updated User")

        // When current session is nil
        await mockSession.clearSession()
        let result3 = try await useCase.execute(
            displayName: "No Session",
            avatarUrl: nil,
            preferredLocale: nil
        )
        XCTAssertEqual(result3.displayName, "Updated User")
        let afterClear = await mockSession.currentSession()
        XCTAssertNil(afterClear)
    }

    // MARK: - VerifyPhoneOtpUseCase Error Handling

    func testVerifyPhoneOtpUseCase_extended() async {
        let mockRepo = MockAuthRepository()
        let mockSession = MockSessionManager()
        let useCase = VerifyPhoneOtpUseCase(repository: mockRepo, sessionManager: mockSession)

        // User status does not allow sign in
        let suspendedUser = User(
            id: UUID(),
            email: "suspended@splick.app",
            username: "suspended",
            displayName: "Suspended",
            avatarURL: nil,
            status: .inactive,
            preferredLocale: "vi",
            timezone: "Asia/Ho_Chi_Minh",
            dateOfBirth: nil,
            createdAt: Date()
        )
        let suspendedSession = AuthSession(
            user: suspendedUser,
            token: AuthToken(accessToken: "tok", refreshToken: "ref", expiresIn: 3600, tokenType: "Bearer", sessionId: nil)
        )
        mockRepo.verifyPhoneOtpResult = .success(suspendedSession)

        do {
            _ = try await useCase.execute(phoneNumber: "+84901234567", otpCode: "123456")
            XCTFail("Expected invalidCredentials error for suspended user")
        } catch let error as AuthError {
            XCTAssertEqual(error, .invalidCredentials)
        } catch {
            XCTFail("Unexpected error \(error)")
        }

        // Network connectivity error is rethrown
        mockRepo.verifyPhoneOtpResult = .failure(NetworkError.noConnection)
        do {
            _ = try await useCase.execute(phoneNumber: "+84901234567", otpCode: "123456")
            XCTFail("Expected NetworkError.noConnection")
        } catch let error as NetworkError {
            XCTAssertEqual(error, .noConnection)
        } catch {
            XCTFail("Unexpected error \(error)")
        }

        // Generic error maps to AuthError.invalidCredentials
        struct GenericError: Error {}
        mockRepo.verifyPhoneOtpResult = .failure(GenericError())
        do {
            _ = try await useCase.execute(phoneNumber: "+84901234567", otpCode: "123456")
            XCTFail("Expected invalidCredentials error for generic failure")
        } catch let error as AuthError {
            XCTAssertEqual(error, .invalidCredentials)
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }

    // MARK: - RefreshTokenUseCase Inactive User

    func testRefreshTokenUseCase_inactiveUser_throwsAccountLocked() async {
        let mockRepo = MockAuthRepository()
        let mockSession = MockSessionManager()
        let tokenProvider = InMemoryTokenProvider()
        await tokenProvider.updateTokens(access: "acc", refresh: "ref")

        let lockedUser = User(
            id: UUID(),
            email: "locked@splick.app",
            username: "locked",
            displayName: "Locked",
            avatarURL: nil,
            status: .inactive,
            preferredLocale: "vi",
            timezone: "Asia/Ho_Chi_Minh",
            dateOfBirth: nil,
            createdAt: Date()
        )
        let lockedSession = AuthSession(
            user: lockedUser,
            token: AuthToken(accessToken: "tok", refreshToken: "ref", expiresIn: 3600, tokenType: "Bearer", sessionId: nil)
        )
        mockRepo.refreshTokenResult = .success(lockedSession)

        let useCase = RefreshTokenUseCase(
            repository: mockRepo,
            sessionManager: mockSession,
            tokenProvider: tokenProvider
        )

        do {
            try await useCase.refreshSession()
            XCTFail("Expected accountLocked error")
        } catch let error as AuthError {
            XCTAssertEqual(error, .accountLocked)
        } catch {
            XCTFail("Unexpected error \(error)")
        }

        let sessionAfterLock = await mockSession.currentSession()
        XCTAssertNil(sessionAfterLock)
    }

    // MARK: - RestoreSessionUseCase Extended

    func testRestoreSessionUseCase_restoreLocal_jwtParsingAndFallbacks() async {
        let mockRepo = MockAuthRepository()
        let mockSession = MockSessionManager()
        let mockKeychain = MockKeychainService()
        let tokenProvider = InMemoryTokenProvider()
        let mockRefresh = MockRefreshTokenUseCase()
        let mockDefaults = MockUserDefaultsService()

        let useCase = RestoreSessionUseCase(
            repository: mockRepo,
            sessionManager: mockSession,
            keychainService: mockKeychain,
            tokenProvider: tokenProvider,
            refreshTokenUseCase: mockRefresh,
            userDefaultsService: mockDefaults
        )

        // 1. No tokens stored -> returns nil
        let nilSession = await useCase.restoreLocal()
        XCTAssertNil(nilSession)

        // 2. Tokens stored, no cached user, but stored userId in keychain
        let userId = UUID()
        try? mockKeychain.saveString("raw_access_token", for: AppConstants.Keychain.accessTokenKey)
        try? mockKeychain.saveString("raw_refresh_token", for: AppConstants.Keychain.refreshTokenKey)
        try? mockKeychain.saveString(userId.uuidString, for: AppConstants.Keychain.userIdKey)

        let sessionWithUserId = await useCase.restoreLocal()
        XCTAssertNotNil(sessionWithUserId)
        XCTAssertEqual(sessionWithUserId?.user.id, userId)

        // 3. Tokens stored, no cached user, no stored userId, but access token is JWT with sub
        try? mockKeychain.delete(for: AppConstants.Keychain.userIdKey)
        let jwtSubId = UUID()
        let header = Data(#"{"alg":"none","typ":"JWT"}"#.utf8).base64EncodedString()
        let payload = Data("{\"sub\":\"\(jwtSubId.uuidString)\"}".utf8).base64EncodedString()
        let jwtToken = "\(header).\(payload)."
        try? mockKeychain.saveString(jwtToken, for: AppConstants.Keychain.accessTokenKey)

        let sessionFromJwt = await useCase.restoreLocal()
        XCTAssertNotNil(sessionFromJwt)
        XCTAssertEqual(sessionFromJwt?.user.id, jwtSubId)

        // 4. Invalid JWT and no stored userId -> returns nil
        try? mockKeychain.saveString("invalid_jwt_token", for: AppConstants.Keychain.accessTokenKey)
        try? mockKeychain.delete(for: AppConstants.Keychain.userIdKey)
        let failedLocal = await useCase.restoreLocal()
        XCTAssertNil(failedLocal)
    }

    func testRestoreSessionUseCase_confirmRemote_branches() async {
        let mockRepo = MockAuthRepository()
        let mockSession = MockSessionManager()
        let mockKeychain = MockKeychainService()
        let tokenProvider = InMemoryTokenProvider()
        let mockRefresh = MockRefreshTokenUseCase()
        let mockDefaults = MockUserDefaultsService()

        let useCase = RestoreSessionUseCase(
            repository: mockRepo,
            sessionManager: mockSession,
            keychainService: mockKeychain,
            tokenProvider: tokenProvider,
            refreshTokenUseCase: mockRefresh,
            userDefaultsService: mockDefaults
        )

        // 1. Stored tokens is nil -> .signedOut
        let signedOutWhenNoTokens = await useCase.confirmRemote()
        if case .signedOut = signedOutWhenNoTokens {} else {
            XCTFail("Expected .signedOut")
        }

        // Set up valid tokens
        try? mockKeychain.saveString("acc_tok", for: AppConstants.Keychain.accessTokenKey)
        try? mockKeychain.saveString("ref_tok", for: AppConstants.Keychain.refreshTokenKey)

        // 2. Server user has status .suspended (allowsSignIn == false) -> .signedOut
        let suspendedUser = User(
            id: UUID(),
            email: "s@s.app",
            username: "s",
            displayName: "S",
            avatarURL: nil,
            status: .inactive,
            preferredLocale: "vi",
            timezone: "Asia/Ho_Chi_Minh",
            dateOfBirth: nil,
            createdAt: Date()
        )
        mockRepo.currentUserResult = .success(suspendedUser)
        let signedOutSuspended = await useCase.confirmRemote()
        if case .signedOut = signedOutSuspended {} else {
            XCTFail("Expected .signedOut for suspended user")
        }

        // 3. Unauthorized on getCurrentUser, refresh succeeds and updates session in sessionManager -> .updated
        try? mockKeychain.saveString("acc_tok", for: AppConstants.Keychain.accessTokenKey)
        try? mockKeychain.saveString("ref_tok", for: AppConstants.Keychain.refreshTokenKey)
        mockRepo.currentUserResult = .failure(NetworkError.unauthorized)

        let refreshedUser = User(
            id: UUID(),
            email: "refreshed@s.app",
            username: "refreshed",
            displayName: "Refreshed",
            avatarURL: nil,
            status: .active,
            preferredLocale: "vi",
            timezone: "Asia/Ho_Chi_Minh",
            dateOfBirth: nil,
            createdAt: Date()
        )
        let refreshedSession = AuthSession(
            user: refreshedUser,
            token: AuthToken(accessToken: "new_acc", refreshToken: "new_ref", expiresIn: 3600, tokenType: "Bearer", sessionId: nil)
        )
        mockRefresh.onRefresh = {
            await mockSession.setSession(refreshedSession)
        }

        let updatedAfterRefresh = await useCase.confirmRemote()
        if case .updated(let s) = updatedAfterRefresh {
            XCTAssertEqual(s.user.email, "refreshed@s.app")
        } else {
            XCTFail("Expected .updated after refresh")
        }

        // 4. Unauthorized on getCurrentUser, refresh succeeds but sessionManager has no session -> .unchanged
        mockRefresh.onRefresh = {
            await mockSession.clearSession()
        }
        let unchangedAfterRefreshNoSession = await useCase.confirmRemote()
        if case .unchanged = unchangedAfterRefreshNoSession {} else {
            XCTFail("Expected .unchanged when refreshed session is nil")
        }

        // 5. Remote failure with transient error (noConnection) -> .unchanged (keeps local)
        mockRepo.currentUserResult = .failure(NetworkError.noConnection)
        let unchangedNoInternet = await useCase.confirmRemote()
        if case .unchanged = unchangedNoInternet {} else {
            XCTFail("Expected .unchanged on noConnection")
        }

        // 6. Remote failure with AuthError.accountLocked -> .signedOut
        mockRepo.currentUserResult = .failure(AuthError.accountLocked)
        let signedOutLocked = await useCase.confirmRemote()
        if case .signedOut = signedOutLocked {} else {
            XCTFail("Expected .signedOut on accountLocked")
        }

        // 7. Remote failure with AuthError.accountInactive -> .signedOut
        mockRepo.currentUserResult = .failure(AuthError.accountInactive(.init(deactivatedAt: nil, scheduledDeletionAt: nil, reactivationToken: "tok")))
        let signedOutInactive = await useCase.confirmRemote()
        if case .signedOut = signedOutInactive {} else {
            XCTFail("Expected .signedOut on accountInactive")
        }

        // 8. Remote failure with generic error -> .unchanged
        try? mockKeychain.saveString("acc_tok", for: AppConstants.Keychain.accessTokenKey)
        try? mockKeychain.saveString("ref_tok", for: AppConstants.Keychain.refreshTokenKey)
        struct RandomError: Error {}
        mockRepo.currentUserResult = .failure(RandomError())
        let unchangedRandom = await useCase.confirmRemote()
        if case .unchanged = unchangedRandom {} else {
            XCTFail("Expected .unchanged on random error")
        }
    }

    func testRestoreSessionUseCase_execute_branches() async {
        let mockRepo = MockAuthRepository()
        let mockSession = MockSessionManager()
        let mockKeychain = MockKeychainService()
        let tokenProvider = InMemoryTokenProvider()
        let mockRefresh = MockRefreshTokenUseCase()
        let mockDefaults = MockUserDefaultsService()

        let useCase = RestoreSessionUseCase(
            repository: mockRepo,
            sessionManager: mockSession,
            keychainService: mockKeychain,
            tokenProvider: tokenProvider,
            refreshTokenUseCase: mockRefresh,
            userDefaultsService: mockDefaults
        )

        // 1. restoreLocal fails -> returns nil
        let nilResult = await useCase.execute()
        XCTAssertNil(nilResult)

        // 2. restoreLocal succeeds, confirmRemote returns .unchanged -> returns local session
        let localUser = User(
            id: UUID(),
            email: "local@splick.app",
            username: "local",
            displayName: "Local",
            avatarURL: nil,
            status: .active,
            preferredLocale: "vi",
            timezone: "Asia/Ho_Chi_Minh",
            dateOfBirth: nil,
            createdAt: Date()
        )
        try? mockKeychain.saveString("acc_tok", for: AppConstants.Keychain.accessTokenKey)
        try? mockKeychain.saveString("ref_tok", for: AppConstants.Keychain.refreshTokenKey)
        mockDefaults.set(localUser, for: AppConstants.UserDefaults.cachedCurrentUser)
        mockRepo.currentUserResult = .failure(NetworkError.noConnection)

        let unchangedResult = await useCase.execute()
        XCTAssertNotNil(unchangedResult)
        XCTAssertEqual(unchangedResult?.user.email, "local@splick.app")

        // 3. restoreLocal succeeds, confirmRemote returns .signedOut -> returns nil
        mockRepo.currentUserResult = .failure(AuthError.accountLocked)
        let signedOutResult = await useCase.execute()
        XCTAssertNil(signedOutResult)
    }
}

// MARK: - Helpers

private struct AnyEncodable: Encodable {
    private let encodeFunc: (Encoder) throws -> Void

    init(_ encodable: Encodable) {
        self.encodeFunc = encodable.encode
    }

    func encode(to encoder: Encoder) throws {
        try encodeFunc(encoder)
    }
}
