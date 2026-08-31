import SwiftUI
import UIKit
import DesignSystem
import Common
import FeatureMedia
import Localization
import SplickDomain

struct GroupDetailView: View {
    @StateObject private var viewModel: GroupDetailViewModel
    @EnvironmentObject private var languageService: LanguageService
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
    @Environment(\.openGroupChat) private var openGroupChat
    @Environment(\.addMembersToGroupConversation) private var addMembersToGroupConversation

    @State private var showGroupQR = false
    @State private var showInviteFriends = false
    @State private var showEditGroup = false
    @State private var showTransferOwnership = false
    @State private var confirmLeave = false
    @State private var confirmDelete = false
    @State private var isOpeningChat = false

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
        deleteGroupUseCase: DeleteGroupUseCaseProtocol? = nil,
        languageService: LanguageService
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
                deleteGroupUseCase: deleteGroupUseCase,
                languageService: languageService
            )
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            groupDetailHeader
            membersList
        }
        .background(SplickTheme.Colors.background)
        .navigationTitle(viewModel.group.name)
        .navigationBarTitleDisplayMode(.inline)
        .splickInteractivePopEnabled()
        .sheet(isPresented: $showGroupQR) {
            GroupInviteQRSheet(
                groupName: viewModel.group.name,
                groupId: viewModel.group.id,
                generateGroupQrUseCase: generateGroupQrUseCase,
                revokeGroupQrUseCase: revokeGroupQrUseCase,
                languageService: languageService
            )
        }
        .sheet(isPresented: $showEditGroup) {
            EditGroupSheet(
                group: viewModel.group,
                updateGroupUseCase: updateGroupUseCase,
                updateGroupAvatarUseCase: updateGroupAvatarUseCase,
                uploadGroupAvatarUseCase: uploadGroupAvatarUseCase,
                languageService: languageService,
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
                languageService: languageService,
                onInvited: { invitedIds in
                    Task {
                        await viewModel.loadMembers()
                        await viewModel.loadPendingMembers()
                        if let addMembers = addMembersToGroupConversation {
                            await addMembers(viewModel.group.id, invitedIds)
                        }
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
        .alert(languageService.text(.commonNotice), isPresented: Binding(
            get: { viewModel.actionMessage != nil },
            set: { if !$0 { viewModel.actionMessage = nil } }
        )) {
            Button(languageService.text(.commonOK), role: .cancel) { viewModel.actionMessage = nil }
        } message: {
            Text(viewModel.actionMessage ?? "")
        }
        .alert(languageService.text(.commonError), isPresented: Binding(
            get: { viewModel.actionError != nil },
            set: { if !$0 { viewModel.actionError = nil } }
        )) {
            Button(languageService.text(.commonOK), role: .cancel) { viewModel.actionError = nil }
        } message: {
            Text(viewModel.actionError ?? "")
        }
        .confirmationDialog(
            languageService.text(.friendsLeaveGroupConfirmTitle),
            isPresented: $confirmLeave,
            titleVisibility: .visible
        ) {
            Button(languageService.text(.messagingLeaveGroup), role: .destructive) {
                Task {
                    if await viewModel.leave(currentUserId: currentUserSummary?.id) {
                        onGroupLeft()
                        dismiss()
                    }
                }
            }
            Button(languageService.text(.friendsCancel), role: .cancel) {}
        } message: {
            Text(languageService.text(.friendsLeaveGroupMessage))
        }
        .alert(languageService.text(.friendsDeleteGroupConfirmTitle), isPresented: $confirmDelete) {
            Button(languageService.text(.friendsCancel), role: .cancel) {}
            Button(languageService.text(.friendsDeleteGroup), role: .destructive) {
                Task {
                    if await viewModel.deleteGroup(currentUserId: currentUserSummary?.id) {
                        onGroupDeleted()
                        dismiss()
                    }
                }
            }
        } message: {
            Text(languageService.text(.friendsDeleteGroupMessage))
        }
    }

    @ViewBuilder
    private var pendingMembersSection: some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.sm) {
            Text(languageService.format(.friendsGroupPending, viewModel.pendingMembers.count))
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
                        Button(languageService.text(.friendsApproveMember)) {
                            Task { await viewModel.approve(member, currentUserId: currentUserSummary?.id) }
                        }
                        .buttonStyle(.borderedProminent)
                        Button(languageService.text(.friendsReject)) {
                            Task { await viewModel.reject(member, currentUserId: currentUserSummary?.id) }
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .splickCard(padding: SplickTheme.Spacing.sm)
            }
        }
    }

    private var groupDetailHeader: some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.lg) {
            headerCard

            if !viewModel.pendingMembers.isEmpty {
                pendingMembersSection
            }

            Text(languageService.format(.friendsGroupMembers, viewModel.displayedMemberCount))
                .font(SplickTheme.Typography.headline)
                .foregroundStyle(SplickTheme.Colors.textPrimary)
        }
        .padding(.horizontal, SplickTheme.Spacing.md)
        .padding(.top, SplickTheme.Spacing.md)
        .padding(.bottom, SplickTheme.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SplickTheme.Colors.background)
    }

    @ViewBuilder
    private var membersList: some View {
        ScrollView {
            switch viewModel.membersState {
            case .idle, .loading where viewModel.members.isEmpty:
                LoadingView(message: languageService.text(.messagingGroupMembersLoading))
                    .frame(minHeight: 120)
                    .frame(maxWidth: .infinity)
            case .failed(let message) where viewModel.members.isEmpty:
                ErrorView(message: message) {
                    Task { await viewModel.loadMembers() }
                }
                .frame(minHeight: 120)
                .frame(maxWidth: .infinity)
            default:
                LazyVStack(spacing: SplickTheme.Spacing.xs) {
                    ForEach(viewModel.sortedMembers(currentUserId: currentUserSummary?.id)) { member in
                        memberRow(member)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, SplickTheme.Spacing.md)
        .padding(.bottom, SplickTheme.Spacing.md)
    }

    private var headerCard: some View {
        HStack(alignment: .top, spacing: SplickTheme.Spacing.sm) {
            VStack(alignment: .leading, spacing: SplickTheme.Spacing.xs) {
                headerIdentityRow

                if let description = viewModel.group.description, !description.isEmpty {
                    Text(description)
                        .font(SplickTheme.Typography.callout)
                        .foregroundStyle(SplickTheme.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            headerQuickActions
        }
        .splickCard()
    }

    private var headerIdentityRow: some View {
        HStack(alignment: .center, spacing: SplickTheme.Spacing.sm) {
            if let avatarURL = viewModel.group.avatarURL {
                AvatarView(imageURL: avatarURL, name: viewModel.group.name, size: .large)
            } else {
                Image(systemName: "person.3.fill")
                    .font(.title2)
                    .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
                    .frame(width: 52, height: 52)
                    .background(SplickTheme.Colors.primaryGradientStart.opacity(0.12))
                    .clipShape(Circle())
            }

            VStack(alignment: .leading, spacing: SplickTheme.Spacing.xxxs) {
                Text(viewModel.group.name)
                    .font(SplickTheme.Typography.title)
                    .fixedSize(horizontal: false, vertical: true)

                Text(languageService.format(.friendsGroupMemberCount, viewModel.displayedMemberCount))
                    .font(SplickTheme.Typography.caption)
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var headerQuickActions: some View {
        let isOwner = viewModel.isOwner(currentUserId: currentUserSummary?.id)
        let hasInviteCode = !viewModel.displayedInviteCode.isEmpty

        return LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: SplickTheme.Spacing.xs),
                GridItem(.flexible(), spacing: SplickTheme.Spacing.xs),
            ],
            spacing: SplickTheme.Spacing.xs
        ) {
            headerQuickActionButton(
                icon: "bubble.left.and.bubble.right.fill",
                title: languageService.text(.friendsGroupChat),
                isDisabled: isOpeningChat
            ) {
                openGroupChatThread()
            }

            headerQuickActionButton(
                icon: "person.badge.plus",
                title: languageService.text(.friendsAddMembersTitle)
            ) {
                showInviteFriends = true
            }

            headerQuickActionButton(icon: "qrcode", title: languageService.text(.friendsGroupQR)) {
                showGroupQR = true
            }

            headerQuickActionButton(
                icon: "doc.on.doc",
                title: languageService.text(.friendsGroupCode),
                isDisabled: !hasInviteCode
            ) {
                copyInviteCode()
            }

            if isOwner {
                headerQuickActionButton(
                    icon: "person.crop.circle.badge.checkmark",
                    title: languageService.text(.friendsTransferOwnership)
                ) {
                    showTransferOwnership = true
                }

                headerQuickActionButton(
                    icon: "trash",
                    title: languageService.text(.friendsDeleteGroup),
                    isDestructive: true
                ) {
                    confirmDelete = true
                }
            } else {
                headerQuickActionButton(
                    icon: "rectangle.portrait.and.arrow.right",
                    title: languageService.text(.messagingLeaveGroup),
                    isDestructive: true
                ) {
                    confirmLeave = true
                }
            }
        }
        .frame(width: 168)
    }

    private func headerQuickActionButton(
        icon: String,
        title: String,
        isDestructive: Bool = false,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.85)
            }
            .foregroundStyle(
                isDisabled
                    ? SplickTheme.Colors.textTertiary
                    : (isDestructive ? SplickTheme.Colors.error : SplickTheme.Colors.primaryGradientStart)
            )
            .frame(maxWidth: .infinity, minHeight: 68)
            .padding(.horizontal, SplickTheme.Spacing.xxs)
            .padding(.vertical, SplickTheme.Spacing.xs)
            .background {
                RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.inset, style: .continuous)
                    .fill(
                        (isDestructive ? SplickTheme.Colors.error : SplickTheme.Colors.primaryGradientStart)
                            .opacity(isDisabled ? 0.04 : 0.1)
                    )
            }
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }

    private func copyInviteCode() {
        let code = viewModel.displayedInviteCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty else { return }
        UIPasteboard.general.string = code
        viewModel.actionMessage = languageService.text(.friendsGroupCodeCopied)
    }

    private func openGroupChatThread() {
        guard !isOpeningChat else { return }
        let memberIds = viewModel.members
            .map(\.userId)
            .filter { $0 != currentUserSummary?.id }
        guard !memberIds.isEmpty else {
            viewModel.actionError = languageService.text(.messagingGroupChatRequiresMembers)
            return
        }
        guard let openGroupChat else {
            viewModel.actionError = languageService.text(.friendsGroupChatFailed)
            return
        }
        isOpeningChat = true
        Task { @MainActor in
            let conversationId = await openGroupChat(
                OpenGroupChatRequest(
                    groupId: viewModel.group.id,
                    name: viewModel.group.name,
                    avatarURL: viewModel.group.avatarURL?.absoluteString,
                    memberUserIds: memberIds
                )
            )
            if conversationId == nil {
                viewModel.actionError = languageService.text(.friendsGroupChatFailed)
            }
            isOpeningChat = false
        }
    }

    private func memberDisplayName(_ member: GroupMemberItem, isMe: Bool) -> String {
        if member.isOwner && isMe {
            return "\(member.displayName) \(languageService.text(.friendsMemberOwnerMe))"
        }
        if member.isOwner {
            return "\(member.displayName) \(languageService.text(.friendsMemberOwner))"
        }
        if isMe {
            return "\(member.displayName) \(languageService.text(.friendsMemberMe))"
        }
        return member.displayName
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
        let canRemove = viewModel.isOwner(currentUserId: currentUserSummary?.id)
            && !member.isOwner
            && !isMe

        GroupMemberRowView(
            displayName: memberDisplayName(member, isMe: isMe),
            username: member.username,
            avatarURL: member.avatarURL,
            onProfileTap: { onUserTap(userSummary) },
            onRemove: canRemove ? {
                Task { await viewModel.remove(member, currentUserId: currentUserSummary?.id) }
            } : nil
        )
    }
}
