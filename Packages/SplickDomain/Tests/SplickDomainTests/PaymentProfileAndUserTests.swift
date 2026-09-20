import XCTest
@testable import SplickDomain

final class PaymentProfileAndUserTests: XCTestCase {
    func testUserAndUserSummary() {
        let userId = UUID()
        let user = User(
            id: userId,
            email: "test@splick.app",
            username: "hoantq",
            displayName: "Hoan Thai",
            status: .active
        )
        
        XCTAssertEqual(user.preferredLocale, "vi")
        XCTAssertEqual(user.timezone, "Asia/Ho_Chi_Minh")
        
        let summary1 = UserSummary(
            id: userId,
            username: "hoantq",
            displayName: "Hoan Thai",
            subtitle: "Thai Quoc Hoan"
        )
        XCTAssertEqual(summary1.preferredName, "Hoan Thai")
        XCTAssertEqual(summary1.dualDisplayName, "Thai Quoc Hoan (Hoan Thai)")
        
        // When subtitle equals displayName
        let summary2 = UserSummary(
            id: userId,
            username: "hoantq",
            displayName: "Thai Quoc Hoan",
            subtitle: "thai quoc hoan"
        )
        XCTAssertEqual(summary2.dualDisplayName, "Thai Quoc Hoan")
        
        // When subtitle is nil
        let summary3 = UserSummary(
            id: userId,
            username: "hoantq",
            displayName: "Hoan"
        )
        XCTAssertEqual(summary3.dualDisplayName, "Hoan")
    }

    func testPaymentProfileContentCheck() {
        let userId = UUID()
        let now = Date()
        
        // Empty profile
        let empty = PaymentProfile(
            userId: userId,
            qrImageURL: nil,
            accountName: nil,
            accountNumber: nil,
            bankName: nil,
            updatedAt: now
        )
        XCTAssertFalse(empty.hasQrImage)
        XCTAssertFalse(empty.hasBankDetails)
        XCTAssertFalse(empty.hasPartialBankDetails)
        XCTAssertFalse(empty.hasAnyContent)
        XCTAssertFalse(empty.hasDisplayableBankFields)
        
        // Full bank details
        let full = PaymentProfile(
            userId: userId,
            qrImageURL: URL(string: "https://splick.app/qr.png"),
            accountName: "THAI QUOC HOAN",
            accountNumber: "123456789",
            bankName: "Techcombank",
            updatedAt: now
        )
        XCTAssertTrue(full.hasQrImage)
        XCTAssertTrue(full.hasBankDetails)
        XCTAssertFalse(full.hasPartialBankDetails)
        XCTAssertTrue(full.hasAnyContent)
        XCTAssertTrue(full.hasDisplayableBankFields)
        
        // Partial bank details (e.g. missing bank name)
        let partial = PaymentProfile(
            userId: userId,
            qrImageURL: nil,
            accountName: "THAI QUOC HOAN",
            accountNumber: "123456789",
            bankName: nil,
            updatedAt: now
        )
        XCTAssertFalse(partial.hasQrImage)
        XCTAssertFalse(partial.hasBankDetails)
        XCTAssertTrue(partial.hasPartialBankDetails)
        XCTAssertTrue(partial.hasAnyContent)
        XCTAssertTrue(partial.hasDisplayableBankFields)
    }

    func testPostAudienceModes() {
        let id1 = UUID()
        let id2 = UUID()
        
        let friends = PostAudience.friends
        XCTAssertEqual(friends.mode, .friends)
        XCTAssertFalse(friends.requiresSelection)
        
        let emptyGroups = PostAudience(mode: .groups)
        XCTAssertTrue(emptyGroups.requiresSelection)
        let groups = PostAudience(mode: .groups, allowedGroupIds: [id1])
        XCTAssertFalse(groups.requiresSelection)
        XCTAssertEqual(groups.allowedGroupIds, [id1])
        
        let emptySpecific = PostAudience(mode: .specificUsers)
        XCTAssertTrue(emptySpecific.requiresSelection)
        let specific = PostAudience(mode: .specificUsers, allowedUserIds: [id1, id2])
        XCTAssertFalse(specific.requiresSelection)
        
        let emptyExcept = PostAudience(mode: .friendsExcept)
        XCTAssertTrue(emptyExcept.requiresSelection)
        let friendsExcept = PostAudience(mode: .friendsExcept, excludedUserIds: [id2])
        XCTAssertFalse(friendsExcept.requiresSelection)
    }
}
