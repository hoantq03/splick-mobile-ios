import XCTest
@testable import Storage

final class DiskCacheTests: XCTestCase {
    private var sut: DiskCache!
    private let testSubdir = "TestDiskCache_\(UUID().uuidString)"

    override func setUp() async throws {
        try await super.setUp()
        sut = DiskCache(subdirectory: testSubdir)
    }

    struct CachePayload: Codable, Equatable {
        let name: String
        let score: Double
    }

    func testWriteReadAndRemove() async {
        let payload = CachePayload(name: "Splick", score: 99.5)
        let key = "sample_key"

        await sut.write(payload, key: key)

        let readValue = await sut.read(CachePayload.self, key: key)
        XCTAssertEqual(readValue, payload)

        let entry = await sut.readEntry(CachePayload.self, key: key)
        XCTAssertNotNil(entry)
        XCTAssertEqual(entry?.value, payload)

        await sut.remove(key: key)
        let deletedValue = await sut.read(CachePayload.self, key: key)
        XCTAssertNil(deletedValue)
    }

    func testReadNonExistent() async {
        let missing = await sut.read(CachePayload.self, key: "missing_key")
        XCTAssertNil(missing)
    }
}
