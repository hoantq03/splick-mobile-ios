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

final class MockFetchPhotoAlbumUseCase: FetchPhotoAlbumUseCaseProtocol, Sendable {
    func execute(page: Int, filters: PhotoAlbumFilters) async throws -> [AlbumPhoto] {
        _ = filters
        _ = page
        return PreviewData.samplePosts.flatMap { post in
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
