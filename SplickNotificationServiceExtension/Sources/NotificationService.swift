import UniformTypeIdentifiers
import UserNotifications

/// Downloads `actorAvatarUrl` from the APNs payload and attaches it so the lock-screen /
/// banner shows the actor photo instead of only the app icon. Also applies the user's
/// globally selected notification sound from the app group.
///
/// After delivering, keeps the extension alive briefly and removes the delivered
/// notification so the heads-up auto-hides outside the app (same ~2.5s as in-app).
final class NotificationService: UNNotificationServiceExtension {
    /// Must stay in sync with `AppConstants.PushNotifications.bannerAutoDismissDelay`.
    private static let bannerAutoDismissSeconds: TimeInterval = 2.5

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

        guard let avatarURL = Self.actorAvatarURL(from: request.content.userInfo) else {
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

    /// Delivers the banner, then blocks until auto-dismiss so iOS does not suspend the
    /// extension before `removeDeliveredNotifications` runs.
    private func finish(with content: UNNotificationContent) {
        guard !didFinish else { return }
        didFinish = true

        let handler = contentHandler
        contentHandler = nil
        let identifier = requestIdentifier

        handler?(content)

        guard !identifier.isEmpty else { return }

        let delay = Self.bannerAutoDismissSeconds
        let group = DispatchGroup()
        group.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            Thread.sleep(forTimeInterval: delay)
            UNUserNotificationCenter.current()
                .removeDeliveredNotifications(withIdentifiers: [identifier])
            group.leave()
        }
        _ = group.wait(timeout: .now() + delay + 0.5)
    }

    private func applySelectedSound(to content: UNMutableNotificationContent) {
        content.sound = UNNotificationSound(named: UNNotificationSoundName("splick_notif_default.wav"))
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
