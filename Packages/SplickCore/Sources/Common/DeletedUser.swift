import Foundation

public enum DeletedUser {
    /// Legacy anonymized display name from older account deletions.
    public static let legacyDisplayName = "Deleted User"

    /// Suffix appended to the original display name when an account is deleted.
    public static let displayNameSuffix = " ( Deleted )"

    /// - Note: Prefer `isDeleted(displayName:)`. Kept for callers that still reference the legacy constant.
    public static let displayName = legacyDisplayName

    public static func isDeleted(displayName name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        return trimmed == legacyDisplayName || trimmed.hasSuffix(displayNameSuffix)
    }
}
