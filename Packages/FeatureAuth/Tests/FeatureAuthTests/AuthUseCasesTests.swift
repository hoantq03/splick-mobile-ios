import XCTest
import SplickDomain
import Common
import Storage
import Networking
@testable import FeatureAuth

// MARK: - Mock Repository

final class MockAuthRepository: AuthRepositoryProtocol, @unchecked Sendable {
    var checkIdentifierResult: Result<Bool, Error> = .success(true)
    var checkUsernameResult: Result<Bool, Error> = .success(true)
    var signInWithGoogleResult: Result<AuthSession, Error>?
    var signInWithAppleResult: Result<AuthSession, Error>?
    var loginResult: Result<AuthSession, Error>?
    var requestEmailOtpResult: Result<Void, Error> = .success(())
    var requestPhoneOtpResult: Result<Void, Error> = .success(())
    var verifyPhoneOtpResult: Result<AuthSession, Error>?
    var registerEmailResult: Result<AuthSession, Error>?
    var registerPhoneResult: Result<AuthSession, Error>?
    var refreshTokenResult: Result<AuthSession, Error>?
    var forgotPasswordResult: Result<Void, Error> = .success(())
    var verifyResetPasswordOtpResult: Result<Void, Error> = .success(())
    var resetPasswordResult: Result<AuthSession, Error>?
    var changePasswordResult: Result<AuthSession, Error>?
    var verifyPasswordChangeResult: Result<Void, Error> = .success(())
    var logoutCalled = false
    var currentUserResult: Result<User, Error>?
    var updateProfileResult: Result<User, Error>?
    var sessionsResult: Result<[UserSession], Error> = .success([])
    var revokeSessionResult: Result<Void, Error> = .success(())
    var revokeAllSessionsResult: Result<Void, Error> = .success(())
    var deactivateAccountResult: Result<Void, Error> = .success(())
    var reactivateAccountResult: Result<AuthSession, Error>?
    var deleteAccountResult: Result<Void, Error> = .success(())
    var connectedAccountsResult: Result<ConnectedAccounts, Error>?
    var linkGoogleResult: Result<Void, Error> = .success(())
    var unlinkGoogleResult: Result<Void, Error> = .success(())
    var requestLinkPhoneOtpResult: Result<Void, Error> = .success(())
    var linkPhoneResult: Result<Void, Error> = .success(())
    var requestLinkEmailOtpResult: Result<Void, Error> = .success(())
    var linkEmailResult: Result<Void, Error> = .success(())
    var paymentProfileResult: Result<PaymentProfile, Error>?
    var upsertPaymentProfileResult: Result<PaymentProfile, Error>?
    var deletePaymentProfileResult: Result<Void, Error> = .success(())

    func checkIdentifier(email: String?, phoneNumber: String?) async throws -> Bool {
        try checkIdentifierResult.get()
    }

    func checkUsernameAvailability(_ username: String) async throws -> Bool {
        try checkUsernameResult.get()
    }

    func signInWithGoogle(idToken: String) async throws -> AuthSession {
        try (signInWithGoogleResult ?? .failure(AuthError.invalidCredentials)).get()
    }

    func signInWithApple(idToken: String) async throws -> AuthSession {
        try (signInWithAppleResult ?? .failure(AuthError.invalidCredentials)).get()
    }

    func login(email: String, password: String) async throws -> AuthSession {
        try (loginResult ?? .failure(AuthError.invalidCredentials)).get()
    }

    func requestEmailOtp(email: String) async throws {
        try requestEmailOtpResult.get()
    }

    func requestPhoneOtp(phoneNumber: String) async throws {
        try requestPhoneOtpResult.get()
    }

    func verifyPhoneOtp(phoneNumber: String, otpCode: String) async throws -> AuthSession {
        try (verifyPhoneOtpResult ?? .failure(AuthError.invalidCredentials)).get()
    }

    func registerWithEmail(
        email: String,
        username: String,
        password: String,
        otpCode: String,
        displayName: String?,
        dateOfBirth: Date?
    ) async throws -> AuthSession {
        try (registerEmailResult ?? .failure(AuthError.invalidCredentials)).get()
    }

    func registerWithPhone(
        phoneNumber: String,
        username: String,
        password: String,
        otpCode: String,
        displayName: String?,
        dateOfBirth: Date?
    ) async throws -> AuthSession {
        try (registerPhoneResult ?? .failure(AuthError.invalidCredentials)).get()
    }

