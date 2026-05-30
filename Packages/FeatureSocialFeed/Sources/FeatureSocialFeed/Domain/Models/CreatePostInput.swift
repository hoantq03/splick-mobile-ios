import Foundation
import SplickDomain

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
    public let checkInPlace: String?
    public let feedKind: PostFeedKind
    public let billSplit: PostBillSplit?
    public let billSplitType: String?
    public let groupId: UUID?

    public init(
        mediaItems: [CreatePostMediaInput],
        caption: String?,
        companionIds: [UUID] = [],
        checkInPlace: String? = nil,
        feedKind: PostFeedKind = .checkIn,
        billSplit: PostBillSplit? = nil,
        billSplitType: String? = nil,
        groupId: UUID? = nil
    ) {
        self.mediaItems = mediaItems
        self.caption = caption
        self.companionIds = companionIds
        self.checkInPlace = checkInPlace
        self.feedKind = feedKind
        self.billSplit = billSplit
        self.billSplitType = billSplitType
        self.groupId = groupId
    }
}
