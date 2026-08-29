import Foundation
import Networking
import Common
import SplickDomain
import FeatureMedia
import Storage

public final class FeedRepository: FeedRepositoryProtocol, Sendable {
    private let apiClient: APIClientProtocol
    private let mediaRepository: MediaRepositoryProtocol
    private let friendDisplayNameStore: FriendDisplayNameStore?
    private static let maxCachedPosts = 80

    public init(
        apiClient: APIClientProtocol,
        mediaRepository: MediaRepositoryProtocol,
        friendDisplayNameStore: FriendDisplayNameStore? = nil
    ) {
        self.apiClient = apiClient
        self.mediaRepository = mediaRepository
        self.friendDisplayNameStore = friendDisplayNameStore
    }

    public func fetchFeed(
        page: Int,
        limit: Int,
        authorId: UUID? = nil
    ) async throws -> [Post] {
        let dtos: [PostDTO] = try await apiClient.request(
            FeedEndpoint.feed(page: page, limit: limit, authorId: authorId)
        )
        return await resolvePosts(dtos.map(FeedMapper.toPost))
    }

    public func recordPostViews(postIds: [UUID]) async throws -> [Post] {
        guard !postIds.isEmpty else { return [] }
        let dtos: [PostDTO] = try await apiClient.request(
            FeedEndpoint.batchViewed(BatchViewPostsRequestDTO(postIds: Array(postIds.prefix(20))))
        )
        return await resolvePosts(dtos.map(FeedMapper.toPost))
    }

    public func loadCachedFeed(userId: UUID) async -> [Post]? {
        guard let posts = await DiskCache.shared.read(FeedCachePayload.self, key: Self.cacheKey(for: userId))?.posts else {
            return nil
        }
        return await resolvePosts(posts)
    }

    public func saveCachedFeed(_ posts: [Post], userId: UUID) async {
        let capped = Array(posts.prefix(Self.maxCachedPosts))
        await DiskCache.shared.write(FeedCachePayload(posts: capped), key: Self.cacheKey(for: userId))
    }

    private static func cacheKey(for userId: UUID) -> String {
        "feed.page0.\(userId.uuidString)"
    }

    public func fetchPhotoAlbumFirstPage(
        limit: Int,
        filters: PhotoAlbumFilters = PhotoAlbumFilters()
    ) async throws -> AlbumPhotoPage {
        let dtos: [AlbumPhotoDTO] = try await apiClient.request(
            FeedEndpoint.photoAlbumFirstPage(limit: limit, filters: filters)
        )
        let photos = dtos.compactMap(FeedMapper.toAlbumPhoto)
        let resolvedPhotos = await resolveAlbumPhotos(photos)
        let nextCursor = makeNextCursor(from: resolvedPhotos, limit: limit)
        return AlbumPhotoPage(photos: resolvedPhotos, nextCursor: nextCursor)
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
        let resolvedPhotos = await resolveAlbumPhotos(photos)
        return AlbumPhotoPage(photos: resolvedPhotos, nextCursor: pageDTO.nextCursor)
    }

    private func makeNextCursor(from photos: [AlbumPhoto], limit: Int) -> String? {
        guard photos.count >= limit, let last = photos.last else { return nil }
        return AlbumPhotoCursor.encode(createdAt: last.createdAt, mediaItemId: last.id)
    }

    public func fetchPost(id: UUID) async throws -> Post {
        let dto: PostDTO = try await apiClient.request(FeedEndpoint.post(id: id))
        return await resolvePost(FeedMapper.toPost(dto))
    }

    public func fetchPostComments(
        postId: UUID,
        page: Int,
        limit: Int,
        filter: CommentThreadFilter
    ) async throws -> CommentThreadPage {
        let dto: CommentThreadPageDTO = try await apiClient.request(
            FeedEndpoint.postComments(postId: postId, page: page, limit: limit, filter: filter)
        )
        return await resolveCommentThreadPage(FeedMapper.toCommentThreadPage(dto))
    }

