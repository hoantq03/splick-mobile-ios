import Foundation
import SplickDomain

public struct CreatePostInput: Sendable {
    public let imageData: Data?
    public let mediaType: PostMediaType
    public let videoURL: URL?
    public let caption: String?
    public let companionIds: [UUID]
    public let checkInPlace: String?
    public let feedKind: PostFeedKind
    public let billSplit: PostBillSplit?
    public let billSplitType: String?
    public let groupId: UUID?

    public init(
        imageData: Data?,
        mediaType: PostMediaType,
        videoURL: URL? = nil,
        caption: String?,
        companionIds: [UUID] = [],
        checkInPlace: String? = nil,
        feedKind: PostFeedKind = .checkIn,
        billSplit: PostBillSplit? = nil,
        billSplitType: String? = nil,
        groupId: UUID? = nil
    ) {
        self.imageData = imageData
        self.mediaType = mediaType
        self.videoURL = videoURL
        self.caption = caption
        self.companionIds = companionIds
        self.checkInPlace = checkInPlace
        self.feedKind = feedKind
        self.billSplit = billSplit
        self.billSplitType = billSplitType
        self.groupId = groupId
    }
}
