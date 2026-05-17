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

#Preview("Feed") {
    FeedView(
        viewModel: FeedViewModel(
            fetchFeedUseCase: MockFetchFeedUseCase(),
            reactToPostUseCase: MockReactToPostUseCase()
        )
    )
}

#Preview("Post Card") {
    PostCardView(post: PreviewData.samplePost) { _ in }
        .padding()
}

#endif
