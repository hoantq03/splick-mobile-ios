import SwiftUI
import SplickDomain
import Localization

private struct OpenProfileActionKey: EnvironmentKey {
    static let defaultValue: (() -> Void)? = nil
}

private struct CurrentUserSummaryKey: EnvironmentKey {
    static let defaultValue: UserSummary? = nil
}

private struct OpenNotificationsActionKey: EnvironmentKey {
    static let defaultValue: (() -> Void)? = nil
}

private struct NotificationUnreadCountKey: EnvironmentKey {
    static let defaultValue: Int = 0
}

extension EnvironmentValues {
    public var openProfileSettings: (() -> Void)? {
        get { self[OpenProfileActionKey.self] }
        set { self[OpenProfileActionKey.self] = newValue }
    }

    public var currentUserSummary: UserSummary? {
        get { self[CurrentUserSummaryKey.self] }
        set { self[CurrentUserSummaryKey.self] = newValue }
    }

    public var openNotifications: (() -> Void)? {
        get { self[OpenNotificationsActionKey.self] }
        set { self[OpenNotificationsActionKey.self] = newValue }
    }

    public var notificationUnreadCount: Int {
        get { self[NotificationUnreadCountKey.self] }
        set { self[NotificationUnreadCountKey.self] = newValue }
    }
}

extension View {
    /// Avatar button top-leading + notification bell top-trailing.
    public func splickProfileToolbar(
        titleDisplayMode: NavigationBarItem.TitleDisplayMode = .large
    ) -> some View {
        modifier(SplickProfileToolbarModifier(titleDisplayMode: titleDisplayMode))
    }
}

private struct SplickProfileToolbarModifier: ViewModifier {
    let titleDisplayMode: NavigationBarItem.TitleDisplayMode

    @Environment(\.openProfileSettings) private var openProfileSettings
    @Environment(\.currentUserSummary) private var currentUserSummary
    @Environment(\.openNotifications) private var openNotifications
    @Environment(\.notificationUnreadCount) private var notificationUnreadCount
    @Environment(\.languageService) private var languageService

    func body(content: Content) -> some View {
        content
            .navigationBarTitleDisplayMode(titleDisplayMode)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if let openProfileSettings, let user = currentUserSummary {
                        Button(action: openProfileSettings) {
                            AvatarView(
                                imageURL: user.avatarURL,
                                name: user.displayName,
                                size: .small
                            )
                            .frame(width: 34, height: 34)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(
                            languageService?.text(.profileSettingsAccessibility)
                                ?? L10n.string(.profileSettingsAccessibility, locale: .default)
                        )
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    if let openNotifications {
                        Button(action: openNotifications) {
                            ZStack(alignment: .topTrailing) {
                                Image(systemName: notificationUnreadCount > 0 ? "bell.fill" : "bell")
                                    .font(.system(size: 20, weight: .medium))
                                    .frame(width: 34, height: 34)
                                if notificationUnreadCount > 0 {
                                    Circle()
                                        .fill(Color.red)
                                        .frame(width: 8, height: 8)
                                        .offset(x: 2, y: -2)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(
                            languageService?.text(.notificationBellAccessibility)
                                ?? L10n.string(.notificationBellAccessibility, locale: .default)
                        )
                    }
                }
            }
    }
}
