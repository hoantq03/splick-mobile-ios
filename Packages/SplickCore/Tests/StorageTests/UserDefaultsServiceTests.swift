import XCTest
@testable import Storage
@testable import Common

final class UserDefaultsServiceTests: XCTestCase {
    private var sut: UserDefaultsService!
    private var testDefaults: UserDefaults!
    private let suiteName = "com.splick.test.userdefaults"

    override func setUp() {
        super.setUp()
        testDefaults = UserDefaults(suiteName: suiteName)
        testDefaults.removePersistentDomain(forName: suiteName)
        sut = UserDefaultsService(defaults: testDefaults)
    }

    override func tearDown() {
        testDefaults.removePersistentDomain(forName: suiteName)
        testDefaults = nil
        sut = nil
        super.tearDown()
    }

    struct MockItem: Codable, Equatable {
        let id: String
        let count: Int
    }

    func testCodableStorage() {
        let item = MockItem(id: "item_1", count: 42)
        sut.set(item, for: "test_key")

        let retrieved: MockItem? = sut.get(for: "test_key")
        XCTAssertEqual(retrieved, item)

        sut.remove(for: "test_key")
        let removed: MockItem? = sut.get(for: "test_key")
        XCTAssertNil(removed)
    }

    func testBoolStorage() {
        XCTAssertFalse(sut.getBool(for: "non_existent"))

        sut.setBool(true, for: "bool_key")
        XCTAssertTrue(sut.getBool(for: "bool_key"))

        sut.setBool(false, for: "bool_key")
        XCTAssertFalse(sut.getBool(for: "bool_key"))
    }
}
