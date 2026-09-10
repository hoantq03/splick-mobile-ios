import Foundation

public enum PresenceDisplayPolicy {
    public static let maxLastSeenInterval: TimeInterval = 24 * 60 * 60

    public static func shouldShowOnlineIndicator(isOnline: Bool) -> Bool {
        isOnline
    }

    public static func lastSeenText(
        isOnline: Bool,
        lastSeenAt: Date?,
        appLocale: AppLocale,
        now: Date = .now
    ) -> String? {
        guard !isOnline else { return nil }
        guard let lastSeenAt else { return nil }
        let elapsed = now.timeIntervalSince(lastSeenAt)
        guard elapsed >= 0, elapsed <= maxLastSeenInterval else { return nil }
        return LocaleFormatting.presenceLastSeen(from: lastSeenAt, appLocale: appLocale, now: now)
    }

    public static func compactLastSeenLabel(
        isOnline: Bool,
        lastSeenAt: Date?,
        appLocale: AppLocale,
        now: Date = .now
    ) -> String? {
        lastSeenText(isOnline: isOnline, lastSeenAt: lastSeenAt, appLocale: appLocale, now: now)
    }
}
