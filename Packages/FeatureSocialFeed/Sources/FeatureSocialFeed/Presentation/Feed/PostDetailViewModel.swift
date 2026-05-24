import Foundation
import SplickDomain

@MainActor
final class PostDetailViewModel: ObservableObject {
    @Published private(set) var displayedTopLevel: [PostComment] = []
    @Published private(set) var isLoadingPage = false

    let pageSize = 20
    private(set) var allComments: [PostComment]
    private var loadedTopLevelCount = 0

    var canLoadMore: Bool {
        loadedTopLevelCount < allComments.topLevel.count
    }

    init(comments: [PostComment]) {
        self.allComments = comments
    }

    func loadInitial() {
        guard displayedTopLevel.isEmpty else { return }
        loadNextPage()
    }

    func loadNextPage() {
        guard canLoadMore, !isLoadingPage else { return }
        isLoadingPage = true

        let topLevel = allComments.topLevel
        let end = min(loadedTopLevelCount + pageSize, topLevel.count)
        let slice = Array(topLevel[loadedTopLevelCount..<end])
        displayedTopLevel.append(contentsOf: slice)
        loadedTopLevelCount = end
        isLoadingPage = false
    }

    func children(of commentId: UUID) -> [PostComment] {
        allComments.children(of: commentId)
    }

    func refresh(with comments: [PostComment]) {
        allComments = comments
        let topLevel = comments.topLevel
        displayedTopLevel = Array(topLevel.prefix(max(loadedTopLevelCount, pageSize)))
        loadedTopLevelCount = displayedTopLevel.count
    }
}
