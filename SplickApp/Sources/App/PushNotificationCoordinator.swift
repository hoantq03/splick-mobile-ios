import Foundation
import Combine
import UIKit
import UserNotifications
import Common
import Networking
import SplickDomain
import Storage

@MainActor
final class PushNotificationCoordinator: ObservableObject {
    static let shared = PushNotificationCoordinator()

    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published private(set) var isRegisteredOnServer = false
    @Published private(set) var localDeviceToken: String?
    @Published var pendingDestination: NotificationDestination?

    private var deviceTokenService: DeviceTokenServiceProtocol?
    private var userDefaultsService: UserDefaultsServiceProtocol?
    private var hasAccessToken: (@Sendable () async -> Bool)?
    private var serverSyncInFlight = false
    private var lastSyncedToken: String?

    private init() {}

    func configure(
        deviceTokenService: DeviceTokenServiceProtocol,
        userDefaultsService: UserDefaultsServiceProtocol,
        hasAccessToken: @escaping @Sendable () async -> Bool
    ) {
        self.deviceTokenService = deviceTokenService
        self.userDefaultsService = userDefaultsService
        self.hasAccessToken = hasAccessToken
        localDeviceToken = userDefaultsService.get(for: AppConstants.UserDefaults.pushNotificationDeviceToken)

        Log.info(
            "Push notification coordinator configured",
            category: .notification,
            metadata: [
                "hasStoredToken": String(localDeviceToken != nil),
                "storedTokenSuffix": localDeviceToken?.suffix(8).description ?? "-",
            ]
        )
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

    /// Ensures an APNs token exists locally and is registered on the backend.
    /// Handles users who granted push permission before device-token sync existed.
    func ensureDeviceTokenRegistered() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        authorizationStatus = settings.authorizationStatus
        let canSync = await hasAccessToken?() ?? false

        Log.info(
            "Ensuring device token registration",
            category: .notification,
            metadata: [
                "authorizationStatus": authorizationStatusLogLabel(settings.authorizationStatus),
                "hasStoredToken": String(storedDeviceToken != nil),
                "storedTokenSuffix": storedDeviceToken?.suffix(8).description ?? "-",
                "canSyncWithServer": String(canSync),
            ]
        )

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            userDefaultsService?.setBool(true, for: AppConstants.UserDefaults.pushNotificationsEnabled)

            if let token = storedDeviceToken {
                localDeviceToken = token
                await registerTokenOnServer(token)
                return
            }

            isRegisteredOnServer = false
            Log.info(
                "Push permission granted but no local APNs token; requesting registration from Apple",
                category: .notification
            )
            pushDebug("No local token yet — calling registerForRemoteNotifications()")
            await registerForRemoteNotifications()
        case .notDetermined:
            Log.info(
                "Push permission not determined; requesting authorization",
                category: .notification
            )
            await requestAuthorizationIfNeeded(center: center)
        case .denied:
            userDefaultsService?.setBool(false, for: AppConstants.UserDefaults.pushNotificationsEnabled)
            Log.warning(
                "Push notifications permission denied; open Settings to enable",
                category: .notification
            )
        @unknown default:
            Log.warning("Unknown notification authorization status", category: .notification)
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
            lastSyncedToken = nil
        } catch {
            isRegisteredOnServer = true
        }
    }

    func handleDeviceTokenRegistration(_ deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        userDefaultsService?.set(token, for: AppConstants.UserDefaults.pushNotificationDeviceToken)
        localDeviceToken = token
        pushDebug("APNs token received suffix=\(token.suffix(8))")
        Log.info(
            "Received APNs device token",
            category: .notification,
            metadata: ["tokenSuffix": token.suffix(8).description]
        )

        Task { [weak self] in
            await self?.registerTokenOnServer(token)
        }
    }

    func handleDeviceTokenRegistrationFailure(_ error: Error) {
        isRegisteredOnServer = false
        pushDebug("APNs registration FAILED error=\(error.localizedDescription)")
        Log.error(
            "APNs device token registration failed",
            category: .notification,
            metadata: ["error": error.localizedDescription]
        )
    }

    func handleRemoteNotification(userInfo: [AnyHashable: Any]) {
        if let badge = ((userInfo["aps"] as? [String: Any])?["badge"] as? Int) {
            syncAppIconBadge(count: badge)
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

    /// Keeps the home-screen app icon badge aligned with server unread totals.
    func syncAppIconBadge(count: Int) {
        let safeCount = max(0, count)
        UNUserNotificationCenter.current().setBadgeCount(safeCount) { error in
            if let error {
                Log.error(
                    error,
                    category: .notification,
                    metadata: ["action": "syncAppIconBadge", "count": String(safeCount)]
                )
            }
        }
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
            if let token = storedDeviceToken {
                localDeviceToken = token
                await registerTokenOnServer(token)
            } else {
                await registerForRemoteNotifications()
            }
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
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }

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

    private func registerTokenOnServer(_ token: String) async {
        if token == lastSyncedToken, isRegisteredOnServer {
            return
        }
        guard !serverSyncInFlight else { return }
        serverSyncInFlight = true
        defer { serverSyncInFlight = false }

        let tokenSuffix = token.suffix(8).description

        guard let deviceTokenService else {
            isRegisteredOnServer = false
            Log.warning(
                "Device token service not configured; token stored locally only",
                category: .notification,
                metadata: ["tokenSuffix": tokenSuffix]
            )
            return
        }

        guard await hasAccessToken?() ?? false else {
            isRegisteredOnServer = false
            pushDebug("SKIP POST /v1/devices — not authenticated yet suffix=\(tokenSuffix)")
            Log.warning(
                "Skipping POST /v1/devices because user is not authenticated yet",
                category: .notification,
                metadata: ["tokenSuffix": tokenSuffix]
            )
            return
        }

        pushDebug("CALL POST /v1/devices suffix=\(tokenSuffix)")
        Log.info(
            "Calling POST /v1/devices to sync APNs token",
            category: .notification,
            metadata: ["tokenSuffix": tokenSuffix]
        )

        do {
            try await deviceTokenService.registerCurrentDeviceToken(token)
            await MainActor.run {
                isRegisteredOnServer = true
                lastSyncedToken = token
            }
        } catch {
            await MainActor.run {
                isRegisteredOnServer = false
            }
            Log.error(
                "POST /v1/devices failed",
                category: .notification,
                metadata: [
                    "tokenSuffix": tokenSuffix,
                    "error": error.localizedDescription,
                ]
            )
        }
    }

    private func registerForRemoteNotifications() async {
        Log.info(
            "Calling UIApplication.registerForRemoteNotifications()",
            category: .notification
        )
        await MainActor.run {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }

    private func authorizationStatusLogLabel(_ status: UNAuthorizationStatus) -> String {
        switch status {
        case .notDetermined: return "notDetermined"
        case .denied: return "denied"
        case .authorized: return "authorized"
        case .provisional: return "provisional"
        case .ephemeral: return "ephemeral"
        @unknown default: return "unknown"
        }
    }

    private func pushDebug(_ message: String) {
        #if DEBUG
        print("[SplickPush] \(message)")
        #endif
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
            ?? (userInfo["conversationId"] as? String)
            ?? (userInfo["conversation_id"] as? String)
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
                ?? (dictionary["conversationId"] as? String)
                ?? (dictionary["conversation_id"] as? String)
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
