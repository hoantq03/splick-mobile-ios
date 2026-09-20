import XCTest
import SplickDomain
import Common
import Storage
import Localization
import DesignSystem
@testable import FeatureAuth

@MainActor
private final class MockGooglePresenter: GoogleSignInPresenting {
    var isAvailable: Bool = true
    var tokenToReturn: String = "mock_google_token"
    var errorToThrow: Error?

    func fetchIdToken() async throws -> String {
        if let error = errorToThrow { throw error }
        return tokenToReturn
    }
}

@MainActor
final class ConnectedAccountsViewModelTests: XCTestCase {

    private var mockRepo: MockAuthRepository!
    private var languageService: LanguageService!
    private var googlePresenter: MockGooglePresenter!

    override func setUp() {
        super.setUp()
        mockRepo = MockAuthRepository()
        let mockDefaults = MockUserDefaultsService()
        languageService = LanguageService(userDefaults: mockDefaults)
        googlePresenter = MockGooglePresenter()
    }

    override func tearDown() {
        mockRepo = nil
        languageService = nil
        googlePresenter = nil
        super.tearDown()
    }

    private func makeViewModel(email: String = "test@example.com") -> ConnectedAccountsViewModel {
        ConnectedAccountsViewModel(
            accountEmail: email,
            getConnectedAccountsUseCase: GetConnectedAccountsUseCase(repository: mockRepo),
            linkGoogleAccountUseCase: LinkGoogleAccountUseCase(repository: mockRepo),
            unlinkGoogleAccountUseCase: UnlinkGoogleAccountUseCase(repository: mockRepo),
            linkPhoneAccountUseCase: LinkPhoneAccountUseCase(repository: mockRepo),
            linkEmailAccountUseCase: LinkEmailAccountUseCase(repository: mockRepo),
            requestEmailOtpUseCase: RequestEmailOtpUseCase(repository: mockRepo),
            googleSignInPresenter: googlePresenter,
            languageService: languageService
        )
    }

    func testLoad_success() async {
        let accounts = ConnectedAccounts(
            google: .init(isLinked: true, detail: "g@example.com"),
            emailPassword: .init(isLinked: true, detail: "test@example.com"),
            phone: .init(isLinked: false, detail: nil)
        )
        mockRepo.connectedAccountsResult = .success(accounts)

        let vm = makeViewModel()
        await vm.load()

        XCTAssertNotNil(vm.accounts)
        XCTAssertTrue(vm.accounts?.google.isLinked == true)
        XCTAssertNil(vm.listErrorMessage)
    }

    func testLoad_failure() async {
        mockRepo.connectedAccountsResult = .failure(NetworkError.serverError(statusCode: 500))

        let vm = makeViewModel()
        await vm.load()

        XCTAssertNil(vm.accounts)
        XCTAssertNotNil(vm.listErrorMessage)
    }

    func testGoogleLink_success() async {
        mockRepo.connectedAccountsResult = .success(ConnectedAccounts(
            google: .init(isLinked: true, detail: nil),
            emailPassword: .init(isLinked: true, detail: nil),
            phone: .init(isLinked: false, detail: nil)
        ))

        let vm = makeViewModel()
        await vm.linkGoogle()

        XCTAssertNotNil(vm.listInfoMessage)
        XCTAssertNil(vm.listErrorMessage)
    }

    func testGoogleLink_presenterUnavailable() async {
        googlePresenter.isAvailable = false
        let vm = makeViewModel()
        await vm.linkGoogle()

        XCTAssertNotNil(vm.listErrorMessage)
    }

    func testGoogleLink_error() async {
        googlePresenter.errorToThrow = AuthError.invalidCredentials
        let vm = makeViewModel()
        await vm.linkGoogle()

        XCTAssertNotNil(vm.listErrorMessage)
    }

