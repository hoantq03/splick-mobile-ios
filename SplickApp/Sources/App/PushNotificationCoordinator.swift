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
    private var messagingRepository: MessagingRepositoryProtocol?
    private var languageService: LanguageService?
    private var serverSyncInFlight = false
    private var lastSyncedToken: String?
    private var bannerAutoDismissTasks: [String: Task<Void, Never>] = [:]
    /// Request identifiers currently scheduled for short-lived banner display.
    private var activeBannerRequestIdentifiers: Set<String> = []

    private init() {}

    func configure(
        deviceTokenService: DeviceTokenServiceProtocol,
        userDefaultsService: UserDefaultsServiceProtocol,
        hasAccessToken: @escaping @Sendable () async -> Bool,
        friendRequestInbox: FriendRequestInboxResponding? = nil,
        messagingRepository: MessagingRepositoryProtocol? = nil,
        languageService: LanguageService? = nil
    ) {
        self.deviceTokenService = deviceTokenService
        self.userDefaultsService = userDefaultsService
        self.hasAccessToken = hasAccessToken
        self.friendRequestInbox = friendRequestInbox
        self.messagingRepository = messagingRepository
        self.languageService = languageService
        localDeviceToken = userDefaultsService.get(for: AppConstants.UserDefaults.pushNotificationDeviceToken)
        notificationSound = AppNotificationSound.resolved(
            AppNotificationSound.loadRawFromAppGroup()
                ?? userDefaultsService.get(for: AppConstants.UserDefaults.pushNotificationSound)
        )
        AppNotificationSound.persistToAppGroup(notificationSound)
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
        case PushNotificationAction.messageReply:
            acknowledgeMessagingDeliveryIfNeeded(userInfo: userInfo)
            await replyToMessageFromNotification(response)
        case PushNotificationAction.messageReactHeart,
             PushNotificationAction.messageReactThumb,
             PushNotificationAction.messageReactLaugh:
            acknowledgeMessagingDeliveryIfNeeded(userInfo: userInfo)
            await reactToMessageFromNotification(response)
        default:
            handleRemoteNotification(userInfo: userInfo)
        }
    }

    func handleRemoteNotification(userInfo: [AnyHashable: Any], queueDestination: Bool = true) {
        if let badge = ((userInfo["aps"] as? [String: Any])?["badge"] as? Int) {
            syncAppIconBadge(count: badge)
        }

        acknowledgeMessagingDeliveryIfNeeded(userInfo: userInfo)
        invalidateFriendshipsDirectoryIfNeeded(userInfo: userInfo)
        invalidateExpensesDirectoryIfNeeded(userInfo: userInfo)
        invalidateFeedContentIfNeeded(userInfo: userInfo)
        invalidateMessagingInboxIfNeeded(userInfo: userInfo)

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

    /// Friend request pushes should refresh the Friends tab directory without requiring a manual pull.
    private func invalidateFriendshipsDirectoryIfNeeded(userInfo: [AnyHashable: Any]) {
        guard let type = notificationType(from: userInfo),
              type == .friendRequestSent || type == .friendRequestAccepted
        else { return }
        FriendshipsDirectoryChange.post()
    }

    /// Expense / settlement / payment-evidence pushes should soft-refresh Chi tiêu.
    private func invalidateExpensesDirectoryIfNeeded(userInfo: [AnyHashable: Any]) {
        guard let type = notificationType(from: userInfo),
              type.isExpensesDirectoryNotification
        else { return }
        ExpensesDirectoryChange.post()
    }

    /// Feed social pushes should force an ahead-count check for the new-posts pill.
    private func invalidateFeedContentIfNeeded(userInfo: [AnyHashable: Any]) {
        guard let type = notificationType(from: userInfo),
              type.isFeedContentNotification
        else { return }
        FeedContentMayHaveChanged.post()
    }

    /// Messaging pushes should soft-refresh the inbox (filters + unread) when WS missed the event.
    private func invalidateMessagingInboxIfNeeded(userInfo: [AnyHashable: Any]) {
        guard let type = notificationType(from: userInfo),
              type.isMessagingNotification
        else { return }
        MessagingInboxMayHaveChanged.post()
    }

    private func notificationType(from userInfo: [AnyHashable: Any]) -> NotificationType? {
        let typeRaw =
            (userInfo["type"] as? String)
            ?? ((userInfo["payload"] as? [String: Any])?["type"] as? String)
        return typeRaw.flatMap(NotificationType.init(rawValue:))
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
        AppNotificationSound.persistToAppGroup(sound)
    }

    func foregroundPresentationOptions(
        userInfo: [AnyHashable: Any] = [:]
    ) -> UNNotificationPresentationOptions {
        if shouldSuppressForegroundChatBanner(userInfo: userInfo) {
            return []
        }
        if notificationSound.isSilent {
            return [.banner, .badge]
        }
        playSelectedSound()
        // Omit `.sound` so APNs "default" does not override the bundled tone.
        return [.banner, .badge]
    }

    /// iOS keeps actionable / attachment banners until the user swipes them away, which also
    /// blocks subsequent banners. Remove the delivered notification after a short delay.
    func scheduleBannerAutoDismiss(
        requestIdentifier: String? = nil,
        userInfo: [AnyHashable: Any] = [:]
    ) {
        if let requestIdentifier {
            activeBannerRequestIdentifiers.insert(requestIdentifier)
        }
        let taskKey = requestIdentifier
            ?? notificationIdString(from: userInfo)
            ?? UUID().uuidString
        bannerAutoDismissTasks[taskKey]?.cancel()
        bannerAutoDismissTasks[taskKey] = Task { @MainActor [weak self] in
            try? await Task.sleep(for: AppConstants.PushNotifications.bannerAutoDismissDelay)
            guard !Task.isCancelled else { return }
            await self?.dismissDeliveredBanner(
                requestIdentifier: requestIdentifier,
                userInfo: userInfo
            )
            // Background deliver can lag slightly behind the wake callback — retry once.
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            await self?.dismissDeliveredBanner(
                requestIdentifier: requestIdentifier,
                userInfo: userInfo
            )
            if let requestIdentifier {
                self?.activeBannerRequestIdentifiers.remove(requestIdentifier)
            }
            self?.bannerAutoDismissTasks[taskKey] = nil
        }
    }

    /// Clears still-visible short-lived banners so a newly arrived push is not queued behind them.
    func dismissPendingBanners(except requestIdentifier: String? = nil) {
        let staleRequestIds = activeBannerRequestIdentifiers.filter { $0 != requestIdentifier }
        let staleTaskKeys = bannerAutoDismissTasks.keys.filter { $0 != requestIdentifier }
        for key in staleTaskKeys {
            bannerAutoDismissTasks[key]?.cancel()
            bannerAutoDismissTasks[key] = nil
        }
        activeBannerRequestIdentifiers.subtract(staleRequestIds)
        guard !staleRequestIds.isEmpty else { return }
        UNUserNotificationCenter.current()
            .removeDeliveredNotifications(withIdentifiers: Array(staleRequestIds))
    }

    private func dismissDeliveredBanner(
        requestIdentifier: String?,
        userInfo: [AnyHashable: Any]
    ) async {
        let center = UNUserNotificationCenter.current()
        if let requestIdentifier {
            center.removeDeliveredNotifications(withIdentifiers: [requestIdentifier])
            return
        }

        let targetId = notificationIdString(from: userInfo)
        let delivered = await center.deliveredNotifications()
        let identifiers: [String]
        if let targetId {
            identifiers = delivered.compactMap { notification in
                let info = notification.request.content.userInfo
                guard notificationIdString(from: info) == targetId else { return nil }
                return notification.request.identifier
            }
        } else if !userInfo.isEmpty {
            // Fallback: remove the newest delivered notification from this app.
            identifiers = delivered
                .sorted { $0.date > $1.date }
                .prefix(1)
                .map(\.request.identifier)
        } else {
            identifiers = []
        }
        guard !identifiers.isEmpty else { return }
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    private func notificationIdString(from userInfo: [AnyHashable: Any]) -> String? {
        if let value = userInfo["notificationId"] as? String, !value.isEmpty {
            return value
        }
        if let value = userInfo["notification_id"] as? String, !value.isEmpty {
            return value
        }
        return nil
    }

    private func shouldSuppressForegroundChatBanner(userInfo: [AnyHashable: Any]) -> Bool {
        guard UIApplication.shared.applicationState == .active else {
            return false
        }
        guard let destination = NotificationDestination.fromPushUserInfo(userInfo),
              destination.screen == .messages
        else {
            return false
        }
        return VisibleChatThreadStore.shared.matches(destination.conversationId)
    }

    func playSelectedSound() {
        Self.playNotificationSound(notificationSound)
    }

    static func playNotificationSound(_ sound: AppNotificationSound) {
        sound.play()
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
        let message = UNNotificationCategory(
            identifier: PushNotificationAction.messageCategory,
            actions: messageQuickReplyActions(),
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([friendRequest, message])
    }

    private func messageQuickReplyActions() -> [UNNotificationAction] {
        let replyTitle = languageService?.text(.messagingReplyAction) ?? "Reply"
        let sendTitle = languageService?.text(.messagingSend) ?? "Send"
        let placeholder = languageService?.text(.messagingNotificationReplyPlaceholder) ?? "Message"
        let reply = UNTextInputNotificationAction(
            identifier: PushNotificationAction.messageReply,
            title: replyTitle,
            options: [],
            textInputButtonTitle: sendTitle,
            textInputPlaceholder: placeholder
        )
        let heart = UNNotificationAction(
            identifier: PushNotificationAction.messageReactHeart,
            title: "❤️",
            options: []
        )
        let thumb = UNNotificationAction(
            identifier: PushNotificationAction.messageReactThumb,
            title: "👍",
            options: []
        )
        let laugh = UNNotificationAction(
            identifier: PushNotificationAction.messageReactLaugh,
            title: "😂",
            options: []
        )
        return [reply, heart, thumb, laugh]
    }

    private func replyToMessageFromNotification(_ response: UNNotificationResponse) async {
        let userInfo = response.notification.request.content.userInfo
        guard let conversationId = conversationId(from: userInfo) else {
            Log.warning("Message reply push action missing conversationId", category: .notification)
            return
        }
        let body = (response as? UNTextInputNotificationResponse)?
            .userText
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !body.isEmpty else { return }
        guard let messagingRepository else { return }
        let replyTo = parseUUID(userInfo["messageId"]) ?? parseUUID(userInfo["referenceId"])
        do {
            _ = try await messagingRepository.sendMessage(
                conversationId: conversationId,
                body: body,
                clientMessageId: UUID(),
                imageAttachments: [],
                replyToMessageId: replyTo
            )
        } catch {
            Log.error(error, category: .notification, metadata: ["action": "messageReply"])
        }
    }

    private func reactToMessageFromNotification(_ response: UNNotificationResponse) async {
        let userInfo = response.notification.request.content.userInfo
        guard let conversationId = conversationId(from: userInfo),
              let messageId = parseUUID(userInfo["messageId"]) ?? parseUUID(userInfo["referenceId"]),
              let emoji = PushNotificationAction.reactionEmoji(for: response.actionIdentifier)
        else {
            Log.warning("Message react push action missing ids", category: .notification)
            return
        }
        guard let messagingRepository else { return }
        do {
            _ = try await messagingRepository.addReaction(
                conversationId: conversationId,
                messageId: messageId,
                emoji: emoji
            )
        } catch {
            Log.error(error, category: .notification, metadata: ["action": "messageReact"])
        }
    }

    private func conversationId(from userInfo: [AnyHashable: Any]) -> UUID? {
        if let destination = NotificationDestination.fromPushUserInfo(userInfo),
           let conversationId = destination.conversationId ?? destination.postId {
            return conversationId
        }
        return parseUUID(userInfo["conversationId"]) ?? parseUUID(userInfo["postId"])
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
            // Repository posts FriendshipsDirectoryChange; ensure badge refresh even if the
            // Friends tab is not observing badge counts from that notification.
            FriendshipsDirectoryChange.post()
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
