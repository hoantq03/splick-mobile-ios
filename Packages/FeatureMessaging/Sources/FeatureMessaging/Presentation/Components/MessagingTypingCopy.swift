import Foundation

enum MessagingTypingTiming {
    static let startRefresh: TimeInterval = 3
    static let idleStop: TimeInterval = 2
    static let displayTimeout: TimeInterval = 5
}

enum MessagingTypingCopy {
    /// Inbox / conversation-list preview: "{display name}: Composing..."
    /// For multiple typers, names are comma-separated before the colon.
    static func inboxPreview(
        userIds: [UUID],
        nameForUserId: (UUID) -> String?,
        typing: String,
        fallbackName: String? = nil
    ) -> String? {
        guard !userIds.isEmpty else { return nil }
        let names = userIds.compactMap(nameForUserId)
        let namePrefix: String? = if !names.isEmpty {
            Self.formatNamePrefix(names)
        } else if let fallbackName, !fallbackName.isEmpty {
            fallbackName
        } else {
            nil
        }
        guard let namePrefix else { return typing }
        return "\(namePrefix): \(typing)"
    }

    /// Removes trailing ellipsis from inbox typing copy so animated dots can append in the UI.
    static func stripTrailingEllipsis(_ text: String) -> String {
        var trimmed = text.trimmingCharacters(in: .whitespaces)
        if trimmed.hasSuffix("...") {
            trimmed = String(trimmed.dropLast(3))
        } else if trimmed.hasSuffix("…") {
            trimmed = String(trimmed.dropLast())
        }
        return trimmed.trimmingCharacters(in: .whitespaces)
    }

    private static func formatNamePrefix(_ names: [String]) -> String {
        switch names.count {
        case 1:
            return names[0]
        case 2:
            return "\(names[0]), \(names[1])"
        default:
            return "\(names[0]), \(names[1])"
        }
    }
}
