import Foundation
import SwiftUI
import Common
import DesignSystem
import Localization
import SplickDomain

enum FriendsDirectoryItem: Identifiable {
    case friend(UserSummary)
    case group(SplickDomain.Group)

    var id: String {
        switch self {
        case .friend(let user):
            return "friend-\(user.id.uuidString)"
        case .group(let group):
            return "group-\(group.id.uuidString)"
        }
    }

    var sortKey: String {
        switch self {
        case .friend(let user):
            return user.displayName
        case .group(let group):
            return group.name
        }
    }
}

enum FriendsSearchItem: Identifiable {
    case user(UserSearchResult)
    case group(SplickDomain.Group)
    case joinGroupInvite(code: String)

    var id: String {
        switch self {
        case .user(let result):
            return "user-\(result.user.id.uuidString)"
        case .group(let group):
            return "group-\(group.id.uuidString)"
        case .joinGroupInvite(let code):
            return "join-\(code.lowercased())"
        }
    }

    var sortKey: String {
        switch self {
        case .user(let result):
            return result.user.displayName
        case .group(let group):
            return group.name
        case .joinGroupInvite(let code):
            return code
        }
    }
}

@MainActor
public final class FriendsRootViewModel: ObservableObject {
    @Published var friends: [UserSummary] = []
    @Published var groups: [SplickDomain.Group] = []
    @Published private(set) var combinedDirectoryItems: [FriendsDirectoryItem] = []
    @Published private(set) var combinedSearchItems: [FriendsSearchItem] = []
    @Published var friendsState: LoadingState<[UserSummary]> = .idle
    @Published var groupsState: LoadingState<[SplickDomain.Group]> = .idle
    @Published var isRefreshing = false
    @Published var alertMessage: String?
    @Published var searchQuery = ""
    @Published var searchResults: [UserSearchResult] = []
    @Published var searchState: LoadingState<[UserSearchResult]> = .idle
    @Published private(set) var isSearchFetching = false
    @Published private(set) var canLoadMoreFriends = false
    @Published private(set) var isLoadingMoreFriends = false
    @Published private(set) var canLoadMoreSearch = false
    @Published private(set) var isLoadingMoreSearch = false
    @Published private(set) var incomingRequestCount = 0
    @Published private(set) var outgoingRequestCount = 0

    private(set) var cachedIncomingRequests: [IncomingFriendRequest] = []
    private(set) var cachedOutgoingRequests: [OutgoingFriendRequest] = []

    private let fetchMyFriendsUseCase: FetchMyFriendsUseCaseProtocol
    private let fetchMyGroupsUseCase: FetchMyGroupsUseCaseProtocol
    private let searchUsersUseCase: SearchUsersUseCaseProtocol
    private let addFriendUseCase: AddFriendUseCaseProtocol
    private let acceptFriendRequestUseCase: AcceptFriendRequestUseCaseProtocol
    private let fetchIncomingFriendRequestsUseCase: FetchIncomingFriendRequestsUseCaseProtocol
    private let fetchOutgoingFriendRequestsUseCase: FetchOutgoingFriendRequestsUseCaseProtocol
    private let cancelFriendRequestUseCase: CancelFriendRequestUseCaseProtocol
    private let languageService: LanguageService
    private let onDirectoryLoaded: (([SplickDomain.Group]) async -> Void)?
    private let onFriendRequestsLoaded: (([IncomingFriendRequest]) async -> Void)?
    private var searchTask: Task<Void, Never>?
    private var refreshTask: Task<Void, Never>?
    private var backgroundFriendsLoadTask: Task<Void, Never>?
    private var inFlightRelationActionUserIds: Set<UUID> = []
    private var currentUserId: UUID?
    private var friendsPage = 0
    private var searchPage = 0
    private let friendsPageSize = 30
    private let searchPageSize = 20

