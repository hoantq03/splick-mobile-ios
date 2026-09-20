import UniformTypeIdentifiers
import UserNotifications

/// Applies the selected notification sound. For non-message alerts, downloads
/// `actorAvatarUrl` and attaches it as a compact actor photo.
///
/// Message pushes skip the attachment so expanding the banner shows the reply field
/// and heart action instead of a full-bleed avatar.
///
/// After ~2.5s the heads-up is retracted by re-posting the same alert as a quiet
/// (passive) notification so it remains in Notification Center without a sticky banner.
final class NotificationService: UNNotificationServiceExtension {
    /// Must stay in sync with `AppConstants.PushNotifications.bannerAutoDismissDelay`.
    private static let bannerAutoDismissSeconds: TimeInterval = 2.5
    /// Must stay in sync with `AppConstants.PushNotifications.headsUpRetractedUserInfoKey`.
    private static let headsUpRetractedUserInfoKey = "splickHeadsUpRetracted"

    private var contentHandler: ((UNNotificationContent) -> Void)?
    private var bestAttemptContent: UNMutableNotificationContent?
    private var downloadTask: URLSessionDataTask?
    private var requestIdentifier: String = ""
    private var didFinish = false

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        self.contentHandler = contentHandler
        requestIdentifier = request.identifier
        bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)

        guard let bestAttemptContent else {
            finish(with: request.content)
            return
        }

        applySelectedSound(to: bestAttemptContent)

        let isMessage = Self.isMessageNotification(request.content.userInfo)
        if isMessage, bestAttemptContent.categoryIdentifier.isEmpty {
            bestAttemptContent.categoryIdentifier = "MESSAGE"
        }
        guard !isMessage,
              let avatarURL = Self.actorAvatarURL(from: request.content.userInfo)
        else {
            finish(with: bestAttemptContent)
            return
        }

        var urlRequest = URLRequest(url: avatarURL, timeoutInterval: 2.0)
        urlRequest.httpMethod = "GET"

        downloadTask = URLSession.shared.dataTask(with: urlRequest) { [weak self] data, response, error in
            defer { self?.downloadTask = nil }
            guard let self else { return }

            var content = bestAttemptContent
            if error == nil,
               let data,
               !data.isEmpty,
               let http = response as? HTTPURLResponse,
               (200 ... 299).contains(http.statusCode)
            {
                let fileExtension = Self.preferredFileExtension(
                    url: avatarURL,
                    mimeType: http.value(forHTTPHeaderField: "Content-Type")
                )
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathExtension(fileExtension)

                do {
                    try data.write(to: tempURL, options: .atomic)
                    var options: [String: Any] = [:]
                    if let typeIdentifier = UTType(filenameExtension: fileExtension)?.identifier {
                        options[UNNotificationAttachmentOptionsTypeHintKey] = typeIdentifier
                    }
                    let attachment = try UNNotificationAttachment(
                        identifier: "actorAvatar",
                        url: tempURL,
                        options: options.isEmpty ? nil : options
                    )
                    content.attachments = [attachment]
                } catch {
                    // Fail soft — deliver original alert without attachment.
                }
            }
            self.finish(with: content)
        }
        downloadTask?.resume()
    }

    override func serviceExtensionTimeWillExpire() {
        downloadTask?.cancel()
        if let bestAttemptContent {
            finish(with: bestAttemptContent)
        }
    }

    /// Delivers the heads-up, then retracts it into Notification Center after a short delay.
    /// If another push is already on screen, that previous heads-up is retracted immediately.
    private func finish(with content: UNNotificationContent) {
        guard !didFinish else { return }
        didFinish = true

        let handler = contentHandler
        contentHandler = nil
        let identifier = requestIdentifier

        guard !identifier.isEmpty,
              !Self.isHeadsUpRetractedRetain(content.userInfo)
        else {
            handler?(content)
            return
        }

        // Newer push wins: hide any previous heads-up now so this banner can appear.
        Self.retractAllVisibleHeadsUps(except: identifier)

        handler?(content)

        let delay = Self.bannerAutoDismissSeconds
        let group = DispatchGroup()
        group.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            Thread.sleep(forTimeInterval: delay)
            Self.retractHeadsUpPreservingNotificationCenter(
                identifier: identifier,
                fallbackContent: content
            )
            group.leave()
        }
        _ = group.wait(timeout: .now() + delay + 1.0)
    }

    private static func retractAllVisibleHeadsUps(except identifier: String) {
        let center = UNUserNotificationCenter.current()
        let semaphore = DispatchSemaphore(value: 0)
        var delivered: [UNNotification] = []

        center.getDeliveredNotifications { notifications in
            delivered = notifications
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: .now() + 0.5)

        for notification in delivered {
            let otherId = notification.request.identifier
            guard otherId != identifier else { continue }
            let info = notification.request.content.userInfo
            guard !isHeadsUpRetractedRetain(info) else { continue }
            retractHeadsUpPreservingNotificationCenter(
                identifier: otherId,
                fallbackContent: notification.request.content
            )
        }
    }

    private static func retractHeadsUpPreservingNotificationCenter(
        identifier: String,
        fallbackContent: UNNotificationContent
    ) {
        let center = UNUserNotificationCenter.current()
        let semaphore = DispatchSemaphore(value: 0)
        var sourceContent = fallbackContent

        center.getDeliveredNotifications { delivered in
            if let match = delivered.first(where: { $0.request.identifier == identifier }) {
                sourceContent = match.request.content
            }
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: .now() + 0.5)

        if isHeadsUpRetractedRetain(sourceContent.userInfo) {
            return
        }

        let retained = makeQuietNotificationCenterContent(from: sourceContent)
        center.removeDeliveredNotifications(withIdentifiers: [identifier])

        let request = UNNotificationRequest(
            identifier: identifier,
            content: retained,
            trigger: nil
        )
        center.add(request) { _ in }
        // Brief wait so the quiet re-post is accepted before the extension suspends.
        Thread.sleep(forTimeInterval: 0.3)
    }

    private static func makeQuietNotificationCenterContent(
        from original: UNNotificationContent
    ) -> UNMutableNotificationContent {
        let retained = UNMutableNotificationContent()
        retained.title = original.title
        retained.subtitle = original.subtitle
        retained.body = original.body
        retained.badge = original.badge
        retained.categoryIdentifier = original.categoryIdentifier
        retained.threadIdentifier = original.threadIdentifier
        retained.targetContentIdentifier = original.targetContentIdentifier
        retained.attachments = copyAttachments(original.attachments)
        retained.sound = nil
        retained.interruptionLevel = .passive

        var info = original.userInfo
        info[headsUpRetractedUserInfoKey] = true
        retained.userInfo = info
        return retained
    }

    private static func copyAttachments(
        _ attachments: [UNNotificationAttachment]
    ) -> [UNNotificationAttachment] {
        attachments.compactMap { attachment in
            let destination = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(attachment.url.pathExtension)
            do {
                try FileManager.default.copyItem(at: attachment.url, to: destination)
                return try UNNotificationAttachment(
                    identifier: attachment.identifier,
                    url: destination,
                    options: nil
                )
            } catch {
                return nil
            }
        }
    }

    private static func isHeadsUpRetractedRetain(_ userInfo: [AnyHashable: Any]) -> Bool {
        if let value = userInfo[headsUpRetractedUserInfoKey] as? Bool {
            return value
        }
        if let value = userInfo[headsUpRetractedUserInfoKey] as? NSNumber {
            return value.boolValue
        }
        return false
    }

    private func applySelectedSound(to content: UNMutableNotificationContent) {
        content.sound = UNNotificationSound(named: UNNotificationSoundName("splick_notif_default.wav"))
    }

    private static func isMessageNotification(_ userInfo: [AnyHashable: Any]) -> Bool {
        if let aps = userInfo["aps"] as? [String: Any],
           let category = aps["category"] as? String,
           category.caseInsensitiveCompare("MESSAGE") == .orderedSame
        {
            return true
        }
        if let actionCategory = userInfo["actionCategory"] as? String,
           actionCategory.caseInsensitiveCompare("MESSAGE") == .orderedSame
        {
            return true
        }
        if let type = userInfo["type"] as? String {
            switch type.uppercased() {
            case "DIRECT_MESSAGE", "GROUP_MESSAGE", "MESSAGE_NEW":
                return true
            default:
                break
            }
        }
        if let screen = userInfo["screen"] as? String,
           screen.caseInsensitiveCompare("MESSAGES") == .orderedSame
        {
            return true
        }
        return false
    }

    private static func actorAvatarURL(from userInfo: [AnyHashable: Any]) -> URL? {
        let raw: String?
        if let value = userInfo["actorAvatarUrl"] as? String {
            raw = value
        } else if let aps = userInfo["aps"] as? [String: Any],
                  let value = aps["actorAvatarUrl"] as? String {
            raw = value
        } else {
            raw = nil
        }
        guard let raw, let url = URL(string: raw), url.scheme?.lowercased() == "https" else {
            return nil
        }
        return url
    }

    private static func preferredFileExtension(url: URL, mimeType: String?) -> String {
        if let mimeType {
            let normalized = mimeType.split(separator: ";").first.map(String.init)?.lowercased()
            switch normalized {
            case "image/png":
                return "png"
            case "image/gif":
                return "gif"
            case "image/webp":
                return "webp"
            case "image/jpeg", "image/jpg":
                return "jpeg"
            default:
                break
            }
        }
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "jpg", "jpeg", "png", "gif", "webp":
            return ext == "jpg" ? "jpeg" : ext
        default:
            return "jpeg"
        }
    }
}
