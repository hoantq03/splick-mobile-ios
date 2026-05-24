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
        guard let imageData = input.imageData else {
            throw NetworkError.unknown("Missing image data")
        }

        let upload = try await mediaRepository.uploadImage(
            data: imageData,
            mimeType: "image/jpeg",
            purpose: .postImage,
            groupId: input.groupId
        )

        let billSplitRequest = buildBillSplitRequest(from: input)
        let request = CreatePostRequestDTO(
            caption: input.caption,
            groupId: input.groupId,
            feedKind: input.feedKind.rawValue,
            checkInPlace: input.checkInPlace,
            imageUrl: upload.url.absoluteString,
            thumbnailUrl: upload.thumbnailURL?.absoluteString,
            videoUrl: input.videoURL?.absoluteString,
            videoDurationSeconds: nil,
            mediaType: input.mediaType.rawValue,
            companionIds: input.companionIds,
            mediaId: upload.id,
            billSplit: billSplitRequest
        )

        let dto: PostDTO = try await apiClient.request(FeedEndpoint.createPost(request))
        return FeedMapper.toPost(dto)
    }

    public func addComment(postId: UUID, body: String, parentCommentId: UUID?) async throws {
        let request = CreateCommentRequestDTO(body: body, parentCommentId: parentCommentId)
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
