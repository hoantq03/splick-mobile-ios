import XCTest
import SplickDomain
import Common
import Networking
import Storage
@testable import FeatureAuth

private final class MockAPIClientForAuthRepo: APIClientProtocol, @unchecked Sendable {
    var lastEndpoint: APIEndpoint?
    var mockResponse: Any?
    var errorToThrow: Error?

    func request<T: Decodable>(_ endpoint: APIEndpoint) async throws -> T {
        lastEndpoint = endpoint
        if let error = errorToThrow { throw error }
        guard let response = mockResponse as? T else {
            fatalError("Mock response type mismatch. Expected \(T.self), got \(String(describing: mockResponse))")
        }
        return response
    }

    func request(_ endpoint: APIEndpoint) async throws {
        lastEndpoint = endpoint
        if let error = errorToThrow { throw error }
    }

    func upload<T: Decodable>(_ endpoint: APIEndpoint, data: Data, mimeType: String) async throws -> T {
        lastEndpoint = endpoint
        if let error = errorToThrow { throw error }
        guard let response = mockResponse as? T else {
            fatalError("Mock response mismatch for upload")
        }
        return response
    }
}

final class AuthRepositoryTests: XCTestCase {

    private var apiClient: MockAPIClientForAuthRepo!
    private var keychainService: MockKeychainService!
    private var tokenProvider: InMemoryTokenProvider!
    private var userDefaultsService: MockUserDefaultsService!
    private var sut: AuthRepository!

    override func setUp() {
        super.setUp()
        apiClient = MockAPIClientForAuthRepo()
        keychainService = MockKeychainService()
        tokenProvider = InMemoryTokenProvider()
        userDefaultsService = MockUserDefaultsService()
        sut = AuthRepository(
            apiClient: apiClient,
            keychainService: keychainService,
            tokenProvider: tokenProvider,
            userDefaultsService: userDefaultsService
        )
    }

    override func tearDown() {
        apiClient = nil
        keychainService = nil
        tokenProvider = nil
        userDefaultsService = nil
        sut = nil
        super.tearDown()
    }

    private func makeAuthResponseDTO(sessionId: UUID? = UUID(), userId: UUID = UUID()) -> AuthResponseDTO {
        AuthResponseDTO(
            accessToken: "access_123",
            refreshToken: "refresh_456",
            expiresIn: 3600,
            tokenType: "Bearer",
            sessionId: sessionId,
            user: UserDTO(
                id: userId,
                email: "test@example.com",
                username: "tester",
                displayName: "Test User",
                avatarUrl: "https://example.com/avatar.png",
                status: "active",
                preferredLocale: "en",
                timezone: "Asia/Ho_Chi_Minh",
                dateOfBirth: "2000-01-01",
                createdAt: Date()
            ),
            newUser: false
        )
    }

    func testCheckIdentifier() async throws {
        apiClient.mockResponse = CheckIdentifierResponseDTO(exists: true)
        let exists = try await sut.checkIdentifier(email: "a@b.com", phoneNumber: nil)
        XCTAssertTrue(exists)
        XCTAssertNotNil(apiClient.lastEndpoint)
    }

    func testCheckUsernameAvailability() async throws {
        apiClient.mockResponse = CheckUsernameResponseDTO(available: true)
        let available = try await sut.checkUsernameAvailability("  tester  ")
        XCTAssertTrue(available)
    }

    func testSignInWithGoogle() async throws {
        let authDto = makeAuthResponseDTO()
        apiClient.mockResponse = authDto

        let session = try await sut.signInWithGoogle(idToken: "google_id_token")
        XCTAssertEqual(session.user.id, authDto.user.id)
        XCTAssertEqual(try? keychainService.loadString(for: AppConstants.Keychain.accessTokenKey), "access_123")
        XCTAssertEqual(try? keychainService.loadString(for: AppConstants.Keychain.refreshTokenKey), "refresh_456")
        XCTAssertEqual(try? keychainService.loadString(for: AppConstants.Keychain.userIdKey), authDto.user.id.uuidString)
        let token = await tokenProvider.accessToken()
        XCTAssertEqual(token, "access_123")
    }

