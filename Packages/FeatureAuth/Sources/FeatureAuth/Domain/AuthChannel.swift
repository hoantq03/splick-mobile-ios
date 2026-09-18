import Foundation
import Common

public enum LoginIdentifierKind: Sendable, Equatable {
    case email
    case phone
    case unknown
}

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

public extension String {
    /// Complete email or E.164 phone — used to enable continue / lookup.
    var detectedLoginIdentifierKind: LoginIdentifierKind {
        switch classifiedLoginIdentifier {
        case .email(.valid):
            return .email
        case .phone(let parsed) where parsed.completeness == .complete:
            return .phone
        default:
            return .unknown
        }
    }

    /// Channel the user is typing toward, even before the value is valid.
    var loginIdentifierIntent: LoginIdentifierKind {
        switch classifiedLoginIdentifier {
        case .email:
            return .email
        case .phone:
            return .phone
        case .empty:
            return .unknown
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
