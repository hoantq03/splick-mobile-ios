import Foundation
import Combine
import UIKit
import UserNotifications
import Common
import FeatureMessaging
import FeatureNotification
import Localization
import Networking
import SplickDomain
import Storage

/// Coordinates APNs permission, token sync, and tap routing.
/// Actor avatars on the lock-screen / banner are attached by
/// `SplickNotificationServiceExtension` from the `actorAvatarUrl` payload key
/// (requires APNs `mutable-content`).
@MainActor
final class PushNotificationCoordinator: ObservableObject {
    static let shared = PushNotificationCoordinator()

    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published private(set) var isRegisteredOnServer = false
    @Published private(set) var localDeviceToken: String?
    @Published private(set) var notificationSound: AppNotificationSound = .default
    @Published var pendingDestination: NotificationDestination?

    private var deviceTokenService: DeviceTokenServiceProtocol?
    private var userDefaultsService: UserDefaultsServiceProtocol?
    private var hasAccessToken: (@Sendable () async -> Bool)?
    private var friendRequestInbox: FriendRequestInboxResponding?
    private var languageService: LanguageService?
    private var serverSyncInFlight = false
    private var lastSyncedToken: String?

    private init() {}

    func configure(
        deviceTokenService: DeviceTokenServiceProtocol,
        userDefaultsService: UserDefaultsServiceProtocol,
        hasAccessToken: @escaping @Sendable () async -> Bool,
        friendRequestInbox: FriendRequestInboxResponding? = nil,
        languageService: LanguageService? = nil
    ) {
        self.deviceTokenService = deviceTokenService
        self.userDefaultsService = userDefaultsService
        self.hasAccessToken = hasAccessToken
        self.friendRequestInbox = friendRequestInbox
        self.languageService = languageService
        localDeviceToken = userDefaultsService.get(for: AppConstants.UserDefaults.pushNotificationDeviceToken)
        notificationSound = AppNotificationSound.resolved(
            userDefaultsService.get(for: AppConstants.UserDefaults.pushNotificationSound)
        )
        registerNotificationCategories()

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

    func handleNotificationResponse(_ response: UNNotificationResponse) async {
        let userInfo = response.notification.request.content.userInfo
        switch response.actionIdentifier {
        case PushNotificationAction.accept:
            await respondToFriendRequest(accept: true, userInfo: userInfo)
        case PushNotificationAction.reject:
            await respondToFriendRequest(accept: false, userInfo: userInfo)
        default:
            handleRemoteNotification(userInfo: userInfo)
        }
    }

    func handleRemoteNotification(userInfo: [AnyHashable: Any], queueDestination: Bool = true) {
        if let badge = ((userInfo["aps"] as? [String: Any])?["badge"] as? Int) {
            syncAppIconBadge(count: badge)
        }

        acknowledgeMessagingDeliveryIfNeeded(userInfo: userInfo)

        guard queueDestination else { return }

        guard let destination = NotificationDestination.fromPushUserInfo(userInfo) else {
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

    /// When a messaging push is presented/received, ACK delivery so the sender sees "đã nhận".
    private func acknowledgeMessagingDeliveryIfNeeded(userInfo: [AnyHashable: Any]) {
        guard let destination = NotificationDestination.fromPushUserInfo(userInfo),
              destination.screen == .messages,
              let conversationId = destination.conversationId ?? destination.postId
        else { return }

        let messageIdString =
            (userInfo["messageId"] as? String)
            ?? (userInfo["message_id"] as? String)
            ?? ((userInfo["payload"] as? [String: Any])?["messageId"] as? String)
        guard let messageIdString,
              let messageId = UUID(uuidString: messageIdString)
        else { return }

        MessageDeliveryAckService.shared.acknowledge(
            conversationId: conversationId,
            messageId: messageId
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

    func setNotificationSound(_ sound: AppNotificationSound) {
        notificationSound = sound
        userDefaultsService?.set(sound.rawValue, for: AppConstants.UserDefaults.pushNotificationSound)
    }

    func foregroundPresentationOptions() -> UNNotificationPresentationOptions {
        notificationSound.isSilent ? [.banner, .badge] : [.banner, .badge, .sound]
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
            registerNotificationCategories()
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

    private func registerNotificationCategories() {
        let acceptTitle = languageService?.text(.friendsAccept) ?? "Accept"
        let rejectTitle = languageService?.text(.friendsReject) ?? "Reject"
        let accept: UNNotificationAction
        let reject: UNNotificationAction
        if #available(iOS 15.0, *) {
            accept = UNNotificationAction(
                identifier: PushNotificationAction.accept,
                title: acceptTitle,
                options: [],
                icon: UNNotificationActionIcon(systemImageName: "person.badge.plus")
            )
            reject = UNNotificationAction(
                identifier: PushNotificationAction.reject,
                title: rejectTitle,
                options: [.destructive],
                icon: UNNotificationActionIcon(systemImageName: "person.crop.circle.badge.xmark")
            )
        } else {
            accept = UNNotificationAction(
                identifier: PushNotificationAction.accept,
                title: acceptTitle,
                options: []
            )
            reject = UNNotificationAction(
                identifier: PushNotificationAction.reject,
                title: rejectTitle,
                options: [.destructive]
            )
        }
        let friendRequest = UNNotificationCategory(
            identifier: PushNotificationAction.friendRequestCategory,
            actions: [accept, reject],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([friendRequest])
    }

    private func respondToFriendRequest(accept: Bool, userInfo: [AnyHashable: Any]) async {
        guard let requestId = parseUUID(userInfo["requestId"]) ?? parseUUID(userInfo["referenceId"])
        else {
            Log.warning("Friend request push action missing requestId", category: .notification)
            return
        }
        guard let friendRequestInbox else { return }

        do {
            if accept {
                try await friendRequestInbox.acceptIncomingRequest(requestId: requestId)
            } else {
                try await friendRequestInbox.rejectIncomingRequest(requestId: requestId)
            }
            persistFriendRequestOutcome(requestId, accept ? .accepted : .rejected)
        } catch {
            Log.error(
                error,
                category: .notification,
                metadata: ["action": accept ? "accept" : "reject"]
            )
        }
    }

    private func persistFriendRequestOutcome(_ requestId: UUID, _ outcome: FriendRequestInboxOutcome) {
        var stored = FriendRequestInboxOutcomePersistence.load(from: userDefaultsService)
        stored[requestId] = outcome
        FriendRequestInboxOutcomePersistence.save(stored, to: userDefaultsService)
    }

    private func parseUUID(_ rawValue: Any?) -> UUID? {
        (rawValue as? String).flatMap(UUID.init(uuidString:))
    }
}
