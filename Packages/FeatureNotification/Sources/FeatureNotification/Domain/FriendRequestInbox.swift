import Foundation
import Common
import SplickDomain
import Storage

public protocol FriendRequestInboxResponding: Sendable {
    func acceptIncomingRequest(requestId: UUID) async throws
    func rejectIncomingRequest(requestId: UUID) async throws
    func pendingIncomingRequests() async throws -> PendingIncomingFriendRequests
}

public enum FriendRequestInboxOutcome: String, Codable, Sendable {
    case accepted
    case rejected
}

public enum PushNotificationAction {
    public static let friendRequestCategory = "FRIEND_REQUEST"
    public static let accept = "FRIEND_REQUEST_ACCEPT"
    public static let reject = "FRIEND_REQUEST_REJECT"
    public static let messageCategory = "MESSAGE"
    public static let messageReply = "MESSAGE_REPLY"
    public static let messageReactHeart = "MESSAGE_REACT_HEART"
    public static let messageReactThumb = "MESSAGE_REACT_THUMB"
    public static let messageReactLaugh = "MESSAGE_REACT_LAUGH"

    public static func reactionEmoji(for actionIdentifier: String) -> String? {
        switch actionIdentifier {
        case messageReactHeart: return "❤️"
        case messageReactThumb: return "👍"
        case messageReactLaugh: return "😂"
        default: return nil
        }
    }
}

public enum FriendRequestInboxOutcomePersistence {
    public static func load(from defaults: UserDefaultsServiceProtocol?) -> [UUID: FriendRequestInboxOutcome] {
        let stored: [String: String] =
            defaults?.get(for: AppConstants.UserDefaults.processedFriendRequestOutcomes) ?? [:]
        var result: [UUID: FriendRequestInboxOutcome] = [:]
        for (key, value) in stored {
            guard let requestId = UUID(uuidString: key),
                  let outcome = FriendRequestInboxOutcome(rawValue: value)
            else { continue }
            result[requestId] = outcome
        }
        return result
    }

    public static func save(
        _ outcomes: [UUID: FriendRequestInboxOutcome],
        to defaults: UserDefaultsServiceProtocol?
    ) {
        let payload = Dictionary(
            uniqueKeysWithValues: outcomes.map { ($0.key.uuidString, $0.value.rawValue) }
        )
        defaults?.set(payload, for: AppConstants.UserDefaults.processedFriendRequestOutcomes)
    }
}

