import Foundation

public struct UserSession: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let deviceInfo: String?
    public let createdAt: Date
    public let expiresAt: Date
    public let isCurrent: Bool

    public init(
        id: UUID,
        deviceInfo: String?,
        createdAt: Date,
        expiresAt: Date,
        isCurrent: Bool
    ) {
        self.id = id
        self.deviceInfo = deviceInfo
        self.createdAt = createdAt
        self.expiresAt = expiresAt
        self.isCurrent = isCurrent
    }
}
