import Foundation

public enum AppNotificationSound: String, CaseIterable, Sendable {
    case `default` = "default"

    public var isSilent: Bool { false }

    public var bundledFileName: String { "splick_notif_default.wav" }

    public static func resolved(_ raw: String?) -> AppNotificationSound {
        _ = raw
        return .default
    }

    public static func persistToAppGroup(_ sound: AppNotificationSound) {
        let suite = UserDefaults(suiteName: AppConstants.UserDefaults.appGroup)
        suite?.set(sound.rawValue, forKey: AppConstants.UserDefaults.pushNotificationSound)
        suite?.synchronize()
        guard let directory = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: AppConstants.UserDefaults.appGroup
        ) else {
            return
        }
        try? sound.rawValue.write(
            to: directory.appendingPathComponent("pushNotificationSound.txt"),
            atomically: true,
            encoding: .utf8
        )
    }

    public static func loadRawFromAppGroup() -> String? {
        if let directory = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: AppConstants.UserDefaults.appGroup
        ) {
            let fileURL = directory.appendingPathComponent("pushNotificationSound.txt")
            if let raw = try? String(contentsOf: fileURL, encoding: .utf8) {
                return resolved(raw).rawValue
            }
        }
        let suite = UserDefaults(suiteName: AppConstants.UserDefaults.appGroup)
        if let raw = suite?.string(forKey: AppConstants.UserDefaults.pushNotificationSound),
           !raw.isEmpty {
            return resolved(raw).rawValue
        }
        if let data = suite?.data(forKey: AppConstants.UserDefaults.pushNotificationSound),
           let decoded = try? JSONDecoder().decode(String.self, from: data) {
            return resolved(decoded).rawValue
        }
        return nil
    }

    public static func loadFromAppGroup() -> AppNotificationSound {
        resolved(loadRawFromAppGroup())
    }
}
