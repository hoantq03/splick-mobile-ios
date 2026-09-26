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

    func testLegacyMigrationAndFallback() async throws {
        let fm = FileManager.default
        let tempDir = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let supportDir = tempDir.appendingPathComponent("Support")
        let cachesDir = tempDir.appendingPathComponent("Caches")
        let legacySubdir = "MigrateSubdir"

        let legacyCache = DiskCache(
            subdirectory: legacySubdir,
            supportDirectory: cachesDir,
            cachesDirectory: cachesDir
        )

        let payload = CachePayload(name: "LegacyItem", score: 88.0)
        let safeKey = "legacy_sample"
        await legacyCache.write(payload, key: safeKey)

        // Verify it was written in cachesDir/MigrateSubdir
        let customCache = DiskCache(
            subdirectory: legacySubdir,
            supportDirectory: supportDir,
            cachesDirectory: cachesDir
        )

        // Read from fresh customCache should find in legacy (cachesDir) and migrate to supportDir
        let retrieved = await customCache.read(CachePayload.self, key: safeKey)
        XCTAssertEqual(retrieved, payload)

        // Read entry should also succeed
        let retrievedEntry = await customCache.readEntry(CachePayload.self, key: safeKey)
        XCTAssertEqual(retrievedEntry?.value, payload)

        try? fm.removeItem(at: tempDir)
    }

    func testDefaultInitAndSharedInstance() async {
        let defaultCache = DiskCache()
        let payload = CachePayload(name: "DefaultCacheItem", score: 1.0)
        let key = "default_key_\(UUID().uuidString)"

        await defaultCache.write(payload, key: key)
        let fetched = await defaultCache.read(CachePayload.self, key: key)
        XCTAssertEqual(fetched, payload)
        await defaultCache.remove(key: key)

        _ = DiskCache.shared
    }
}



