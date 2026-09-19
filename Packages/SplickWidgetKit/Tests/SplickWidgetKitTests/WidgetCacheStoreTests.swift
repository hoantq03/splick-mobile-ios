import XCTest
@testable import SplickWidgetKit

final class WidgetCacheStoreTests: XCTestCase {
    func testWriteAndReadExpenseSnapshot() throws {
        let store = WidgetCacheStore()
        let snapshot = WidgetExpenseSummarySnapshot(
            netAmount: "+100,000₫",
            currency: "VND",
            totalOwing: "0₫",
            totalOwed: "100,000₫",
            owingPeopleCount: 0,
            owedPeopleCount: 1,
            topDebts: []
        )

        try store.write(snapshot, to: "test_expense_summary.json")
        let loaded = store.read(WidgetExpenseSummarySnapshot.self, from: "test_expense_summary.json")

        XCTAssertEqual(loaded, snapshot)

        if let url = store.fileURL(for: "test_expense_summary.json") {
            try? FileManager.default.removeItem(at: url)
        }
    }
}
