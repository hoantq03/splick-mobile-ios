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
                HStack {
                    Text(languageService.text(.notificationSettingsPermissionLabel))
                    Spacer()
                    Text(permissionStatusText)
                        .foregroundStyle(SplickTheme.Colors.textSecondary)
                }

                HStack {
                    Text(languageService.text(.notificationSettingsDeviceRegistrationLabel))
                    Spacer()
                    Text(deviceRegistrationStatusText)
                        .foregroundStyle(SplickTheme.Colors.textSecondary)
                }
            }

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

            Section(languageService.text(.notificationSettingsActionSection)) {
                Button(languageService.text(.notificationSettingsEnableAction)) {
                    pushNotificationCoordinator.requestAuthorizationIfNeeded()
                }

                Button(languageService.text(.notificationSettingsOpenSystemSettingsAction)) {
                    pushNotificationCoordinator.openSystemSettings()
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

    private var deviceRegistrationStatusText: String {
        if pushNotificationCoordinator.isRegisteredOnServer {
            return languageService.text(.notificationSettingsRegistrationSynced)
        }
        if pushNotificationCoordinator.storedDeviceToken != nil {
            return languageService.text(.notificationSettingsRegistrationPending)
        }
        return languageService.text(.notificationSettingsRegistrationUnavailable)
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
