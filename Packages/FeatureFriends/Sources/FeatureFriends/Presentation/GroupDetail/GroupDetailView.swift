import SwiftUI
import DesignSystem
import Common
import FeatureMedia
import SplickDomain

struct GroupDetailView: View {
    @StateObject private var viewModel: GroupDetailViewModel
    let onUserTap: (UserSummary) -> Void
    let onGroupLeft: () -> Void
    let onGroupDeleted: () -> Void
    let generateGroupQrUseCase: GenerateGroupQrUseCaseProtocol
    let revokeGroupQrUseCase: RevokeGroupQrUseCaseProtocol
    let updateGroupUseCase: UpdateGroupUseCaseProtocol
    let updateGroupAvatarUseCase: UpdateGroupAvatarUseCaseProtocol
    let uploadGroupAvatarUseCase: UploadGroupAvatarUseCaseProtocol
    let transferOwnershipUseCase: TransferGroupOwnershipUseCaseProtocol
    let searchUsersUseCase: SearchUsersUseCaseProtocol
    let addFriendUseCase: AddFriendUseCaseProtocol
    let inviteFriendsUseCase: InviteFriendsToGroupUseCaseProtocol

    @Environment(\.currentUserSummary) private var currentUserSummary
    @Environment(\.dismiss) private var dismiss

    @State private var showGroupQR = false
    @State private var showInviteFriends = false
    @State private var showEditGroup = false
    @State private var showTransferOwnership = false
    @State private var confirmLeave = false
    @State private var confirmDelete = false