    func testSignInWithApple() async throws {
        let authDto = makeAuthResponseDTO(sessionId: nil)
        apiClient.mockResponse = authDto

        let session = try await sut.signInWithApple(idToken: "apple_id_token")
        XCTAssertEqual(session.user.id, authDto.user.id)
        XCTAssertEqual(try? keychainService.loadString(for: AppConstants.Keychain.accessTokenKey), "access_123")
    }

    func testLogin() async throws {
        let authDto = makeAuthResponseDTO()
        apiClient.mockResponse = authDto

        let session = try await sut.login(email: "a@b.com", password: "pwd")
        XCTAssertEqual(session.user.email, "test@example.com")
        let token = await tokenProvider.accessToken()
        XCTAssertEqual(token, "access_123")
    }

    func testRequestEmailOtp() async throws {
        try await sut.requestEmailOtp(email: "a@b.com")
        XCTAssertNotNil(apiClient.lastEndpoint)
    }

    func testRequestPhoneOtp() async throws {
        try await sut.requestPhoneOtp(phoneNumber: "+84901234567")
        XCTAssertNotNil(apiClient.lastEndpoint)
    }

    func testVerifyPhoneOtp() async throws {
        let authDto = makeAuthResponseDTO()
        apiClient.mockResponse = authDto

        let session = try await sut.verifyPhoneOtp(phoneNumber: "+84901234567", otpCode: "123456")
        XCTAssertEqual(session.user.id, authDto.user.id)
    }

    func testRegisterWithEmail() async throws {
        let authDto = makeAuthResponseDTO()
        apiClient.mockResponse = authDto

        let session = try await sut.registerWithEmail(
            email: "a@b.com",
            username: "tester",
            password: "pwd",
            otpCode: "123456",
            displayName: "Test",
            dateOfBirth: Date()
        )
        XCTAssertEqual(session.user.id, authDto.user.id)
    }

    func testRegisterWithPhone() async throws {
        let authDto = makeAuthResponseDTO()
        apiClient.mockResponse = authDto

        let session = try await sut.registerWithPhone(
            phoneNumber: "+84901234567",
            username: "tester",
            password: "pwd",
            otpCode: "123456",
            displayName: "Test",
            dateOfBirth: Date()
        )
        XCTAssertEqual(session.user.id, authDto.user.id)
    }

    func testRefreshToken() async throws {
        let authDto = makeAuthResponseDTO()
        apiClient.mockResponse = authDto

        let session = try await sut.refreshToken("refresh_old")
        XCTAssertEqual(session.token.accessToken, "access_123")
    }

    func testForgotPassword() async throws {
        try await sut.forgotPassword(email: "a@b.com")
        XCTAssertNotNil(apiClient.lastEndpoint)
    }

    func testVerifyResetPasswordOtp() async throws {
        try await sut.verifyResetPasswordOtp(email: "a@b.com", otpCode: "123456")
        XCTAssertNotNil(apiClient.lastEndpoint)
    }

    func testResetPassword() async throws {
        let authDto = makeAuthResponseDTO()
        apiClient.mockResponse = authDto

        let session = try await sut.resetPassword(email: "a@b.com", otpCode: "123456", newPassword: "new")
        XCTAssertEqual(session.user.id, authDto.user.id)
    }

    func testChangePassword() async throws {
        let authDto = makeAuthResponseDTO()
        apiClient.mockResponse = authDto

        let session = try await sut.changePassword(currentPassword: "old", otpCode: nil, newPassword: "new")
        XCTAssertEqual(session.user.id, authDto.user.id)
    }

    func testVerifyPasswordChange() async throws {
        try await sut.verifyPasswordChange(currentPassword: "pwd", otpCode: nil)
        XCTAssertNotNil(apiClient.lastEndpoint)
    }

