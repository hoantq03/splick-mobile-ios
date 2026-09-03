import Foundation
import Common
import Localization
import SplickDomain

@MainActor
final class InviteFriendsToGroupViewModel: ObservableObject {
    enum State: Equatable {
        case idle
        case submitting
    }

    @Published private(set) var state: State = .idle
    @Published var searchQuery = ""
    @Published var searchResults: [UserSearchResult] = []
    @Published var searchState: LoadingState<[UserSearchResult]> = .idle
    @Published private(set) var isLoadingMore = false
    @Published var selectedIds: Set<UUID> = []
    @Published var alertMessage: String?
    @Published var successMessage: String?
    @Published var showHistoryShareConfirm = false

    private let groupId: UUID
    private let existingMemberIds: Set<UUID>
    private let currentUserId: UUID?
    private let fetchMyFriendsUseCase: FetchMyFriendsUseCaseProtocol
    private let searchUsersUseCase: SearchUsersUseCaseProtocol
    private let addFriendUseCase: AddFriendUseCaseProtocol
    private let inviteFriendsUseCase: InviteFriendsToGroupUseCaseProtocol
    private let languageService: LanguageService
    private let onInvited: ([UUID], Bool) -> Void
    private var searchTask: Task<Void, Never>?
    private var inFlightRelationActionUserIds: Set<UUID> = []

    private var friendResults: [UserSearchResult] = []
    private var friendsPage = 0
    private var canLoadMoreFriends = false
    private var hasLoadedFriends = false
    private var searchPage = 0
    private var canLoadMoreSearch = false

    private static let pageSize = 20

