import Foundation

public struct NotificationDestination: Codable, Equatable, Sendable {
    public let screen: NotificationScreen
    /// Post id for `.postDetail`, conversation id for `.messages`, user id for `.userProfile`.
    public let postId: UUID?
    /// Comment to focus after opening `.postDetail`.
    public let commentId: UUID?

    public init(screen: NotificationScreen, postId: UUID? = nil, commentId: UUID? = nil) {
        self.screen = screen
        self.postId = postId
        self.commentId = commentId
    }

    public init(screen: String, postId: UUID? = nil, commentId: UUID? = nil) {
        self.init(
            screen: NotificationScreen(rawValue: screen.uppercased()) ?? .unknown,
            postId: postId,
            commentId: commentId
        )
    }

    public var postDetailId: UUID? {
        guard screen == .postDetail else { return nil }
        return postId
    }

    public var conversationId: UUID? {
        guard screen == .messages else { return nil }
        return postId
    }

    public var userProfileId: UUID? {
        guard screen == .userProfile else { return nil }
        return postId
    }

    /// Parses FCM/APNs `userInfo` into a navigation destination.
    public static func fromPushUserInfo(_ userInfo: [AnyHashable: Any]) -> NotificationDestination? {
        if let nested = fromNestedValue(userInfo["destination"]) ?? fromNestedValue(userInfo["payload"]) {
            return nested
        }

        let screenRaw = stringValue(userInfo["screen"])
            ?? stringValue(userInfo["destinationScreen"])
            ?? stringValue(userInfo["targetScreen"])
            ?? screenRaw(fromType: stringValue(userInfo["type"]))

        let entityId = uuidValue(userInfo["conversationId"])
            ?? uuidValue(userInfo["conversation_id"])
            ?? uuidValue(userInfo["postId"])
            ?? uuidValue(userInfo["post_id"])
            ?? uuidValue(userInfo["destinationPostId"])
            ?? uuidValue(userInfo["referenceId"])
            ?? uuidValue(userInfo["userId"])

        guard let screenRaw else { return nil }
        return NotificationDestination(
            screen: screenRaw,
            postId: entityId,
            commentId: uuidValue(userInfo["commentId"]) ?? uuidValue(userInfo["comment_id"])
        )
    }

    private static func fromNestedValue(_ rawValue: Any?) -> NotificationDestination? {
        guard let rawValue else { return nil }

        if let dictionary = rawValue as? [String: Any] {
            return fromDictionary(dictionary)
        }
        if let dictionary = rawValue as? [AnyHashable: Any] {
            var stringKeyed: [String: Any] = [:]
            for (key, value) in dictionary {
                if let key = key as? String {
                    stringKeyed[key] = value
                }
            }
            return fromDictionary(stringKeyed)
        }
        if let data = stringValue(rawValue)?.data(using: .utf8),
           let dictionary = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return fromDictionary(dictionary)
        }
        return nil
    }

    private static func fromDictionary(_ dictionary: [String: Any]) -> NotificationDestination? {
        let screenRaw = stringValue(dictionary["screen"])
            ?? stringValue(dictionary["destinationScreen"])
            ?? screenRaw(fromType: stringValue(dictionary["type"]))
        let entityId = uuidValue(dictionary["conversationId"])
            ?? uuidValue(dictionary["conversation_id"])
            ?? uuidValue(dictionary["postId"])
            ?? uuidValue(dictionary["post_id"])
            ?? uuidValue(dictionary["destinationPostId"])
            ?? uuidValue(dictionary["userId"])
        let commentId = uuidValue(dictionary["commentId"])
            ?? uuidValue(dictionary["comment_id"])
        guard let screenRaw else { return nil }
        return NotificationDestination(screen: screenRaw, postId: entityId, commentId: commentId)
    }

    private static func screenRaw(fromType type: String?) -> String? {
        guard let type else { return nil }
        switch type.uppercased() {
        case "DIRECT_MESSAGE", "GROUP_MESSAGE", "MESSAGE_NEW",
             "GROUP_CREATED", "GROUP_MEMBER_ADDED", "GROUP_MEMBER_REMOVED",
             "GROUP_RENAMED", "GROUP_ADMIN_TRANSFERRED":
            return NotificationScreen.messages.rawValue
        case "GROUP_DELETED", "GROUP_INVITE":
            return NotificationScreen.friends.rawValue
        case "PAYMENT_EVIDENCE_SUBMITTED", "PAYMENT_EVIDENCE_APPROVED", "PAYMENT_EVIDENCE_REJECTED":
            return NotificationScreen.postDetail.rawValue
        default:
            return nil
        }
    }

    private static func stringValue(_ rawValue: Any?) -> String? {
        if let value = rawValue as? String {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        return nil
    }

    private static func uuidValue(_ rawValue: Any?) -> UUID? {
        if let uuid = rawValue as? UUID {
            return uuid
        }
        return stringValue(rawValue).flatMap(UUID.init(uuidString:))
    }
}

public enum NotificationScreen: String, Codable, Sendable {
    case inbox = "INBOX"
    case feed = "FEED"
    case postDetail = "POST_DETAIL"
    case friends = "FRIENDS"
    case expenses = "EXPENSES"
    case messages = "MESSAGES"
    case userProfile = "USER_PROFILE"
    case unknown = "UNKNOWN"
}