    init(
        group: SplickDomain.Group,
        onUserTap: @escaping (UserSummary) -> Void,
        onGroupLeft: @escaping () -> Void = {},
        onGroupDeleted: @escaping () -> Void = {},
        fetchGroupMembersUseCase: FetchGroupMembersUseCaseProtocol,
        fetchInviteCodeUseCase: FetchGroupInviteCodeUseCaseProtocol,
        generateGroupQrUseCase: GenerateGroupQrUseCaseProtocol,
        revokeGroupQrUseCase: RevokeGroupQrUseCaseProtocol,
        updateGroupUseCase: UpdateGroupUseCaseProtocol,
        updateGroupAvatarUseCase: UpdateGroupAvatarUseCaseProtocol,
        uploadGroupAvatarUseCase: UploadGroupAvatarUseCaseProtocol,
        transferOwnershipUseCase: TransferGroupOwnershipUseCaseProtocol,
        searchUsersUseCase: SearchUsersUseCaseProtocol,
        addFriendUseCase: AddFriendUseCaseProtocol,
        inviteFriendsUseCase: InviteFriendsToGroupUseCaseProtocol,
        fetchGroupUseCase: FetchGroupUseCaseProtocol? = nil,
        approveMemberUseCase: ApproveGroupMemberUseCaseProtocol? = nil,
        rejectMemberUseCase: RejectGroupMemberUseCaseProtocol? = nil,
        removeMemberUseCase: RemoveGroupMemberUseCaseProtocol? = nil,
        leaveGroupUseCase: LeaveGroupUseCaseProtocol? = nil,
        deleteGroupUseCase: DeleteGroupUseCaseProtocol? = nil
    ) {
        self.onUserTap = onUserTap
        self.onGroupLeft = onGroupLeft
        self.onGroupDeleted = onGroupDeleted
        self.generateGroupQrUseCase = generateGroupQrUseCase
        self.revokeGroupQrUseCase = revokeGroupQrUseCase
        self.updateGroupUseCase = updateGroupUseCase
        self.updateGroupAvatarUseCase = updateGroupAvatarUseCase
        self.uploadGroupAvatarUseCase = uploadGroupAvatarUseCase
        self.transferOwnershipUseCase = transferOwnershipUseCase
        self.searchUsersUseCase = searchUsersUseCase
        self.addFriendUseCase = addFriendUseCase
        self.inviteFriendsUseCase = inviteFriendsUseCase
        _viewModel = StateObject(
            wrappedValue: GroupDetailViewModel(
                group: group,
                fetchGroupMembersUseCase: fetchGroupMembersUseCase,
                fetchInviteCodeUseCase: fetchInviteCodeUseCase,
                fetchGroupUseCase: fetchGroupUseCase,
                approveMemberUseCase: approveMemberUseCase,
                rejectMemberUseCase: rejectMemberUseCase,
                removeMemberUseCase: removeMemberUseCase,
                leaveGroupUseCase: leaveGroupUseCase,
                deleteGroupUseCase: deleteGroupUseCase
            )
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SplickTheme.Spacing.lg) {
                headerCard
                if !viewModel.pendingMembers.isEmpty {
                    pendingMembersSection
                }
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
                generateGroupQrUseCase: generateGroupQrUseCase,
                revokeGroupQrUseCase: revokeGroupQrUseCase
            )
        }
        .sheet(isPresented: $showEditGroup) {
            EditGroupSheet(
                group: viewModel.group,
                updateGroupUseCase: updateGroupUseCase,
                updateGroupAvatarUseCase: updateGroupAvatarUseCase,
                uploadGroupAvatarUseCase: uploadGroupAvatarUseCase,
                onSaved: { updated in
                    viewModel.applyUpdatedGroup(updated)
                }
            )
        }
        .sheet(isPresented: $showTransferOwnership) {
            TransferGroupOwnershipSheet(
                groupId: viewModel.group.id,
                members: viewModel.members,
                currentUserId: currentUserSummary?.id,
                transferOwnershipUseCase: transferOwnershipUseCase,
                onTransferred: { updated in
                    viewModel.applyUpdatedGroup(updated)
                    Task { await viewModel.load(currentUserId: currentUserSummary?.id) }
                }
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
                    Task {
                        await viewModel.loadMembers()
                        await viewModel.loadPendingMembers()
                    }
                }
            )
        }
        .task {
            await viewModel.load(currentUserId: currentUserSummary?.id)
        }
        .refreshable {
            await viewModel.load(currentUserId: currentUserSummary?.id)
        }
        .alert("Thông báo", isPresented: Binding(
            get: { viewModel.actionMessage != nil },
            set: { if !$0 { viewModel.actionMessage = nil } }
        )) {
            Button("OK", role: .cancel) { viewModel.actionMessage = nil }
        } message: {
            Text(viewModel.actionMessage ?? "")
        }
        .alert("Lỗi", isPresented: Binding(
            get: { viewModel.actionError != nil },
            set: { if !$0 { viewModel.actionError = nil } }
        )) {
            Button("OK", role: .cancel) { viewModel.actionError = nil }
        } message: {
            Text(viewModel.actionError ?? "")
        }
        .confirmationDialog("Rời nhóm?", isPresented: $confirmLeave, titleVisibility: .visible) {
            Button("Rời nhóm", role: .destructive) {
                Task {
                    if await viewModel.leave(currentUserId: currentUserSummary?.id) {
                        onGroupLeft()
                        dismiss()
                    }
                }
            }
            Button("Huỷ", role: .cancel) {}
        }
        .confirmationDialog("Xóa nhóm?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Xóa nhóm", role: .destructive) {
                Task {
                    if await viewModel.deleteGroup(currentUserId: currentUserSummary?.id) {
                        onGroupDeleted()
                        dismiss()
                    }
                }
            }
            Button("Huỷ", role: .cancel) {}
        }
    }

    @ViewBuilder
    private var pendingMembersSection: some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.sm) {
            Text("Chờ duyệt (\(viewModel.pendingMembers.count))")
                .font(SplickTheme.Typography.headline)
                .foregroundStyle(SplickTheme.Colors.textPrimary)

            ForEach(viewModel.pendingMembers) { member in
                HStack(spacing: SplickTheme.Spacing.sm) {
                    AvatarView(imageURL: member.avatarURL, name: member.displayName, size: .medium)
                    VStack(alignment: .leading) {
                        Text(member.displayName)
                            .font(SplickTheme.Typography.headline)
                        Text("@\(member.username)")
                            .font(SplickTheme.Typography.caption)
                            .foregroundStyle(SplickTheme.Colors.textSecondary)
                    }
                    Spacer()
                    if viewModel.isOwner(currentUserId: currentUserSummary?.id) {
                        Button("Duyệt") {
                            Task { await viewModel.approve(member, currentUserId: currentUserSummary?.id) }
                        }
                        .buttonStyle(.borderedProminent)
                        Button("Từ chối") {
                            Task { await viewModel.reject(member, currentUserId: currentUserSummary?.id) }
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .splickCard(padding: SplickTheme.Spacing.sm)
            }
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
                        memberRow(member)
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

            if viewModel.isOwner(currentUserId: currentUserSummary?.id) {
                Button {
                    showEditGroup = true
                } label: {
                    Label("Chỉnh sửa nhóm", systemImage: "pencil")
                }

                Button {
                    showTransferOwnership = true
                } label: {
                    Label("Chuyển quyền chủ nhóm", systemImage: "person.crop.circle.badge.checkmark")
                }

                Divider()
                Button(role: .destructive) {
                    confirmDelete = true
                } label: {
                    Label("Xóa nhóm", systemImage: "trash")
                }
            } else {
                Button(role: .destructive) {
                    confirmLeave = true
                } label: {
                    Label("Rời nhóm", systemImage: "rectangle.portrait.and.arrow.right")
                }
            }
        } label: {
            Image(systemName: "ellipsis.circle.fill")
                .font(.system(size: 28))
                .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
        }
        .accessibilityLabel("Thao tác nhóm")
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.sm) {
            HStack(spacing: SplickTheme.Spacing.sm) {
                if let avatarURL = viewModel.group.avatarURL {
                    AvatarView(imageURL: avatarURL, name: viewModel.group.name, size: .large)
                } else {
                    Image(systemName: "person.3.fill")
                        .font(.title2)
                        .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
                        .frame(width: 52, height: 52)
                        .background(SplickTheme.Colors.primaryGradientStart.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

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

    @ViewBuilder
    private func memberRow(_ member: GroupMemberItem) -> some View {
        let isMe = viewModel.isCurrentUser(member, currentUserId: currentUserSummary?.id)
        let userSummary = UserSummary(
            id: member.userId,
            username: member.username,
            displayName: member.displayName,
            avatarURL: member.avatarURL
        )

        HStack(spacing: SplickTheme.Spacing.sm) {
            Button {
                onUserTap(userSummary)
            } label: {
                HStack(spacing: SplickTheme.Spacing.sm) {
                    AvatarView(imageURL: member.avatarURL, name: member.displayName, size: .medium)
                    VStack(alignment: .leading, spacing: SplickTheme.Spacing.xxxs) {
                        Text(isMe ? "\(member.displayName) (tôi)" : member.displayName)
                            .font(SplickTheme.Typography.headline)
                            .foregroundStyle(SplickTheme.Colors.textPrimary)
                        Text("@\(member.username)")
                            .font(SplickTheme.Typography.caption)
                            .foregroundStyle(SplickTheme.Colors.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(SplickTheme.Colors.textTertiary)
                }
            }
            .buttonStyle(.plain)

            if viewModel.isOwner(currentUserId: currentUserSummary?.id), !member.isOwner, !isMe {
                Menu {
                    Button(role: .destructive) {
                        Task { await viewModel.remove(member, currentUserId: currentUserSummary?.id) }
                    } label: {
                        Label("Xóa khỏi nhóm", systemImage: "person.fill.xmark")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundStyle(SplickTheme.Colors.textSecondary)
                        .padding(.horizontal, SplickTheme.Spacing.xs)
                }
            }
        }
        .splickCard(padding: SplickTheme.Spacing.sm)
    }
}
