import SwiftUI
import DesignSystem
import Common
import FeatureMedia
import Localization
import SplickDomain

private struct UserProfileRoute: Identifiable {
    let user: UserSummary
    let mode: FriendProfileMode
    var id: UUID { user.id }
}


public struct FriendsRootView: View {
    @StateObject private var viewModel: FriendsRootViewModel
    @StateObject private var addFriendViewModel: AddFriendViewModel
    @StateObject private var joinGroupViewModel: JoinGroupViewModel
    @StateObject private var incomingRequestsViewModel: IncomingFriendRequestsViewModel
    @StateObject private var outgoingRequestsViewModel: OutgoingFriendRequestsViewModel
    @StateObject private var blockedUsersViewModel: BlockedUsersViewModel
    @EnvironmentObject private var languageService: LanguageService
    @Environment(\.currentUserSummary) private var currentUserSummary

    private let fetchOutgoingFriendRequestsUseCase: FetchOutgoingFriendRequestsUseCaseProtocol
    private let fetchBlockedUsersUseCase: FetchBlockedUsersUseCaseProtocol
    private let cancelFriendRequestUseCase: CancelFriendRequestUseCaseProtocol
    private let removeFriendUseCase: RemoveFriendUseCaseProtocol
    private let setFriendNicknameUseCase: SetFriendNicknameUseCaseProtocol
    private let blockUserUseCase: BlockUserUseCaseProtocol
    private let unblockUserUseCase: UnblockUserUseCaseProtocol

    @State private var showAddFriend = false
    @State private var showJoinGroup = false
    @State private var showCreateGroup = false
    @State private var showAddFriendQR = false
    @State private var showJoinGroupQR = false
    @State private var showIncomingRequests = false
    @State private var showOutgoingRequests = false
    @State private var showBlockedUsers = false
    @State private var profileRoute: UserProfileRoute?

    private let fetchGroupMembersUseCase: FetchGroupMembersUseCaseProtocol
    private let searchUsersUseCase: SearchUsersUseCaseProtocol
    private let addFriendUseCase: AddFriendUseCaseProtocol
    private let generateMyQrUseCase: GenerateMyQrUseCaseProtocol
    private let createGroupUseCase: CreateGroupUseCaseProtocol
    private let fetchGroupInviteCodeUseCase: FetchGroupInviteCodeUseCaseProtocol
    private let generateGroupInviteCodeUseCase: GenerateGroupInviteCodeUseCaseProtocol
    private let inviteFriendsToGroupUseCase: InviteFriendsToGroupUseCaseProtocol
    private let fetchGroupUseCase: FetchGroupUseCaseProtocol
    private let approveGroupMemberUseCase: ApproveGroupMemberUseCaseProtocol
    private let rejectGroupMemberUseCase: RejectGroupMemberUseCaseProtocol
    private let removeGroupMemberUseCase: RemoveGroupMemberUseCaseProtocol
    private let leaveGroupUseCase: LeaveGroupUseCaseProtocol
    private let deleteGroupUseCase: DeleteGroupUseCaseProtocol
    private let updateGroupUseCase: UpdateGroupUseCaseProtocol
    private let updateGroupAvatarUseCase: UpdateGroupAvatarUseCaseProtocol
    private let uploadGroupAvatarUseCase: UploadGroupAvatarUseCaseProtocol
    private let transferGroupOwnershipUseCase: TransferGroupOwnershipUseCaseProtocol
    private let generateGroupQrUseCase: GenerateGroupQrUseCaseProtocol
    private let revokeGroupQrUseCase: RevokeGroupQrUseCaseProtocol

