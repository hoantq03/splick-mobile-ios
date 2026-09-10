import SwiftUI
import Common
import DesignSystem
import Localization

@MainActor
final class GroupMembersSheetViewModel: ObservableObject {
    @Published private(set) var members: [GroupChatMember] = []
    @Published private(set) var state: LoadingState<[GroupChatMember]> = .idle
    @Published var actionError: String?

    let currentUserId: UUID
    private let groupId: UUID
    private let fetchMembers: (UUID) async throws -> [GroupChatMember]
    private let removeMember: (UUID, UUID) async throws -> Void
    private let transferAdmin: ((UUID, UUID) async throws -> Void)?
    private let onTransferred: (() -> Void)?

    init(
        groupId: UUID,
        currentUserId: UUID,
        fetchMembers: @escaping (UUID) async throws -> [GroupChatMember],
        removeMember: @escaping (UUID, UUID) async throws -> Void,
        transferAdmin: ((UUID, UUID) async throws -> Void)? = nil,
        onTransferred: (() -> Void)? = nil
    ) {
        self.groupId = groupId
        self.currentUserId = currentUserId
        self.fetchMembers = fetchMembers
        self.removeMember = removeMember
        self.transferAdmin = transferAdmin
        self.onTransferred = onTransferred
    }

    func load() async {
        state = .loading
        do {
            let loaded = try await fetchMembers(groupId)
            members = sorted(loaded)
            state = .loaded(members)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func remove(_ member: GroupChatMember) async {
        guard member.userId != currentUserId, !member.isOwner else { return }
        actionError = nil
        do {
            try await removeMember(groupId, member.userId)
            members.removeAll { $0.id == member.id }
            state = .loaded(members)
        } catch {
            actionError = error.localizedDescription
        }
    }

    var isCurrentUserAdmin: Bool {
        members.contains { $0.userId == currentUserId && $0.isOwner }
    }

    func canRemove(_ member: GroupChatMember) -> Bool {
        isCurrentUserAdmin && member.userId != currentUserId && !member.isOwner
    }

    func canTransfer(to member: GroupChatMember) -> Bool {
        transferAdmin != nil && isCurrentUserAdmin && member.userId != currentUserId && !member.isOwner
    }

    func transfer(to member: GroupChatMember) async {
        guard canTransfer(to: member), let transferAdmin else { return }
        actionError = nil
        do {
            try await transferAdmin(groupId, member.userId)
            onTransferred?()
            await load()
        } catch {
            actionError = error.localizedDescription
        }
    }

    private func sorted(_ members: [GroupChatMember]) -> [GroupChatMember] {
        members.sorted { lhs, rhs in
            if lhs.userId == currentUserId { return true }
            if rhs.userId == currentUserId { return false }
            if lhs.isOwner != rhs.isOwner { return lhs.isOwner }
            return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }
    }
}

struct GroupMembersSheet: View {
    @StateObject private var viewModel: GroupMembersSheetViewModel
    @EnvironmentObject private var languageService: LanguageService
    @Environment(\.dismiss) private var dismiss
    private let onAddMembers: ((Set<UUID>) -> Void)?
    private let groupId: UUID
    private let fetchMembers: (UUID) async throws -> [GroupChatMember]
    private let transferAdmin: ((UUID, UUID) async throws -> Void)?
    private let onTransferred: (() -> Void)?
    @State private var showTransferPicker = false
    @State private var memberPendingTransfer: GroupChatMember?

    init(
        groupId: UUID,
        currentUserId: UUID,
        fetchMembers: @escaping (UUID) async throws -> [GroupChatMember],
        removeMember: @escaping (UUID, UUID) async throws -> Void,
        transferAdmin: ((UUID, UUID) async throws -> Void)? = nil,
        onTransferred: (() -> Void)? = nil,
        onAddMembers: ((Set<UUID>) -> Void)? = nil
    ) {
        self.groupId = groupId
        self.fetchMembers = fetchMembers
        self.onAddMembers = onAddMembers
        self.transferAdmin = transferAdmin
        self.onTransferred = onTransferred
        _viewModel = StateObject(
            wrappedValue: GroupMembersSheetViewModel(
                groupId: groupId,
                currentUserId: currentUserId,
                fetchMembers: fetchMembers,
                removeMember: removeMember,
                transferAdmin: transferAdmin,
                onTransferred: onTransferred
            )
        )
    }

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.state {
                case .idle, .loading:
                    LoadingView(message: languageService.text(.messagingGroupMembersLoading))
                case .failed(let message):
                    ErrorView(message: message) {
                        Task { await viewModel.load() }
                    }
                case .loaded:
                    List {
                        ForEach(viewModel.members) { member in
                            memberRow(member)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle(languageService.text(.messagingGroupManageMembers))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    HStack {
                        if let onAddMembers {
                            Button {
                                var ids = Set(viewModel.members.map(\.userId))
                                ids.insert(viewModel.currentUserId)
                                onAddMembers(ids)
                            } label: {
                                Label(
                                    languageService.text(.friendsAddMembersTitle),
                                    systemImage: "person.badge.plus"
                                )
                            }
                        }
                        if transferAdmin != nil, viewModel.isCurrentUserAdmin {
                            Button {
                                showTransferPicker = true
                            } label: {
                                Label(
                                    languageService.text(.friendsTransferOwnership),
                                    systemImage: "person.crop.circle.badge.checkmark"
                                )
                            }
                        }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(languageService.text(.commonDone)) { dismiss() }
                }
            }
            .sheet(isPresented: $showTransferPicker) {
                if let transferAdmin {
                    TransferGroupAdminSheet(
                        groupId: groupId,
                        currentUserId: viewModel.currentUserId,
                        fetchMembers: fetchMembers,
                        transferAdmin: transferAdmin,
                        onTransferred: {
                            onTransferred?()
                            Task { await viewModel.load() }
                        }
                    )
                    .environmentObject(languageService)
                }
            }
            .alert(
                languageService.text(.friendsTransferTitle),
                isPresented: Binding(
                    get: { memberPendingTransfer != nil },
                    set: { if !$0 { memberPendingTransfer = nil } }
                )
            ) {
                Button(languageService.text(.commonCancel), role: .cancel) {
                    memberPendingTransfer = nil
                }
                Button(languageService.text(.friendsTransferAction)) {
                    guard let member = memberPendingTransfer else { return }
                    memberPendingTransfer = nil
                    Task { await viewModel.transfer(to: member) }
                }
            } message: {
                Text(
                    languageService.format(
                        .friendsTransferConfirmMember,
                        memberPendingTransfer?.displayName ?? ""
                    )
                )
            }
            .alert(
                languageService.text(.commonError),
                isPresented: Binding(
                    get: { viewModel.actionError != nil },
                    set: { if !$0 { viewModel.actionError = nil } }
                )
            ) {
                Button(languageService.text(.commonOK), role: .cancel) {
                    viewModel.actionError = nil
                }
            } message: {
                Text(viewModel.actionError ?? "")
            }
            .task { await viewModel.load() }
            .refreshable { await viewModel.load() }
        }
    }

    private func memberRow(_ member: GroupChatMember) -> some View {
        HStack(spacing: SplickTheme.Spacing.sm) {
            AvatarView(imageURL: member.avatarURL, name: member.displayName, size: .medium)

            VStack(alignment: .leading, spacing: 2) {
                Text(displayName(for: member))
                    .font(SplickTheme.Typography.body)
                    .foregroundStyle(SplickTheme.Colors.textPrimary)
                Text("@\(member.username)")
                    .font(SplickTheme.Typography.caption)
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
            }

            Spacer(minLength: 0)

            if member.isOwner {
                Text(languageService.text(.messagingGroupOwnerBadge))
                    .font(SplickTheme.Typography.caption.weight(.semibold))
                    .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if viewModel.canRemove(member) {
                Button(role: .destructive) {
                    Task { await viewModel.remove(member) }
                } label: {
                    Label(
                        languageService.text(.messagingGroupRemoveMember),
                        systemImage: "person.badge.minus"
                    )
                }
            }
            if viewModel.canTransfer(to: member) {
                Button {
                    memberPendingTransfer = member
                } label: {
                    Label(
                        languageService.text(.friendsTransferOwnership),
                        systemImage: "person.crop.circle.badge.checkmark"
                    )
                }
                .tint(SplickTheme.Colors.primaryGradientStart)
            }
        }
    }

    private func displayName(for member: GroupChatMember) -> String {
        if member.userId == viewModel.currentUserId {
            return "\(member.displayName) (\(languageService.text(.messagingYou)))"
        }
        return member.displayName
    }
}