    func refreshToken(_ refreshToken: String) async throws -> AuthSession {
        try (refreshTokenResult ?? .failure(AuthError.refreshFailed)).get()
    }

    func forgotPassword(email: String) async throws {
        try forgotPasswordResult.get()
    }

    func verifyResetPasswordOtp(email: String, otpCode: String) async throws {
        try verifyResetPasswordOtpResult.get()
    }

    func resetPassword(email: String, otpCode: String, newPassword: String) async throws -> AuthSession {
        try (resetPasswordResult ?? .failure(AuthError.invalidCredentials)).get()
    }

    func changePassword(currentPassword: String?, otpCode: String?, newPassword: String) async throws -> AuthSession {
        try (changePasswordResult ?? .failure(AuthError.invalidCredentials)).get()
    }

    func verifyPasswordChange(currentPassword: String?, otpCode: String?) async throws {
        try verifyPasswordChangeResult.get()
    }

    func logout() async {
        logoutCalled = true
    }

    func getCurrentUser() async throws -> User {
        try (currentUserResult ?? .failure(AuthError.tokenExpired)).get()
    }

    func updateProfile(
        displayName: String?,
        avatarUrl: String?,
        preferredLocale: String?,
        dateOfBirth: Date?,
        username: String?,
        timezone: String?
    ) async throws -> User {
        try (updateProfileResult ?? .failure(AuthError.invalidCredentials)).get()
    }

    func listSessions() async throws -> [UserSession] {
        try sessionsResult.get()
    }

    func revokeSession(id: UUID) async throws {
        try revokeSessionResult.get()
    }

    func revokeAllSessions() async throws {
        try revokeAllSessionsResult.get()
    }

    func deactivateAccount(currentPassword: String?, otpCode: String?) async throws {
        try deactivateAccountResult.get()
    }

    func reactivateAccount(reactivationToken: String) async throws -> AuthSession {
        try (reactivateAccountResult ?? .failure(AuthError.invalidCredentials)).get()
    }

    func deleteAccount(currentPassword: String?, otpCode: String?) async throws {
        try deleteAccountResult.get()
    }

    func getConnectedAccounts() async throws -> ConnectedAccounts {
        try (connectedAccountsResult ?? .failure(AuthError.invalidCredentials)).get()
    }

    func linkGoogleAccount(idToken: String) async throws {
        try linkGoogleResult.get()
    }

    func unlinkGoogleAccount(currentPassword: String?, otpCode: String?) async throws {
        try unlinkGoogleResult.get()
    }

    func requestLinkPhoneOtp(phoneNumber: String) async throws {
        try requestLinkPhoneOtpResult.get()
    }

    func linkPhoneAccount(phoneNumber: String, otpCode: String) async throws {
        try linkPhoneResult.get()
    }

    func requestLinkEmailOtp(email: String?) async throws {
        try requestLinkEmailOtpResult.get()
    }

    func linkEmailAccount(email: String?, otpCode: String, password: String) async throws {
        try linkEmailResult.get()
    }

    func fetchMyPaymentProfile() async throws -> PaymentProfile {
        try (paymentProfileResult ?? .failure(AuthError.invalidCredentials)).get()
    }

    func upsertMyPaymentProfile(
        qrImageUrl: String?,
        accountName: String?,
        accountNumber: String?,
        bankName: String?
    ) async throws -> PaymentProfile {
        try (upsertPaymentProfileResult ?? .failure(AuthError.invalidCredentials)).get()
    }

    func deleteMyPaymentProfile() async throws {
        try deletePaymentProfileResult.get()
    }
}

// MARK: - Mock Session Manager

final class MockSessionManager: SessionManagerProtocol, @unchecked Sendable {
    var storedSession: AuthSession?

    func currentSession() async -> AuthSession? {
        storedSession
    }

    func setSession(_ session: AuthSession) async {
        storedSession = session
    }

    func clearSession() async {
        storedSession = nil
    }

    func isAuthenticated() async -> Bool {
        storedSession != nil
    }
}

// MARK: - Mock User Defaults

final class MockUserDefaultsService: UserDefaultsServiceProtocol, @unchecked Sendable {
    private var store: [String: Any] = [:]

    func set<T: Codable>(_ value: T, for key: String) {
        if let data = try? JSONEncoder().encode(value) {
            store[key] = data
        }
    }

    func get<T: Codable>(for key: String) -> T? {
        guard let data = store[key] as? Data else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    func setBool(_ value: Bool, for key: String) {
        store[key] = value
    }

    func getBool(for key: String) -> Bool {
        store[key] as? Bool ?? false
    }

    func remove(for key: String) {
        store.removeValue(forKey: key)
    }
}

// MARK: - Mock Keychain

final class MockKeychainService: KeychainServiceProtocol, @unchecked Sendable {
    var storage: [String: Data] = [:]

