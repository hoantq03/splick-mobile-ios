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

final class MockReactToPostUseCase: ReactToPostUseCaseProtocol, Sendable {
    func execute(postId: UUID, emoji: String) async throws -> Reaction {
        Reaction(id: UUID(), emoji: emoji, userId: PreviewData.currentUser.id)
    }
}

final class MockDeletePostUseCase: DeletePostUseCaseProtocol, Sendable {
    func execute(postId: UUID) async throws {}
}

#Preview("Feed") {
    NavigationStack {
        FeedView(
            viewModel: FeedViewModel(
                fetchFeedUseCase: MockFetchFeedUseCase(),
                reactToPostUseCase: MockReactToPostUseCase(),
                deletePostUseCase: MockDeletePostUseCase(),
                currentUserId: PreviewData.currentUser.id,
                currentUser: UserSummary(
                    id: PreviewData.currentUser.id,
                    username: PreviewData.currentUser.username,
                    displayName: PreviewData.currentUser.displayName,
                    avatarURL: PreviewData.currentUser.avatarURL
                )
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