    public func fetchPostReactions(postId: UUID) async throws -> [UserReactionSummary] {
        let dto: PostReactionsDTO = try await apiClient.request(FeedEndpoint.postReactions(postId: postId))
        return await resolveReactions(FeedMapper.toPostReactions(dto).items)
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
        let audienceRequest = CreatePostAudienceRequestDTO(
            mode: input.audience.mode.rawValue,
            allowedGroupIds: input.audience.allowedGroupIds,
            allowedUserIds: input.audience.allowedUserIds,
            excludedUserIds: input.audience.excludedUserIds
        )
        let request = CreatePostRequestDTO(
            caption: input.caption,
            groupId: input.groupId,
            feedKind: input.feedKind.rawValue,
            checkInPlace: input.checkInPlace,
            location: input.location.flatMap { place in
                guard place.hasCoordinates else { return nil }
                return CreatePostLocationRequestDTO(
                    placeId: place.placeId,
                    displayName: place.displayName,
                    lat: place.lat,
                    lon: place.lon
                )
            },
            mediaItems: requestMediaItems,
            companionIds: input.companionIds,
            mediaId: primaryMediaId,
            billSplit: billSplitRequest,
            audience: audienceRequest
        )

        let dto: PostDTO = try await apiClient.request(FeedEndpoint.createPost(request))
        return await resolvePost(FeedMapper.toPost(dto))
    }

