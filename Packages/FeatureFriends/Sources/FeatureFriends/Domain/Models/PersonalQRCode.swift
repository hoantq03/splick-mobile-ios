import Foundation

public struct PersonalQRCode: Sendable, Equatable {
    public let payload: String
    public let version: Int
    public let issuedAt: Date

    public init(payload: String, version: Int, issuedAt: Date) {
        self.payload = payload
        self.version = version
        self.issuedAt = issuedAt
    }
}
