import Foundation

enum OAuthDisplayName {
    static let genericPlaceholder = "Splick User"
    static let maxLength = 100

    static func resolved(current: String, email: String) -> String {
        let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed.caseInsensitiveCompare(genericPlaceholder) == .orderedSame {
            return emailLocalPart(email)
        }
        return String(trimmed.prefix(maxLength))
    }

    static func emailLocalPart(_ email: String) -> String {
        let local = email.split(separator: "@", maxSplits: 1, omittingEmptySubsequences: true)
            .first
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) } ?? ""
        if local.isEmpty {
            return "user"
        }
        return String(local.prefix(maxLength))
    }
}
