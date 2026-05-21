import SwiftUI
import DesignSystem
import Common
import SplickDomain

struct GroupDetailView: View {
    @StateObject private var viewModel: GroupDetailViewModel
    let onUserTap: (UserSummary) -> Void
    let fetchInviteCodeUseCase: FetchGroupInviteCodeUseCaseProtocol
    let generateInviteCodeUseCase: GenerateGroupInviteCodeUseCaseProtocol
    let searchUsersUseCase: SearchUsersUseCaseProtocol
    let addFriendUseCase: AddFriendUseCaseProtocol
    let inviteFriendsUseCase: InviteFriendsToGroupUseCaseProtocol

    @Environment(\.currentUserSummary) private var currentUserSummary

    @State private var showGroupQR = false
    @State private var showInviteFriends = false

    init(
        group: SplickDomain.Group,
        onUserTap: @escaping (UserSummary) -> Void,
        fetchGroupMembersUseCase: FetchGroupMembersUseCaseProtocol,
        fetchInviteCodeUseCase: FetchGroupInviteCodeUseCaseProtocol,
        generateInviteCodeUseCase: GenerateGroupInviteCodeUseCaseProtocol,
        searchUsersUseCase: SearchUsersUseCaseProtocol,
        addFriendUseCase: AddFriendUseCaseProtocol,
        inviteFriendsUseCase: InviteFriendsToGroupUseCaseProtocol
    ) {
        self.onUserTap = onUserTap
        self.fetchInviteCodeUseCase = fetchInviteCodeUseCase
        self.generateInviteCodeUseCase = generateInviteCodeUseCase
        self.searchUsersUseCase = searchUsersUseCase
        self.addFriendUseCase = addFriendUseCase
        self.inviteFriendsUseCase = inviteFriendsUseCase
        _viewModel = StateObject(
            wrappedValue: GroupDetailViewModel(
                group: group,
                fetchGroupMembersUseCase: fetchGroupMembersUseCase,
                fetchInviteCodeUseCase: fetchInviteCodeUseCase
            )
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SplickTheme.Spacing.lg) {
                headerCard
                membersSection
            }
            .padding(SplickTheme.Spacing.md)
        }
        .background(SplickTheme.Colors.background)
        .navigationTitle(viewModel.group.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                groupActionsMenu
            }
        }
        .sheet(isPresented: $showGroupQR) {
            GroupInviteQRSheet(
                groupName: viewModel.group.name,
                groupId: viewModel.group.id,
                fetchInviteCodeUseCase: fetchInviteCodeUseCase,
                generateInviteCodeUseCase: generateInviteCodeUseCase
            )
        }
        .sheet(isPresented: $showInviteFriends) {
            InviteFriendsToGroupSheet(
                groupId: viewModel.group.id,
                existingMemberIds: viewModel.existingMemberIds,
                currentUserId: currentUserSummary?.id,
                searchUsersUseCase: searchUsersUseCase,
                addFriendUseCase: addFriendUseCase,
                inviteFriendsUseCase: inviteFriendsUseCase,
                onInvited: {
                    Task { await viewModel.loadMembers() }
                }
            )
        }
        .task {
            await viewModel.load()
        }
        .refreshable {
            await viewModel.loadMembers()
        }
    }

    @ViewBuilder
    private var membersSection: some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.sm) {
            Text("Thành viên (\(viewModel.displayedMemberCount))")
                .font(SplickTheme.Typography.headline)
                .foregroundStyle(SplickTheme.Colors.textPrimary)

            switch viewModel.membersState {
            case .idle, .loading where viewModel.members.isEmpty:
                LoadingView(message: "Đang tải thành viên...")
                    .frame(minHeight: 80)
            case .failed(let message) where viewModel.members.isEmpty:
                ErrorView(message: message) {
                    Task { await viewModel.loadMembers() }
                }
                .frame(minHeight: 80)
            default:
                LazyVStack(spacing: SplickTheme.Spacing.xs) {
                    ForEach(viewModel.sortedMembers(currentUserId: currentUserSummary?.id)) { member in
                        Button {
                            onUserTap(member)
                        } label: {
                            memberRow(
                                member,
                                isCurrentUser: viewModel.isCurrentUser(member, currentUserId: currentUserSummary?.id)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var groupActionsMenu: some View {
        Menu {
            Button {
                showGroupQR = true
            } label: {
                Label("Mã QR & mã nhóm", systemImage: "qrcode")
            }

            Button {
                showInviteFriends = true
            } label: {
                Label("Thêm thành viên", systemImage: "person.badge.plus")
            }
        } label: {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 28))
                .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
        }
        .accessibilityLabel("Thao tác nhóm")
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.sm) {
            HStack(spacing: SplickTheme.Spacing.sm) {
                Image(systemName: "person.3.fill")
                    .font(.title2)
                    .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
                    .frame(width: 52, height: 52)
                    .background(SplickTheme.Colors.primaryGradientStart.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: SplickTheme.Spacing.xxxs) {
                    Text(viewModel.group.name)
                        .font(SplickTheme.Typography.title)
                    Text("\(viewModel.displayedMemberCount) thành viên")
                        .font(SplickTheme.Typography.caption)
                        .foregroundStyle(SplickTheme.Colors.textSecondary)
                }
            }

            if let description = viewModel.group.description, !description.isEmpty {
                Text(description)
                    .font(SplickTheme.Typography.callout)
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
            }

            if !viewModel.displayedInviteCode.isEmpty {
                HStack {
                    Text("Mã mời: \(viewModel.displayedInviteCode)")
                        .font(SplickTheme.Typography.caption)
                        .foregroundStyle(SplickTheme.Colors.textSecondary)
                    Spacer()
                }
            }
        }
        .splickCard()
    }

    private func memberRow(_ user: UserSummary, isCurrentUser: Bool) -> some View {
        HStack(spacing: SplickTheme.Spacing.sm) {
            AvatarView(imageURL: user.avatarURL, name: user.displayName, size: .medium)

            VStack(alignment: .leading, spacing: SplickTheme.Spacing.xxxs) {
                Text(isCurrentUser ? "\(user.displayName) (tôi)" : user.displayName)
                    .font(SplickTheme.Typography.headline)
                    .foregroundStyle(SplickTheme.Colors.textPrimary)
                Text("@\(user.username)")
                    .font(SplickTheme.Typography.caption)
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(SplickTheme.Colors.textTertiary)
        }
        .splickCard(padding: SplickTheme.Spacing.sm)
    }
}
