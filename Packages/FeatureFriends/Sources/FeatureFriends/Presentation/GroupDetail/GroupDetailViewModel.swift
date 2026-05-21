import Foundation
import Common
import SplickDomain

@MainActor
final class GroupDetailViewModel: ObservableObject {
    let group: Group

    @Published private(set) var members: [UserSummary] = []
    @Published private(set) var membersState: LoadingState<[UserSummary]> = .idle
    @Published var displayedInviteCode: String

    private let fetchGroupMembersUseCase: FetchGroupMembersUseCaseProtocol
    private let fetchInviteCodeUseCase: FetchGroupInviteCodeUseCaseProtocol

    var displayedMemberCount: Int {
        if case .loaded = membersState, !members.isEmpty {
            return members.count
        }
        return group.memberCount
    }

    var existingMemberIds: Set<UUID> {
        Set(members.map(\.id))
    }

    init(
        group: Group,
        fetchGroupMembersUseCase: FetchGroupMembersUseCaseProtocol,
        fetchInviteCodeUseCase: FetchGroupInviteCodeUseCaseProtocol
    ) {
        self.group = group
        self.fetchGroupMembersUseCase = fetchGroupMembersUseCase
        self.fetchInviteCodeUseCase = fetchInviteCodeUseCase
        self.displayedInviteCode = group.inviteCode
    }

    func load() async {
        await loadMembers()
        await refreshInviteCodeLabel()
    }

    func loadMembers() async {
        membersState = .loading
        do {
            let loaded = try await fetchGroupMembersUseCase.execute(groupId: group.id, status: "ACTIVE")
            members = loaded
            membersState = .loaded(loaded)
        } catch {
            membersState = .failed(error.localizedDescription)
        }
    }

    func refreshInviteCodeLabel() async {
        guard displayedInviteCode.isEmpty else { return }
        if let code = try? await fetchInviteCodeUseCase.execute(groupId: group.id) {
            displayedInviteCode = code.code
        }
    }

    func sortedMembers(currentUserId: UUID?) -> [UserSummary] {
        guard let me = currentUserId else { return members }
        return members.sorted { lhs, rhs in
            if lhs.id == me { return true }
            if rhs.id == me { return false }
            return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }
    }

    func isCurrentUser(_ user: UserSummary, currentUserId: UUID?) -> Bool {
        currentUserId == user.id
    }
}