    public var isSearching: Bool {
        !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public init(
        fetchMyFriendsUseCase: FetchMyFriendsUseCaseProtocol,
        fetchMyGroupsUseCase: FetchMyGroupsUseCaseProtocol,
        searchUsersUseCase: SearchUsersUseCaseProtocol,
        addFriendUseCase: AddFriendUseCaseProtocol,
        acceptFriendRequestUseCase: AcceptFriendRequestUseCaseProtocol,
        fetchIncomingFriendRequestsUseCase: FetchIncomingFriendRequestsUseCaseProtocol,
        fetchOutgoingFriendRequestsUseCase: FetchOutgoingFriendRequestsUseCaseProtocol,
        cancelFriendRequestUseCase: CancelFriendRequestUseCaseProtocol,
        languageService: LanguageService,
        onDirectoryLoaded: (([SplickDomain.Group]) async -> Void)? = nil,
        onFriendRequestsLoaded: (([IncomingFriendRequest]) async -> Void)? = nil
    ) {
        self.fetchMyFriendsUseCase = fetchMyFriendsUseCase
        self.fetchMyGroupsUseCase = fetchMyGroupsUseCase
        self.searchUsersUseCase = searchUsersUseCase
        self.addFriendUseCase = addFriendUseCase
        self.acceptFriendRequestUseCase = acceptFriendRequestUseCase
        self.fetchIncomingFriendRequestsUseCase = fetchIncomingFriendRequestsUseCase
        self.fetchOutgoingFriendRequestsUseCase = fetchOutgoingFriendRequestsUseCase
        self.cancelFriendRequestUseCase = cancelFriendRequestUseCase
        self.languageService = languageService
        self.onDirectoryLoaded = onDirectoryLoaded
        self.onFriendRequestsLoaded = onFriendRequestsLoaded
    }

    func load(userId: UUID? = nil) async {
        if let userId {
            currentUserId = userId
        }
        Log.info("Loading friends tab", category: .friends)
        await loadDiskCacheIfNeeded()

        if friends.isEmpty { friendsState = .loading }
        if groups.isEmpty { groupsState = .loading }

        async let friendsResult = fetchFriendsPageForRefresh(reset: true)
        async let groupsResult = fetchGroupsForRefresh()
        async let incomingResult = fetchIncomingRequestsForCache()
        async let outgoingResult = fetchOutgoingRequestsForCache()

        let (friendsPageResult, groups, incoming, outgoing) = await (
            friendsResult,
            groupsResult,
            incomingResult,
            outgoingResult
        )

        applyFriendsPageRefreshResult(friendsPageResult, replace: true)
        applyGroupsRefreshResult(groups)
        cachedIncomingRequests = incoming
        incomingRequestCount = incoming.count
        cachedOutgoingRequests = outgoing
        outgoingRequestCount = outgoing.count
        await onFriendRequestsLoaded?(incoming)

        if case .success(let loadedGroups) = groups {
            await onDirectoryLoaded?(loadedGroups)
        }

        if canLoadMoreFriends {
            startBackgroundFriendsLoad()
        }
    }

    func peopleYouMayKnowSnapshot(blocked: [BlockedUser]) -> PeopleYouMayKnowDirectorySnapshot {
        PeopleYouMayKnowDirectorySnapshot(
            friends: friends,
            groups: groups,
            incoming: cachedIncomingRequests,
            outgoing: cachedOutgoingRequests,
            blocked: blocked
        )
    }

    func refresh() async {
        if let existing = refreshTask {
            await existing.value
            return
        }

        let task = Task { @MainActor in
            isRefreshing = true
            defer { isRefreshing = false }
            await performPullToRefresh()
        }
        refreshTask = task
        await task.value
        refreshTask = nil
    }

    func refreshSearch(query: String) async {
        searchTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isSearchFetching = true
        defer { isSearchFetching = false }

        let task = Task { @MainActor in
            do {
                searchPage = 0
                let results = try await searchUsersUseCase.execute(
                    query: trimmed,
                    page: 0,
                    size: searchPageSize
                )
                guard !Task.isCancelled else { return }
                withAnimation(Self.searchResultsAnimation) {
                    searchResults = results
                    searchPage = 1
                    canLoadMoreSearch = results.count == searchPageSize
                    searchState = .loaded(results)
                    rebuildSearchItems()
                }
            } catch {
                guard !Task.isCancelled else { return }
                if searchResults.isEmpty {
                    searchState = .failed(languageService.localizedMessage(for: error))
                } else {
                    searchState = .loaded(searchResults)
                }
                Log.error(error, category: .friends, metadata: ["query": trimmed])
            }
        }
        searchTask = task
        await task.value
    }

    func loadMoreFriendsIfNeeded(currentItemID: String?) async {
        guard let currentItemID,
              currentItemID == combinedDirectoryItems.last?.id,
              canLoadMoreFriends,
              !isLoadingMoreFriends else { return }
        await loadMoreFriends()
    }

    func loadMoreFriends() async {
        guard canLoadMoreFriends, !isLoadingMoreFriends else { return }
        isLoadingMoreFriends = true
        defer { isLoadingMoreFriends = false }

        do {
            let page = try await fetchMyFriendsUseCase.executePage(
                page: friendsPage,
                size: friendsPageSize
            )
            appendFriends(page.friends)
            friendsPage = page.page + 1
            canLoadMoreFriends = page.hasMore
            persistFriendsCache()
            prefetchAvatars(for: page.friends)
        } catch {
            Log.error(error, category: .friends, metadata: ["action": "loadMoreFriends"])
        }
    }

    func loadMoreSearchIfNeeded(currentItemID: String?) async {
        guard let currentItemID,
              currentItemID == combinedSearchItems.last?.id,
              canLoadMoreSearch,
              !isLoadingMoreSearch,
              !isSearchFetching else { return }
        await loadMoreSearch()
    }

    func loadMoreSearch() async {
        let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, canLoadMoreSearch, !isLoadingMoreSearch else { return }

        isLoadingMoreSearch = true
        defer { isLoadingMoreSearch = false }

        do {
            let results = try await searchUsersUseCase.execute(
                query: trimmed,
                page: searchPage,
                size: searchPageSize
            )
            let existingIds = Set(searchResults.map(\.user.id))
            let unique = results.filter { !existingIds.contains($0.user.id) }
            searchResults.append(contentsOf: unique)
            searchPage += 1
            canLoadMoreSearch = results.count == searchPageSize
            searchState = .loaded(searchResults)
            rebuildSearchItems()
        } catch {
            canLoadMoreSearch = false
            Log.error(error, category: .friends, metadata: ["action": "loadMoreSearch", "query": trimmed])
        }
    }

    private func performPullToRefresh() async {
        backgroundFriendsLoadTask?.cancel()
        backgroundFriendsLoadTask = nil

        async let friendsResult = fetchFriendsPageForRefresh(reset: true)
        async let groupsResult = fetchGroupsForRefresh()
        async let incomingResult = fetchIncomingRequestsForCache()
        async let outgoingResult = fetchOutgoingRequestsForCache()

        let (friendsPageResult, groups, incoming, outgoing) = await (
            friendsResult,
            groupsResult,
            incomingResult,
            outgoingResult
        )

        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            applyFriendsPageRefreshResult(friendsPageResult, replace: true)
            applyGroupsRefreshResult(groups)
            cachedIncomingRequests = incoming
            incomingRequestCount = incoming.count
            cachedOutgoingRequests = outgoing
            outgoingRequestCount = outgoing.count
        }
        await onFriendRequestsLoaded?(incoming)
        if case .success(let loadedGroups) = groups {
            await onDirectoryLoaded?(loadedGroups)
        }

        if canLoadMoreFriends {
            startBackgroundFriendsLoad()
        }
    }

