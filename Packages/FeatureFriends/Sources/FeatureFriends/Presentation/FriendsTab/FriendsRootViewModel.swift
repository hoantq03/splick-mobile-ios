import Foundation
import Common
import SplickDomain

@MainActor
public final class FriendsRootViewModel: ObservableObject {
    enum Segment: String, CaseIterable {
        case friends = "Friends"
        case groups = "Groups"
    }

    @Published var segment: Segment = .friends
    @Published var friends: [UserSummary] = []
    @Published var groups: [Group] = []
    @Published var friendsState: LoadingState<[UserSummary]> = .idle
    @Published var groupsState: LoadingState<[Group]> = .idle
    @Published var isRefreshing = false
    @Published var alertMessage: String?
    @Published var searchQuery = ""
    @Published var searchResults: [UserSearchResult] = []
    @Published var searchState: LoadingState<[UserSearchResult]> = .idle
    @Published private(set) var sendingFriendRequestUserIds: Set<UUID> = []
    @Published private(set) var incomingRequestCount = 0

    private let fetchMyFriendsUseCase: FetchMyFriendsUseCaseProtocol
    private let fetchMyGroupsUseCase: FetchMyGroupsUseCaseProtocol
    private let searchUsersUseCase: SearchUsersUseCaseProtocol
    private let addFriendUseCase: AddFriendUseCaseProtocol
    private let fetchIncomingFriendRequestsUseCase: FetchIncomingFriendRequestsUseCaseProtocol
    private var searchTask: Task<Void, Never>?

    public var isSearching: Bool {
        !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public init(
        fetchMyFriendsUseCase: FetchMyFriendsUseCaseProtocol,
        fetchMyGroupsUseCase: FetchMyGroupsUseCaseProtocol,
        searchUsersUseCase: SearchUsersUseCaseProtocol,
        addFriendUseCase: AddFriendUseCaseProtocol,
        fetchIncomingFriendRequestsUseCase: FetchIncomingFriendRequestsUseCaseProtocol
    ) {
        self.fetchMyFriendsUseCase = fetchMyFriendsUseCase
        self.fetchMyGroupsUseCase = fetchMyGroupsUseCase
        self.searchUsersUseCase = searchUsersUseCase
        self.addFriendUseCase = addFriendUseCase
        self.fetchIncomingFriendRequestsUseCase = fetchIncomingFriendRequestsUseCase
    }

    func load() async {
        await loadFriends(isPullToRefresh: false)
        await loadGroups(isPullToRefresh: false)
        await refreshIncomingRequestCount()
    }

    func refresh() async {
        isRefreshing = true
        await loadFriends(isPullToRefresh: true)
        await loadGroups(isPullToRefresh: true)
        await refreshIncomingRequestCount()
        isRefreshing = false
    }

    func refreshIncomingRequestCount() async {
        do {
            let incoming = try await fetchIncomingFriendRequestsUseCase.execute(page: 0, size: 50)
            incomingRequestCount = incoming.count
        } catch {
            incomingRequestCount = 0
        }
    }

    func loadFriends(isPullToRefresh: Bool) async {
        if !isPullToRefresh {
            friendsState = .loading
        }
        do {
            let items = try await fetchMyFriendsUseCase.execute()
            friends = items
            friendsState = .loaded(items)
        } catch {
            if isPullToRefresh, !friends.isEmpty {
                friendsState = .loaded(friends)
            } else {
                friendsState = .failed(error.localizedDescription)
            }
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
        } catch {
            if isPullToRefresh, !groups.isEmpty {
                groupsState = .loaded(groups)
            } else {
                groupsState = .failed(error.localizedDescription)
            }
        }
    }

    func onFriendAdded() {
        Task {
            await loadFriends(isPullToRefresh: true)
            await refreshIncomingRequestCount()
        }
    }

    func onGroupJoined() {
        Task { await loadGroups(isPullToRefresh: true) }
    }

    func onGroupCreated(_ group: Group) {
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

        searchState = .loading
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
                searchState = .failed(error.localizedDescription)
            }
        }
    }

    func sendFriendRequest(to result: UserSearchResult) async {
        guard result.friendStatus == .none else { return }
        let userId = result.user.id
        guard !sendingFriendRequestUserIds.contains(userId) else { return }

        sendingFriendRequestUserIds.insert(userId)
        defer { sendingFriendRequestUserIds.remove(userId) }

        do {
            _ = try await addFriendUseCase.execute(username: result.user.username)
            updateSearchResult(userId: userId, status: .requestSent)
            onFriendAdded()
        } catch {
            alertMessage = error.localizedDescription
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
