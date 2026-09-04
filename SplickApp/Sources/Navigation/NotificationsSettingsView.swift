import SwiftUI
import Common
import Localization
import DesignSystem

struct NotificationsSettingsView: View {
    @EnvironmentObject private var languageService: LanguageService
    @EnvironmentObject private var pushNotificationCoordinator: PushNotificationCoordinator

    var body: some View {
        List {
            Section(languageService.text(.notificationSettingsStatusSection)) {
                HStack(spacing: 10) {
                    Text(languageService.text(.notificationSettingsPermissionLabel))
                    Spacer(minLength: 8)
                    Text(permissionStatusText)
                        .foregroundStyle(permissionStatusColor)
                        .lineLimit(1)
                    Rectangle()
                        .fill(SplickTheme.Colors.textSecondary.opacity(0.35))
                        .frame(width: 1, height: 14)
                    Button(languageService.text(.notificationSettingsOpenSystemSettingsAction)) {
                        pushNotificationCoordinator.openSystemSettings()
                    }
                    .buttonStyle(.borderless)
                }
            }

            if isNotificationsAllowed {
                Section(languageService.text(.notificationSettingsSoundSection)) {
                    ForEach(AppNotificationSound.allCases, id: \.self) { sound in
                        Button {
                            pushNotificationCoordinator.setNotificationSound(sound)
                            PushNotificationCoordinator.playNotificationSound(sound)
                        } label: {
                            HStack {
                                Text(soundTitle(sound))
                                    .foregroundStyle(SplickTheme.Colors.textPrimary)
                                Spacer()
                                if pushNotificationCoordinator.notificationSound == sound {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
                                }
                            }
                        }
                    }
                }
            }

            Section {
                Text(languageService.text(.notificationSettingsDescription))
                    .font(SplickTheme.Typography.caption)
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(languageService.text(.profileNotifications))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            pushNotificationCoordinator.refreshAuthorizationStatus()
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
        switch sound {
        case .default: return languageService.text(.messagingChatNotificationSoundDefault)
        case .note: return languageService.text(.messagingChatNotificationSoundNote)
        case .chime: return languageService.text(.messagingChatNotificationSoundChime)
        case .pop: return languageService.text(.messagingChatNotificationSoundPop)
        case .silent: return languageService.text(.messagingChatNotificationSoundSilent)
        }
    }
}
