import Foundation
import Common
import SplickDomain

@MainActor
final class GroupDetailViewModel: ObservableObject {
    @Published private(set) var group: Group
    @Published private(set) var members: [GroupMemberItem] = []
    @Published private(set) var pendingMembers: [GroupMemberItem] = []
    @Published private(set) var membersState: LoadingState<[GroupMemberItem]> = .idle
    @Published private(set) var pendingState: LoadingState<[GroupMemberItem]> = .idle
    @Published var displayedInviteCode: String
    @Published var actionMessage: String?
    @Published var actionError: String?

    private let fetchGroupMembersUseCase: FetchGroupMembersUseCaseProtocol
    private let fetchInviteCodeUseCase: FetchGroupInviteCodeUseCaseProtocol
    private let fetchGroupUseCase: FetchGroupUseCaseProtocol?
    private let approveMemberUseCase: ApproveGroupMemberUseCaseProtocol?
    private let rejectMemberUseCase: RejectGroupMemberUseCaseProtocol?
    private let removeMemberUseCase: RemoveGroupMemberUseCaseProtocol?
    private let leaveGroupUseCase: LeaveGroupUseCaseProtocol?
    private let deleteGroupUseCase: DeleteGroupUseCaseProtocol?

    var displayedMemberCount: Int {
        if case .loaded = membersState, !members.isEmpty {
            return members.count
        }
        return group.memberCount
    }

    var existingMemberIds: Set<UUID> {
        var ids = Set(members.map(\.userId))
        ids.formUnion(pendingMembers.map(\.userId))
        return ids
    }

    init(
        group: Group,
        fetchGroupMembersUseCase: FetchGroupMembersUseCaseProtocol,
        fetchInviteCodeUseCase: FetchGroupInviteCodeUseCaseProtocol,
        fetchGroupUseCase: FetchGroupUseCaseProtocol? = nil,
        approveMemberUseCase: ApproveGroupMemberUseCaseProtocol? = nil,
        rejectMemberUseCase: RejectGroupMemberUseCaseProtocol? = nil,
        removeMemberUseCase: RemoveGroupMemberUseCaseProtocol? = nil,
        leaveGroupUseCase: LeaveGroupUseCaseProtocol? = nil,
        deleteGroupUseCase: DeleteGroupUseCaseProtocol? = nil
    ) {
        self.group = group
        self.fetchGroupMembersUseCase = fetchGroupMembersUseCase
        self.fetchInviteCodeUseCase = fetchInviteCodeUseCase
        self.fetchGroupUseCase = fetchGroupUseCase
        self.approveMemberUseCase = approveMemberUseCase
        self.rejectMemberUseCase = rejectMemberUseCase
        self.removeMemberUseCase = removeMemberUseCase
        self.leaveGroupUseCase = leaveGroupUseCase
        self.deleteGroupUseCase = deleteGroupUseCase
        self.displayedInviteCode = group.inviteCode
    }

    func isOwner(currentUserId: UUID?) -> Bool {
        guard let currentUserId else { return false }
        return group.createdBy == currentUserId
    }

    func load(currentUserId: UUID?) async {
        await refreshGroupIfNeeded()
        await loadMembers()
        if isOwner(currentUserId: currentUserId) {
            await loadPendingMembers()
        } else {
            pendingMembers = []
            pendingState = .idle
        }
        await refreshInviteCodeLabel()
    }

    private func refreshGroupIfNeeded() async {
        guard let fetchGroupUseCase else { return }
        if let refreshed = try? await fetchGroupUseCase.execute(groupId: group.id) {
            group = refreshed
        }
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

    func loadPendingMembers() async {
        pendingState = .loading
        do {
            let loaded = try await fetchGroupMembersUseCase.execute(groupId: group.id, status: "PENDING")
            pendingMembers = loaded
            pendingState = .loaded(loaded)
        } catch {
            pendingState = .failed(error.localizedDescription)
            pendingMembers = []
        }
    }

    func refreshInviteCodeLabel() async {
        guard displayedInviteCode.isEmpty else { return }
        if let code = try? await fetchInviteCodeUseCase.execute(groupId: group.id) {
            displayedInviteCode = code.code
        }
    }

    func sortedMembers(currentUserId: UUID?) -> [GroupMemberItem] {
        guard let me = currentUserId else { return members }
        return members.sorted { lhs, rhs in
            if lhs.userId == me { return true }
            if rhs.userId == me { return false }
            return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }
    }

    func isCurrentUser(_ member: GroupMemberItem, currentUserId: UUID?) -> Bool {
        currentUserId == member.userId
    }

    func approve(_ member: GroupMemberItem, currentUserId: UUID?) async {
        guard isOwner(currentUserId: currentUserId), let approveMemberUseCase else { return }
        do {
            try await approveMemberUseCase.execute(groupId: group.id, memberRowId: member.id)
            actionMessage = "Đã duyệt \(member.displayName)"
            await loadMembers()
            await loadPendingMembers()
        } catch {
            actionError = error.localizedDescription
        }
    }

    func reject(_ member: GroupMemberItem, currentUserId: UUID?) async {
        guard isOwner(currentUserId: currentUserId), let rejectMemberUseCase else { return }
        do {
            try await rejectMemberUseCase.execute(groupId: group.id, memberRowId: member.id)
            actionMessage = "Đã từ chối \(member.displayName)"
            await loadPendingMembers()
        } catch {
            actionError = error.localizedDescription
        }
    }

    func remove(_ member: GroupMemberItem, currentUserId: UUID?) async {
        guard isOwner(currentUserId: currentUserId), let removeMemberUseCase else { return }
        guard !member.isOwner else {
            actionError = "Không thể xóa chủ nhóm"
            return
        }
        do {
            try await removeMemberUseCase.execute(groupId: group.id, memberRowId: member.id)
            actionMessage = "Đã xóa \(member.displayName) khỏi nhóm"
            await loadMembers()
        } catch {
            actionError = error.localizedDescription
        }
    }

    func leave(currentUserId: UUID?) async -> Bool {
        guard let leaveGroupUseCase, let currentUserId else { return false }
        if isOwner(currentUserId: currentUserId) {
            actionError = "Chuyển quyền chủ nhóm trước khi rời nhóm"
            return false
        }
        do {
            try await leaveGroupUseCase.execute(groupId: group.id)
            return true
        } catch {
            actionError = error.localizedDescription
            return false
        }
    }

    func deleteGroup(currentUserId: UUID?) async -> Bool {
        guard isOwner(currentUserId: currentUserId), let deleteGroupUseCase else { return false }
        do {
            try await deleteGroupUseCase.execute(groupId: group.id)
            return true
        } catch {
            actionError = error.localizedDescription
            return false
        }
    }

    func applyUpdatedGroup(_ updated: Group) {
        group = updated
    }
}