    private func fetchFriendsPageForRefresh(reset: Bool) async -> Result<FriendsPageResult, Error> {
        do {
            let pageIndex = reset ? 0 : friendsPage
            let page = try await fetchMyFriendsUseCase.executePage(
                page: pageIndex,
                size: friendsPageSize
            )
            return .success(page)
        } catch {
            return .failure(error)
        }
    }

    private func fetchGroupsForRefresh() async -> Result<[SplickDomain.Group], Error> {
        do {
            return .success(try await fetchMyGroupsUseCase.execute())
        } catch {
            return .failure(error)
        }
    }

    private func fetchIncomingRequestsForCache() async -> [IncomingFriendRequest] {
        (try? await fetchIncomingFriendRequestsUseCase.executeAll()) ?? cachedIncomingRequests
    }

    private func fetchOutgoingRequestsForCache() async -> [OutgoingFriendRequest] {
        (try? await fetchOutgoingFriendRequestsUseCase.executeAll()) ?? cachedOutgoingRequests
    }

    private func applyFriendsPageRefreshResult(
        _ result: Result<FriendsPageResult, Error>,
        replace: Bool
    ) {
        switch result {
        case .success(let page):
            if replace {
                friends = page.friends
                friendsPage = page.page + 1
            } else {
                appendFriends(page.friends)
                friendsPage = page.page + 1
            }
            canLoadMoreFriends = page.hasMore
            friendsState = .loaded(friends)
            rebuildDirectoryItems()
            rebuildSearchItems()
            persistFriendsCache()
            prefetchAvatars(for: page.friends)
            Log.info("Loaded friends", category: .friends, metadata: ["count": String(friends.count)])
        case .failure(let error):
            if friends.isEmpty {
                friendsState = .failed(languageService.localizedMessage(for: error))
            } else {
                friendsState = .loaded(friends)
            }
            Log.error(error, category: .friends)
        }
    }

