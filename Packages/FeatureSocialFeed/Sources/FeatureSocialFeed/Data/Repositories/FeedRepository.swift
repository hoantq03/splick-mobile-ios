import Foundation
import Networking
import Common
import SplickDomain
import FeatureMedia

public final class FeedRepository: FeedRepositoryProtocol, Sendable {
    private let apiClient: APIClientProtocol
    private let mediaRepository: MediaRepositoryProtocol

    public init(
        apiClient: APIClientProtocol,
        mediaRepository: MediaRepositoryProtocol
    ) {
        self.apiClient = apiClient
        self.mediaRepository = mediaRepository
    }

    public func fetchFeed(page: Int, limit: Int) async throws -> [Post] {
        let dtos: [PostDTO] = try await apiClient.request(FeedEndpoint.feed(page: page, limit: limit))
        return dtos.map(FeedMapper.toPost)
    }

    public func fetchPhotoAlbumFirstPage(
        limit: Int,
        filters: PhotoAlbumFilters = PhotoAlbumFilters()
    ) async throws -> AlbumPhotoPage {
        let dtos: [AlbumPhotoDTO] = try await apiClient.request(
            FeedEndpoint.photoAlbumFirstPage(limit: limit, filters: filters)
        )
        let photos = dtos.compactMap(FeedMapper.toAlbumPhoto)
        let nextCursor = makeNextCursor(from: photos, limit: limit)
        return AlbumPhotoPage(photos: photos, nextCursor: nextCursor)
    }

    public func fetchPhotoAlbumNextPage(
        limit: Int,
        filters: PhotoAlbumFilters,
        cursor: String
    ) async throws -> AlbumPhotoPage {
        let pageDTO: AlbumPhotoPageDTO = try await apiClient.request(
            FeedEndpoint.photoAlbumCursor(cursor: cursor, limit: limit, filters: filters)
        )
        let photos = pageDTO.items.compactMap(FeedMapper.toAlbumPhoto)
        return AlbumPhotoPage(photos: photos, nextCursor: pageDTO.nextCursor)
    }

    private func makeNextCursor(from photos: [AlbumPhoto], limit: Int) -> String? {
        guard photos.count >= limit, let last = photos.last else { return nil }
        return AlbumPhotoCursor.encode(createdAt: last.createdAt, mediaItemId: last.id)
    }

    public func fetchPost(id: UUID) async throws -> Post {
        let dto: PostDTO = try await apiClient.request(FeedEndpoint.post(id: id))
        return FeedMapper.toPost(dto)
    }

    public func addReaction(postId: UUID, emoji: String) async throws -> Reaction {
        let requestDTO = CreateReactionRequestDTO(emoji: emoji)
        let dto: ReactionDTO = try await apiClient.request(
            FeedEndpoint.addReaction(postId: postId, requestDTO)
        )
        return FeedMapper.toReaction(dto)
    }

    public func removeReaction(postId: UUID, reactionId: UUID) async throws {
        try await apiClient.request(FeedEndpoint.removeReaction(postId: postId, reactionId: reactionId))
    }

    public func createPost(_ input: CreatePostInput) async throws -> Post {
        guard !input.mediaItems.isEmpty else {
            throw NetworkError.unknown("Missing media items")
        }

        var requestMediaItems: [CreatePostMediaItemRequestDTO] = []
        var primaryMediaId: UUID?
        for (index, mediaItem) in input.mediaItems.enumerated() {
            let upload = try await mediaRepository.uploadImage(
                data: mediaItem.data,
                mimeType: mediaItem.mimeType,
                purpose: .postImage,
                groupId: input.groupId
            )
            if primaryMediaId == nil {
                primaryMediaId = upload.id
            }
            requestMediaItems.append(
                CreatePostMediaItemRequestDTO(
                    mediaUrl: upload.url.absoluteString,
                    thumbnailUrl: upload.thumbnailURL?.absoluteString,
                    mediaType: mediaItem.mediaType.rawValue,
                    durationSecs: mediaItem.videoDurationSeconds,
                    sortOrder: index
                )
            )
        }

        let billSplitRequest = buildBillSplitRequest(from: input)
        let request = CreatePostRequestDTO(
            caption: input.caption,
            groupId: input.groupId,
            feedKind: input.feedKind.rawValue,
            checkInPlace: input.checkInPlace,
            location: nil,
            mediaItems: requestMediaItems,
            companionIds: input.companionIds,
            mediaId: primaryMediaId,
            billSplit: billSplitRequest
        )

        let dto: PostDTO = try await apiClient.request(FeedEndpoint.createPost(request))
        return FeedMapper.toPost(dto)
    }

