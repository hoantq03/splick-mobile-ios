import Foundation
import Combine
import UIKit
import UserNotifications
import Common
import SplickDomain
import Storage

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

    func refreshAuthorizationStatus() {
        Task { [weak self] in
            await self?.refreshAuthorizationStatusAsync()
        }
    }

    func requestAuthorizationIfNeeded() {
        Task { [weak self] in
            guard let self else { return }
            await self.requestAuthorizationIfNeeded(center: UNUserNotificationCenter.current())
        }
    }

    func syncStoredDeviceTokenIfPossible() async {
        guard let token = storedDeviceToken else {
            Log.debug("No stored push token to sync", category: .notification)
            isRegisteredOnServer = false
            return
        }
        guard let deviceTokenService else {
            isRegisteredOnServer = false
            return
        }

        do {
            try await deviceTokenService.registerCurrentDeviceToken(token)
            isRegisteredOnServer = true
        } catch {
            isRegisteredOnServer = false
        }
    }

    func unregisterCurrentDeviceToken() async {
        guard let token = storedDeviceToken else {
            return
        }
        guard let deviceTokenService else { return }

        do {
            try await deviceTokenService.unregisterDeviceToken(token)
            isRegisteredOnServer = false
        } catch {
            isRegisteredOnServer = true
        }
    }

    func handleDeviceTokenRegistration(_ deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        userDefaultsService?.set(token, for: AppConstants.UserDefaults.pushNotificationDeviceToken)
        Log.info(
            "Received APNs device token",
            category: .notification,
            metadata: ["tokenSuffix": token.suffix(8).description]
        )

        Task { [weak self] in
            guard let self, let deviceTokenService = self.deviceTokenService else { return }
            do {
                try await deviceTokenService.registerCurrentDeviceToken(token)
                self.isRegisteredOnServer = true
            } catch {
                self.isRegisteredOnServer = false
            }
        }
    }

    func handleDeviceTokenRegistrationFailure(_ error: Error) {
        isRegisteredOnServer = false
        Log.error(
            "APNs device token registration failed",
            category: .notification,
            metadata: ["error": error.localizedDescription]
        )
    }

    func handleRemoteNotification(userInfo: [AnyHashable: Any]) {
        if let badge = ((userInfo["aps"] as? [String: Any])?["badge"] as? Int) {
            UIApplication.shared.applicationIconBadgeNumber = max(0, badge)
        }

        guard let destination = parseDestination(from: userInfo) else {
            Log.debug("Remote notification had no destination", category: .notification)
            return
        }

        pendingDestination = destination
        Log.info(
            "Queued notification destination",
            category: .notification,
            metadata: ["screen": destination.screen.rawValue]
        )
    }

    func clearPendingDestination() {
        pendingDestination = nil
    }

    func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    var storedDeviceToken: String? {
        userDefaultsService?.get(for: AppConstants.UserDefaults.pushNotificationDeviceToken)
    }

    private func refreshAuthorizationStatusAsync() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        authorizationStatus = settings.authorizationStatus

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            userDefaultsService?.setBool(true, for: AppConstants.UserDefaults.pushNotificationsEnabled)
            await registerForRemoteNotifications()
        case .notDetermined:
            await requestAuthorizationIfNeeded(center: center)
        case .denied:
            userDefaultsService?.setBool(false, for: AppConstants.UserDefaults.pushNotificationsEnabled)
            Log.warning("Push notifications permission denied", category: .notification)
        @unknown default:
            Log.warning("Unknown notification authorization status", category: .notification)
        }
    }

    private func requestAuthorizationIfNeeded(center: UNUserNotificationCenter) async {
        let alreadyRequested = userDefaultsService?.getBool(
            for: AppConstants.UserDefaults.pushNotificationPermissionRequested
        ) ?? false
        guard !alreadyRequested else { return }

        userDefaultsService?.setBool(
            true,
            for: AppConstants.UserDefaults.pushNotificationPermissionRequested
        )

        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            userDefaultsService?.setBool(granted, for: AppConstants.UserDefaults.pushNotificationsEnabled)
            authorizationStatus = granted ? .authorized : .denied
            Log.info(
                "Push notifications permission resolved",
                category: .notification,
                metadata: ["granted": String(granted)]
            )

            guard granted else { return }
            await registerForRemoteNotifications()
        } catch {
            Log.error(
                "Failed to request push notification permission",
                category: .notification,
                metadata: ["error": error.localizedDescription]
            )
        }
    }

    private func registerForRemoteNotifications() async {
        await MainActor.run {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }

    private func parseDestination(from userInfo: [AnyHashable: Any]) -> NotificationDestination? {
        if let destination = parseNestedDestination(userInfo["destination"]) {
            return destination
        }

        if let payload = parseNestedDestination(userInfo["payload"]) {
            return payload
        }

        let screen =
            (userInfo["screen"] as? String)
            ?? (userInfo["destinationScreen"] as? String)
            ?? (userInfo["targetScreen"] as? String)

        let postIdString =
            (userInfo["postId"] as? String)
            ?? (userInfo["post_id"] as? String)
            ?? (userInfo["destinationPostId"] as? String)
            ?? (userInfo["referenceId"] as? String)

        guard let screen else { return nil }
        return NotificationDestination(
            screen: screen,
            postId: postIdString.flatMap(UUID.init(uuidString:))
        )
    }

    private func parseNestedDestination(_ rawValue: Any?) -> NotificationDestination? {
        guard let rawValue else { return nil }

        if let dictionary = rawValue as? [String: Any] {
            let screen =
                (dictionary["screen"] as? String)
                ?? (dictionary["destinationScreen"] as? String)
            let postIdString =
                (dictionary["postId"] as? String)
                ?? (dictionary["post_id"] as? String)
                ?? (dictionary["destinationPostId"] as? String)
            guard let screen else { return nil }
            return NotificationDestination(
                screen: screen,
                postId: postIdString.flatMap(UUID.init(uuidString:))
            )
        }

        if let data = (rawValue as? String)?.data(using: .utf8),
           let dictionary = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return parseNestedDestination(dictionary)
        }

        return nil
    }
}
