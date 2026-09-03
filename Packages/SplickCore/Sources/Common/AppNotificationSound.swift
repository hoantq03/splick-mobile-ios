import Foundation

public enum AppNotificationSound: String, CaseIterable, Sendable {
    case `default` = "default"
    case note = "note"
    case chime = "chime"
    case pop = "pop"
    case silent = "silent"

    public var isSilent: Bool { self == .silent }

    public var bundledFileName: String {
        switch self {
        case .default: return "splick_notif_default.wav"
        case .note: return "splick_notif_note.wav"
        case .chime: return "splick_notif_chime.wav"
        case .pop: return "splick_notif_pop.wav"
        case .silent: return "splick_notif_silent.wav"
        }
    }

    public static func resolved(_ raw: String?) -> AppNotificationSound {
        AppNotificationSound(rawValue: raw ?? Self.`default`.rawValue) ?? .default
    }
}
