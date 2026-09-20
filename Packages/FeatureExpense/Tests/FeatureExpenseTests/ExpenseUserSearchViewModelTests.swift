import XCTest
import SplickDomain
@testable import FeatureExpense

private final class MockUserSearchUseCase: UserSearchUseCaseProtocol, @unchecked Sendable {
    var usersToReturn: [UserSummary] = []
    var shouldThrow = false
    private(set) var executedQueries: [(query: String, page: Int, limit: Int)] = []

    func execute(query: String, page: Int, limit: Int) async throws -> [UserSummary] {
        executedQueries.append((query, page, limit))
        if shouldThrow {
            throw URLError(.badServerResponse)
        }
        return usersToReturn
    }
}

final class ExpenseUserSearchViewModelTests: XCTestCase {

    @MainActor
    func testSearchPaginationAndReset() async {
        let mockUseCase = MockUserSearchUseCase()
        let vm = ExpenseUserSearchViewModel(useCase: mockUseCase, pageSize: 2)

        let user1 = UserSummary(id: UUID(), username: "alice", displayName: "Alice", avatarURL: nil)
        let user2 = UserSummary(id: UUID(), username: "bob", displayName: "Bob", avatarURL: nil)
        let user3 = UserSummary(id: UUID(), username: "charlie", displayName: "Charlie", avatarURL: nil)

        // First batch
        mockUseCase.usersToReturn = [user1, user2]
        vm.reset(query: "test")

        // Wait for search task
        try? await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(vm.users.count, 2)
        XCTAssertTrue(vm.hasMore)

        // Load next page
        mockUseCase.usersToReturn = [user3]
        await vm.loadMoreIfNeeded(current: user2)

        XCTAssertEqual(vm.users.count, 3)
        XCTAssertFalse(vm.hasMore) // since batch.count (1) < pageSize (2)

        // Reset with empty or new query
        mockUseCase.usersToReturn = []
        vm.reset(query: "new")
        try? await Task.sleep(for: .milliseconds(50))
        XCTAssertTrue(vm.users.isEmpty)
    }

    @MainActor
    func testSearchErrorHandling() async {
        let mockUseCase = MockUserSearchUseCase()
        mockUseCase.shouldThrow = true
        let vm = ExpenseUserSearchViewModel(useCase: mockUseCase)

        vm.reset(query: "fail")
        try? await Task.sleep(for: .milliseconds(50))

        XCTAssertFalse(vm.hasMore)
        XCTAssertTrue(vm.users.isEmpty)
    }

    @MainActor
    func testNilUseCaseDoesNothing() async {
        let vm = ExpenseUserSearchViewModel(useCase: nil)
        vm.reset(query: "nothing")
        await vm.loadMore()
        XCTAssertTrue(vm.users.isEmpty)
    }
}