    public func addComment(
        postId: UUID,
        body: String?,
        parentCommentId: UUID?,
        submissionAttachments: [CommentSubmissionAttachment] = []
    ) async throws {
        let attachmentDTOs = try await buildCommentAttachmentDTOs(from: submissionAttachments)

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

    public func updatePost(_ input: UpdatePostInput) async throws -> Post {
        guard !input.mediaItems.isEmpty else {
            throw NetworkError.unknown("Missing media items")
        }
        var requestMediaItems: [CreatePostMediaItemRequestDTO] = []
        for (index, item) in input.mediaItems.enumerated() {
            switch item {
            case .existing(let media):
                requestMediaItems.append(
                    CreatePostMediaItemRequestDTO(
                        mediaUrl: media.mediaURL.absoluteString,
                        thumbnailUrl: media.thumbnailURL?.absoluteString,
                        mediaType: media.mediaType.rawValue,
                        durationSecs: media.durationSeconds,
                        sortOrder: index
                    )
                )
            case .uploaded(let data, let mimeType, let mediaType, let duration):
                let upload = try await mediaRepository.uploadImage(
                    data: data,
                    mimeType: mimeType,
                    purpose: .postImage,
                    groupId: nil
                )
                requestMediaItems.append(
                    CreatePostMediaItemRequestDTO(
                        mediaUrl: upload.url.absoluteString,
                        thumbnailUrl: upload.thumbnailURL?.absoluteString,
                        mediaType: mediaType.rawValue,
                        durationSecs: duration,
                        sortOrder: index
                    )
                )
            }
        }
        let dto: PostDTO = try await apiClient.request(
            FeedEndpoint.updatePost(
                id: input.postId,
                UpdatePostRequestDTO(caption: input.caption, mediaItems: requestMediaItems)
            )
        )
        return await resolvePosts([FeedMapper.toPost(dto)]).first ?? FeedMapper.toPost(dto)
    }

    public func fetchPostEdits(postId: UUID) async throws -> [PostEditRevision] {
        let dto: PostEditsResponseDTO = try await apiClient.request(FeedEndpoint.postEdits(id: postId))
        return dto.items.map(FeedMapper.toEditRevision)
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
        message: String,
        submissionAttachments: [CommentSubmissionAttachment]
    ) async throws -> SendBillReminderResult {
        let attachmentDTOs = try await buildCommentAttachmentDTOs(from: submissionAttachments)
        let request = SendPostBillReminderRequestDTO(
            targetUserIds: targetUserIds,
            message: message,
            attachments: attachmentDTOs
        )
        let response: SendPostBillReminderResponseDTO = try await apiClient.request(
            FeedEndpoint.sendBillReminder(postId: postId, request)
        )
        return SendBillReminderResult(
            sentCount: response.sentCount,
            skippedCount: response.skippedCount
        )
    }

    public func submitPaymentEvidence(
        postId: UUID,
        splitId: UUID,
        message: String?,
        submissionAttachments: [CommentSubmissionAttachment]
    ) async throws -> SubmitPaymentEvidenceResult {
        let attachmentDTOs = try await buildCommentAttachmentDTOs(from: submissionAttachments)
        let request = SubmitPaymentEvidenceRequestDTO(
            splitId: splitId,
            message: message,
            attachments: attachmentDTOs
        )
        let response: SubmitPaymentEvidenceResponseDTO = try await apiClient.request(
            FeedEndpoint.submitPaymentEvidence(postId: postId, request)
        )
        return SubmitPaymentEvidenceResult(
            evidenceId: response.evidenceId,
            commentId: response.commentId
        )
    }

    public func approvePaymentEvidence(postId: UUID, evidenceId: UUID) async throws {
        try await apiClient.request(
            FeedEndpoint.approvePaymentEvidence(postId: postId, evidenceId: evidenceId)
        )
    }

    public func rejectPaymentEvidence(postId: UUID, evidenceId: UUID, reason: String) async throws {
        let request = RejectPaymentEvidenceRequestDTO(reason: reason)
        try await apiClient.request(
            FeedEndpoint.rejectPaymentEvidence(postId: postId, evidenceId: evidenceId, request)
        )
    }

    private func buildCommentAttachmentDTOs(
        from submissions: [CommentSubmissionAttachment]
    ) async throws -> [CreateCommentAttachmentRequestDTO] {
        var attachmentDTOs: [CreateCommentAttachmentRequestDTO] = []
        for submission in submissions {
            if submission.isPreUploaded {
                if let dto = makeAttachmentDTO(from: submission) {
                    attachmentDTOs.append(dto)
                }
                continue
            }
            if submission.isRemoteOnly, let remoteURL = submission.remoteURL {
                if let dto = makeAttachmentDTO(from: submission) {
                    attachmentDTOs.append(dto)
                }
                continue
            }
            if let data = submission.data, let mimeType = submission.mimeType {
                let upload = try await mediaRepository.uploadImage(
                    data: data,
                    mimeType: mimeType,
                    purpose: .commentAttachment,
                    groupId: nil
                )
                if let dto = makeAttachmentDTO(from: submission, uploaded: upload) {
                    attachmentDTOs.append(dto)
                }
            }
        }
        return attachmentDTOs
    }

    private func makeAttachmentDTO(
        from submission: CommentSubmissionAttachment,
        uploaded: MediaUploadResult? = nil
    ) -> CreateCommentAttachmentRequestDTO? {
        if submission.isPreUploaded,
           let mediaId = submission.uploadedMediaId,
           let url = submission.remoteURL {
            return CreateCommentAttachmentRequestDTO(
                kind: submission.kind.rawValue,
                mediaId: mediaId,
                url: url.absoluteString,
                fileName: submission.fileName,
                thumbnailUrl: submission.uploadedThumbnailURL?.absoluteString,
                sizeBytes: submission.uploadedSizeBytes
            )
        }
        if submission.isRemoteOnly, let remoteURL = submission.remoteURL {
            return CreateCommentAttachmentRequestDTO(
                kind: submission.kind.rawValue,
                mediaId: nil,
                url: remoteURL.absoluteString,
                fileName: submission.fileName,
                thumbnailUrl: remoteURL.absoluteString,
                sizeBytes: nil
            )
        }
        if let upload = uploaded {
            return CreateCommentAttachmentRequestDTO(
                kind: submission.kind.rawValue,
                mediaId: upload.id,
                url: upload.url.absoluteString,
                fileName: submission.fileName,
                thumbnailUrl: upload.thumbnailURL?.absoluteString,
                sizeBytes: upload.sizeBytes
            )
        }
        return nil
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
        return await resolveAlbumPhotos(dtos.compactMap(FeedMapper.toAlbumPhoto))
    }

    public func searchLocations(query: String, lat: Double?, lon: Double?) async throws -> [PostPlace] {
        let dto: LocationSearchResponseDTO = try await apiClient.request(
            FeedEndpoint.searchLocations(query: query, limit: 10, lat: lat, lon: lon)
        )
        return dto.locations.compactMap(FeedMapper.toPlace)
    }

    public func nearbyLocations(lat: Double, lon: Double, radiusMeters: Int) async throws -> [PostPlace] {
        let dto: LocationSearchResponseDTO = try await apiClient.request(
            FeedEndpoint.nearbyLocations(lat: lat, lon: lon, radius: radiusMeters, limit: 10)
        )
        return dto.locations.compactMap(FeedMapper.toPlace)
    }

    private func resolvePosts(_ posts: [Post]) async -> [Post] {
        guard let friendDisplayNameStore else { return posts }
        return await friendDisplayNameStore.resolve(posts)
    }

    private func resolvePost(_ post: Post) async -> Post {
        guard let friendDisplayNameStore else { return post }
        return await friendDisplayNameStore.resolve(post)
    }

    private func resolveCommentThreadPage(_ page: CommentThreadPage) async -> CommentThreadPage {
        guard let friendDisplayNameStore else { return page }
        return await friendDisplayNameStore.resolve(page)
    }

    private func resolveReactions(_ reactions: [UserReactionSummary]) async -> [UserReactionSummary] {
        guard let friendDisplayNameStore else { return reactions }
        return await friendDisplayNameStore.resolve(reactions)
    }

    private func resolveAlbumPhotos(_ photos: [AlbumPhoto]) async -> [AlbumPhoto] {
        guard let friendDisplayNameStore else { return photos }
        return await friendDisplayNameStore.resolve(photos)
    }
}