    private func applyGroupsRefreshResult(_ result: Result<[SplickDomain.Group], Error>) {
        switch result {
        case .success(let items):
            groups = items
            groupsState = .loaded(items)
            rebuildDirectoryItems()
            rebuildSearchItems()
            Log.info("Loaded groups", category: .friends, metadata: ["count": String(items.count)])
        case .failure(let error):
            if groups.isEmpty {
                groupsState = .failed(languageService.localizedMessage(for: error))
            } else {
                groupsState = .loaded(groups)
            }
            Log.error(error, category: .friends)
        }
    }

    private func appendFriends(_ newFriends: [UserSummary]) {
        guard !newFriends.isEmpty else { return }
        let existingIds = Set(friends.map(\.id))
        let unique = newFriends.filter { !existingIds.contains($0.id) }
        guard !unique.isEmpty else { return }
        friends.append(contentsOf: unique)
        friendsState = .loaded(friends)
        rebuildDirectoryItems()
        rebuildSearchItems()
    }

    private func startBackgroundFriendsLoad() {
        backgroundFriendsLoadTask?.cancel()
        backgroundFriendsLoadTask = Task { @MainActor in
            while canLoadMoreFriends, !Task.isCancelled {
                await loadMoreFriends()
            }
        }
    }

    private func loadDiskCacheIfNeeded() async {
        guard friends.isEmpty, let userId = currentUserId else { return }
        if let cached = await fetchMyFriendsUseCase.loadCached(userId: userId), !cached.isEmpty {
            friends = cached
            friendsState = .loaded(cached)
            rebuildDirectoryItems()
            rebuildSearchItems()
            prefetchAvatars(for: Array(cached.prefix(20)))
            Log.info("Loaded friends from disk cache", category: .friends, metadata: [
                "count": String(cached.count)
            ])
        }
    }

    private func persistFriendsCache() {
        guard let userId = currentUserId else { return }
        let snapshot = friends
        Task {
            await fetchMyFriendsUseCase.saveCached(snapshot, userId: userId)
        }
    }

    private func invalidateFriendsCache() {
        guard let userId = currentUserId else { return }
        Task {
            await fetchMyFriendsUseCase.invalidateCache(userId: userId)
        }
    }