    func testLogout_withStoredRefreshToken() async {
        try? keychainService.saveString("ref_tok", for: AppConstants.Keychain.refreshTokenKey)
        try? keychainService.saveString("acc_tok", for: AppConstants.Keychain.accessTokenKey)
        try? keychainService.saveString("usr_id", for: AppConstants.Keychain.userIdKey)
        try? keychainService.saveString("ses_id", for: AppConstants.Keychain.sessionIdKey)

        await sut.logout()

        XCTAssertNil(try? keychainService.loadString(for: AppConstants.Keychain.accessTokenKey))
        XCTAssertNil(try? keychainService.loadString(for: AppConstants.Keychain.refreshTokenKey))
        XCTAssertNil(try? keychainService.loadString(for: AppConstants.Keychain.userIdKey))
        XCTAssertNil(try? keychainService.loadString(for: AppConstants.Keychain.sessionIdKey))
        let token = await tokenProvider.accessToken()
        XCTAssertNil(token)
    }

    func testLogout_withError() async {
        try? keychainService.saveString("ref_tok", for: AppConstants.Keychain.refreshTokenKey)
        apiClient.errorToThrow = NetworkError.unauthorized

        await sut.logout()

        XCTAssertNil(try? keychainService.loadString(for: AppConstants.Keychain.accessTokenKey))
    }

    func testGetCurrentUser() async throws {
        let userDto = UserDTO(
            id: UUID(),
            email: "me@example.com",
            username: "me",
            displayName: "Me",
            avatarUrl: nil,
            status: "active",
            preferredLocale: "vi",
            timezone: "Asia/Ho_Chi_Minh",
            dateOfBirth: nil,
            createdAt: Date()
        )
        apiClient.mockResponse = userDto

        let user = try await sut.getCurrentUser()
        XCTAssertEqual(user.id, userDto.id)
        let cached: User? = userDefaultsService.get(for: AppConstants.UserDefaults.cachedCurrentUser)
        XCTAssertEqual(cached?.id, userDto.id)
    }

