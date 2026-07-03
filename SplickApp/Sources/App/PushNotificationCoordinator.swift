import Foundation
import UIKit
import UserNotifications
import Common
import Storage
import SplickDomain
import FeatureNotification

@MainActor
final class PushNotificationCoordinator: ObservableObject {
    static let shared = PushNotificationCoordinator()

    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published private(set) var isRegisteredOnServer = false
    @Published var pendingDestination: NotificationDestination?

    private var deviceTokenService: DeviceTokenServiceProtocol?
    private var userDefaultsService: UserDefaultsServiceProtocol?

    private init() {}

    func configure(
        deviceTokenService: DeviceTokenServiceProtocol,
        userDefaultsService: UserDefaultsServiceProtocol
    ) {
        self.deviceTokenService = deviceTokenService
        self.userDefaultsService = userDefaultsService
    }

    func requestAuthorizationIfNeeded() {
        Task {
            let center = UNUserNotificationCenter.current()
            let settings = await center.notificationSettings()
            authorizationStatus = settings.authorizationStatus

            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                setPushEnabledLocally(true)
                UIApplication.shared.registerForRemoteNotifications()
            case .denied:
                setPushEnabledLocally(false)
            case .notDetermined:
                do {
                    let granted = try await center.requestAuthorization(
                        options: [.alert, .badge, .sound]
                    )
                    let refreshedSettings = await center.notificationSettings()
                    authorizationStatus = refreshedSettings.authorizationStatus
                    setPushEnabledLocally(granted)
                    userDefaultsService?.setBool(
                        true,
                        for: AppConstants.UserDefaults.pushNotificationPermissionRequested
                    )
                    if granted {
                        UIApplication.shared.registerForRemoteNotifications()
                    }
                } catch {
                    Log.error(error, category: .notification)
                }
            @unknown default:
                setPushEnabledLocally(false)
            }
        }
    }

    func refreshAuthorizationStatus() {
        Task {
            authorizationStatus = await UNUserNotificationCenter.current()
                .notificationSettings()
                .authorizationStatus
            setPushEnabledLocally(isSystemAuthorizationGranted)
        }
    }

    func handleDeviceToken(_ deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        userDefaultsService?.set(token, for: AppConstants.UserDefaults.pushNotificationDeviceToken)
        Log.info("APNs device token received", category: .notification)

        Task {
            await syncStoredDeviceTokenIfPossible()
        }
    }

    func syncStoredDeviceTokenIfPossible() async {
        guard isSystemAuthorizationGranted else { return }
        guard let deviceTokenService, let token = storedDeviceToken else { return }

        do {
            try await deviceTokenService.register(
                token: token,
                bundleId: Bundle.main.bundleIdentifier ?? "com.splick.app",
                environment: currentApnsEnvironment
            )
            isRegisteredOnServer = true
            setPushEnabledLocally(true)
            Log.info("APNs token synced to backend", category: .notification)
        } catch {
            isRegisteredOnServer = false
            Log.error(error, category: .notification)
        }
    }

    func unregisterCurrentDeviceToken() async {
        guard let deviceTokenService, let token = storedDeviceToken else { return }

        do {
            try await deviceTokenService.unregister(token: token)
            isRegisteredOnServer = false
            Log.info("APNs token unregistered from backend", category: .notification)
        } catch {
            Log.error(error, category: .notification)
        }
    }

    func handleRemoteNotificationPayload(userInfo: [AnyHashable: Any]) {
        if let badge = ((userInfo["aps"] as? [String: Any])?["badge"] as? Int) {
            UIApplication.shared.applicationIconBadgeNumber = max(0, badge)
        }

        if let destination = parseDestination(from: userInfo) {
            pendingDestination = destination
        }
    }

    func clearPendingDestination() {
        pendingDestination = nil
    }

    func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    var isSystemAuthorizationGranted: Bool {
        switch authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined, .denied:
            return false
        @unknown default:
            return false
        }
    }

    var storedDeviceToken: String? {
        userDefaultsService?.get(for: AppConstants.UserDefaults.pushNotificationDeviceToken)
    }

    private var currentApnsEnvironment: String {
        #if DEBUG
        return "sandbox"
        #else
        return "production"
        #endif
    }

    private func setPushEnabledLocally(_ value: Bool) {
        userDefaultsService?.setBool(value, for: AppConstants.UserDefaults.pushNotificationsEnabled)
    }

    private func parseDestination(from userInfo: [AnyHashable: Any]) -> NotificationDestination? {
        if let destinationPayload = userInfo["destination"] as? [AnyHashable: Any] {
            let screen = (destinationPayload["screen"] as? String) ?? NotificationScreen.inbox.rawValue
            let postId = parseUuid(
                destinationPayload["postId"] ?? destinationPayload["post_id"]
            )
            return NotificationDestination(screen: screen, postId: postId)
        }

        let screen = (userInfo["screen"] as? String) ?? NotificationScreen.inbox.rawValue
        let postId = parseUuid(userInfo["postId"] ?? userInfo["post_id"] ?? userInfo["referenceId"])
        return NotificationDestination(screen: screen, postId: postId)
    }

    private func parseUuid(_ value: Any?) -> UUID? {
        guard let string = value as? String else { return nil }
        return UUID(uuidString: string)
    }
}
