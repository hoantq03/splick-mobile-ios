import Foundation

public enum AuthSignInMethod: String, CaseIterable, Identifiable, Sendable {
    case email
    case phone

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .email: return "Email"
        case .phone: return "Phone"
        }
    }
}

public enum AuthRegistrationChannel: String, CaseIterable, Identifiable, Sendable {
    case email
    case phone

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .email: return "Email"
        case .phone: return "Phone"
        }
    }
}
