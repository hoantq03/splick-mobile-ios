import Foundation
import SwiftUI
import Common
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
    @Published var friendsState: LoadingState<[UserSummary]> = .idle
    @Published var groupsState: LoadingState<[SplickDomain.Group]> = .idle
    @Published var isRefreshing = false
    @Published var alertMessage: String?
    @Published var searchQuery = ""
    @Published var searchResults: [UserSearchResult] = []
    @Published var searchState: LoadingState<[UserSearchResult]> = .idle
    @Published private(set) var sendingFriendRequestUserIds: Set<UUID> = []
    @Published private(set) var acceptingFriendRequestUserIds: Set<UUID> = []
    @Published private(set) var incomingRequestCount = 0
    @Published private(set) var outgoingRequestCount = 0

    private let fetchMyFriendsUseCase: FetchMyFriendsUseCaseProtocol
    private let fetchMyGroupsUseCase: FetchMyGroupsUseCaseProtocol
    private let searchUsersUseCase: SearchUsersUseCaseProtocol
    private let addFriendUseCase: AddFriendUseCaseProtocol
    private let acceptFriendRequestUseCase: AcceptFriendRequestUseCaseProtocol
    private let fetchIncomingFriendRequestsUseCase: FetchIncomingFriendRequestsUseCaseProtocol
    private let fetchOutgoingFriendRequestsUseCase: FetchOutgoingFriendRequestsUseCaseProtocol
    private var searchTask: Task<Void, Never>?
    private var refreshTask: Task<Void, Never>?

    public var isSearching: Bool {
        !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var combinedDirectoryItems: [FriendsDirectoryItem] {
        let friendItems = friends.map { FriendsDirectoryItem.friend($0) }
        let groupItems = groups.map { FriendsDirectoryItem.group($0) }
        return (friendItems + groupItems).sorted {
            $0.sortKey.localizedCaseInsensitiveCompare($1.sortKey) == .orderedAscending
        }
    }

    var combinedSearchItems: [FriendsSearchItem] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }

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

        return items.sorted {
            $0.sortKey.localizedCaseInsensitiveCompare($1.sortKey) == .orderedAscending
        }
    }

    public init(
        fetchMyFriendsUseCase: FetchMyFriendsUseCaseProtocol,
        fetchMyGroupsUseCase: FetchMyGroupsUseCaseProtocol,
        searchUsersUseCase: SearchUsersUseCaseProtocol,
        addFriendUseCase: AddFriendUseCaseProtocol,
        acceptFriendRequestUseCase: AcceptFriendRequestUseCaseProtocol,
        fetchIncomingFriendRequestsUseCase: FetchIncomingFriendRequestsUseCaseProtocol,
        fetchOutgoingFriendRequestsUseCase: FetchOutgoingFriendRequestsUseCaseProtocol
    ) {
        self.fetchMyFriendsUseCase = fetchMyFriendsUseCase
        self.fetchMyGroupsUseCase = fetchMyGroupsUseCase
        self.searchUsersUseCase = searchUsersUseCase
        self.addFriendUseCase = addFriendUseCase
        self.acceptFriendRequestUseCase = acceptFriendRequestUseCase
        self.fetchIncomingFriendRequestsUseCase = fetchIncomingFriendRequestsUseCase
        self.fetchOutgoingFriendRequestsUseCase = fetchOutgoingFriendRequestsUseCase
    }

    func load() async {
        Log.info("Loading friends tab", category: .friends)
        await loadFriends(isPullToRefresh: false)
        await loadGroups(isPullToRefresh: false)
        await refreshIncomingRequestCount()
        await refreshOutgoingRequestCount()
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

        let task = Task { @MainActor in
            do {
                let results = try await searchUsersUseCase.execute(query: trimmed, page: 0, size: 20)
                guard !Task.isCancelled else { return }
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    searchResults = results
                    searchState = .loaded(results)
                }
            } catch {
                guard !Task.isCancelled else { return }
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    if searchResults.isEmpty {
                        searchState = .failed(error.localizedDescription)
                    } else {
                        searchState = .loaded(searchResults)
                    }
                }
                Log.error(error, category: .friends, metadata: ["query": trimmed])
            }
        }
        searchTask = task
        await task.value
    }

    private func performPullToRefresh() async {
        async let friendsResult = fetchFriendsForRefresh()
        async let groupsResult = fetchGroupsForRefresh()
        async let incomingCount = fetchIncomingRequestCount()
        async let outgoingCount = fetchOutgoingRequestCount()

        let (friends, groups, incoming, outgoing) = await (
            friendsResult,
            groupsResult,
            incomingCount,
            outgoingCount
        )

        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            applyFriendsRefreshResult(friends)
            applyGroupsRefreshResult(groups)
            incomingRequestCount = incoming
            outgoingRequestCount = outgoing
        }
    }

    private func fetchFriendsForRefresh() async -> Result<[UserSummary], Error> {
        do {
            return .success(try await fetchMyFriendsUseCase.execute())
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

    private func fetchIncomingRequestCount() async -> Int {
        (try? await fetchIncomingFriendRequestsUseCase.executeAll())?.count ?? 0
    }

    private func fetchOutgoingRequestCount() async -> Int {
        (try? await fetchOutgoingFriendRequestsUseCase.executeAll())?.count ?? 0
    }

    private func applyFriendsRefreshResult(_ result: Result<[UserSummary], Error>) {
        switch result {
        case .success(let items):
            friends = items
            friendsState = .loaded(items)
            Log.info("Loaded friends", category: .friends, metadata: ["count": String(items.count)])
        case .failure(let error):
            if friends.isEmpty {
                friendsState = .failed(error.localizedDescription)
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
            Log.info("Loaded groups", category: .friends, metadata: ["count": String(items.count)])
        case .failure(let error):
            if groups.isEmpty {
                groupsState = .failed(error.localizedDescription)
            } else {
                groupsState = .loaded(groups)
            }
            Log.error(error, category: .friends)
        }
    }

    func refreshIncomingRequestCount() async {
        do {
            let incoming = try await fetchIncomingFriendRequestsUseCase.executeAll()
            incomingRequestCount = incoming.count
        } catch {
            incomingRequestCount = 0
        }
    }

    func refreshOutgoingRequestCount() async {
        do {
            let outgoing = try await fetchOutgoingFriendRequestsUseCase.executeAll()
            outgoingRequestCount = outgoing.count
        } catch {
            outgoingRequestCount = 0
        }
    }

    func isFriend(userId: UUID) -> Bool {
        friends.contains { $0.id == userId }
    }

    func loadFriends(isPullToRefresh: Bool) async {
        if !isPullToRefresh {
            friendsState = .loading
        }
        do {
            let items = try await fetchMyFriendsUseCase.execute()
            friends = items
            friendsState = .loaded(items)
            Log.info("Loaded friends", category: .friends, metadata: ["count": String(items.count)])
        } catch {
            if isPullToRefresh, !friends.isEmpty {
                friendsState = .loaded(friends)
            } else {
                friendsState = .failed(error.localizedDescription)
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
            Log.info("Loaded groups", category: .friends, metadata: ["count": String(items.count)])
        } catch {
            if isPullToRefresh, !groups.isEmpty {
                groupsState = .loaded(groups)
            } else {
                groupsState = .failed(error.localizedDescription)
            }
            Log.error(error, category: .friends)
        }
    }

    func onFriendAdded() {
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
            return
        }

        searchResults = []
        if combinedSearchItems.isEmpty {
            searchState = .loading
        } else {
            searchState = .loaded([])
        }
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }

            do {
                let results = try await searchUsersUseCase.execute(query: trimmed, page: 0, size: 20)
                guard !Task.isCancelled else { return }
                searchResults = results
                searchState = .loaded(results)
            } catch {
                guard !Task.isCancelled else { return }
                searchResults = []
                if combinedSearchItems.isEmpty {
                    searchState = .failed(error.localizedDescription)
                } else {
                    searchState = .loaded([])
                }
                Log.error(error, category: .friends, metadata: ["query": trimmed])
            }
        }
    }

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

    func sendFriendRequest(to result: UserSearchResult, message: String? = nil) async {
        guard result.friendStatus == .none else { return }
        let userId = result.user.id
        guard !sendingFriendRequestUserIds.contains(userId) else { return }

        sendingFriendRequestUserIds.insert(userId)
        defer { sendingFriendRequestUserIds.remove(userId) }

        do {
            _ = try await addFriendUseCase.execute(username: result.user.username, message: message)
            updateSearchResult(userId: userId, status: .requestSent)
            onFriendAdded()
        } catch {
            alertMessage = error.localizedDescription
            Log.error(error, category: .friends, metadata: ["action": "sendFriendRequest"])
        }
    }

    func acceptFriendRequest(from result: UserSearchResult) async {
        guard result.friendStatus == .requestReceived else { return }
        let userId = result.user.id
        guard !acceptingFriendRequestUserIds.contains(userId) else { return }

        acceptingFriendRequestUserIds.insert(userId)
        defer { acceptingFriendRequestUserIds.remove(userId) }

        do {
            let incoming = try await fetchIncomingFriendRequestsUseCase.executeAll()
            guard let request = incoming.first(where: { $0.requester.id == userId }) else {
                alertMessage = "Friend request not found. Open incoming requests to refresh."
                return
            }
            try await acceptFriendRequestUseCase.execute(requestId: request.id)
            updateSearchResult(userId: userId, status: .friends)
            onFriendAdded()
        } catch {
            alertMessage = error.localizedDescription
            Log.error(error, category: .friends, metadata: ["action": "acceptFriendRequest"])
        }
    }

    private func updateSearchResult(userId: UUID, status: FriendRelationStatus) {
        searchResults = searchResults.map { item in
            guard item.user.id == userId else { return item }
            return UserSearchResult(user: item.user, friendStatus: status)
        }
        if case .loaded = searchState {
            searchState = .loaded(searchResults)
        }
    }
}
