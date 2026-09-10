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
    /// Infers whether the user entered an email address or a phone number.
    var detectedLoginIdentifierKind: LoginIdentifierKind {
        let value = trimmed
        guard !value.isEmpty else { return .unknown }

        if value.contains("@") {
            return value.isValidEmail ? .email : .unknown
        }

        let normalizedPhone = value.normalizedE164Phone
        if normalizedPhone.isValidE164Phone {
            return .phone
        }

        return .unknown
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
