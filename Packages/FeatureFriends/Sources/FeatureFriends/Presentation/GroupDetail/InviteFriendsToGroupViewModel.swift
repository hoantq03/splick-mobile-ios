import Foundation
import Common
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
    @Published var selectedIds: Set<UUID> = []
    @Published var alertMessage: String?
    @Published var successMessage: String?
    @Published private(set) var sendingFriendRequestUserIds: Set<UUID> = []

    private let groupId: UUID
    private let existingMemberIds: Set<UUID>
    private let currentUserId: UUID?
    private let searchUsersUseCase: SearchUsersUseCaseProtocol
    private let addFriendUseCase: AddFriendUseCaseProtocol
    private let inviteFriendsUseCase: InviteFriendsToGroupUseCaseProtocol
    private let onInvited: () -> Void
    private var searchTask: Task<Void, Never>?

    var isSearching: Bool {
        !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    init(
        groupId: UUID,
        existingMemberIds: Set<UUID>,
        currentUserId: UUID?,
        searchUsersUseCase: SearchUsersUseCaseProtocol,
        addFriendUseCase: AddFriendUseCaseProtocol,
        inviteFriendsUseCase: InviteFriendsToGroupUseCaseProtocol,
        onInvited: @escaping () -> Void
    ) {
        self.groupId = groupId
        self.existingMemberIds = existingMemberIds
        self.currentUserId = currentUserId
        self.searchUsersUseCase = searchUsersUseCase
        self.addFriendUseCase = addFriendUseCase
        self.inviteFriendsUseCase = inviteFriendsUseCase
        self.onInvited = onInvited
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
                let filtered = results.filter { result in
                    !existingMemberIds.contains(result.user.id)
                        && result.user.id != currentUserId
                }
                searchResults = filtered
                searchState = .loaded(filtered)
            } catch {
                guard !Task.isCancelled else { return }
                searchResults = []
                searchState = .failed(error.localizedDescription)
            }
        }
    }

    func toggleSelection(_ userId: UUID) {
        if selectedIds.contains(userId) {
            selectedIds.remove(userId)
        } else {
            selectedIds.insert(userId)
        }
    }

    func sendFriendRequest(to result: UserSearchResult) async {
        guard result.friendStatus == .none else { return }
        let userId = result.user.id
        guard !sendingFriendRequestUserIds.contains(userId) else { return }

        sendingFriendRequestUserIds.insert(userId)
        defer { sendingFriendRequestUserIds.remove(userId) }

        do {
            _ = try await addFriendUseCase.execute(username: result.user.username, message: nil)
            updateSearchResult(userId: userId, status: .requestSent)
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    func submit() async {
        guard !selectedIds.isEmpty else {
            alertMessage = "Chọn ít nhất một người."
            return
        }
        state = .submitting
        do {
            let result = try await inviteFriendsUseCase.execute(
                groupId: groupId,
                userIds: Array(selectedIds)
            )
            let invitedCount = result.invited.count
            let skippedCount = result.skipped.count
            if invitedCount > 0 {
                successMessage = "Đã mời \(invitedCount) người vào nhóm."
                onInvited()
            } else if skippedCount > 0 {
                alertMessage = "Không thể mời (có thể chưa kết bạn, đã trong nhóm hoặc bị chặn)."
            } else {
                alertMessage = "Không có ai được mời."
            }
            selectedIds.removeAll()
            state = .idle
        } catch {
            alertMessage = error.localizedDescription
            state = .idle
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
