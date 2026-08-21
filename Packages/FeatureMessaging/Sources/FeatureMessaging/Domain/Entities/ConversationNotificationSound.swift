import Foundation

public enum ConversationNotificationSound: String, CaseIterable, Sendable {
    case `default` = "default"
    case note = "note"
    case chime = "chime"
    case pop = "pop"
    case silent = "silent"

    public static func resolved(_ raw: String?) -> ConversationNotificationSound {
        ConversationNotificationSound(rawValue: raw ?? Self.default.rawValue) ?? .default
    }
}
