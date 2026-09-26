import XCTest
@testable import SplickDomain

final class PostBillSplitLineTests: XCTestCase {
    func testPaymentStatusDefaultsFromIsPaid() {
        let user = UserSummary(id: UUID(), username: "debtor", displayName: "Debtor", avatarURL: nil)

        let unpaid = PostBillSplitLine(user: user, amount: 100_000, isPaid: false)
        XCTAssertEqual(unpaid.paymentStatus, .unpaid)

        let paid = PostBillSplitLine(user: user, amount: 100_000, isPaid: true)
        XCTAssertEqual(paid.paymentStatus, .paid)
    }

    func testExplicitPaymentStatusOverridesIsPaidDefault() {
        let user = UserSummary(id: UUID(), username: "debtor", displayName: "Debtor", avatarURL: nil)

        let pending = PostBillSplitLine(
            user: user,
            amount: 100_000,
            isPaid: false,
            paymentStatus: .pendingApproval
        )
        XCTAssertEqual(pending.paymentStatus, .pendingApproval)
    }
}
