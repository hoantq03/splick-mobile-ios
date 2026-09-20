import XCTest
@testable import SplickWidgetKit

final class WidgetCacheStoreTests: XCTestCase {
    func testWriteAndReadExpenseSnapshot() throws {
        let store = WidgetCacheStore()
        let testDate = Date(timeIntervalSince1970: 1_700_000_000)
        let snapshot = WidgetExpenseSummarySnapshot(
            netAmount: "+100,000₫",
            currency: "VND",
            totalOwing: "0₫",
            totalOwed: "100,000₫",
            owingPeopleCount: 0,
            owedPeopleCount: 1,
            topDebts: [
                WidgetDebtItem(
                    userId: UUID(),
                    displayName: "John Doe",
                    amount: "100,000₫",
                    currency: "VND",
                    isOwed: true
                )
            ],
            updatedAt: testDate
        )

        let filename = "test_expense_summary_\(UUID().uuidString).json"
        try store.write(snapshot, to: filename)
        let loaded = store.read(WidgetExpenseSummarySnapshot.self, from: filename)

        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.netAmount, snapshot.netAmount)
        XCTAssertEqual(loaded?.currency, snapshot.currency)
        XCTAssertEqual(loaded?.totalOwing, snapshot.totalOwing)
        XCTAssertEqual(loaded?.totalOwed, snapshot.totalOwed)
        XCTAssertEqual(loaded?.owingPeopleCount, snapshot.owingPeopleCount)
        XCTAssertEqual(loaded?.owedPeopleCount, snapshot.owedPeopleCount)
        XCTAssertEqual(loaded?.topDebts, snapshot.topDebts)
        XCTAssertEqual(loaded?.updatedAt, testDate)
        XCTAssertEqual(loaded, snapshot)

        if let url = store.fileURL(for: filename) {
            try? FileManager.default.removeItem(at: url)
        }
    }

    func testReadNonExistentFileReturnsNil() {
        let store = WidgetCacheStore()
        let loaded = store.read(WidgetExpenseSummarySnapshot.self, from: "non_existent_\(UUID().uuidString).json")
        XCTAssertNil(loaded)
    }

    func testReadCorruptedFileReturnsNil() throws {
        let store = WidgetCacheStore()
        let filename = "corrupted_\(UUID().uuidString).json"
        guard let url = store.fileURL(for: filename) else { return }
        try? "not a valid json".data(using: .utf8)?.write(to: url)

        let loaded = store.read(WidgetExpenseSummarySnapshot.self, from: filename)
        XCTAssertNil(loaded)

        try? FileManager.default.removeItem(at: url)
    }

    func testWidgetCacheErrorCases() {
        let errors: [WidgetCacheError] = [
            .appGroupUnavailable,
            .encodingFailed,
            .decodingFailed
        ]
        XCTAssertEqual(errors.count, 3)
    }

    func testSharedInstance() {
        XCTAssertNotNil(WidgetCacheStore.shared)
    }
}
