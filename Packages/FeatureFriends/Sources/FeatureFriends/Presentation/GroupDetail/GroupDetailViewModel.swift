import Foundation
import Common
import Localization
import Networking
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
    @Published var showTransferBeforeLeave = false

    private let fetchGroupMembersUseCase: FetchGroupMembersUseCaseProtocol
    private let fetchInviteCodeUseCase: FetchGroupInviteCodeUseCaseProtocol
    private let generateInviteCodeUseCase: GenerateGroupInviteCodeUseCaseProtocol
    private let fetchGroupUseCase: FetchGroupUseCaseProtocol?
    private let approveMemberUseCase: ApproveGroupMemberUseCaseProtocol?
    private let rejectMemberUseCase: RejectGroupMemberUseCaseProtocol?
    private let removeMemberUseCase: RemoveGroupMemberUseCaseProtocol?
    private let leaveGroupUseCase: LeaveGroupUseCaseProtocol?
    private let deleteGroupUseCase: DeleteGroupUseCaseProtocol?
    private let languageService: LanguageService

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
        generateInviteCodeUseCase: GenerateGroupInviteCodeUseCaseProtocol,
        fetchGroupUseCase: FetchGroupUseCaseProtocol? = nil,
        approveMemberUseCase: ApproveGroupMemberUseCaseProtocol? = nil,
        rejectMemberUseCase: RejectGroupMemberUseCaseProtocol? = nil,
        removeMemberUseCase: RemoveGroupMemberUseCaseProtocol? = nil,
        leaveGroupUseCase: LeaveGroupUseCaseProtocol? = nil,
        deleteGroupUseCase: DeleteGroupUseCaseProtocol? = nil,
        languageService: LanguageService
    ) {
        self.group = group
        self.fetchGroupMembersUseCase = fetchGroupMembersUseCase
        self.fetchInviteCodeUseCase = fetchInviteCodeUseCase
        self.generateInviteCodeUseCase = generateInviteCodeUseCase
        self.fetchGroupUseCase = fetchGroupUseCase
        self.approveMemberUseCase = approveMemberUseCase
        self.rejectMemberUseCase = rejectMemberUseCase
        self.removeMemberUseCase = removeMemberUseCase
        self.leaveGroupUseCase = leaveGroupUseCase
        self.deleteGroupUseCase = deleteGroupUseCase
        self.languageService = languageService
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
            membersState = .failed(languageService.localizedMessage(for: error))
        }
    }

    func loadPendingMembers() async {
        pendingState = .loading
        do {
            let loaded = try await fetchGroupMembersUseCase.execute(groupId: group.id, status: "PENDING")
            pendingMembers = loaded
            pendingState = .loaded(loaded)
        } catch {
            pendingState = .failed(languageService.localizedMessage(for: error))
            pendingMembers = []
        }
    }

    func refreshInviteCodeLabel() async {
        do {
            if let active = try await fetchInviteCodeUseCase.execute(groupId: group.id) {
                let code = active.code.trimmingCharacters(in: .whitespacesAndNewlines)
                if !code.isEmpty {
                    displayedInviteCode = code
                    return
                }
            }
        } catch {
            return
        }
        if !displayedInviteCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return
        }
        if let generated = try? await generateInviteCodeUseCase.execute(groupId: group.id) {
            displayedInviteCode = generated.code
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
            actionMessage = languageService.format(.friendsMemberApproved, member.displayName)
            await loadMembers()
            await loadPendingMembers()
        } catch {
            actionError = languageService.localizedMessage(for: error)
        }
    }

    func reject(_ member: GroupMemberItem, currentUserId: UUID?) async {
        guard isOwner(currentUserId: currentUserId), let rejectMemberUseCase else { return }
        do {
            try await rejectMemberUseCase.execute(groupId: group.id, memberRowId: member.id)
            actionMessage = languageService.format(.friendsMemberRejected, member.displayName)
            await loadPendingMembers()
        } catch {
            actionError = languageService.localizedMessage(for: error)
        }
    }

    func remove(_ member: GroupMemberItem, currentUserId: UUID?) async {
        guard isOwner(currentUserId: currentUserId), let removeMemberUseCase else { return }
        guard !member.isOwner else {
            actionError = languageService.text(.friendsCannotRemoveOwner)
            return
        }
        do {
            try await removeMemberUseCase.execute(groupId: group.id, memberRowId: member.id)
            actionMessage = languageService.format(.friendsMemberRemoved, member.displayName)
            await loadMembers()
        } catch {
            actionError = languageService.localizedMessage(for: error)
        }
    }

    func leave(currentUserId: UUID?) async -> Bool {
        guard let leaveGroupUseCase, let currentUserId else { return false }
        if isOwner(currentUserId: currentUserId) {
            showTransferBeforeLeave = true
            return false
        }
        do {
            try await leaveGroupUseCase.execute(groupId: group.id)
            return true
        } catch {
            if error.isIgnorableSocialLeave {
                return true
            }
            if error.isOwnershipTransferRequired {
                showTransferBeforeLeave = true
                return false
            }
            actionError = languageService.localizedMessage(for: error)
            return false
        }
    }

    func deleteGroup(currentUserId: UUID?) async -> Bool {
        guard isOwner(currentUserId: currentUserId), let deleteGroupUseCase else { return false }
        do {
            try await deleteGroupUseCase.execute(groupId: group.id)
            return true
        } catch {
            actionError = languageService.localizedMessage(for: error)
            return false
        }
    }

    func applyUpdatedGroup(_ updated: Group) {
        group = updated
    }
}

private extension Error {
    var isOwnershipTransferRequired: Bool {
        if case .apiError(let code, _, _) = self as? NetworkError {
            return code.caseInsensitiveCompare("OWNERSHIP_TRANSFER_REQUIRED") == .orderedSame
        }
        return false
    }

    var isIgnorableSocialLeave: Bool {
        guard let network = self as? NetworkError else { return false }
        switch network {
        case .notFound, .forbidden:
            return true
        default:
            return false
        }
    }
}
