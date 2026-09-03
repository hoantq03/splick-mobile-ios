import UniformTypeIdentifiers
import UserNotifications

/// Downloads `actorAvatarUrl` from the APNs payload and attaches it so the lock-screen /
/// banner shows the actor photo instead of only the app icon. Also applies the user's
/// globally selected notification sound from the app group.
final class NotificationService: UNNotificationServiceExtension {
    private var contentHandler: ((UNNotificationContent) -> Void)?
    private var bestAttemptContent: UNMutableNotificationContent?
    private var downloadTask: URLSessionDataTask?

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        self.contentHandler = contentHandler
        bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)

        guard let bestAttemptContent else {
            contentHandler(request.content)
            return
        }

        applySelectedSound(to: bestAttemptContent)

        guard let avatarURL = Self.actorAvatarURL(from: request.content.userInfo) else {
            contentHandler(bestAttemptContent)
            return
        }

        var urlRequest = URLRequest(url: avatarURL, timeoutInterval: 2.0)
        urlRequest.httpMethod = "GET"

        downloadTask = URLSession.shared.dataTask(with: urlRequest) { [weak self] data, response, error in
            defer { self?.downloadTask = nil }
            guard
                error == nil,
                let data,
                !data.isEmpty,
                let http = response as? HTTPURLResponse,
                (200 ... 299).contains(http.statusCode)
            else {
                contentHandler(bestAttemptContent)
                return
            }

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
                bestAttemptContent.attachments = [attachment]
            } catch {
                // Fail soft — deliver original alert without attachment.
            }
            contentHandler(bestAttemptContent)
        }
        downloadTask?.resume()
    }

    override func serviceExtensionTimeWillExpire() {
        downloadTask?.cancel()
        if let contentHandler, let bestAttemptContent {
            contentHandler(bestAttemptContent)
        }
    }

    private func applySelectedSound(to content: UNMutableNotificationContent) {
        let raw = UserDefaults(suiteName: "group.com.splick.app")?
            .string(forKey: "pushNotificationSound")
        switch raw {
        case "silent":
            content.sound = UNNotificationSound(named: UNNotificationSoundName("splick_notif_silent.wav"))
        case "note":
            content.sound = UNNotificationSound(named: UNNotificationSoundName("splick_notif_note.wav"))
        case "chime":
            content.sound = UNNotificationSound(named: UNNotificationSoundName("splick_notif_chime.wav"))
        case "pop":
            content.sound = UNNotificationSound(named: UNNotificationSoundName("splick_notif_pop.wav"))
        default:
            content.sound = UNNotificationSound(named: UNNotificationSoundName("splick_notif_default.wav"))
        }
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