    public func addComment(
        postId: UUID,
        body: String?,
        parentCommentId: UUID?,
        submissionAttachments: [CommentSubmissionAttachment] = []
    ) async throws {
        var attachmentDTOs: [CreateCommentAttachmentRequestDTO] = []
        for submission in submissionAttachments {
            if submission.isRemoteOnly, let remoteURL = submission.remoteURL {
                attachmentDTOs.append(
                    CreateCommentAttachmentRequestDTO(
                        kind: submission.kind.rawValue,
                        mediaId: nil,
                        url: remoteURL.absoluteString,
                        fileName: submission.fileName,
                        thumbnailUrl: remoteURL.absoluteString,
                        sizeBytes: nil
                    )
                )
            } else if let data = submission.data, let mimeType = submission.mimeType {
                let upload = try await mediaRepository.uploadImage(
                    data: data,
                    mimeType: mimeType,
                    purpose: .commentAttachment,
                    groupId: nil
                )
                attachmentDTOs.append(
                    CreateCommentAttachmentRequestDTO(
                        kind: submission.kind.rawValue,
                        mediaId: upload.id,
                        url: upload.url.absoluteString,
                        fileName: submission.fileName,
                        thumbnailUrl: upload.thumbnailURL?.absoluteString,
                        sizeBytes: upload.sizeBytes
                    )
                )
            }
        }

        let trimmedBody = body?.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedBody = (trimmedBody?.isEmpty ?? true) ? nil : trimmedBody
        let request = CreateCommentRequestDTO(
            body: normalizedBody,
            parentCommentId: parentCommentId,
            attachments: attachmentDTOs.isEmpty ? nil : attachmentDTOs
        )
        try await apiClient.request(FeedEndpoint.addComment(postId: postId, request))
    }

    public func deletePost(id: UUID) async throws {
        try await apiClient.request(FeedEndpoint.deletePost(id: id))
    }

    private func buildBillSplitRequest(from input: CreatePostInput) -> CreatePostBillSplitRequestDTO? {
        guard input.feedKind == .shareBill, let billSplit = input.billSplit else {
            return nil
        }

        let participants = billSplit.splits.map(\.user.id)
        let splitType = (input.billSplitType ?? "EQUAL").uppercased()

        var customAmounts: [String: String]?
        if splitType == "EXACT" || splitType == "PERCENTAGE" {
            customAmounts = Dictionary(
                uniqueKeysWithValues: billSplit.splits.map { ($0.user.id.uuidString, "\($0.amount)") }
            )
        }

        return CreatePostBillSplitRequestDTO(
            totalAmount: "\(billSplit.totalAmount)",
            currency: billSplit.currency,
            splitType: splitType,
            participants: participants,
            customAmounts: customAmounts,
            autoReminderEnabled: input.autoReminderEnabled ? true : nil
        )
    }

    public func sendBillReminder(
        postId: UUID,
        targetUserIds: [UUID]?,
        message: String
    ) async throws -> SendBillReminderResult {
        let request = SendPostBillReminderRequestDTO(
            targetUserIds: targetUserIds,
            message: message
        )
        let response: SendPostBillReminderResponseDTO = try await apiClient.request(
            FeedEndpoint.sendBillReminder(postId: postId, request)
        )
        return SendBillReminderResult(
            sentCount: response.sentCount,
            skippedCount: response.skippedCount
        )
    }

    public func fetchStreakSummary() async throws -> StreakSummary {
        let dto: StreakSummaryDTO = try await apiClient.request(FeedEndpoint.streakSummary)
        return FeedMapper.toStreakSummary(dto)
    }

    public func fetchStreakCalendar(year: Int, month: Int) async throws -> [StreakDay] {
        let dtos: [StreakDayDTO] = try await apiClient.request(
            FeedEndpoint.streakCalendar(year: year, month: month)
        )
        return dtos.compactMap(FeedMapper.toStreakDay)
    }

    public func fetchStreakDayPhotos(date: String) async throws -> [AlbumPhoto] {
        let dtos: [AlbumPhotoDTO] = try await apiClient.request(
            FeedEndpoint.streakDayPhotos(date: date)
        )
        return dtos.compactMap(FeedMapper.toAlbumPhoto)
    }
}
