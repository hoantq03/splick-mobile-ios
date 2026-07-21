import XCTest
import SplickDomain
@testable import FeatureFriends

@MainActor
final class FriendUserProfileViewModelPostsTests: XCTestCase {
    func test_isOwnProfile_whenUserMatchesCurrentUser() {
        let user = makeUser()
        let viewModel = FriendUserProfileViewModel(
            user: user,
            currentUserId: user.id,
            fetchUserProfileUseCase: nil
        )

        XCTAssertTrue(viewModel.isOwnProfile)
    }

    func test_loadPostsAndNextPage_appendsUniquePosts() async {
        let user = makeUser()
        let firstPage = (0..<20).map { makePost(author: user, index: $0) }
        let nextPost = makePost(author: user, index: 20)
        let useCase = StubFetchUserPostsUseCase(pages: [0: firstPage, 1: [nextPost]])
        let viewModel = FriendUserProfileViewModel(
            user: user,
            currentUserId: UUID(),
            fetchUserProfileUseCase: nil,
            fetchUserPostsUseCase: useCase
        )

        await viewModel.loadPostsIfNeeded()
        await viewModel.loadMorePostsIfNeeded(currentPostId: firstPage.last!.id)

        XCTAssertEqual(viewModel.posts.count, 21)
        XCTAssertEqual(viewModel.posts.last?.id, nextPost.id)
        XCTAssertFalse(viewModel.canLoadMorePosts)
    }

    func test_loadPostsFailure_exposesErrorWithoutPosts() async {
        let user = makeUser()
        let viewModel = FriendUserProfileViewModel(
            user: user,
            fetchUserProfileUseCase: nil,
            fetchUserPostsUseCase: StubFetchUserPostsUseCase(error: TestError.failed)
        )

        await viewModel.loadPostsIfNeeded()

        XCTAssertTrue(viewModel.posts.isEmpty)
        XCTAssertNotNil(viewModel.postsError)
    }

    private func makeUser() -> UserSummary {
        UserSummary(
            id: UUID(),
            username: "profile-user",
            displayName: "Profile User",
            avatarURL: nil
        )
    }

    private func makePost(author: UserSummary, index: Int) -> Post {
        Post(
            id: UUID(),
            author: author,
            imageURL: URL(string: "https://example.com/\(index).jpg")!
        )
    }
}

private actor StubFetchUserPostsUseCase: FetchUserPostsUseCaseProtocol {
    private let pages: [Int: [Post]]
    private let error: Error?

    init(pages: [Int: [Post]] = [:], error: Error? = nil) {
        self.pages = pages
        self.error = error
    }

    func execute(authorId: UUID, page: Int) async throws -> [Post] {
        if let error {
            throw error
        }
        return pages[page] ?? []
    }
}

private enum TestError: Error {
    case failed
}
