import Foundation

public struct PostAudience: Codable, Equatable, Sendable {
    public let isPublic: Bool
    public let allowedGroupIds: [UUID]
    public let allowedUserIds: [UUID]

    public static let everyone = PostAudience(isPublic: true)

    public var isRestricted: Bool { !isPublic }

    public init(
        isPublic: Bool,
        allowedGroupIds: [UUID] = [],
        allowedUserIds: [UUID] = []
    ) {
        let uniqueGroupIds = Array(Set(allowedGroupIds)).sorted { $0.uuidString < $1.uuidString }
        let uniqueUserIds = Array(Set(allowedUserIds)).sorted { $0.uuidString < $1.uuidString }

        self.isPublic = isPublic
        self.allowedGroupIds = isPublic ? [] : uniqueGroupIds
        self.allowedUserIds = isPublic ? [] : uniqueUserIds
    }

    public init(
        allowedGroupIds: [UUID],
        allowedUserIds: [UUID]
    ) {
        self.init(
            isPublic: allowedGroupIds.isEmpty && allowedUserIds.isEmpty,
            allowedGroupIds: allowedGroupIds,
            allowedUserIds: allowedUserIds
        )
    }
}