    func save(_ data: Data, for key: String) throws {
        storage[key] = data
    }

    func load(for key: String) throws -> Data? {
        storage[key]
    }

    func delete(for key: String) throws {
        storage.removeValue(forKey: key)
    }

    func saveString(_ value: String, for key: String) throws {
        storage[key] = value.data(using: .utf8)
    }

    func loadString(for key: String) throws -> String? {
        guard let data = storage[key] else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

// MARK: - Mock Token Refresh UseCase

final class MockRefreshTokenUseCase: RefreshTokenUseCaseProtocol, @unchecked Sendable {
    var refreshSessionResult: Result<Void, Error> = .success(())

    func refreshSession() async throws {
        try refreshSessionResult.get()
    }
}

// MARK: - UseCases Tests


final class AuthUseCasesTests: XCTestCase {

    private func createDummySession(status: UserAccountStatus = .active) -> AuthSession {
        let user = User(
            id: UUID(),
            email: "user@example.com",
            username: "user_test",
            displayName: "Test User",
            avatarURL: nil,
            status: status,
            preferredLocale: "vi",
            timezone: "Asia/Ho_Chi_Minh",
            dateOfBirth: nil,
            createdAt: Date()
        )
        let token = AuthToken(
            accessToken: "mock_access",
            refreshToken: "mock_refresh",
            expiresIn: 3600,
            tokenType: "Bearer",
            sessionId: UUID()
        )
        return AuthSession(user: user, token: token, isNewUser: false)
    }

    // MARK: - LoginUseCase Tests

    func testLoginUseCase_success() async throws {
        let mockRepo = MockAuthRepository()
        let mockSession = MockSessionManager()
        let expectedSession = createDummySession(status: .active)
        mockRepo.loginResult = .success(expectedSession)

        let useCase = LoginUseCase(repository: mockRepo, sessionManager: mockSession)
        let result = try await useCase.execute(email: "user@example.com", password: "Password123!")

        XCTAssertEqual(result.user.id, expectedSession.user.id)
        let stored = await mockSession.currentSession()
        XCTAssertEqual(stored?.user.id, expectedSession.user.id)
    }

    func testLoginUseCase_accountInactive_throwsAccountInactive() async {
        let mockRepo = MockAuthRepository()
        let mockSession = MockSessionManager()
        let inactiveSession = createDummySession(status: .inactive)
        mockRepo.loginResult = .success(inactiveSession)

        let useCase = LoginUseCase(repository: mockRepo, sessionManager: mockSession)
        do {
            _ = try await useCase.execute(email: "user@example.com", password: "Password123!")
            XCTFail("Expected error")
        } catch let error as AuthError {
            if case .accountInactive = error {
                // Success
            } else {
                XCTFail("Expected accountInactive, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }

    func testLoginUseCase_accountLocked_throwsAccountLocked() async {
        let mockRepo = MockAuthRepository()
        let mockSession = MockSessionManager()
        let lockedSession = createDummySession(status: .locked)
        mockRepo.loginResult = .success(lockedSession)

        let useCase = LoginUseCase(repository: mockRepo, sessionManager: mockSession)
        do {
            _ = try await useCase.execute(email: "user@example.com", password: "Password123!")
            XCTFail("Expected error")
        } catch let error as AuthError {
            XCTAssertEqual(error, .accountLocked)
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }

    func testLoginUseCase_connectivityIssue_rethrowsNetworkError() async {
        let mockRepo = MockAuthRepository()
        let mockSession = MockSessionManager()
        mockRepo.loginResult = .failure(NetworkError.noConnection)

        let useCase = LoginUseCase(repository: mockRepo, sessionManager: mockSession)
        do {
            _ = try await useCase.execute(email: "user@example.com", password: "Password123!")
            XCTFail("Expected network error")
        } catch let error as NetworkError {
            XCTAssertEqual(error, .noConnection)
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }

    func testLoginUseCase_unknownError_throwsInvalidCredentials() async {
        let mockRepo = MockAuthRepository()
        let mockSession = MockSessionManager()
        mockRepo.loginResult = .failure(NSError(domain: "test", code: -1))

        let useCase = LoginUseCase(repository: mockRepo, sessionManager: mockSession)
        do {
            _ = try await useCase.execute(email: "user@example.com", password: "Password123!")
            XCTFail("Expected invalidCredentials")
        } catch let error as AuthError {
            XCTAssertEqual(error, .invalidCredentials)
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }

    // MARK: - RegisterUseCase Tests

    func testRegisterUseCase_email_success() async throws {
        let mockRepo = MockAuthRepository()
        let mockSession = MockSessionManager()
        let expectedSession = createDummySession(status: .active)
        mockRepo.registerEmailResult = .success(expectedSession)

        let useCase = RegisterUseCase(repository: mockRepo, sessionManager: mockSession)
        let result = try await useCase.execute(
            channel: .email,
            identifier: "user@example.com",
            username: "tester",
            password: "Password123!",
            otpCode: "123456",
            displayName: "Tester",
            dateOfBirth: nil
        )

        XCTAssertEqual(result.user.id, expectedSession.user.id)
        let stored = await mockSession.currentSession()
        XCTAssertEqual(stored?.user.id, expectedSession.user.id)
    }

    func testRegisterUseCase_phone_success() async throws {
        let mockRepo = MockAuthRepository()
        let mockSession = MockSessionManager()
        let expectedSession = createDummySession(status: .active)
        mockRepo.registerPhoneResult = .success(expectedSession)

        let useCase = RegisterUseCase(repository: mockRepo, sessionManager: mockSession)
        let result = try await useCase.execute(
            channel: .phone,
            identifier: "+84901234567",
            username: "tester",
            password: "Password123!",
            otpCode: "123456",
            displayName: "Tester",
            dateOfBirth: nil
        )

        XCTAssertEqual(result.user.id, expectedSession.user.id)
    }

    func testRegisterUseCase_accountLocked_throwsAccountLocked() async {
        let mockRepo = MockAuthRepository()
        let mockSession = MockSessionManager()
        let lockedSession = createDummySession(status: .locked)
        mockRepo.registerEmailResult = .success(lockedSession)

        let useCase = RegisterUseCase(repository: mockRepo, sessionManager: mockSession)
        do {
            _ = try await useCase.execute(
                channel: .email,
                identifier: "user@example.com",
                username: "tester",
                password: "Password123!",
                otpCode: "123456",
                displayName: "Tester",
                dateOfBirth: nil
            )
            XCTFail("Expected locked error")
        } catch let error as AuthError {
            XCTAssertEqual(error, .accountLocked)
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }

    // MARK: - LogoutUseCase Tests

    func testLogoutUseCase_callsRepoAndClearsSession() async {
        let mockRepo = MockAuthRepository()
        let mockSession = MockSessionManager()
        await mockSession.setSession(createDummySession())

        let useCase = LogoutUseCase(repository: mockRepo, sessionManager: mockSession)
        await useCase.execute()

        XCTAssertTrue(mockRepo.logoutCalled)
        let session = await mockSession.currentSession()
        XCTAssertNil(session)
    }

    // MARK: - CheckIdentifier & Username UseCases Tests

    func testCheckIdentifierUseCase() async throws {
        let mockRepo = MockAuthRepository()
        mockRepo.checkIdentifierResult = .success(true)

        let useCase = CheckIdentifierUseCase(repository: mockRepo)
        let exists = try await useCase.execute(email: "test@example.com", phoneNumber: nil)
        XCTAssertTrue(exists)
    }

    func testCheckUsernameAvailabilityUseCase() async throws {
        let mockRepo = MockAuthRepository()
        mockRepo.checkUsernameResult = .success(false)

        let useCase = CheckUsernameAvailabilityUseCase(repository: mockRepo)
        let available = try await useCase.execute(username: "taken_user")
        XCTAssertFalse(available)
    }

    // MARK: - Payment Profile UseCases Tests

    func testPaymentProfileUseCases() async throws {
        let mockRepo = MockAuthRepository()
        let expectedProfile = PaymentProfile(
            userId: UUID(),
            qrImageURL: URL(string: "https://example.com/qr.png"),
            accountName: "NAME",
            accountNumber: "123456",
            bankName: "BANK",
            updatedAt: Date()
        )
        mockRepo.paymentProfileResult = .success(expectedProfile)
        mockRepo.upsertPaymentProfileResult = .success(expectedProfile)

        let fetchUseCase = FetchMyPaymentProfileUseCase(repository: mockRepo)
        let fetched = try await fetchUseCase.execute()
        XCTAssertEqual(fetched.accountName, "NAME")

        let upsertUseCase = UpsertMyPaymentProfileUseCase(repository: mockRepo)
        let upserted = try await upsertUseCase.execute(.init(
            qrImageUrl: "https://example.com/qr.png",
            accountName: "NAME",
            accountNumber: "123456",
            bankName: "BANK"
        ))
        XCTAssertEqual(upserted.accountNumber, "123456")

        let deleteUseCase = DeleteMyPaymentProfileUseCase(repository: mockRepo)
        do {
            try await deleteUseCase.execute()
        } catch {
            XCTFail("Unexpected throw: \(error)")
        }
    }

    // MARK: - SessionManager Actor Tests

    func testSessionManager_lifecycle() async {
        let mockDefaults = MockUserDefaultsService()
        let sessionManager = SessionManager(userDefaultsService: mockDefaults)

        let authBefore = await sessionManager.isAuthenticated()
        XCTAssertFalse(authBefore)
        let currentBefore = await sessionManager.currentSession()
        XCTAssertNil(currentBefore)

        let dummy = createDummySession()
        await sessionManager.setSession(dummy)

        let authAfter = await sessionManager.isAuthenticated()
        XCTAssertTrue(authAfter)
        let currentAfter = await sessionManager.currentSession()
        XCTAssertEqual(currentAfter?.user.id, dummy.user.id)

        // Cached user in defaults
        let cachedUser: User? = mockDefaults.get(for: AppConstants.UserDefaults.cachedCurrentUser)
        XCTAssertEqual(cachedUser?.id, dummy.user.id)

        await sessionManager.clearSession()
        let authCleared = await sessionManager.isAuthenticated()
        XCTAssertFalse(authCleared)
        let currentCleared = await sessionManager.currentSession()
        XCTAssertNil(currentCleared)
        let cachedAfterClear: User? = mockDefaults.get(for: AppConstants.UserDefaults.cachedCurrentUser)
        XCTAssertNil(cachedAfterClear)
    }

    // MARK: - OAuth Sign In UseCases

    func testAppleSignInUseCase_success() async throws {
        let mockRepo = MockAuthRepository()
        let mockSession = MockSessionManager()
        let dummy = createDummySession(status: .active)
        mockRepo.signInWithAppleResult = .success(dummy)

        let useCase = AppleSignInUseCase(repository: mockRepo, sessionManager: mockSession)
        let session = try await useCase.execute(idToken: "apple_token")
        XCTAssertEqual(session.user.id, dummy.user.id)
        let stored = await mockSession.currentSession()
        XCTAssertEqual(stored?.user.id, dummy.user.id)
    }

    func testAppleSignInUseCase_locked_throwsAccountLocked() async {
        let mockRepo = MockAuthRepository()
        let mockSession = MockSessionManager()
        let dummy = createDummySession(status: .locked)
        mockRepo.signInWithAppleResult = .success(dummy)

        let useCase = AppleSignInUseCase(repository: mockRepo, sessionManager: mockSession)
        do {
            _ = try await useCase.execute(idToken: "apple_token")
            XCTFail("Expected locked error")
        } catch let error as AuthError {
            XCTAssertEqual(error, .accountLocked)
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }

    func testGoogleSignInUseCase_success() async throws {
        let mockRepo = MockAuthRepository()
        let mockSession = MockSessionManager()
        let dummy = createDummySession(status: .active)
        mockRepo.signInWithGoogleResult = .success(dummy)

        let useCase = GoogleSignInUseCase(repository: mockRepo, sessionManager: mockSession)
        let session = try await useCase.execute(idToken: "google_token")
        XCTAssertEqual(session.user.id, dummy.user.id)
        let stored = await mockSession.currentSession()
        XCTAssertEqual(stored?.user.id, dummy.user.id)
    }

    func testGoogleSignInUseCase_locked_throwsAccountLocked() async {
        let mockRepo = MockAuthRepository()
        let mockSession = MockSessionManager()
        let dummy = createDummySession(status: .locked)
        mockRepo.signInWithGoogleResult = .success(dummy)

        let useCase = GoogleSignInUseCase(repository: mockRepo, sessionManager: mockSession)
        do {
            _ = try await useCase.execute(idToken: "google_token")
            XCTFail("Expected locked error")
        } catch let error as AuthError {
            XCTAssertEqual(error, .accountLocked)
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }

    // MARK: - Password Management UseCases

    func testChangePasswordUseCase_success() async throws {
        let mockRepo = MockAuthRepository()
        let mockSession = MockSessionManager()
        let dummy = createDummySession(status: .active)
        mockRepo.changePasswordResult = .success(dummy)

        let useCase = ChangePasswordUseCase(repository: mockRepo, sessionManager: mockSession)
        let session = try await useCase.execute(currentPassword: "old", otpCode: nil, newPassword: "new")
        XCTAssertEqual(session.user.id, dummy.user.id)
    }

    func testChangePasswordUseCase_unauthorized_throwsInvalidCredentials() async {
        let mockRepo = MockAuthRepository()
        let mockSession = MockSessionManager()
        mockRepo.changePasswordResult = .failure(NetworkError.unauthorized)

        let useCase = ChangePasswordUseCase(repository: mockRepo, sessionManager: mockSession)
        do {
            _ = try await useCase.execute(currentPassword: "wrong", otpCode: nil, newPassword: "new")
            XCTFail("Expected invalidCredentials")
        } catch let error as AuthError {
            XCTAssertEqual(error, .invalidCredentials)
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }

    func testResetPasswordUseCase_success() async throws {
        let mockRepo = MockAuthRepository()
        let mockSession = MockSessionManager()
        let dummy = createDummySession(status: .active)
        mockRepo.resetPasswordResult = .success(dummy)

        let useCase = ResetPasswordUseCase(repository: mockRepo, sessionManager: mockSession)
        let session = try await useCase.execute(email: "a@b.com", otpCode: "123456", newPassword: "new")
        XCTAssertEqual(session.user.id, dummy.user.id)
    }

    func testForgotPasswordUseCase() async throws {
        let mockRepo = MockAuthRepository()
        let useCase = ForgotPasswordUseCase(repository: mockRepo)
        do {
            try await useCase.execute(email: "a@b.com")
        } catch {
            XCTFail("Unexpected throw: \(error)")
        }
    }

    // MARK: - OTP Verification UseCases

    func testVerifyPhoneOtpUseCase_success() async throws {
        let mockRepo = MockAuthRepository()
        let mockSession = MockSessionManager()
        let dummy = createDummySession(status: .active)
        mockRepo.verifyPhoneOtpResult = .success(dummy)

        let useCase = VerifyPhoneOtpUseCase(repository: mockRepo, sessionManager: mockSession)
        let session = try await useCase.execute(phoneNumber: "+84901234567", otpCode: "123456")
        XCTAssertEqual(session.user.id, dummy.user.id)
    }

    func testVerifyResetPasswordOtpUseCase() async throws {
        let mockRepo = MockAuthRepository()
        let useCase = VerifyResetPasswordOtpUseCase(repository: mockRepo)
        do {
            try await useCase.execute(email: "a@b.com", otpCode: "123456")
        } catch {
            XCTFail("Unexpected throw: \(error)")
        }
    }

    func testVerifyPasswordChangeUseCase() async throws {
        let mockRepo = MockAuthRepository()
        let useCase = VerifyPasswordChangeUseCase(repository: mockRepo)
        do {
            try await useCase.execute(currentPassword: "old", otpCode: "123456")
        } catch {
            XCTFail("Unexpected throw: \(error)")
        }
    }

    func testRequestOtpUseCases() async throws {
        let mockRepo = MockAuthRepository()
        let emailUseCase = RequestEmailOtpUseCase(repository: mockRepo)
        do {
            try await emailUseCase.execute(email: "a@b.com")
        } catch {
            XCTFail("Unexpected throw: \(error)")
        }

        let phoneUseCase = RequestPhoneOtpUseCase(repository: mockRepo)
        do {
            try await phoneUseCase.execute(phoneNumber: "+84901234567")
        } catch {
            XCTFail("Unexpected throw: \(error)")
        }
    }

    // MARK: - Sessions & Account Management UseCases

    func testListAndRevokeSessionsUseCases() async throws {
        let mockRepo = MockAuthRepository()
        let dummySession = UserSession(
            id: UUID(),
            deviceInfo: "iPhone",
            deviceName: "My Phone",
            loginIp: "127.0.0.1",
            loginLocation: "Hanoi",
            createdAt: Date(),
            expiresAt: Date().addingTimeInterval(3600),
            isCurrent: true
        )
        mockRepo.sessionsResult = .success([dummySession])

        let listUseCase = ListSessionsUseCase(repository: mockRepo)
        let sessions = try await listUseCase.execute()
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions.first?.deviceName, "My Phone")

        let mockSession = MockSessionManager()
        let revokeUseCase = RevokeSessionUseCase(repository: mockRepo)
        do {
            try await revokeUseCase.execute(sessionId: dummySession.id)
        } catch {
            XCTFail("Unexpected throw: \(error)")
        }

        let revokeAllUseCase = RevokeAllSessionsUseCase(repository: mockRepo, sessionManager: mockSession)
        do {
            try await revokeAllUseCase.execute()
        } catch {
            XCTFail("Unexpected throw: \(error)")
        }
    }

    func testAccountLifecycleUseCases() async throws {
        let mockRepo = MockAuthRepository()
        let mockSession = MockSessionManager()
        await mockSession.setSession(createDummySession())

        let deactivateUseCase = DeactivateAccountUseCase(repository: mockRepo, sessionManager: mockSession)
        try await deactivateUseCase.execute(currentPassword: "pwd", otpCode: nil)
        let afterDeactivate = await mockSession.currentSession()
        XCTAssertNil(afterDeactivate)

        let dummy = createDummySession(status: .active)
        mockRepo.reactivateAccountResult = .success(dummy)
        let reactivateUseCase = ReactivateAccountUseCase(repository: mockRepo, sessionManager: mockSession)
        let reactivated = try await reactivateUseCase.execute(reactivationToken: "token")
        XCTAssertEqual(reactivated.user.id, dummy.user.id)

        let deleteUseCase = DeleteAccountUseCase(repository: mockRepo, sessionManager: mockSession)
        try await deleteUseCase.execute(currentPassword: "pwd", otpCode: nil)
        let afterDelete = await mockSession.currentSession()
        XCTAssertNil(afterDelete)
    }

    func testConnectedAccountsUseCases() async throws {
        let mockRepo = MockAuthRepository()
        let accounts = ConnectedAccounts(
            google: .init(isLinked: true, detail: "g@splick.app"),
            emailPassword: .init(isLinked: true, detail: "e@splick.app"),
            phone: .init(isLinked: false, detail: nil)
        )
        mockRepo.connectedAccountsResult = .success(accounts)

        let getUseCase = GetConnectedAccountsUseCase(repository: mockRepo)
        let result = try await getUseCase.execute()
        XCTAssertTrue(result.google.isLinked)

        let linkGoogle = LinkGoogleAccountUseCase(repository: mockRepo)
        try await linkGoogle.execute(idToken: "tok")

        let unlinkGoogle = UnlinkGoogleAccountUseCase(repository: mockRepo)
        try await unlinkGoogle.execute(currentPassword: "pwd", otpCode: nil)

        let linkPhone = LinkPhoneAccountUseCase(repository: mockRepo)
        try await linkPhone.requestOtp(phoneNumber: "+84901234567")
        try await linkPhone.execute(phoneNumber: "+84901234567", otpCode: "123456")

        let linkEmail = LinkEmailAccountUseCase(repository: mockRepo)
        try await linkEmail.requestOtp(email: "a@b.com")
        try await linkEmail.execute(email: "a@b.com", otpCode: "123456", password: "pwd")
    }

    // MARK: - Profile UseCases

    func testProfileUseCases() async throws {
        let mockRepo = MockAuthRepository()
        let mockSession = MockSessionManager()
        let initialSession = createDummySession(status: .active)
        await mockSession.setSession(initialSession)

        let updatedUser = User(
            id: initialSession.user.id,
            email: initialSession.user.email,
            username: "new_username",
            displayName: "New Name",
            avatarURL: nil,
            status: .active,
            preferredLocale: "vi",
            timezone: "Asia/Ho_Chi_Minh",
            dateOfBirth: nil,
            createdAt: Date()
        )
        mockRepo.updateProfileResult = .success(updatedUser)
        mockRepo.currentUserResult = .success(updatedUser)

        let updateUseCase = UpdateProfileUseCase(repository: mockRepo, sessionManager: mockSession)
        let updated = try await updateUseCase.execute(displayName: "New Name", avatarUrl: nil, preferredLocale: "vi")
        XCTAssertEqual(updated.displayName, "New Name")
        let sessionAfterUpdate = await mockSession.currentSession()
        XCTAssertEqual(sessionAfterUpdate?.user.displayName, "New Name")

        let refreshUseCase = RefreshProfileUseCase(repository: mockRepo, sessionManager: mockSession)
        let refreshed = try await refreshUseCase.execute()
        XCTAssertEqual(refreshed.displayName, "New Name")
    }

    // MARK: - RefreshTokenUseCase & RestoreSessionUseCase Tests

    func testRefreshTokenUseCase_noToken_throwsRefreshFailed() async {
        let mockRepo = MockAuthRepository()
        let mockSession = MockSessionManager()
        let tokenProvider = InMemoryTokenProvider()

        let useCase = RefreshTokenUseCase(
            repository: mockRepo,
            sessionManager: mockSession,
            tokenProvider: tokenProvider
        )

        do {
            try await useCase.refreshSession()
            XCTFail("Expected refreshFailed")
        } catch let error as AuthError {
            XCTAssertEqual(error, .refreshFailed)
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }

    func testRefreshTokenUseCase_success() async throws {
        let mockRepo = MockAuthRepository()
        let mockSession = MockSessionManager()
        let tokenProvider = InMemoryTokenProvider()
        await tokenProvider.updateTokens(access: "acc", refresh: "ref")

        let newSession = createDummySession(status: .active)
        mockRepo.refreshTokenResult = .success(newSession)

        let useCase = RefreshTokenUseCase(
            repository: mockRepo,
            sessionManager: mockSession,
            tokenProvider: tokenProvider
        )

        try await useCase.refreshSession()
        let stored = await mockSession.currentSession()
        XCTAssertEqual(stored?.user.id, newSession.user.id)
    }

    func testRestoreSessionUseCase_hasStoredCredentials() {
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

        XCTAssertFalse(useCase.hasStoredCredentials())

        try? mockKeychain.saveString("acc123", for: AppConstants.Keychain.accessTokenKey)
        try? mockKeychain.saveString("ref123", for: AppConstants.Keychain.refreshTokenKey)
        XCTAssertTrue(useCase.hasStoredCredentials())
    }

    func testRestoreSessionUseCase_restoreLocal_withCachedUser() async {
        let mockRepo = MockAuthRepository()
        let mockSession = MockSessionManager()
        let mockKeychain = MockKeychainService()
        let tokenProvider = InMemoryTokenProvider()
        let mockRefresh = MockRefreshTokenUseCase()
        let mockDefaults = MockUserDefaultsService()

        try? mockKeychain.saveString("acc123", for: AppConstants.Keychain.accessTokenKey)
        try? mockKeychain.saveString("ref123", for: AppConstants.Keychain.refreshTokenKey)

        let dummyUser = User(
            id: UUID(),
            email: "cached@example.com",
            username: "cached_user",
            displayName: "Cached User",
            avatarURL: nil,
            status: .active,
            preferredLocale: "vi",
            timezone: "Asia/Ho_Chi_Minh",
            dateOfBirth: nil,
            createdAt: Date()
        )
        mockDefaults.set(dummyUser, for: AppConstants.UserDefaults.cachedCurrentUser)

        let useCase = RestoreSessionUseCase(
            repository: mockRepo,
            sessionManager: mockSession,
            keychainService: mockKeychain,
            tokenProvider: tokenProvider,
            refreshTokenUseCase: mockRefresh,
            userDefaultsService: mockDefaults
        )

        let session = await useCase.restoreLocal()
        XCTAssertNotNil(session)
        XCTAssertEqual(session?.user.email, "cached@example.com")
        let stored = await mockSession.currentSession()
        XCTAssertEqual(stored?.user.email, "cached@example.com")
    }

    func testRestoreSessionUseCase_confirmRemote_success() async {
        let mockRepo = MockAuthRepository()
        let mockSession = MockSessionManager()
        let mockKeychain = MockKeychainService()
        let tokenProvider = InMemoryTokenProvider()
        let mockRefresh = MockRefreshTokenUseCase()
        let mockDefaults = MockUserDefaultsService()

        try? mockKeychain.saveString("acc123", for: AppConstants.Keychain.accessTokenKey)
        try? mockKeychain.saveString("ref123", for: AppConstants.Keychain.refreshTokenKey)

        let remoteUser = User(
            id: UUID(),
            email: "remote@example.com",
            username: "remote_user",
            displayName: "Remote User",
            avatarURL: nil,
            status: .active,
            preferredLocale: "vi",
            timezone: "Asia/Ho_Chi_Minh",
            dateOfBirth: nil,
            createdAt: Date()
        )
        mockRepo.currentUserResult = .success(remoteUser)

        let useCase = RestoreSessionUseCase(
            repository: mockRepo,
            sessionManager: mockSession,
            keychainService: mockKeychain,
            tokenProvider: tokenProvider,
            refreshTokenUseCase: mockRefresh,
            userDefaultsService: mockDefaults
        )

        let result = await useCase.confirmRemote()
        if case .updated(let s) = result {
            XCTAssertEqual(s.user.email, "remote@example.com")
        } else {
            XCTFail("Expected .updated, got \(result)")
        }
    }
}

