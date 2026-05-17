import Foundation

extension String {
    public var isValidEmail: Bool {
        let pattern = #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return range(of: pattern, options: .regularExpression) != nil
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
}
