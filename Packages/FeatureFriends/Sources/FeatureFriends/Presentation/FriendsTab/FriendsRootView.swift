import SwiftUI
import Combine
import DesignSystem
import Common
import FeatureMedia
import Localization
import SplickDomain

private struct UserProfileRoute: Identifiable {
    let user: UserSummary
    let initialFriendStatus: FriendRelationStatus
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
    @Environment(\.tabBarScrollState) private var tabBarScrollState
    @Environment(\.pullToRefreshActive) private var pullToRefreshActive
    @State private var isPullRefreshing = false

    private var suppressRefreshAnimations: Bool {
        pullToRefreshActive || isPullRefreshing
    }

    private let fetchOutgoingFriendRequestsUseCase: FetchOutgoingFriendRequestsUseCaseProtocol
    private let fetchBlockedUsersUseCase: FetchBlockedUsersUseCaseProtocol
    private let cancelFriendRequestUseCase: CancelFriendRequestUseCaseProtocol
    private let removeFriendUseCase: RemoveFriendUseCaseProtocol
    private let setFriendNicknameUseCase: SetFriendNicknameUseCaseProtocol
    private let blockUserUseCase: BlockUserUseCaseProtocol
    private let unblockUserUseCase: UnblockUserUseCaseProtocol

    @State private var showCreateGroup = false
    @State private var showQRScanner = false
    @State private var showIncomingRequests = false
    @State private var showOutgoingRequests = false
    @State private var showBlockedUsers = false
    @State private var isJoiningGroupFromSearch = false
    @State private var profileRoute: UserProfileRoute?
    @State private var scrollTopSignal = 0
    @State private var searchScrollTopSignal = 0
    @State private var directoryRefreshController = SplickRefreshController()
    @State private var searchRefreshController = SplickRefreshController()

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
    private let profileDependencies: FriendUserProfileDependencies
    private let onBadgeCountsChanged: (() async -> Void)?

