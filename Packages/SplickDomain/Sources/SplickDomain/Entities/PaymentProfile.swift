import Foundation

public struct PaymentProfile: Equatable, Sendable {
    public let userId: UUID
    public let qrImageURL: URL?
    public let accountName: String?
    public let accountNumber: String?
    public let bankName: String?
    public let updatedAt: Date

    public init(
        userId: UUID,
        qrImageURL: URL?,
        accountName: String?,
        accountNumber: String?,
        bankName: String?,
        updatedAt: Date
    ) {
        self.userId = userId
        self.qrImageURL = qrImageURL
        self.accountName = accountName
        self.accountNumber = accountNumber
        self.bankName = bankName
        self.updatedAt = updatedAt
    }

    public var hasQrImage: Bool { qrImageURL != nil }
    public var hasBankDetails: Bool {
        !(accountName?.isEmpty ?? true)
            && !(accountNumber?.isEmpty ?? true)
            && !(bankName?.isEmpty ?? true)
    }
}
