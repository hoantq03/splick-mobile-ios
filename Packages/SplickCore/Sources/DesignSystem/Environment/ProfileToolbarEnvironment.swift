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
    static let defaultValue: ((CGRect) -> Void)? = nil
}

private struct NotificationUnreadCountKey: EnvironmentKey {
    static let defaultValue: Int = 0
}

private struct NotificationsPresentedKey: EnvironmentKey {
    static let defaultValue: Bool = false
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

    public var openNotifications: ((CGRect) -> Void)? {
        get { self[OpenNotificationsActionKey.self] }
        set { self[OpenNotificationsActionKey.self] = newValue }
    }

    public var notificationUnreadCount: Int {
        get { self[NotificationUnreadCountKey.self] }
        set { self[NotificationUnreadCountKey.self] = newValue }
    }

    public var notificationsPresented: Bool {
        get { self[NotificationsPresentedKey.self] }
        set { self[NotificationsPresentedKey.self] = newValue }
    }
}

extension View {
    /// Avatar button top-leading + notification bell top-trailing.
    public func splickProfileToolbar(
        titleDisplayMode: NavigationBarItem.TitleDisplayMode = .large,
        isSuppressed: Bool = false,
        showsBell: Bool = true
    ) -> some View {
        modifier(
            SplickProfileToolbarModifier(
                titleDisplayMode: titleDisplayMode,
                isSuppressed: isSuppressed,
                showsBell: showsBell
            )
        )
    }
}

private struct SplickProfileToolbarModifier: ViewModifier {
    let titleDisplayMode: NavigationBarItem.TitleDisplayMode
    var isSuppressed: Bool = false
    var showsBell: Bool = true

    @Environment(\.openProfileSettings) private var openProfileSettings
    @Environment(\.currentUserSummary) private var currentUserSummary
    @Environment(\.openNotifications) private var openNotifications
    @Environment(\.notificationUnreadCount) private var notificationUnreadCount
    @Environment(\.notificationsPresented) private var notificationsPresented
    @Environment(\.languageService) private var languageService

    func body(content: Content) -> some View {
        content
            .navigationBarTitleDisplayMode(titleDisplayMode)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !isSuppressed, let openProfileSettings, let user = currentUserSummary {
                        Button(action: openProfileSettings) {
                            AvatarView(
                                imageURL: user.avatarURL,
                                name: user.displayName,
                                size: .small
                            )
                            .frame(width: 38, height: 38)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(
                            languageService?.text(.profileSettingsAccessibility)
                                ?? L10n.string(.profileSettingsAccessibility, locale: .default)
                        )
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    if showsBell, !notificationsPresented, let openNotifications {
                        NotificationBellButton(
                            unreadCount: notificationUnreadCount,
                            isPresented: false,
                            accessibilityLabel: languageService?.text(.notificationBellAccessibility)
                                ?? L10n.string(.notificationBellAccessibility, locale: .default),
                            onTap: openNotifications
                        )
                    }
                }
            }
    }
}
