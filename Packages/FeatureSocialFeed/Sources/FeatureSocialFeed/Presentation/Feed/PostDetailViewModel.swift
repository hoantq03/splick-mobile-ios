import Foundation
import SplickDomain
import Common

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
        commentsLoaded = false
        hasMore = false
        await reload()
    }

    func loadNextPage() async {
        guard hasMore, !isLoadingPage else { return }
        await fetchPages(reset: false, ensureVisibleId: nil)
    }

    func reload(
        ensureVisibleId: UUID? = nil,
        loadThroughEnd: Bool = false,
        scrollToPendingEvidence: Bool = false,
        preferPendingEvidence: ((PostComment) -> Bool)? = nil
    ) async {
        await fetchPages(
            reset: true,
            ensureVisibleId: ensureVisibleId,
            loadThroughEnd: loadThroughEnd,
            scrollToPendingEvidence: scrollToPendingEvidence,
            preferPendingEvidence: preferPendingEvidence
        )
    }

    /// Pending payment-evidence comment to bring into view (approve / review flows).
    func firstPendingEvidenceCommentId(
        preferring prefer: ((PostComment) -> Bool)? = nil
    ) -> UUID? {
        Self.firstPendingEvidenceCommentId(in: allComments, preferring: prefer)
    }

    static func firstPendingEvidenceCommentId(
        in comments: [PostComment],
        preferring prefer: ((PostComment) -> Bool)? = nil
    ) -> UUID? {
        let pending = comments
            .filter { $0.isEvidence && !$0.isDeleted && $0.evidenceStatus == .pending }
            .sorted {
                if $0.createdAt != $1.createdAt { return $0.createdAt < $1.createdAt }
                return $0.id.uuidString < $1.id.uuidString
            }
        if let prefer, let match = pending.first(where: prefer) {
            return match.id
        }
        return pending.first?.id
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

    /// Newest matching comment after a reload, when the create API does not return an id.
    func latestMatchingCommentId(authorId: UUID?, parentCommentId: UUID?) -> UUID? {
        allComments
            .filter { comment in
                comment.parentCommentId == parentCommentId
                    && (authorId == nil || comment.author.id == authorId)
            }
            .max(by: { $0.createdAt < $1.createdAt })?
            .id
    }

    private func fetchPages(
        reset: Bool,
        ensureVisibleId: UUID?,
        loadThroughEnd: Bool = false,
        scrollToPendingEvidence: Bool = false,
        preferPendingEvidence: ((PostComment) -> Bool)? = nil
    ) async {
        await SplickViewUpdate.hop()
        requestID += 1
        let currentRequest = requestID
        if reset { nextPage = 0 }
        isLoadingPage = true
        defer {
            if currentRequest == requestID {
                isLoadingPage = false
            }
        }

        if let ensureVisibleId {
            alignFilterIfNeeded(for: ensureVisibleId, in: allComments)
        } else if scrollToPendingEvidence {
            // Evidence-only list is small and matches the approval destination.
            commentFilter = .evidence
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
                let pendingTarget = scrollToPendingEvidence
                    ? Self.firstPendingEvidenceCommentId(in: merged, preferring: preferPendingEvidence)
                    : nil
                let found: Bool
                if let ensureVisibleId {
                    found = merged.contains(where: { $0.id == ensureVisibleId })
                } else if scrollToPendingEvidence {
                    found = pendingTarget != nil
                } else {
                    found = true
                }
                if loadThroughEnd {
                    if !more { break }
                } else if found || !more {
                    break
                }
            } while page < 50

            await SplickViewUpdate.hop()
            guard currentRequest == requestID else { return }
            allComments = merged
            displayedTopLevel = displayed
            hasMore = more
            commentsLoaded = true
            let pendingTarget = scrollToPendingEvidence
                ? Self.firstPendingEvidenceCommentId(in: merged, preferring: preferPendingEvidence)
                : nil
            if let visibleId = ensureVisibleId ?? pendingTarget {
                ensureCommentVisible(visibleId)
            }
        } catch {
            commentsLoaded = true
        }
    }

    /// Switch away from a filter that would hide the target root (e.g. Comments vs Evidence).
    private func alignFilterIfNeeded(for commentId: UUID, in comments: [PostComment]) {
        var current = comments.first(where: { $0.id == commentId })
        while let parentId = current?.parentCommentId {
            current = comments.first(where: { $0.id == parentId }) ?? current
            if current?.parentCommentId == nil { break }
        }
        guard let root = current, root.parentCommentId == nil else { return }
        guard !commentFilter.includesRoot(root) else { return }
        switch root.commentType {
        case .evidence:
            commentFilter = .evidence
        case .standard, .evidenceModeration:
            commentFilter = .comments
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
