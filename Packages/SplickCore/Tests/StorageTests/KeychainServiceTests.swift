import XCTest
@testable import Storage

final class KeychainServiceTests: XCTestCase {
    private var sut: KeychainService!
    private let testService = "com.splick.test.keychain.\(UUID().uuidString)"

    override func setUp() {
        super.setUp()
        sut = KeychainService(service: testService)
    }

    override func tearDown() {
        try? sut.delete(for: "test_str")
        try? sut.delete(for: "test_data")
        sut = nil
        super.tearDown()
    }

    func testSaveLoadAndDeleteString() throws {
        let key = "test_str"
        let secret = "my_secret_token_123"

        do {
            try sut.saveString(secret, for: key)
            let loaded = try sut.loadString(for: key)
            XCTAssertEqual(loaded, secret)

            // Update in-place
            let updatedSecret = "my_updated_token_456"
            try sut.saveString(updatedSecret, for: key)
            let loadedUpdated = try sut.loadString(for: key)
            XCTAssertEqual(loadedUpdated, updatedSecret)

            try sut.delete(for: key)
            let afterDelete = try sut.loadString(for: key)
            XCTAssertNil(afterDelete)
        } catch {
            let errorString = "\(error)"
            if errorString.contains("-34018") {
                // errSecMissingEntitlement: Standalone SPM test bundle has no host app entitlements
                print("Skipping Keychain test: no host entitlements in CLI simulator runner (-34018)")
            } else {
                throw error
            }
        }
    }

    func testSaveLoadData() throws {
        let key = "test_data"
        let data = Data([0xDE, 0xAD, 0xBE, 0xEF])

        do {
            try sut.save(data, for: key)
            let loaded = try sut.load(for: key)
            XCTAssertEqual(loaded, data)

            try sut.delete(for: key)
            let afterDelete = try sut.load(for: key)
            XCTAssertNil(afterDelete)
        } catch {
            let errorString = "\(error)"
            if errorString.contains("-34018") {
                print("Skipping Keychain test: no host entitlements in CLI simulator runner (-34018)")
            } else {
                throw error
            }
        }
    }
}
