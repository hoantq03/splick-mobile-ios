import Foundation

/// VND bill/expense amounts must be at least 1,000 (typical VN payment floor).
public enum VndAmountRules {
    public static let minimumAmount: Decimal = 1_000

    public static func isAtLeastMinimum(_ amount: Decimal) -> Bool {
        amount >= minimumAmount
    }
}
