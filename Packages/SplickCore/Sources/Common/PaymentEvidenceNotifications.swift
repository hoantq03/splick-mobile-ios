import Foundation

public extension Notification.Name {
    /// Posted when payment evidence submit/approve/reject changes expense split state.
    static let paymentEvidenceStatusDidChange = Notification.Name("splick.paymentEvidenceStatusDidChange")
}
