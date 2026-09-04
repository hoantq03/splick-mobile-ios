import Foundation

public struct UserSession: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let deviceInfo: String?
    public let deviceName: String?
    public let loginIp: String?
    public let loginLocation: String?
    public let createdAt: Date
    public let expiresAt: Date
    public let isCurrent: Bool

    public var displayDevice: String {
        if let deviceName, !deviceName.isEmpty {
            return deviceName
        }
        return deviceInfo ?? "Unknown device"
    }

    public init(
        id: UUID,
        deviceInfo: String?,
        deviceName: String? = nil,
        loginIp: String? = nil,
        loginLocation: String? = nil,
        createdAt: Date,
        expiresAt: Date,
        isCurrent: Bool
    ) {
        self.id = id
        self.deviceInfo = deviceInfo
        self.deviceName = deviceName
        self.loginIp = loginIp
        self.loginLocation = loginLocation
        self.createdAt = createdAt
        self.expiresAt = expiresAt
        self.isCurrent = isCurrent
    }
}