    var isSearching: Bool {
        !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    init(
        groupId: UUID,
        existingMemberIds: Set<UUID>,
        currentUserId: UUID?,
        fetchMyFriendsUseCase: FetchMyFriendsUseCaseProtocol,
        searchUsersUseCase: SearchUsersUseCaseProtocol,
        addFriendUseCase: AddFriendUseCaseProtocol,
        inviteFriendsUseCase: InviteFriendsToGroupUseCaseProtocol,
        languageService: LanguageService,
        onInvited: @escaping ([UUID], Bool) -> Void
    ) {
        self.groupId = groupId
        self.existingMemberIds = existingMemberIds
        self.currentUserId = currentUserId
        self.fetchMyFriendsUseCase = fetchMyFriendsUseCase
        self.searchUsersUseCase = searchUsersUseCase
        self.addFriendUseCase = addFriendUseCase
        self.inviteFriendsUseCase = inviteFriendsUseCase
        self.languageService = languageService
        self.onInvited = onInvited
    }

    func loadFriendsIfNeeded() async {
        guard !hasLoadedFriends else { return }
        await loadFriends(reset: true)
    }

    func loadMoreIfNeeded(currentId: UUID) async {
        guard currentId == searchResults.last?.id else { return }
        if isSearching {
            await loadMoreSearch()
        } else {
            await loadMoreFriends()
        }
    }

    func onSearchQueryChanged(_ query: String) {
        searchTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            applyFriendResults()
            return
        }

        searchState = .loading
        searchPage = 0
        canLoadMoreSearch = false
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            await fetchSearchPage(query: trimmed, reset: true)
        }
    }

    func toggleSelection(_ userId: UUID) {
        if selectedIds.contains(userId) {
            selectedIds.remove(userId)
        } else {
            selectedIds.insert(userId)
        }
    }

    func sendFriendRequest(to result: UserSearchResult) {
        guard result.friendStatus == .none else { return }
        let userId = result.user.id
        guard !inFlightRelationActionUserIds.contains(userId) else { return }

        inFlightRelationActionUserIds.insert(userId)
        updateSearchResult(userId: userId, status: .requestSent)

        Task {
            defer { inFlightRelationActionUserIds.remove(userId) }
            do {
                _ = try await addFriendUseCase.execute(username: result.user.username, message: nil)
            } catch {
                updateSearchResult(userId: userId, status: .none)
                alertMessage = languageService.localizedMessage(for: error)
            }
        }
    }

    func requestSubmit() {
        guard !selectedIds.isEmpty else {
            alertMessage = languageService.text(.friendsInviteNeedSelection)
            return
        }
        showHistoryShareConfirm = true
    }

    func submit(shareChatHistory: Bool) async {
        guard !selectedIds.isEmpty else {
            alertMessage = languageService.text(.friendsInviteNeedSelection)
            return
        }
        showHistoryShareConfirm = false
        state = .submitting
        do {
            let result = try await inviteFriendsUseCase.execute(
                groupId: groupId,
                userIds: Array(selectedIds)
            )
            let invitedCount = result.invited.count
            let skippedCount = result.skipped.count
            if invitedCount > 0 {
                successMessage = languageService.format(.friendsInviteSuccessCount, invitedCount)
                onInvited(result.invited, shareChatHistory)
            } else if skippedCount > 0 {
                alertMessage = languageService.text(.friendsInviteFailedReason)
            } else {
                alertMessage = languageService.text(.friendsInviteNone)
            }
            selectedIds.removeAll()
            state = .idle
        } catch {
            alertMessage = languageService.localizedMessage(for: error)
            state = .idle
        }
    }

    private func loadFriends(reset: Bool) async {
        if reset {
            friendsPage = 0
            friendResults = []
            canLoadMoreFriends = true
        }
        guard canLoadMoreFriends else {
            applyFriendResults()
            return
        }
        if friendResults.isEmpty {
            searchState = .loading
        }

        do {
            repeat {
                let page = try await fetchMyFriendsUseCase.executePage(
                    page: friendsPage,
                    size: Self.pageSize
                )
                appendFriends(page.friends)
                friendsPage = page.page + 1
                canLoadMoreFriends = page.hasMore
                hasLoadedFriends = true
            } while friendResults.isEmpty && canLoadMoreFriends && !Task.isCancelled
            applyFriendResults()
        } catch {
            if friendResults.isEmpty {
                hasLoadedFriends = false
                searchResults = []
                searchState = .failed(languageService.localizedMessage(for: error))
            } else {
                hasLoadedFriends = true
                applyFriendResults()
            }
        }
    }

    private func loadMoreFriends() async {
        guard !isSearching, canLoadMoreFriends, !isLoadingMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        await loadFriends(reset: false)
    }

    private func fetchSearchPage(query: String, reset: Bool) async {
        do {
            if reset {
                searchPage = 0
                searchResults = []
            }
            let results = try await searchUsersUseCase.execute(
                query: query,
                page: searchPage,
                size: Self.pageSize
            )
            guard !Task.isCancelled else { return }
            guard searchQuery.trimmingCharacters(in: .whitespacesAndNewlines) == query else { return }

            canLoadMoreSearch = results.count >= Self.pageSize
            searchPage += 1
            let filtered = filterEligible(results)
            if reset {
                searchResults = Self.sortedAlphabetically(filtered)
            } else {
                searchResults = Self.sortedAlphabetically(mergeUnique(searchResults, filtered))
            }
            if searchResults.isEmpty && canLoadMoreSearch && reset {
                await fetchSearchPage(query: query, reset: false)
                return
            }
            searchState = .loaded(searchResults)
        } catch {
            guard !Task.isCancelled else { return }
            if reset {
                searchResults = []
                searchState = .failed(languageService.localizedMessage(for: error))
            }
        }
    }

    private func loadMoreSearch() async {
        let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, canLoadMoreSearch, !isLoadingMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        await fetchSearchPage(query: trimmed, reset: false)
    }

    private func appendFriends(_ friends: [UserSummary]) {
        let mapped = friends.map { UserSearchResult(user: $0, friendStatus: .friends) }
        friendResults = Self.sortedAlphabetically(mergeUnique(friendResults, filterEligible(mapped)))
    }

    private func applyFriendResults() {
        guard !isSearching else { return }
        searchResults = friendResults
        searchState = .loaded(friendResults)
    }

    private func filterEligible(_ results: [UserSearchResult]) -> [UserSearchResult] {
        results.filter { result in
            !existingMemberIds.contains(result.user.id) && result.user.id != currentUserId
        }
    }

    private func mergeUnique(
        _ existing: [UserSearchResult],
        _ incoming: [UserSearchResult]
    ) -> [UserSearchResult] {
        var seen = Set(existing.map(\.user.id))
        var merged = existing
        for item in incoming where seen.insert(item.user.id).inserted {
            merged.append(item)
        }
        return merged
    }

    private static func sortedAlphabetically(_ results: [UserSearchResult]) -> [UserSearchResult] {
        results.sorted {
            $0.user.displayName.localizedCaseInsensitiveCompare($1.user.displayName) == .orderedAscending
        }
    }

    private func updateSearchResult(userId: UUID, status: FriendRelationStatus) {
        searchResults = searchResults.map { item in
            guard item.user.id == userId else { return item }
            return UserSearchResult(user: item.user, friendStatus: status)
        }
        friendResults = friendResults.map { item in
            guard item.user.id == userId else { return item }
            return UserSearchResult(user: item.user, friendStatus: status)
        }
        if case .loaded = searchState {
            searchState = .loaded(searchResults)
        }
    }
}
