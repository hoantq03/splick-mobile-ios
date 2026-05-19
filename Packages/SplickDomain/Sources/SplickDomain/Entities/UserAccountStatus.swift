import Foundation

public enum UserAccountStatus: String, Codable, Sendable, Equatable {
    case active = "ACTIVE"
    case locked = "LOCKED"
    case unknown

    public static func from(apiValue: String?) -> UserAccountStatus {
        guard let apiValue else { return .unknown }
        return UserAccountStatus(rawValue: apiValue.uppercased()) ?? .unknown
    }

    public var allowsSignIn: Bool {
        self == .active
    }
}
