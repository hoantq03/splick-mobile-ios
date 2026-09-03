import Foundation

public enum AppNotificationSound: String, CaseIterable, Sendable {
    case `default` = "default"
    case note = "note"
    case chime = "chime"
    case pop = "pop"
    case silent = "silent"

    public var isSilent: Bool { self == .silent }

    public static func resolved(_ raw: String?) -> AppNotificationSound {
        AppNotificationSound(rawValue: raw ?? Self.default.rawValue) ?? .default
    }
}
