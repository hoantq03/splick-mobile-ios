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

    private let fetchMyFriendsUseCase: FetchMyFriendsUseCaseProtocol
    private let fetchMyGroupsUseCase: FetchMyGroupsUseCaseProtocol

    public init(
        fetchMyFriendsUseCase: FetchMyFriendsUseCaseProtocol,
        fetchMyGroupsUseCase: FetchMyGroupsUseCaseProtocol
    ) {
        self.fetchMyFriendsUseCase = fetchMyFriendsUseCase
        self.fetchMyGroupsUseCase = fetchMyGroupsUseCase
    }

    func load() async {
        await loadFriends(isPullToRefresh: false)
        await loadGroups(isPullToRefresh: false)
    }

    func refresh() async {
        isRefreshing = true
        await loadFriends(isPullToRefresh: true)
        await loadGroups(isPullToRefresh: true)
        isRefreshing = false
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
        Task { await loadFriends(isPullToRefresh: true) }
    }

    func onGroupJoined() {
        Task { await loadGroups(isPullToRefresh: true) }
    }
}
