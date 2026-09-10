import Foundation

public extension Notification.Name {
    static let expensesDirectoryDidChange = ExpensesDirectoryChange.notification

    /// Legacy alias — same bus as `ExpensesDirectoryChange` (payment evidence + broader expense updates).
    static let paymentEvidenceStatusDidChange = ExpensesDirectoryChange.notification
}
