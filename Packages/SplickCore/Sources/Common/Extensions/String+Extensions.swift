import Foundation

extension String {
    public var isValidEmail: Bool {
        let pattern = #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return range(of: pattern, options: .regularExpression) != nil
    }

    public var isValidUsername: Bool {
        let pattern = #"^[a-zA-Z0-9_.]+$"#
        return range(of: pattern, options: .regularExpression) != nil
    }

    /// E.164 — aligned with backend RegisterRequestValidator.
    public var isValidE164Phone: Bool {
        let pattern = #"^\+?[1-9]\d{7,14}$"#
        return range(of: pattern, options: .regularExpression) != nil
    }

    /// Normalizes local input to E.164 when possible (e.g. 0901234567 → +84901234567).
    public var normalizedE164Phone: String {
        let trimmed = trimmed
        if trimmed.hasPrefix("+") { return trimmed }
        if trimmed.hasPrefix("0"), trimmed.count >= 10 {
            return "+84" + String(trimmed.dropFirst())
        }
        return trimmed
    }

    public var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public var isBlank: Bool {
        trimmed.isEmpty
    }

    public func truncated(to limit: Int, trailing: String = "...") -> String {
        if count <= limit { return self }
        return String(prefix(limit)) + trailing
    }

    /// Given name for compact UI — drops Vietnamese family + middle names (keeps last segment when 3+ parts).
    public var givenNameOnly: String {
        let parts = trimmed.split(whereSeparator: \.isWhitespace).map(String.init)
        switch parts.count {
        case 0:
            return trimmed
        case 1:
            return parts[0]
        case 2:
            return parts[0]
        default:
            return parts[parts.count - 1]
        }
    }
}
