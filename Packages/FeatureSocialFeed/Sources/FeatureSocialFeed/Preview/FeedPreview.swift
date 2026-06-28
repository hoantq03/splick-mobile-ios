import Foundation
import SwiftUI
import SplickDomain

#if DEBUG

final class MockFetchFeedUseCase: FetchFeedUseCaseProtocol, Sendable {
    func execute(page: Int) async throws -> [Post] {
        try await Task.sleep(for: .milliseconds(500))
        return PreviewData.samplePosts
    }
}

final class MockFetchPostUseCase: FetchPostUseCaseProtocol, Sendable {
    func execute(postId: UUID) async throws -> Post {
        PreviewData.samplePosts.first(where: { $0.id == postId }) ?? PreviewData.samplePost
    }
}

final class MockReactToPostUseCase: ReactToPostUseCaseProtocol, Sendable {
    func execute(postId: UUID, emoji: String) async throws -> Reaction {
        Reaction(id: UUID(), emoji: emoji, userId: PreviewData.currentUser.id)
    }
}

final class MockDeletePostUseCase: DeletePostUseCaseProtocol, Sendable {
    func execute(postId: UUID) async throws {}
}

final class MockAddCommentUseCase: AddCommentUseCaseProtocol, Sendable {
    func execute(
        postId: UUID,
        body: String?,
        parentCommentId: UUID?,
        submissionAttachments: [CommentSubmissionAttachment]
    ) async throws {}
}

final class MockSendBillReminderUseCase: SendBillReminderUseCaseProtocol, Sendable {
    func execute(postId: UUID, targetUserIds: [UUID]?, message: String) async throws -> SendBillReminderResult {
        SendBillReminderResult(sentCount: targetUserIds?.count ?? 1, skippedCount: 0)
    }
}

final class MockSubmitPaymentEvidenceUseCase: SubmitPaymentEvidenceUseCaseProtocol, Sendable {
    func execute(
        postId: UUID,
        splitId: UUID,
        message: String?,
        submissionAttachments: [CommentSubmissionAttachment]
    ) async throws -> SubmitPaymentEvidenceResult {
        _ = postId
        _ = splitId
        _ = message
        _ = submissionAttachments
        return SubmitPaymentEvidenceResult(evidenceId: UUID(), commentId: UUID())
    }
}

final class MockApprovePaymentEvidenceUseCase: ApprovePaymentEvidenceUseCaseProtocol, Sendable {
    func execute(postId: UUID, evidenceId: UUID) async throws {
        _ = postId
        _ = evidenceId
    }
}

final class MockRejectPaymentEvidenceUseCase: RejectPaymentEvidenceUseCaseProtocol, Sendable {
    func execute(postId: UUID, evidenceId: UUID, reason: String) async throws {
        _ = postId
        _ = evidenceId
        _ = reason
    }
}

final class MockCreatePostUseCase: CreatePostUseCaseProtocol, Sendable {
    func execute(_ input: CreatePostInput) async throws -> Post {
        _ = input
        return PreviewData.samplePost
    }
}

final class MockFetchStreakUseCase: FetchStreakUseCaseProtocol, Sendable {
    func fetchSummary() async throws -> StreakSummary {
        StreakSummary(currentStreak: 5, hasTodayPhoto: true)
    }

    func fetchCalendar(year: Int, month: Int) async throws -> [StreakDay] {
        let cal = Calendar.current
        var components = DateComponents()
        components.year = year
        components.month = month
        guard let start = cal.date(from: components),
              let range = cal.range(of: .day, in: .month, for: start) else { return [] }
        return range.compactMap { day -> StreakDay? in
            components.day = day
            guard let date = cal.date(from: components) else { return nil }
            let hasPhoto = day % 3 != 0
            return StreakDay(
                date: date,
                firstPhotoURL: hasPhoto ? URL(string: "https://picsum.photos/seed/\(day)/200") : nil,
                firstThumbnailURL: nil,
                photoCount: hasPhoto ? 1 : 0
            )
        }
    }

    func fetchDayPhotos(date: String) async throws -> [AlbumPhoto] {
        PreviewData.samplePosts.prefix(3).flatMap { post in
            post.displayMediaItems.filter { $0.mediaType == .image }.map { item in
                AlbumPhoto(
                    id: item.id,
                    postId: post.id,
                    author: post.author,
                    mediaURL: item.mediaURL,
                    thumbnailURL: item.thumbnailURL,
                    mediaType: item.mediaType,
                    sortOrder: item.sortOrder,
                    createdAt: post.createdAt
                )
            }
        }
    }
}

final class MockFetchPhotoAlbumUseCase: FetchPhotoAlbumUseCaseProtocol, Sendable {
    func fetchFirstPage(filters: PhotoAlbumFilters) async throws -> AlbumPhotoPage {
        _ = filters
        let photos = PreviewData.samplePosts.flatMap { post in
            post.displayMediaItems
                .filter { $0.mediaType == .image }
                .map { item in
                    AlbumPhoto(
                        id: item.id,
                        postId: post.id,
                        author: post.author,
                        mediaURL: item.mediaURL,
                        thumbnailURL: item.thumbnailURL,
                        mediaType: item.mediaType,
                        sortOrder: item.sortOrder,
                        createdAt: post.createdAt
                    )
                }
        }
        return AlbumPhotoPage(photos: photos, nextCursor: nil)
    }

    func fetchNextPage(filters: PhotoAlbumFilters, cursor: String) async throws -> AlbumPhotoPage {
        _ = filters
        _ = cursor
        return AlbumPhotoPage(photos: [], nextCursor: nil)
    }
}

#Preview("Feed") {
    NavigationStack {
        FeedView(
            viewModel: FeedViewModel(
                fetchFeedUseCase: MockFetchFeedUseCase(),
                fetchPostUseCase: MockFetchPostUseCase(),
                reactToPostUseCase: MockReactToPostUseCase(),
                deletePostUseCase: MockDeletePostUseCase(),
                addCommentUseCase: MockAddCommentUseCase(),
                sendBillReminderUseCase: MockSendBillReminderUseCase(),
                submitPaymentEvidenceUseCase: MockSubmitPaymentEvidenceUseCase(),
                approvePaymentEvidenceUseCase: MockApprovePaymentEvidenceUseCase(),
                rejectPaymentEvidenceUseCase: MockRejectPaymentEvidenceUseCase(),
                createPostUseCase: MockCreatePostUseCase(),
                currentUserId: PreviewData.currentUser.id,
                currentUser: UserSummary(
                    id: PreviewData.currentUser.id,
                    username: PreviewData.currentUser.username,
                    displayName: PreviewData.currentUser.displayName,
                    avatarURL: PreviewData.currentUser.avatarURL
                )
            ),
            photoAlbumViewModel: PhotoAlbumViewModel(
                fetchPhotoAlbumUseCase: MockFetchPhotoAlbumUseCase()
            ),
            streakViewModel: StreakViewModel(
                fetchStreakUseCase: MockFetchStreakUseCase()
            )
        )
    }
}

#Preview("Post Card") {
    PostCardView(
        post: PreviewData.samplePost,
        currentUser: UserSummary(
            id: PreviewData.currentUser.id,
            username: PreviewData.currentUser.username,
            displayName: PreviewData.currentUser.displayName,
            avatarURL: nil
        ),
        onReact: { _ in },
        onDelete: {},
        onUserTap: { _ in },
        onOpenComments: {},
        onShowCompanions: {}
    )
    .padding()
}

#endif