    private func prefetchAvatars(for users: [UserSummary]) {
        let urls = users.compactMap(\.avatarURL)
        guard !urls.isEmpty else { return }
        let decodeSide = RemoteImageMetrics.avatarMaxPixelWidth(pointSize: 48)
        Task.detached(priority: .utility) {
            await MainActor.run {
                ImagePrefetching.prefetch(urls: urls, thumbnailWidth: decodeSide)
            }
        }
    }

    private func rebuildDirectoryItems() {
        let friendItems = friends.map { FriendsDirectoryItem.friend($0) }
        let groupItems = groups.map { FriendsDirectoryItem.group($0) }
        combinedDirectoryItems = (friendItems + groupItems).sorted {
            $0.sortKey.localizedCaseInsensitiveCompare($1.sortKey) == .orderedAscending
        }
    }

    private func rebuildSearchItems() {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            combinedSearchItems = []
            return
        }

        let apiUserIds = Set(searchResults.map(\.user.id))
        let userItems = searchResults.map { FriendsSearchItem.user($0) }
        let localFriendItems = filterFriends(matching: query)
            .filter { !apiUserIds.contains($0.id) }
            .map { FriendsSearchItem.user(UserSearchResult(user: $0, friendStatus: .friends)) }
        let groupItems = filterGroups(matching: query).map { FriendsSearchItem.group($0) }
        var items = userItems + localFriendItems + groupItems

        if userItems.isEmpty,
           localFriendItems.isEmpty,
           let joinCode = joinableInviteCode(from: query) {
            items.append(.joinGroupInvite(code: joinCode))
        }

