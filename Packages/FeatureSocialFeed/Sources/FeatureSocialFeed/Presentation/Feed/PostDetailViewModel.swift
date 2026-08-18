import Foundation
import SplickDomain

@MainActor
final class PostDetailViewModel: ObservableObject {
    typealias FetchPage = (UUID, Int, Int, CommentThreadFilter) async throws -> CommentThreadPage

    @Published private(set) var displayedTopLevel: [PostComment] = []
    @Published private(set) var allComments: [PostComment] = []
    @Published private(set) var isLoadingPage = false
    @Published private(set) var hasMore = false
    @Published private(set) var commentsLoaded = false
    @Published var expandedParents: Set<UUID> = []
    @Published var commentFilter: CommentThreadFilter = .all

    let pageSize = 20
    let repliesPreviewCount = 2
    let postId: UUID

    private let fetchPage: FetchPage
    private var nextPage = 0
    private var requestID = 0

    var canLoadMore: Bool { hasMore }

    init(postId: UUID, fetchPage: @escaping FetchPage) {
        self.postId = postId
        self.fetchPage = fetchPage
    }

    func loadInitial() async {
        guard !commentsLoaded else { return }
        await reload()
    }

    func setFilter(_ filter: CommentThreadFilter) async {
        guard filter != commentFilter else { return }
        commentFilter = filter
        allComments = []
        displayedTopLevel = []
        commentsLoaded = false
        hasMore = false
        await reload()
    }

    func loadNextPage() async {
        guard hasMore, !isLoadingPage else { return }
        await fetchPages(reset: false, ensureVisibleId: nil)
    }

    func reload(ensureVisibleId: UUID? = nil) async {
        await fetchPages(reset: true, ensureVisibleId: ensureVisibleId)
    }

    func upsertOptimistic(_ comment: PostComment) {
        allComments = merge(allComments, with: [comment])
        if comment.parentCommentId == nil, displayedTopLevel.contains(where: { $0.id == comment.id }) == false {
            displayedTopLevel.append(comment)
        }
        expandAncestorChain(of: comment)
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

    /// Ensures a comment (and its ancestors) are mounted so `ScrollViewReader` can target it.
    func ensureCommentVisible(_ commentId: UUID) {
        guard let comment = allComments.first(where: { $0.id == commentId }) else { return }
        expandAncestorChain(of: comment)
        if let parentId = comment.parentCommentId {
            expandReplies(for: parentId)
        }
    }

    private func fetchPages(reset: Bool, ensureVisibleId: UUID?) async {
        requestID += 1
        let currentRequest = requestID
        if reset { nextPage = 0 }
        isLoadingPage = true
        defer {
            if currentRequest == requestID {
                isLoadingPage = false
            }
        }

        do {
            var page = reset ? 0 : nextPage
            var merged = reset ? [PostComment]() : allComments
            var displayed = reset ? [PostComment]() : displayedTopLevel
            var more: Bool
            repeat {
                let result = try await fetchPage(postId, page, pageSize, commentFilter)
                guard currentRequest == requestID else { return }
                merged = merge(merged, with: result.comments)
                let pageRoots = result.comments.filter { $0.parentCommentId == nil }
                if reset, page == 0 {
                    displayed = pageRoots
                } else {
                    let existing = Set(displayed.map(\.id))
                    displayed.append(contentsOf: pageRoots.filter { !existing.contains($0.id) })
                }
                more = result.hasMore
                page += 1
                nextPage = page
                let found = ensureVisibleId == nil || merged.contains(where: { $0.id == ensureVisibleId })
                if found || !more { break }
            } while page < 50

            allComments = merged
            displayedTopLevel = displayed
            hasMore = more
            commentsLoaded = true
            if let ensureVisibleId {
                ensureCommentVisible(ensureVisibleId)
            }
        } catch {
            commentsLoaded = true
        }
    }

    private func merge(_ existing: [PostComment], with incoming: [PostComment]) -> [PostComment] {
        var byId: [UUID: PostComment] = [:]
        var order: [UUID] = []
        for comment in existing + incoming {
            if byId[comment.id] == nil {
                order.append(comment.id)
            }
            byId[comment.id] = comment
        }
        return order.compactMap { byId[$0] }
    }
}