    func testUpdateProfile_validationFailure_allNil() async {
        do {
            _ = try await sut.updateProfile(
                displayName: "   ",
                avatarUrl: "",
                preferredLocale: "",
                dateOfBirth: nil,
                username: "  ",
                timezone: nil
            )
            XCTFail("Expected validation error")
        } catch let error as AppError {
            if case .validation = error {
                // Expected
            } else {
                XCTFail("Expected validation error, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }

    func testUpdateProfile_success() async throws {
        let userDto = UserDTO(
            id: UUID(),
            email: "me@example.com",
            username: "new_username",
            displayName: "New Display Name",
            avatarUrl: "https://example.com/avatar.jpg",
            status: "active",
            preferredLocale: "en",
            timezone: "UTC",
            dateOfBirth: "1995-05-05",
            createdAt: Date()
        )
        apiClient.mockResponse = userDto

        let updated = try await sut.updateProfile(
            displayName: "New Display Name",
            avatarUrl: "https://example.com/avatar.jpg",
            preferredLocale: "en",
            dateOfBirth: Date(),
            username: "new_username",
            timezone: "UTC"
        )
        XCTAssertEqual(updated.displayName, "New Display Name")
    }

    func testListSessions() async throws {
        let sessionDto = SessionDTO(
            id: UUID(),
            deviceInfo: "iPhone",
            deviceName: "Device",
            loginIp: "127.0.0.1",
            loginLocation: "Hanoi",
            createdAt: Date(),
            expiresAt: Date().addingTimeInterval(3600),
            current: true
        )
        apiClient.mockResponse = [sessionDto]

        let list = try await sut.listSessions()
        XCTAssertEqual(list.count, 1)
        XCTAssertEqual(list.first?.id, sessionDto.id)
    }

    func testRevokeSession() async throws {
        let id = UUID()
        try await sut.revokeSession(id: id)
        XCTAssertNotNil(apiClient.lastEndpoint)
    }

    func testRevokeAllSessions() async throws {
        try await sut.revokeAllSessions()
        XCTAssertNotNil(apiClient.lastEndpoint)
    }

    func testDeactivateAccount() async throws {
        try await sut.deactivateAccount(currentPassword: "pwd", otpCode: nil)
        XCTAssertNotNil(apiClient.lastEndpoint)
    }

    func testReactivateAccount() async throws {
        let authDto = makeAuthResponseDTO()
        apiClient.mockResponse = authDto

        let session = try await sut.reactivateAccount(reactivationToken: "token123")
        XCTAssertEqual(session.user.id, authDto.user.id)
    }

    func testDeleteAccount() async throws {
        try await sut.deleteAccount(currentPassword: "pwd", otpCode: nil)
        XCTAssertNotNil(apiClient.lastEndpoint)
    }

    func testGetConnectedAccounts() async throws {
        let dto = ConnectedAccountsDTO(
            google: .init(linked: true, detail: "g@example.com"),
            emailPassword: .init(linked: true, detail: "e@example.com"),
            phone: .init(linked: false, detail: nil)
        )
        apiClient.mockResponse = dto

        let result = try await sut.getConnectedAccounts()
        XCTAssertTrue(result.google.isLinked)
        XCTAssertEqual(result.google.detail, "g@example.com")
    }

    func testLinkGoogleAccount() async throws {
        try await sut.linkGoogleAccount(idToken: "tok")
        XCTAssertNotNil(apiClient.lastEndpoint)
    }

    func testUnlinkGoogleAccount() async throws {
        try await sut.unlinkGoogleAccount(currentPassword: "pwd", otpCode: nil)
        XCTAssertNotNil(apiClient.lastEndpoint)
    }

    func testRequestLinkPhoneOtp() async throws {
        try await sut.requestLinkPhoneOtp(phoneNumber: "+84901234567")
        XCTAssertNotNil(apiClient.lastEndpoint)
    }

    func testLinkPhoneAccount() async throws {
        try await sut.linkPhoneAccount(phoneNumber: "+84901234567", otpCode: "123456")
        XCTAssertNotNil(apiClient.lastEndpoint)
    }

    func testRequestLinkEmailOtp() async throws {
        try await sut.requestLinkEmailOtp(email: "a@b.com")
        XCTAssertNotNil(apiClient.lastEndpoint)

        try await sut.requestLinkEmailOtp(email: nil)
        XCTAssertNotNil(apiClient.lastEndpoint)
    }

    func testLinkEmailAccount() async throws {
        try await sut.linkEmailAccount(email: "a@b.com", otpCode: "123456", password: "pwd")
        XCTAssertNotNil(apiClient.lastEndpoint)
    }

    func testFetchMyPaymentProfile() async throws {
        let dto = PaymentProfileResponseDTO(
            userId: UUID(),
            qrImageUrl: "https://example.com/qr.png",
            accountName: "Name",
            accountNumber: "12345",
            bankName: "Bank",
            updatedAt: Date()
        )
        apiClient.mockResponse = dto

        let profile = try await sut.fetchMyPaymentProfile()
        XCTAssertEqual(profile.accountName, "Name")
    }

    func testUpsertMyPaymentProfile() async throws {
        let dto = PaymentProfileResponseDTO(
            userId: UUID(),
            qrImageUrl: "https://example.com/qr.png",
            accountName: "Name",
            accountNumber: "12345",
            bankName: "Bank",
            updatedAt: Date()
        )
        apiClient.mockResponse = dto

        let profile = try await sut.upsertMyPaymentProfile(
            qrImageUrl: "https://example.com/qr.png",
            accountName: "Name",
            accountNumber: "12345",
            bankName: "Bank"
        )
        XCTAssertEqual(profile.bankName, "Bank")
    }

    func testDeleteMyPaymentProfile() async throws {
        try await sut.deleteMyPaymentProfile()
        XCTAssertNotNil(apiClient.lastEndpoint)
    }
}
