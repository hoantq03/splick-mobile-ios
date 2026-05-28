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
            let upload = try await mediaRepository.uploadImage(
                data: submission.data,
                mimeType: submission.mimeType,
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
            customAmounts: customAmounts
        )
    }
}
