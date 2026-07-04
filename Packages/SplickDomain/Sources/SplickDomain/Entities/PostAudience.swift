import Foundation

public enum PostAudienceMode: String, Codable, CaseIterable, Sendable {
    case friends
    case groups
    case specificUsers = "specific_users"
    case friendsExcept = "friends_except"
}

public struct PostAudience: Codable, Equatable, Sendable {
    public let mode: PostAudienceMode
    public let allowedGroupIds: [UUID]
    public let allowedUserIds: [UUID]
    public let excludedUserIds: [UUID]

    public static let friends = PostAudience(mode: .friends)

    public init(
        mode: PostAudienceMode,
        allowedGroupIds: [UUID] = [],
        allowedUserIds: [UUID] = [],
        excludedUserIds: [UUID] = []
    ) {
        let uniqueGroupIds = Array(Set(allowedGroupIds)).sorted { $0.uuidString < $1.uuidString }
        let uniqueUserIds = Array(Set(allowedUserIds)).sorted { $0.uuidString < $1.uuidString }
        let uniqueExcludedUserIds = Array(Set(excludedUserIds)).sorted { $0.uuidString < $1.uuidString }

        self.mode = mode
        switch mode {
        case .friends:
            self.allowedGroupIds = []
            self.allowedUserIds = []
            self.excludedUserIds = []
        case .groups:
            self.allowedGroupIds = uniqueGroupIds
            self.allowedUserIds = []
            self.excludedUserIds = []
        case .specificUsers:
            self.allowedGroupIds = []
            self.allowedUserIds = uniqueUserIds
            self.excludedUserIds = []
        case .friendsExcept:
            self.allowedGroupIds = []
            self.allowedUserIds = []
            self.excludedUserIds = uniqueExcludedUserIds
        }
    }

    public var requiresSelection: Bool {
        switch mode {
        case .friends:
            return false
        case .groups:
            return allowedGroupIds.isEmpty
        case .specificUsers:
            return allowedUserIds.isEmpty
        case .friendsExcept:
            return excludedUserIds.isEmpty
        }
    }
}
