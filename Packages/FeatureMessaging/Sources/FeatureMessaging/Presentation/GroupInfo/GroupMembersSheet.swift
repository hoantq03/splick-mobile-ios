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

    init(
        groupId: UUID,
        currentUserId: UUID,
        fetchMembers: @escaping (UUID) async throws -> [GroupChatMember],
        removeMember: @escaping (UUID, UUID) async throws -> Void
    ) {
        self.groupId = groupId
        self.currentUserId = currentUserId
        self.fetchMembers = fetchMembers
        self.removeMember = removeMember
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

    func canRemove(_ member: GroupChatMember) -> Bool {
        member.userId != currentUserId && !member.isOwner
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

    init(
        groupId: UUID,
        currentUserId: UUID,
        fetchMembers: @escaping (UUID) async throws -> [GroupChatMember],
        removeMember: @escaping (UUID, UUID) async throws -> Void
    ) {
        _viewModel = StateObject(
            wrappedValue: GroupMembersSheetViewModel(
                groupId: groupId,
                currentUserId: currentUserId,
                fetchMembers: fetchMembers,
                removeMember: removeMember
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
                ToolbarItem(placement: .confirmationAction) {
                    Button(languageService.text(.commonDone)) { dismiss() }
                }
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
        }
    }

    private func displayName(for member: GroupChatMember) -> String {
        if member.userId == viewModel.currentUserId {
            return "\(member.displayName) (\(languageService.text(.messagingYou)))"
        }
        return member.displayName
    }
}
