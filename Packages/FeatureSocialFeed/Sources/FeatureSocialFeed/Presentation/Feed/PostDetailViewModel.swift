import Foundation
import SplickDomain

@MainActor
final class PostDetailViewModel: ObservableObject {
    @Published private(set) var displayedTopLevel: [PostComment] = []
    @Published private(set) var isLoadingPage = false
    @Published var expandedParents: Set<UUID> = []

    let pageSize = 20
    let repliesPreviewCount = 2

    private(set) var allComments: [PostComment] = []
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

    func expandReplies(for parentId: UUID) {
        expandedParents.insert(parentId)
    }

    /// Expands "view more replies" for every ancestor so nested targets stay visible.
    func expandAncestorChain(of comment: PostComment) {
        var parentId = comment.parentCommentId
        while let id = parentId {
            expandedParents.insert(id)
            parentId = allComments.first(where: { $0.id == id })?.parentCommentId
        }
    }

    func refresh(with comments: [PostComment]) {
        let previousExpanded = expandedParents
        let previousLoaded = loadedTopLevelCount
        allComments = comments
        let topLevel = comments.topLevel
        loadedTopLevelCount = min(max(previousLoaded, pageSize), topLevel.count)
        if loadedTopLevelCount == 0, !topLevel.isEmpty {
            loadedTopLevelCount = min(pageSize, topLevel.count)
        }
        displayedTopLevel = Array(topLevel.prefix(loadedTopLevelCount))
        expandedParents = previousExpanded.filter { parentId in
            comments.contains { $0.id == parentId }
        }
    }
}