        combinedSearchItems = items.sorted {
            $0.sortKey.localizedCaseInsensitiveCompare($1.sortKey) == .orderedAscending
        }
    }

    func refreshIncomingRequestCount() async {
        do {
            let incoming = try await fetchIncomingFriendRequestsUseCase.executeAll()
            cachedIncomingRequests = incoming
            incomingRequestCount = incoming.count
            await onFriendRequestsLoaded?(incoming)
        } catch {
            incomingRequestCount = 0
        }
    }

    func refreshOutgoingRequestCount() async {
        do {
            let outgoing = try await fetchOutgoingFriendRequestsUseCase.executeAll()
            cachedOutgoingRequests = outgoing
            outgoingRequestCount = outgoing.count
        } catch {
            outgoingRequestCount = 0
        }
    }

    func isFriend(userId: UUID) -> Bool {
        friends.contains { $0.id == userId }
    }

    func loadFriends(isPullToRefresh: Bool) async {
        if !isPullToRefresh, friends.isEmpty {
            friendsState = .loading
        }
        do {
            let page = try await fetchMyFriendsUseCase.executePage(page: 0, size: friendsPageSize)
            friends = page.friends
            friendsPage = 1
            canLoadMoreFriends = page.hasMore
            friendsState = .loaded(friends)
            rebuildDirectoryItems()
            rebuildSearchItems()
            persistFriendsCache()
            prefetchAvatars(for: page.friends)
            Log.info("Loaded friends", category: .friends, metadata: ["count": String(friends.count)])
            if canLoadMoreFriends {
                startBackgroundFriendsLoad()
            }
        } catch {
            if isPullToRefresh, !friends.isEmpty {
                friendsState = .loaded(friends)
            } else {
                friendsState = .failed(languageService.localizedMessage(for: error))
            }
            Log.error(error, category: .friends)
        }
    }

    func loadGroups(isPullToRefresh: Bool) async {
        if !isPullToRefresh {
            groupsState = .loading
        }
        do {
            let items = try await fetchMyGroupsUseCase.execute()
            groups = items
            groupsState = .loaded(items)
            rebuildDirectoryItems()
            rebuildSearchItems()
            Log.info("Loaded groups", category: .friends, metadata: ["count": String(items.count)])
            await onDirectoryLoaded?(items)
        } catch {
            if isPullToRefresh, !groups.isEmpty {
                groupsState = .loaded(groups)
            } else {
                groupsState = .failed(languageService.localizedMessage(for: error))
            }
            Log.error(error, category: .friends)
        }
    }

    func onFriendAdded() {
        invalidateFriendsCache()
        Task {
            await loadFriends(isPullToRefresh: true)
            await refreshIncomingRequestCount()
            await refreshOutgoingRequestCount()
        }
    }

    func onGroupJoined() {
        Task { await loadGroups(isPullToRefresh: true) }
    }

    func onGroupCreated(_ group: SplickDomain.Group) {
        if !groups.contains(where: { $0.id == group.id }) {
            groups.insert(group, at: 0)
            rebuildDirectoryItems()
            rebuildSearchItems()
        }
        groupsState = .loaded(groups)
        Task { await loadGroups(isPullToRefresh: true) }
    }

    func onSearchQueryChanged(_ query: String) {
        searchTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            searchResults = []
            searchState = .idle
            isSearchFetching = false
            canLoadMoreSearch = false
            searchPage = 0
            rebuildSearchItems()
            return
        }

        searchResults = []
        searchPage = 0
        canLoadMoreSearch = false
        isSearchFetching = true
        rebuildSearchItems()
        if combinedSearchItems.isEmpty {
            searchState = .loading
        } else {
            searchState = .loaded([])
        }
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }

            do {
                let results = try await searchUsersUseCase.execute(
                    query: trimmed,
                    page: 0,
                    size: searchPageSize
                )
                guard !Task.isCancelled else { return }
                isSearchFetching = false
                withAnimation(Self.searchResultsAnimation) {
                    searchResults = results
                    searchPage = 1
                    canLoadMoreSearch = results.count == searchPageSize
                    searchState = .loaded(results)
                    rebuildSearchItems()
                }
            } catch {
                guard !Task.isCancelled else { return }
                isSearchFetching = false
                searchResults = []
                canLoadMoreSearch = false
                rebuildSearchItems()
                if combinedSearchItems.isEmpty {
                    searchState = .failed(languageService.localizedMessage(for: error))
                } else {
                    searchState = .loaded([])
                }
                Log.error(error, category: .friends, metadata: ["query": trimmed])
            }
        }
    }

    private static let searchResultsAnimation = Animation.spring(response: 0.38, dampingFraction: 0.86)

    private func filterFriends(matching query: String) -> [UserSummary] {
        friends.filter { friend in
            friend.displayName.localizedCaseInsensitiveContains(query)
                || friend.username.localizedCaseInsensitiveContains(query)
                || (friend.subtitle?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    private func filterGroups(matching query: String) -> [SplickDomain.Group] {
        groups.filter { group in
            group.name.localizedCaseInsensitiveContains(query)
                || group.inviteCode.localizedCaseInsensitiveContains(query)
                || (group.description?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    /// Offers "join group" when the query looks like an invite code for a group not yet joined.
    private func joinableInviteCode(from query: String) -> String? {
        let normalized = query
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "@", with: "")
        guard (3 ... 32).contains(normalized.count) else { return nil }
        guard normalized.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }) else {
            return nil
        }

        let alreadyJoined = groups.contains {
            $0.inviteCode.lowercased() == normalized
        }
        guard !alreadyJoined else { return nil }

        return normalized
    }

    func sendFriendRequest(to result: UserSearchResult, message: String? = nil) {
        guard result.friendStatus == .none else { return }
        let userId = result.user.id
        guard !inFlightRelationActionUserIds.contains(userId) else { return }

        inFlightRelationActionUserIds.insert(userId)
        updateUserRelationStatus(userId: userId, status: .requestSent)

        Task {
            defer { inFlightRelationActionUserIds.remove(userId) }
            do {
                _ = try await addFriendUseCase.execute(username: result.user.username, message: message)
                onFriendAdded()
            } catch {
                updateUserRelationStatus(userId: userId, status: .none)
                alertMessage = languageService.localizedMessage(for: error)
                Log.error(error, category: .friends, metadata: ["action": "sendFriendRequest"])
            }
        }
    }

    func acceptFriendRequest(from result: UserSearchResult) {
        guard result.friendStatus == .requestReceived else { return }
        let userId = result.user.id
        guard !inFlightRelationActionUserIds.contains(userId) else { return }

        inFlightRelationActionUserIds.insert(userId)
        updateUserRelationStatus(userId: userId, status: .friends)

        Task {
            defer { inFlightRelationActionUserIds.remove(userId) }
            do {
                let request = try await resolveIncomingRequest(for: userId)
                guard let request else {
                    updateUserRelationStatus(userId: userId, status: .requestReceived)
                    alertMessage = languageService.text(.friendsRequestNotFoundIncoming)
                    return
                }
                try await acceptFriendRequestUseCase.execute(requestId: request.id)
                cachedIncomingRequests.removeAll { $0.id == request.id }
                incomingRequestCount = cachedIncomingRequests.count
                onFriendAdded()
            } catch {
                updateUserRelationStatus(userId: userId, status: .requestReceived)
                alertMessage = languageService.localizedMessage(for: error)
                Log.error(error, category: .friends, metadata: ["action": "acceptFriendRequest"])
            }
        }
    }

    func cancelFriendRequest(from result: UserSearchResult) {
        guard result.friendStatus == .requestSent else { return }
        let userId = result.user.id
        guard !inFlightRelationActionUserIds.contains(userId) else { return }

        inFlightRelationActionUserIds.insert(userId)
        updateUserRelationStatus(userId: userId, status: .none)

        Task {
            defer { inFlightRelationActionUserIds.remove(userId) }
            do {
                let request = try await resolveOutgoingRequest(for: userId)
                guard let request else {
                    updateUserRelationStatus(userId: userId, status: .requestSent)
                    alertMessage = languageService.text(.friendsRequestNotFoundOutgoing)
                    return
                }
                try await cancelFriendRequestUseCase.execute(requestId: request.id)
                cachedOutgoingRequests.removeAll { $0.id == request.id }
                outgoingRequestCount = cachedOutgoingRequests.count
                onFriendAdded()
            } catch {
                updateUserRelationStatus(userId: userId, status: .requestSent)
                alertMessage = languageService.localizedMessage(for: error)
                Log.error(error, category: .friends, metadata: ["action": "cancelFriendRequest"])
            }
        }
    }

    private func resolveIncomingRequest(for userId: UUID) async throws -> IncomingFriendRequest? {
        if let cached = cachedIncomingRequests.first(where: { $0.requester.id == userId }) {
            return cached
        }
        let incoming = try await fetchIncomingFriendRequestsUseCase.executeAll()
        cachedIncomingRequests = incoming
        incomingRequestCount = incoming.count
        return incoming.first(where: { $0.requester.id == userId })
    }

    private func resolveOutgoingRequest(for userId: UUID) async throws -> OutgoingFriendRequest? {
        if let cached = cachedOutgoingRequests.first(where: { $0.addressee.id == userId }) {
            return cached
        }
        let outgoing = try await fetchOutgoingFriendRequestsUseCase.executeAll()
        cachedOutgoingRequests = outgoing
        outgoingRequestCount = outgoing.count
        return outgoing.first(where: { $0.addressee.id == userId })
    }

    func updateUserRelationStatus(userId: UUID, status: FriendRelationStatus) {
        searchResults = searchResults.map { item in
            guard item.user.id == userId else { return item }
            return UserSearchResult(user: item.user, friendStatus: status)
        }
        if case .loaded = searchState {
            searchState = .loaded(searchResults)
        }
        rebuildSearchItems()
    }

    func handleRelationshipChanged(userId: UUID, status: FriendRelationStatus) {
        updateUserRelationStatus(userId: userId, status: status)
        switch status {
        case .friends:
            onFriendAdded()
        case .none, .requestSent, .requestReceived, .blocked:
            if status == .blocked || status == .none {
                invalidateFriendsCache()
            }
            Task {
                await refreshIncomingRequestCount()
                await refreshOutgoingRequestCount()
            }
        }
    }
}