    public init(
        fetchMyFriendsUseCase: FetchMyFriendsUseCaseProtocol,
        fetchMyGroupsUseCase: FetchMyGroupsUseCaseProtocol,
        searchUsersUseCase: SearchUsersUseCaseProtocol,
        generateMyQrUseCase: GenerateMyQrUseCaseProtocol,
        addFriendUseCase: AddFriendUseCaseProtocol,
        fetchIncomingFriendRequestsUseCase: FetchIncomingFriendRequestsUseCaseProtocol,
        acceptFriendRequestUseCase: AcceptFriendRequestUseCaseProtocol,
        rejectFriendRequestUseCase: RejectFriendRequestUseCaseProtocol,
        fetchOutgoingFriendRequestsUseCase: FetchOutgoingFriendRequestsUseCaseProtocol,
        cancelFriendRequestUseCase: CancelFriendRequestUseCaseProtocol,
        removeFriendUseCase: RemoveFriendUseCaseProtocol,
        setFriendNicknameUseCase: SetFriendNicknameUseCaseProtocol,
        blockUserUseCase: BlockUserUseCaseProtocol,
        unblockUserUseCase: UnblockUserUseCaseProtocol,
        fetchBlockedUsersUseCase: FetchBlockedUsersUseCaseProtocol,
        joinGroupUseCase: JoinGroupUseCaseProtocol,
        createGroupUseCase: CreateGroupUseCaseProtocol,
        fetchGroupMembersUseCase: FetchGroupMembersUseCaseProtocol,
        fetchGroupInviteCodeUseCase: FetchGroupInviteCodeUseCaseProtocol,
        generateGroupInviteCodeUseCase: GenerateGroupInviteCodeUseCaseProtocol,
        inviteFriendsToGroupUseCase: InviteFriendsToGroupUseCaseProtocol,
        fetchGroupUseCase: FetchGroupUseCaseProtocol,
        approveGroupMemberUseCase: ApproveGroupMemberUseCaseProtocol,
        rejectGroupMemberUseCase: RejectGroupMemberUseCaseProtocol,
        removeGroupMemberUseCase: RemoveGroupMemberUseCaseProtocol,
        leaveGroupUseCase: LeaveGroupUseCaseProtocol,
        deleteGroupUseCase: DeleteGroupUseCaseProtocol,
        updateGroupUseCase: UpdateGroupUseCaseProtocol,
        updateGroupAvatarUseCase: UpdateGroupAvatarUseCaseProtocol,
        uploadGroupAvatarUseCase: UploadGroupAvatarUseCaseProtocol,
        transferGroupOwnershipUseCase: TransferGroupOwnershipUseCaseProtocol,
        generateGroupQrUseCase: GenerateGroupQrUseCaseProtocol,
        revokeGroupQrUseCase: RevokeGroupQrUseCaseProtocol
    ) {
        let rootVM = FriendsRootViewModel(
            fetchMyFriendsUseCase: fetchMyFriendsUseCase,
            fetchMyGroupsUseCase: fetchMyGroupsUseCase,
            searchUsersUseCase: searchUsersUseCase,
            addFriendUseCase: addFriendUseCase,
            acceptFriendRequestUseCase: acceptFriendRequestUseCase,
            fetchIncomingFriendRequestsUseCase: fetchIncomingFriendRequestsUseCase,
            fetchOutgoingFriendRequestsUseCase: fetchOutgoingFriendRequestsUseCase
        )
        self.fetchOutgoingFriendRequestsUseCase = fetchOutgoingFriendRequestsUseCase
        self.fetchBlockedUsersUseCase = fetchBlockedUsersUseCase
        self.cancelFriendRequestUseCase = cancelFriendRequestUseCase
        self.removeFriendUseCase = removeFriendUseCase
        self.setFriendNicknameUseCase = setFriendNicknameUseCase
        self.blockUserUseCase = blockUserUseCase
        self.unblockUserUseCase = unblockUserUseCase
        self.fetchGroupMembersUseCase = fetchGroupMembersUseCase
        self.searchUsersUseCase = searchUsersUseCase
        self.addFriendUseCase = addFriendUseCase
        self.generateMyQrUseCase = generateMyQrUseCase
        self.createGroupUseCase = createGroupUseCase
        self.fetchGroupInviteCodeUseCase = fetchGroupInviteCodeUseCase
        self.generateGroupInviteCodeUseCase = generateGroupInviteCodeUseCase
        self.inviteFriendsToGroupUseCase = inviteFriendsToGroupUseCase
        self.fetchGroupUseCase = fetchGroupUseCase
        self.approveGroupMemberUseCase = approveGroupMemberUseCase
        self.rejectGroupMemberUseCase = rejectGroupMemberUseCase
        self.removeGroupMemberUseCase = removeGroupMemberUseCase
        self.leaveGroupUseCase = leaveGroupUseCase
        self.deleteGroupUseCase = deleteGroupUseCase
        self.updateGroupUseCase = updateGroupUseCase
        self.updateGroupAvatarUseCase = updateGroupAvatarUseCase
        self.uploadGroupAvatarUseCase = uploadGroupAvatarUseCase
        self.transferGroupOwnershipUseCase = transferGroupOwnershipUseCase
        self.generateGroupQrUseCase = generateGroupQrUseCase
        self.revokeGroupQrUseCase = revokeGroupQrUseCase
        _viewModel = StateObject(wrappedValue: rootVM)
        _addFriendViewModel = StateObject(
            wrappedValue: AddFriendViewModel(addFriendUseCase: addFriendUseCase) {
                rootVM.onFriendAdded()
            }
        )
        _joinGroupViewModel = StateObject(
            wrappedValue: JoinGroupViewModel(joinGroupUseCase: joinGroupUseCase) {
                rootVM.onGroupJoined()
            }
        )
        _incomingRequestsViewModel = StateObject(
            wrappedValue: IncomingFriendRequestsViewModel(
                fetchIncomingUseCase: fetchIncomingFriendRequestsUseCase,
                acceptUseCase: acceptFriendRequestUseCase,
                rejectUseCase: rejectFriendRequestUseCase,
                onFriendshipChanged: { rootVM.onFriendAdded() }
            )
        )
        _outgoingRequestsViewModel = StateObject(
            wrappedValue: OutgoingFriendRequestsViewModel(
                fetchOutgoingUseCase: fetchOutgoingFriendRequestsUseCase,
                cancelUseCase: cancelFriendRequestUseCase,
                onFriendshipChanged: { rootVM.onFriendAdded() }
            )
        )
        _blockedUsersViewModel = StateObject(
            wrappedValue: BlockedUsersViewModel(
                fetchBlockedUsersUseCase: fetchBlockedUsersUseCase,
                unblockUserUseCase: unblockUserUseCase
            )
        )
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if viewModel.segment == .friends {
                    friendsTopBar
                }

                Picker("Section", selection: $viewModel.segment) {
                    ForEach(FriendsRootViewModel.Segment.allCases, id: \.self) { segment in
                        Text(segment.localizedTitle(using: languageService)).tag(segment)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, SplickTheme.Spacing.md)
                .padding(.vertical, SplickTheme.Spacing.sm)

                Group {
                    switch viewModel.segment {
                    case .friends:
                        if viewModel.isSearching {
                            searchResultsContent
                        } else {
                            VStack(spacing: SplickTheme.Spacing.xs) {
                                incomingRequestsBanner
                                outgoingRequestsBanner
                                blockedUsersLink
                                friendsContent
                            }
                        }
                    case .groups:
                        groupsContent
                    }
                }
            }
            .navigationTitle(languageService.text(.friendsTitle))
            .onChange(of: viewModel.searchQuery) { newValue in
                viewModel.onSearchQueryChanged(newValue)
            }
            .onChange(of: viewModel.segment) { segment in
                guard segment == .groups else { return }
                viewModel.searchQuery = ""
                viewModel.onSearchQueryChanged("")
            }
            .splickProfileToolbar()
            .toolbar {
                if viewModel.segment == .groups {
                    toolbarAddMenu
                }
            }
            .refreshable { await viewModel.refresh() }
            .navigationDestination(for: UUID.self) { groupId in
                if let group = viewModel.groups.first(where: { $0.id == groupId }) {
                    GroupDetailView(
                        group: group,
                        onUserTap: { user in
                            profileRoute = UserProfileRoute(user: user, mode: .stranger)
                        },
                        onGroupLeft: { viewModel.onGroupJoined() },
                        onGroupDeleted: { viewModel.onGroupJoined() },
                        fetchGroupMembersUseCase: fetchGroupMembersUseCase,
                        fetchInviteCodeUseCase: fetchGroupInviteCodeUseCase,
                        generateGroupQrUseCase: generateGroupQrUseCase,
                        revokeGroupQrUseCase: revokeGroupQrUseCase,
                        updateGroupUseCase: updateGroupUseCase,
                        updateGroupAvatarUseCase: updateGroupAvatarUseCase,
                        uploadGroupAvatarUseCase: uploadGroupAvatarUseCase,
                        transferOwnershipUseCase: transferGroupOwnershipUseCase,
                        searchUsersUseCase: searchUsersUseCase,
                        addFriendUseCase: addFriendUseCase,
                        inviteFriendsUseCase: inviteFriendsToGroupUseCase,
                        fetchGroupUseCase: fetchGroupUseCase,
                        approveMemberUseCase: approveGroupMemberUseCase,
                        rejectMemberUseCase: rejectGroupMemberUseCase,
                        removeMemberUseCase: removeGroupMemberUseCase,
                        leaveGroupUseCase: leaveGroupUseCase,
                        deleteGroupUseCase: deleteGroupUseCase
                    )
                }
            }
            .sheet(item: $profileRoute) { route in
                FriendUserProfileView(
                    viewModel: FriendUserProfileViewModel(
                        user: route.user,
                        mode: route.mode,
                        removeFriendUseCase: removeFriendUseCase,
                        setNicknameUseCase: setFriendNicknameUseCase,
                        blockUserUseCase: blockUserUseCase,
                        unblockUserUseCase: unblockUserUseCase,
                        onRelationshipChanged: { viewModel.onFriendAdded() }
                    )
                )
            }
            .sheet(isPresented: $showAddFriend) {
                AddFriendSheet(viewModel: addFriendViewModel)
            }
            .sheet(isPresented: $showJoinGroup) {
                JoinGroupSheet(viewModel: joinGroupViewModel)
            }
            .sheet(isPresented: $showCreateGroup) {
                CreateGroupSheet(
                    viewModel: CreateGroupViewModel(createGroupUseCase: createGroupUseCase) { group in
                        viewModel.onGroupCreated(group)
                        showCreateGroup = false
                    }
                )
            }
            .sheet(isPresented: $showIncomingRequests, onDismiss: {
                Task { await viewModel.refreshIncomingRequestCount() }
            }) {
                IncomingFriendRequestsSheet(viewModel: incomingRequestsViewModel)
            }
            .sheet(isPresented: $showOutgoingRequests, onDismiss: {
                Task { await viewModel.refreshOutgoingRequestCount() }
            }) {
                OutgoingFriendRequestsSheet(viewModel: outgoingRequestsViewModel)
            }
            .sheet(isPresented: $showBlockedUsers) {
                BlockedUsersSheet(viewModel: blockedUsersViewModel)
            }
            .sheet(isPresented: $showAddFriendQR) {
                if let user = currentUserSummary {
                    QRScannerSheet(
                        mode: .addFriend,
                        onScan: { code in
                            Task { await addFriendViewModel.addFromQR(code) }
                        },
                        myQrContext: QRScannerMyQrContext(
                            username: user.username,
                            displayName: user.displayName,
                            avatarURL: user.avatarURL,
                            generateMyQrUseCase: generateMyQrUseCase
                        )
                    )
                }
            }
            .sheet(isPresented: $showJoinGroupQR) {
                QRScannerSheet(mode: .joinGroup) { code in
                    Task { await joinGroupViewModel.joinFromQR(code) }
                }
            }
        }
        .alert(languageService.text(.friendsTitle), isPresented: Binding(
            get: { viewModel.alertMessage != nil },
            set: { if !$0 { viewModel.alertMessage = nil } }
        )) {
            Button(languageService.text(.commonOK), role: .cancel) { viewModel.alertMessage = nil }
        } message: {
            Text(viewModel.alertMessage ?? "")
        }
        .onFirstAppear {
            Task { await viewModel.load() }
        }
    }

    @ViewBuilder
    private var outgoingRequestsBanner: some View {
        Button {
            showOutgoingRequests = true
        } label: {
            HStack {
                Image(systemName: "paperplane")
                if viewModel.outgoingRequestCount > 0 {
                    Text(languageService.format(.friendsOutgoingRequests, viewModel.outgoingRequestCount))
                } else {
                    Text(languageService.text(.friendsOutgoingRequestsPlain))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
            }
            .font(SplickTheme.Typography.callout.weight(.semibold))
            .foregroundStyle(SplickTheme.Colors.textSecondary)
            .padding(SplickTheme.Spacing.sm)
            .background(SplickTheme.Colors.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.medium, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, SplickTheme.Spacing.md)
    }

    @ViewBuilder
    private var blockedUsersLink: some View {
        Button {
            showBlockedUsers = true
        } label: {
            HStack {
                Image(systemName: "hand.raised")
                Text(languageService.text(.friendsBlockedUsers))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
            }
            .font(SplickTheme.Typography.callout.weight(.semibold))
            .foregroundStyle(SplickTheme.Colors.textSecondary)
            .padding(SplickTheme.Spacing.sm)
            .background(SplickTheme.Colors.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.medium, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, SplickTheme.Spacing.md)
    }

    @ViewBuilder
    private var incomingRequestsBanner: some View {
        if viewModel.incomingRequestCount > 0 {
            Button {
                showIncomingRequests = true
            } label: {
                HStack {
                    Image(systemName: "person.crop.circle.badge.plus")
                    Text(languageService.format(.friendsIncomingRequests, viewModel.incomingRequestCount))
                        .font(SplickTheme.Typography.callout.weight(.semibold))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
                .padding(SplickTheme.Spacing.sm)
                .background(SplickTheme.Colors.primaryGradientStart.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.medium, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, SplickTheme.Spacing.md)
            .padding(.top, SplickTheme.Spacing.xs)
        }
    }

    private func profileMode(for status: FriendRelationStatus) -> FriendProfileMode {
        switch status {
        case .friends:
            return .friend
        case .blocked:
            return .blocked
        case .none, .requestSent, .requestReceived:
            return .stranger
        }
    }

    private func actionForSearchResult(_ result: UserSearchResult) -> (() -> Void)? {
        switch result.friendStatus {
        case .none:
            return { Task { await viewModel.sendFriendRequest(to: result) } }
        case .requestReceived:
            return { Task { await viewModel.acceptFriendRequest(from: result) } }
        case .requestSent:
            return { showOutgoingRequests = true }
        case .friends, .blocked:
            return nil
        }
    }

    private var friendsTopBar: some View {
        HStack(spacing: SplickTheme.Spacing.sm) {
            friendsSearchField
            scanQrButton
        }
        .padding(.horizontal, SplickTheme.Spacing.md)
        .padding(.bottom, SplickTheme.Spacing.sm)
    }

    private var friendsSearchField: some View {
        HStack(spacing: SplickTheme.Spacing.xs) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(SplickTheme.Colors.textSecondary)

            TextField("Search by username", text: $viewModel.searchQuery)
                .font(SplickTheme.Typography.callout)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
        }
        .padding(.horizontal, SplickTheme.Spacing.md)
        .padding(.vertical, SplickTheme.Spacing.sm)
        .frame(maxWidth: .infinity)
        .background(SplickTheme.Colors.secondaryBackground)
        .clipShape(Capsule(style: .continuous))
    }

    @ToolbarContentBuilder
    private var toolbarAddMenu: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            addMenuButton
        }
    }

    private var scanQrButton: some View {
        Button {
            showAddFriendQR = true
        } label: {
            Image(systemName: "qrcode.viewfinder")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
                .frame(width: 44, height: 44)
                .background(SplickTheme.Colors.secondaryBackground)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(languageService.text(.friendsScanQRAddFriend))
    }

    private var addMenuButton: some View {
        Menu {
            Button {
                showAddFriend = true
            } label: {
                Label("Add friend by username", systemImage: "person.badge.plus")
            }

            Button {
                showAddFriendQR = true
            } label: {
                Label("Add friend by QR", systemImage: "qrcode.viewfinder")
            }

            Button {
                showCreateGroup = true
            } label: {
                Label("Tạo nhóm", systemImage: "plus.circle")
            }

            Divider()

            Button {
                showJoinGroup = true
            } label: {
                Label("Join group by code", systemImage: "person.3.fill")
            }

            Button {
                showJoinGroupQR = true
            } label: {
                Label("Join group by QR", systemImage: "qrcode")
            }
        } label: {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 28))
                .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add")
    }

    @ViewBuilder
    private var searchResultsContent: some View {
        switch viewModel.searchState {
        case .idle, .loading:
            LoadingView(message: "Searching...")
        case .failed(let message):
            ErrorView(message: message) {
                viewModel.onSearchQueryChanged(viewModel.searchQuery)
            }
        case .loaded(let results) where results.isEmpty:
            EmptyStateView(
                icon: "magnifyingglass",
                title: "No users found",
                message: "Try another username."
            )
        case .loaded:
            ScrollView {
                LazyVStack(spacing: SplickTheme.Spacing.xs) {
                    ForEach(viewModel.searchResults) { result in
                        FriendRowView(
                            user: result.user,
                            friendStatus: result.friendStatus,
                            isSendingRequest: viewModel.sendingFriendRequestUserIds.contains(result.user.id)
                                || viewModel.acceptingFriendRequestUserIds.contains(result.user.id),
                            onProfileTap: {
                                profileRoute = UserProfileRoute(
                                    user: result.user,
                                    mode: profileMode(for: result.friendStatus)
                                )
                            },
                            onAddFriend: actionForSearchResult(result)
                        )
                    }
                }
                .padding(.horizontal, SplickTheme.Spacing.md)
                .padding(.bottom, SplickTheme.Spacing.md)
            }
            .tabBarHideOnScroll()
        }
    }

    @ViewBuilder
    private var friendsContent: some View {
        switch viewModel.friendsState {
        case .idle, .loading where viewModel.friends.isEmpty:
            LoadingView(message: "Loading friends...")
        case .failed(let message) where viewModel.friends.isEmpty:
            ErrorView(message: message) {
                Task { await viewModel.loadFriends(isPullToRefresh: false) }
            }
        case .loaded where viewModel.friends.isEmpty:
            EmptyStateView(
                icon: "person.2",
                title: "No friends yet",
                message: "Add friends by username or scan their QR code.",
                actionTitle: "Add friend"
            ) {
                showAddFriend = true
            }
        default:
            ScrollView {
                LazyVStack(spacing: SplickTheme.Spacing.xs) {
                    ForEach(viewModel.friends) { friend in
                        Button {
                            profileRoute = UserProfileRoute(user: friend, mode: .friend)
                        } label: {
                            FriendRowView(user: friend)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, SplickTheme.Spacing.md)
                .padding(.bottom, SplickTheme.Spacing.md)
            }
            .tabBarHideOnScroll()
        }
    }

    @ViewBuilder
    private var groupsContent: some View {
        switch viewModel.groupsState {
        case .idle, .loading where viewModel.groups.isEmpty:
            LoadingView(message: "Loading groups...")
        case .failed(let message) where viewModel.groups.isEmpty:
            ErrorView(message: message) {
                Task { await viewModel.loadGroups(isPullToRefresh: false) }
            }
        case .loaded where viewModel.groups.isEmpty:
            EmptyStateView(
                icon: "person.3",
                title: "Chưa có nhóm",
                message: "Tạo nhóm mới hoặc tham gia bằng mã mời / QR.",
                actionTitle: "Tạo nhóm"
            ) {
                showCreateGroup = true
            }
        default:
            ScrollView {
                LazyVStack(spacing: SplickTheme.Spacing.xs) {
                    ForEach(viewModel.groups) { group in
                        NavigationLink(value: group.id) {
                            GroupRowView(group: group)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, SplickTheme.Spacing.md)
                .padding(.bottom, SplickTheme.Spacing.md)
            }
            .tabBarHideOnScroll()
        }
    }
}

private extension FriendsRootViewModel.Segment {
    @MainActor
    func localizedTitle(using languageService: LanguageService) -> String {
        switch self {
        case .friends:
            return languageService.text(.friendsTabFriends)
        case .groups:
            return languageService.text(.friendsTabGroups)
        }
    }
}
