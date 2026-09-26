import Foundation

public enum LoginIdentifierClassification: Equatable, Sendable {
    public enum EmailStage: Equatable, Sendable {
        case incomplete
        case valid
        case invalid
    }

    case empty
    case email(EmailStage)
    case phone(ParsedPhoneNumber)

    public var phoneRegion: PhoneCallingRegion? {
        if case .phone(let parsed) = self {
            return parsed.region
        }
        return nil
    }
}

public enum LoginIdentifierClassifier {
    public static func classify(_ raw: String) -> LoginIdentifierClassification {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return .empty }

        if value.contains("@") {
            return value.isValidEmail ? .email(.valid) : .email(.invalid)
        }

        if let parsed = PhoneNumberParser.parse(value) {
            return .phone(parsed)
        }

        return .email(.incomplete)
    }
}

public extension String {
    var classifiedLoginIdentifier: LoginIdentifierClassification {
        LoginIdentifierClassifier.classify(self)
    }
}
