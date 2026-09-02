import Foundation
import SplickDomain

public struct PendingCompanionInput: Sendable {
    public let displayName: String
    public let email: String?
    public let amount: Decimal?

    public init(displayName: String, email: String? = nil, amount: Decimal? = nil) {
        self.displayName = displayName
        self.email = email
        self.amount = amount
    }
}

public struct CreatePostMediaInput: Sendable {
    public let data: Data
    public let mimeType: String
    public let mediaType: PostMediaType
    public let videoDurationSeconds: Int?

    public init(data: Data, mimeType: String, mediaType: PostMediaType, videoDurationSeconds: Int? = nil) {
        self.data = data
        self.mimeType = mimeType
        self.mediaType = mediaType
        self.videoDurationSeconds = videoDurationSeconds
    }
}

public struct CreatePostInput: Sendable {
    public let mediaItems: [CreatePostMediaInput]
    public let caption: String?
    public let companionIds: [UUID]
    public let companionGroupName: String?
    public let checkInPlace: String?
    public let location: PostPlace?
    public let feedKind: PostFeedKind
    public let billSplit: PostBillSplit?
    public let billSplitType: String?
    public let autoReminderEnabled: Bool
    public let pendingCompanions: [PendingCompanionInput]
    public let audience: PostAudience
    public let groupId: UUID?

    public init(
        mediaItems: [CreatePostMediaInput],
        caption: String?,
        companionIds: [UUID] = [],
        companionGroupName: String? = nil,
        checkInPlace: String? = nil,
        location: PostPlace? = nil,
        feedKind: PostFeedKind = .checkIn,
        billSplit: PostBillSplit? = nil,
        billSplitType: String? = nil,
        autoReminderEnabled: Bool = false,
        pendingCompanions: [PendingCompanionInput] = [],
        audience: PostAudience = .friends,
        groupId: UUID? = nil
    ) {
        self.mediaItems = mediaItems
        self.caption = caption
        self.companionIds = companionIds
        self.companionGroupName = companionGroupName
        self.checkInPlace = checkInPlace
        self.location = location
        self.feedKind = feedKind
        self.billSplit = billSplit
        self.billSplitType = billSplitType
        self.autoReminderEnabled = autoReminderEnabled
        self.pendingCompanions = pendingCompanions
        self.audience = audience
        self.groupId = groupId
    }
}
