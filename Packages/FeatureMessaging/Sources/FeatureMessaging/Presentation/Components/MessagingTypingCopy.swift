import Foundation

enum MessagingTypingTiming {
    static let startRefresh: TimeInterval = 3
    static let idleStop: TimeInterval = 2
    static let displayTimeout: TimeInterval = 5
}

struct InboxTypingState: Equatable {
    enum Layout: Equatable {
        case direct
        case group(username: String, avatarURL: URL?)
    }

    let layout: Layout
    /// Localized typing label without trailing ellipsis (animated in the row UI).
    let typingBase: String
}

enum MessagingTypingCopy {
    /// Direct chats: typing label only. Groups: first typer's given name / username + optional avatar.
    static func inboxTypingState(
        isGroup: Bool,
        userIds: [UUID],
        typing: String,
        usernameForUserId: (UUID) -> String?
    ) -> InboxTypingState? {
        guard !userIds.isEmpty else { return nil }
        let base = stripTrailingEllipsis(typing)
        guard isGroup else {
            return InboxTypingState(layout: .direct, typingBase: base)
        }
        let firstId = userIds[0]
        let username = usernameForUserId(firstId)?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let username, !username.isEmpty else {
            return InboxTypingState(layout: .direct, typingBase: base)
        }
        return InboxTypingState(
            layout: .group(username: username, avatarURL: nil),
            typingBase: base
        )
    }

    /// Prefer username; otherwise use the given name (last token of a full name).
    static func givenName(from displayName: String?) -> String? {
        guard var trimmed = displayName?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        if !trimmed.contains(" ") { return trimmed }
        if trimmed.hasPrefix("@") { return String(trimmed.dropFirst()) }
        return trimmed.split(separator: " ").last.map(String.init)
    }

    /// Removes trailing ellipsis so animated dots can append in the UI.
    static func stripTrailingEllipsis(_ text: String) -> String {
        var trimmed = text.trimmingCharacters(in: .whitespaces)
        if trimmed.hasSuffix("...") {
            trimmed = String(trimmed.dropLast(3))
        } else if trimmed.hasSuffix("…") {
            trimmed = String(trimmed.dropLast())
        }
        return trimmed.trimmingCharacters(in: .whitespaces)
    }
}
