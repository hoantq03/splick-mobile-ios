import SwiftUI
import Common
import Localization
import DesignSystem

struct NotificationsSettingsView: View {
    @EnvironmentObject private var languageService: LanguageService
    @EnvironmentObject private var pushNotificationCoordinator: PushNotificationCoordinator

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SplickTheme.Spacing.lg) {
                statusSection

                if isNotificationsAllowed {
                    soundSection
                }

                Text(languageService.text(.notificationSettingsDescription))
                    .font(SplickTheme.Typography.caption)
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
                    .padding(.leading, SplickTheme.Spacing.sm)
            }
            .padding(.horizontal, SplickTheme.Spacing.xl)
            .padding(.vertical, SplickTheme.Spacing.lg)
        }
        .background(SplickTheme.Colors.background)
        .navigationTitle(languageService.text(.profileNotifications))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            pushNotificationCoordinator.refreshAuthorizationStatus()
        }
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.xs) {
            Text(languageService.text(.notificationSettingsStatusSection))
                .font(SplickTheme.Typography.headline)
                .foregroundStyle(SplickTheme.Colors.textPrimary)
                .padding(.leading, SplickTheme.Spacing.sm)

            VStack(spacing: 0) {
                HStack(spacing: SplickTheme.Spacing.sm) {
                    Text(languageService.text(.notificationSettingsPermissionLabel))
                        .font(SplickTheme.Typography.body)
                        .foregroundStyle(SplickTheme.Colors.textPrimary)
                    Spacer(minLength: SplickTheme.Spacing.xs)
                    Text(permissionStatusText)
                        .font(SplickTheme.Typography.caption)
                        .foregroundStyle(permissionStatusColor)
                        .lineLimit(1)
                    Rectangle()
                        .fill(SplickTheme.Colors.textSecondary.opacity(0.35))
                        .frame(width: 1, height: 14)
                    Button(languageService.text(.notificationSettingsOpenSystemSettingsAction)) {
                        pushNotificationCoordinator.openSystemSettings()
                    }
                    .font(SplickTheme.Typography.callout.weight(.semibold))
                    .buttonStyle(.plain)
                    .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
                }
                .padding(.horizontal, SplickTheme.Spacing.md)
                .padding(.vertical, SplickTheme.Spacing.sm + 2)
            }
            .splickSettingsCardChrome()
        }
    }

    private var soundSection: some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.xs) {
            Text(languageService.text(.notificationSettingsSoundSection))
                .font(SplickTheme.Typography.headline)
                .foregroundStyle(SplickTheme.Colors.textPrimary)
                .padding(.leading, SplickTheme.Spacing.sm)

            VStack(spacing: 0) {
                ForEach(Array(AppNotificationSound.allCases.enumerated()), id: \.element) { index, sound in
                    Button {
                        pushNotificationCoordinator.setNotificationSound(sound)
                        PushNotificationCoordinator.playNotificationSound(sound)
                    } label: {
                        HStack {
                            Text(soundTitle(sound))
                                .font(SplickTheme.Typography.body)
                                .foregroundStyle(SplickTheme.Colors.textPrimary)
                            Spacer()
                            if pushNotificationCoordinator.notificationSound == sound {
                                Image(systemName: "checkmark")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
                            }
                        }
                        .padding(.horizontal, SplickTheme.Spacing.md)
                        .padding(.vertical, SplickTheme.Spacing.sm + 2)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if index < AppNotificationSound.allCases.count - 1 {
                        Divider()
                            .padding(.leading, SplickTheme.Spacing.md)
                    }
                }
            }
            .splickSettingsCardChrome()
        }
    }

    private var isNotificationsAllowed: Bool {
        switch pushNotificationCoordinator.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        default:
            return false
        }
    }

    private var permissionStatusText: String {
        switch pushNotificationCoordinator.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return languageService.text(.notificationSettingsPermissionAllowed)
        case .denied:
            return languageService.text(.notificationSettingsPermissionDenied)
        case .notDetermined:
            return languageService.text(.notificationSettingsPermissionNotDetermined)
        @unknown default:
            return languageService.text(.notificationSettingsPermissionUnknown)
        }
    }

    private var permissionStatusColor: Color {
        switch pushNotificationCoordinator.authorizationStatus {
        case .denied:
            return SplickTheme.Colors.error
        default:
            return SplickTheme.Colors.textSecondary
        }
    }

    private func soundTitle(_ sound: AppNotificationSound) -> String {
        languageService.text(.messagingChatNotificationSoundDefault)
    }
}