    public init(
        fetchMyFriendsUseCase: FetchMyFriendsUseCaseProtocol,
        fetchMyGroupsUseCase: FetchMyGroupsUseCaseProtocol,
        searchUsersUseCase: SearchUsersUseCaseProtocol,
        fetchUserProfileUseCase: FetchUserProfileUseCaseProtocol,
        fetchFriendPaymentProfileUseCase: FetchFriendPaymentProfileUseCaseProtocol,
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
        revokeGroupQrUseCase: RevokeGroupQrUseCaseProtocol,
        onBadgeCountsChanged: (() async -> Void)? = nil
    ) {
        self.onBadgeCountsChanged = onBadgeCountsChanged
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
        self.profileDependencies = FriendUserProfileDependencies(
            fetchUserProfileUseCase: fetchUserProfileUseCase,
            fetchFriendPaymentProfileUseCase: fetchFriendPaymentProfileUseCase,
            addFriendUseCase: addFriendUseCase,
            fetchIncomingFriendRequestsUseCase: fetchIncomingFriendRequestsUseCase,
            acceptFriendRequestUseCase: acceptFriendRequestUseCase,
            removeFriendUseCase: removeFriendUseCase,
            setFriendNicknameUseCase: setFriendNicknameUseCase,
            blockUserUseCase: blockUserUseCase,
            unblockUserUseCase: unblockUserUseCase
        )
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
                onFriendshipChanged: {
                    rootVM.onFriendAdded()
                    Task { await onBadgeCountsChanged?() }
                }
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
                directoryTopBar

                Group {
                    if viewModel.isSearching {
                        searchResultsContent
                    } else {
                        combinedDirectoryContent
                    }
                }
            }
            .onPreferenceChange(PullToRefreshActivePreferenceKey.self) { isPullRefreshing = $0 }
            .splickTabScreenHeader(languageService.text(.friendsTitle), showsBell: false)
            .onChange(of: viewModel.searchQuery) { newValue in
                viewModel.onSearchQueryChanged(newValue)
            }
            .toolbar {
                toolbarCreateGroup
            }
            .navigationDestination(for: UUID.self) { groupId in
                if let group = viewModel.groups.first(where: { $0.id == groupId }) {
                    GroupDetailView(
                        group: group,
                        onUserTap: { user in
                            profileRoute = UserProfileRoute(user: user, initialFriendStatus: .none)
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
                    viewModel: profileDependencies.makeViewModel(
                        user: route.user,
                        initialFriendStatus: route.initialFriendStatus,
                        onRelationshipChanged: { viewModel.onFriendAdded() }
                    )
                )
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
            .sheet(isPresented: $showQRScanner) {
                if let user = currentUserSummary {
                    QRScannerSheet(
                        mode: .unified,
                        onScan: { code in
                            Task { await handleUnifiedQR(code) }
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
        .onReceive(sameTabTapPublisher) { _ in
            if tabBarScrollState?.isAtTop == true {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                if viewModel.isSearching {
                    searchRefreshController.refresh()
                } else {
                    directoryRefreshController.refresh()
                }
            } else if viewModel.isSearching {
                searchScrollTopSignal += 1
            } else {
                scrollTopSignal += 1
            }
        }
    }

    private var sameTabTapPublisher: AnyPublisher<Void, Never> {
        tabBarScrollState?.sameTabTapSubject.eraseToAnyPublisher()
            ?? Empty().eraseToAnyPublisher()
    }

    private var friendRequestsRow: some View {
        HStack(spacing: SplickTheme.Spacing.sm) {
            friendRequestShortcut(
                icon: "person.crop.circle.badge.plus",
                title: languageService.text(.friendsIncomingTitle),
                count: viewModel.incomingRequestCount,
                isHighlighted: viewModel.incomingRequestCount > 0
            ) {
                showIncomingRequests = true
            }

            friendRequestShortcut(
                icon: "paperplane.fill",
                title: languageService.text(.friendsOutgoingTitle),
                count: viewModel.outgoingRequestCount,
                isHighlighted: false
            ) {
                showOutgoingRequests = true
            }
        }
        .padding(.top, SplickTheme.Spacing.xs)
    }

    private func friendRequestShortcut(
        icon: String,
        title: String,
        count: Int,
        isHighlighted: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: SplickTheme.Spacing.xxxs) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.top, SplickTheme.Spacing.xxxs)

                    if count > 0 {
                        Text(count > 99 ? "99+" : "\(count)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, count > 9 ? 4 : 5)
                            .padding(.vertical, 2)
                            .background(SplickTheme.Colors.primaryGradientStart, in: Capsule())
                            .offset(x: 6, y: -4)
                    }
                }

                Text(title)
                    .font(SplickTheme.Typography.captionBold)
                    .foregroundStyle(
                        isHighlighted
                            ? SplickTheme.Colors.primaryGradientStart
                            : SplickTheme.Colors.textSecondary
                    )
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.85)
                    .frame(maxWidth: .infinity)
            }
            .padding(.vertical, SplickTheme.Spacing.sm)
            .padding(.horizontal, SplickTheme.Spacing.xs)
            .frame(maxWidth: .infinity)
            .background(
                isHighlighted
                    ? SplickTheme.Colors.primaryGradientStart.opacity(0.1)
                    : SplickTheme.Colors.secondaryBackground
            )
            .clipShape(RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.medium, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            count > 0
                ? "\(title), \(count)"
                : title
        )
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

    private var directoryTopBar: some View {
        friendsSearchField
            .padding(.horizontal, SplickTheme.Spacing.md)
            .padding(.bottom, SplickTheme.Spacing.sm)
    }

    private var friendsSearchField: some View {
        HStack(spacing: SplickTheme.Spacing.xs) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(SplickTheme.Colors.textSecondary)

            TextField(languageService.text(.friendsSearchPlaceholder), text: $viewModel.searchQuery)
                .font(SplickTheme.Typography.callout)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

            Button {
                showQRScanner = true
            } label: {
                Image(systemName: "qrcode.viewfinder")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(languageService.text(.friendsScanQRUnified))
        }
        .padding(.leading, SplickTheme.Spacing.md)
        .padding(.trailing, SplickTheme.Spacing.sm)
        .padding(.vertical, SplickTheme.Spacing.sm)
        .frame(maxWidth: .infinity)
        .background(SplickTheme.Colors.secondaryBackground)
        .clipShape(Capsule(style: .continuous))
    }

    @ToolbarContentBuilder
    private var toolbarCreateGroup: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                showCreateGroup = true
            } label: {
                Text(languageService.text(.friendsCreateGroup))
                    .font(SplickTheme.Typography.callout.weight(.semibold))
                    .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
            }
            .buttonStyle(.plain)
        }
    }