    func testPhoneSheet_flows() async {
        let vm = makeViewModel()
        vm.preparePhoneSheet()

        // Empty phone error
        await vm.requestPhoneConnectCode()
        XCTAssertNotNil(vm.phoneSheetError)

        // Valid phone
        vm.connectPhoneNumber = "+84901234567"
        await vm.requestPhoneConnectCode()
        XCTAssertTrue(vm.hasSentPhoneCode)
        XCTAssertNotNil(vm.phoneSheetInfo)

        // Link phone with invalid otp length
        vm.connectPhoneOtp = "123"
        let shortOtpResult = await vm.linkPhone()
        XCTAssertFalse(shortOtpResult)
        XCTAssertNotNil(vm.phoneSheetOtpError)

        // Link phone success
        vm.connectPhoneOtp = "123456"
        let successResult = await vm.linkPhone()
        XCTAssertTrue(successResult)
        XCTAssertNotNil(vm.listInfoMessage)

        // Phone sheet reset
        vm.preparePhoneSheet()
        XCTAssertEqual(vm.connectPhoneNumber, "")
    }

    func testEmailSheet_flows() async {
        let vm = makeViewModel(email: "123456789@phone.splick.local")
        XCTAssertTrue(vm.isPhoneOnlyAccount)
        vm.prepareEmailSheet()

        // Empty email
        await vm.requestEmailConnectCode()
        XCTAssertNotNil(vm.emailSheetError)

        // Valid email
        vm.connectEmail = "real@example.com"
        await vm.requestEmailConnectCode()
        XCTAssertTrue(vm.hasSentEmailCode)

        // Password mismatch
        vm.connectEmailPassword = "StrongPassword123!"
        vm.connectEmailConfirm = "Mismatch123!"
        vm.validateEmailPasswordFields()
        XCTAssertNotNil(vm.emailSheetConfirmPasswordError)

        let mismatchLink = await vm.linkEmail()
        XCTAssertFalse(mismatchLink)

        // Weak password
        vm.connectEmailPassword = "weak"
        vm.connectEmailConfirm = "weak"
        let weakLink = await vm.linkEmail()
        XCTAssertFalse(weakLink)

        // Strong password with short OTP
        vm.connectEmailPassword = "StrongPassword123!"
        vm.connectEmailConfirm = "StrongPassword123!"
        vm.connectEmailOtp = "12"
        let shortOtpLink = await vm.linkEmail()
        XCTAssertFalse(shortOtpLink)
        XCTAssertNotNil(vm.emailSheetOtpError)

        // Success link
        vm.connectEmailOtp = "123456"
        let success = await vm.linkEmail()
        XCTAssertTrue(success)
        XCTAssertNotNil(vm.listInfoMessage)
    }

    func testUnlinkGoogle_flows() async {
        let vm = makeViewModel()
        vm.prepareUnlinkSheet()

        // Password method with empty password
        vm.unlinkMethod = .password
        vm.unlinkPassword = ""
        let emptyPwdResult = await vm.unlinkGoogle()
        XCTAssertFalse(emptyPwdResult)
        XCTAssertNotNil(vm.unlinkSheetPasswordError)

        // Password method valid
        vm.unlinkPassword = "my_secret_password"
        let pwdSuccess = await vm.unlinkGoogle()
        XCTAssertTrue(pwdSuccess)
        XCTAssertNotNil(vm.listInfoMessage)

        // Email OTP method
        vm.unlinkMethod = .emailCode
        vm.unlinkOtpCode = "12"
        let shortOtpResult = await vm.unlinkGoogle()
        XCTAssertFalse(shortOtpResult)
        XCTAssertNotNil(vm.unlinkSheetOtpError)

        // Request unlink email code
        await vm.requestUnlinkCode()
        XCTAssertTrue(vm.hasSentUnlinkCode)

        vm.unlinkOtpCode = "123456"
        let otpSuccess = await vm.unlinkGoogle()
        XCTAssertTrue(otpSuccess)
    }
}