    private func handleUnifiedQR(_ payload: String) async {
        guard let action = SplickQRParser.parse(payload) else {
            viewModel.alertMessage = languageService.text(.friendsScanManualHint)
            return
        }

        switch action {
        case .addFriend(let username):
            addFriendViewModel.username = username
            await addFriendViewModel.addByUsername()
        case .addFriendByServerPayload:
            await addFriendViewModel.addFromQR(payload)
        case .joinGroup, .joinGroupByServerPayload:
            await joinGroupViewModel.joinFromQR(payload)
        }

        if let error = addFriendViewModel.errorMessage ?? joinGroupViewModel.errorMessage {
            viewModel.alertMessage = error
        }
    }

    private func joinGroupFromSearch(inviteCode: String) async {
        guard !isJoiningGroupFromSearch else { return }
        isJoiningGroupFromSearch = true
        defer { isJoiningGroupFromSearch = false }

        joinGroupViewModel.inviteCode = inviteCode
        await joinGroupViewModel.joinByCode()

        if let error = joinGroupViewModel.errorMessage {
            viewModel.alertMessage = error
            return
        }

        viewModel.searchQuery = ""
        viewModel.onSearchQueryChanged("")
    }

    @ViewBuilder
    private var searchResultsContent: some View {
        let items = viewModel.combinedSearchItems

        switch viewModel.searchState {
        case .loading where items.isEmpty:
            LoadingView(message: "Searching...")
        case .failed(let message) where items.isEmpty:
            ErrorView(message: message) {
                viewModel.onSearchQueryChanged(viewModel.searchQuery)
            }
        case .loaded where items.isEmpty, .idle where items.isEmpty:
            EmptyStateView(
                icon: "magnifyingglass",
                title: "No results found",
                message: "Try another name or username."
            )
        default:
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: SplickTheme.Spacing.xs) {
                        Color.clear.frame(height: 0).id("friendsSearchScrollTop")
                        ForEach(items) { item in
                            searchResultRow(item)
                        }
                    }
                    .padding(.horizontal, SplickTheme.Spacing.md)
                    .padding(.bottom, SplickTheme.Spacing.md)
                    .transaction { transaction in
                        if suppressRefreshAnimations {
                            transaction.animation = nil
                        }
                    }
                }
                .id("friendsSearchScroll")
                .tabBarHideOnScroll()
                .splickNativeRefreshable(controller: searchRefreshController) {
                    await viewModel.refreshSearch(query: viewModel.searchQuery)
                }
                .onChange(of: searchScrollTopSignal) { _ in
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                        proxy.scrollTo("friendsSearchScrollTop", anchor: .top)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func searchResultRow(_ item: FriendsSearchItem) -> some View {
        switch item {
        case .user(let result):
            FriendRowView(
                user: result.user,
                friendStatus: result.friendStatus,
                isSendingRequest: viewModel.sendingFriendRequestUserIds.contains(result.user.id)
                    || viewModel.acceptingFriendRequestUserIds.contains(result.user.id),
                onProfileTap: {
                    profileRoute = UserProfileRoute(
                        user: result.user,
                        initialFriendStatus: result.friendStatus
                    )
                },
                onAddFriend: actionForSearchResult(result)
            )
        case .group(let group):
            NavigationLink(value: group.id) {
                GroupRowView(group: group)
            }
            .buttonStyle(.plain)
        case .joinGroupInvite(let code):
            joinGroupInviteRow(code: code)
        }
    }

    private func joinGroupInviteRow(code: String) -> some View {
        Button {
            Task { await joinGroupFromSearch(inviteCode: code) }
        } label: {
            HStack(spacing: SplickTheme.Spacing.sm) {
                Image(systemName: "person.3.fill")
                    .font(.title3)
                    .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
                    .frame(width: 44, height: 44)
                    .background(SplickTheme.Colors.primaryGradientStart.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: SplickTheme.Spacing.xxxs) {
                    Text(languageService.text(.friendsJoinGroupByCode))
                        .font(SplickTheme.Typography.headline)
                        .foregroundStyle(SplickTheme.Colors.textPrimary)
                    Text("@\(code)")
                        .font(SplickTheme.Typography.caption)
                        .foregroundStyle(SplickTheme.Colors.textSecondary)
                }

                Spacer()

                if isJoiningGroupFromSearch {
                    SplickSpinner(size: .small)
                } else {
                    Text(languageService.text(.friendsJoinGroupAction))
                        .font(SplickTheme.Typography.caption.weight(.semibold))
                        .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
                }
            }
            .splickCard(padding: SplickTheme.Spacing.sm)
        }
        .buttonStyle(.plain)
        .disabled(isJoiningGroupFromSearch)
    }

    @ViewBuilder
    private var combinedDirectoryContent: some View {
        let items = viewModel.combinedDirectoryItems
        let isInitialLoading = (viewModel.friendsState == .idle || viewModel.friendsState == .loading
            || viewModel.groupsState == .idle || viewModel.groupsState == .loading)
            && viewModel.friends.isEmpty && viewModel.groups.isEmpty

        switch true {
        case isInitialLoading:
            LoadingView(message: "Loading...")
        case items.isEmpty && directoryLoadFailed:
            ErrorView(message: directoryErrorMessage) {
                Task {
                    await viewModel.loadFriends(isPullToRefresh: false)
                    await viewModel.loadGroups(isPullToRefresh: false)
                }
            }
        default:
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: SplickTheme.Spacing.xs) {
                        Color.clear.frame(height: 0).id("directoryScrollTop")
                        friendRequestsRow
                        blockedUsersLink
                        if items.isEmpty {
                            directoryEmptyStateCard
                        } else {
                            ForEach(items) { item in
                                directoryRow(item)
                            }
                        }
                    }
                    .padding(.horizontal, SplickTheme.Spacing.md)
                    .padding(.bottom, SplickTheme.Spacing.md)
                    .transaction { transaction in
                        if suppressRefreshAnimations {
                            transaction.animation = nil
                        }
                    }
                }
                .id("friendsDirectoryScroll")
                .tabBarHideOnScroll()
                .splickNativeRefreshable(controller: directoryRefreshController) {
                    await viewModel.refresh()
                }
                .onChange(of: scrollTopSignal) { _ in
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                        proxy.scrollTo("directoryScrollTop", anchor: .top)
                    }
                }
            }
        }
    }

    private var directoryEmptyStateCard: some View {
        VStack(spacing: SplickTheme.Spacing.md) {
            Image(systemName: "person.2")
                .font(.system(size: 40))
                .foregroundStyle(SplickTheme.Colors.textTertiary)

            Text("No friends or groups yet")
                .font(SplickTheme.Typography.title)
                .foregroundStyle(SplickTheme.Colors.textPrimary)
                .multilineTextAlignment(.center)

            Text("Search by name or username, scan QR, or create a group.")
                .font(SplickTheme.Typography.body)
                .foregroundStyle(SplickTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)

            SplickButton(languageService.text(.friendsCreateGroup), style: .primary) {
                showCreateGroup = true
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, SplickTheme.Spacing.xl)
        .padding(.horizontal, SplickTheme.Spacing.md)
        .splickCard()
    }

    private var directoryLoadFailed: Bool {
        if case .failed = viewModel.friendsState { return true }
        if case .failed = viewModel.groupsState { return true }
        return false
    }

    private var directoryErrorMessage: String {
        if case .failed(let message) = viewModel.friendsState { return message }
        if case .failed(let message) = viewModel.groupsState { return message }
        return "Something went wrong."
    }

    @ViewBuilder
    private func directoryRow(_ item: FriendsDirectoryItem) -> some View {
        switch item {
        case .friend(let friend):
            Button {
                profileRoute = UserProfileRoute(user: friend, initialFriendStatus: .friends)
            } label: {
                FriendRowView(user: friend)
            }
            .buttonStyle(.plain)
        case .group(let group):
            NavigationLink(value: group.id) {
                GroupRowView(group: group)
            }
            .buttonStyle(.plain)
        }
    }
}
