import SwiftUI
import Combine
import DesignSystem
import Common
import FeatureMedia
import Localization
import Networking
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
    @StateObject private var peopleYouMayKnowViewModel: PeopleYouMayKnowViewModel
    @EnvironmentObject private var languageService: LanguageService
    @Environment(\.currentUserSummary) private var currentUserSummary
    @Environment(\.tabBarScrollState) private var tabBarScrollState
    @Environment(\.pullToRefreshActive) private var pullToRefreshActive
    @Environment(\.sameTabTapHandlingEnabled) private var sameTabTapHandlingEnabled
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @State private var isPullRefreshing = false
    @FocusState private var isSearchFieldFocused: Bool
    @State private var hasCompletedInitialLoad = false

    private var hasSearchText: Bool {
        !viewModel.searchQuery.isEmpty
    }

    private let searchRowAnimation = Animation.spring(response: 0.38, dampingFraction: 0.86)

    private var suppressRefreshAnimations: Bool {
        pullToRefreshActive || isPullRefreshing
    }

    private let fetchOutgoingFriendRequestsUseCase: FetchOutgoingFriendRequestsUseCaseProtocol
    private let fetchBlockedUsersUseCase: FetchBlockedUsersUseCaseProtocol
    private let fetchMyFriendsUseCase: FetchMyFriendsUseCaseProtocol
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
    @State private var showPeopleYouMayKnow = false
    @State private var showNearbyRadar = false
    @State private var isJoiningGroupFromSearch = false
    @State private var profileRoute: UserProfileRoute?
    @State private var scrollTopSignal = 0
    @State private var searchScrollTopSignal = 0
    @StateObject private var directoryRefreshController = SplickRefreshController()
    @StateObject private var searchRefreshController = SplickRefreshController()

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
    private let openLinkedGroupConversation: (_ groupId: UUID, _ name: String, _ memberUserIds: [UUID]) async throws -> Void
    private let profileDependencies: FriendUserProfileDependencies
    private let onBadgeCountsChanged: (() async -> Void)?
    private let onDirectoryLoaded: (([SplickDomain.Group]) async -> Void)?
    private let onFriendRequestsLoaded: (([IncomingFriendRequest]) async -> Void)?
    private let pendingUserProfileUserId: Binding<UUID?>?
    private let pendingUserProfileUsername: Binding<String?>?
    private let isTabActive: Bool

    public init(
        fetchMyFriendsUseCase: FetchMyFriendsUseCaseProtocol,
        fetchMyGroupsUseCase: FetchMyGroupsUseCaseProtocol,
        searchUsersUseCase: SearchUsersUseCaseProtocol,
        fetchUserProfileUseCase: FetchUserProfileUseCaseProtocol,
        fetchUserPostsUseCase: FetchUserPostsUseCaseProtocol? = nil,
        fetchFriendPaymentProfileUseCase: FetchFriendPaymentProfileUseCaseProtocol,
        generateMyQrUseCase: GenerateMyQrUseCaseProtocol,
        addFriendUseCase: AddFriendUseCaseProtocol,
        fetchIncomingFriendRequestsUseCase: FetchIncomingFriendRequestsUseCaseProtocol,
        acceptFriendRequestUseCase: AcceptFriendRequestUseCaseProtocol,
        rejectFriendRequestUseCase: RejectFriendRequestUseCaseProtocol,
        fetchOutgoingFriendRequestsUseCase: FetchOutgoingFriendRequestsUseCaseProtocol,
        cancelFriendRequestUseCase: CancelFriendRequestUseCaseProtocol,
        nearbyDiscoveryUseCase: NearbyDiscoveryUseCaseProtocol,
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
        openLinkedGroupConversation: @escaping (_ groupId: UUID, _ name: String, _ memberUserIds: [UUID]) async throws -> Void = { _, _, _ in },
        languageService: LanguageService,
        searchHistoryRepository: SearchHistoryRepositoryProtocol? = nil,
        onBadgeCountsChanged: (() async -> Void)? = nil,
        onDirectoryLoaded: (([SplickDomain.Group]) async -> Void)? = nil,
        onFriendRequestsLoaded: (([IncomingFriendRequest]) async -> Void)? = nil,
        pendingUserProfileUserId: Binding<UUID?>? = nil,
        pendingUserProfileUsername: Binding<String?>? = nil,
        isTabActive: Bool = true
    ) {
        self.onBadgeCountsChanged = onBadgeCountsChanged
        self.onDirectoryLoaded = onDirectoryLoaded
        self.onFriendRequestsLoaded = onFriendRequestsLoaded
        self.pendingUserProfileUserId = pendingUserProfileUserId
        self.pendingUserProfileUsername = pendingUserProfileUsername
        self.isTabActive = isTabActive
        self.fetchMyFriendsUseCase = fetchMyFriendsUseCase
        let rootVM = FriendsRootViewModel(
            fetchMyFriendsUseCase: fetchMyFriendsUseCase,
            fetchMyGroupsUseCase: fetchMyGroupsUseCase,
            searchUsersUseCase: searchUsersUseCase,
            addFriendUseCase: addFriendUseCase,
            acceptFriendRequestUseCase: acceptFriendRequestUseCase,
            fetchIncomingFriendRequestsUseCase: fetchIncomingFriendRequestsUseCase,
            fetchOutgoingFriendRequestsUseCase: fetchOutgoingFriendRequestsUseCase,
            cancelFriendRequestUseCase: cancelFriendRequestUseCase,
            nearbyDiscoveryUseCase: nearbyDiscoveryUseCase,
            languageService: languageService,
            searchHistoryRepository: searchHistoryRepository,
            onDirectoryLoaded: onDirectoryLoaded,
            onFriendRequestsLoaded: onFriendRequestsLoaded
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
        self.openLinkedGroupConversation = openLinkedGroupConversation
        self.profileDependencies = FriendUserProfileDependencies(
            fetchUserProfileUseCase: fetchUserProfileUseCase,
            fetchUserPostsUseCase: fetchUserPostsUseCase,
            fetchFriendPaymentProfileUseCase: fetchFriendPaymentProfileUseCase,
            addFriendUseCase: addFriendUseCase,
            fetchIncomingFriendRequestsUseCase: fetchIncomingFriendRequestsUseCase,
            fetchOutgoingFriendRequestsUseCase: fetchOutgoingFriendRequestsUseCase,
            acceptFriendRequestUseCase: acceptFriendRequestUseCase,
            cancelFriendRequestUseCase: cancelFriendRequestUseCase,
            removeFriendUseCase: removeFriendUseCase,
            setFriendNicknameUseCase: setFriendNicknameUseCase,
            blockUserUseCase: blockUserUseCase,
            unblockUserUseCase: unblockUserUseCase
        )
        let relationshipChanged: (UUID, FriendRelationStatus) -> Void = { userId, status in
            rootVM.handleRelationshipChanged(userId: userId, status: status)
        }
        _viewModel = StateObject(wrappedValue: rootVM)
        _addFriendViewModel = StateObject(
            wrappedValue: AddFriendViewModel(
                addFriendUseCase: addFriendUseCase,
                languageService: languageService
            ) {
                rootVM.onFriendAdded()
            }
        )
        _joinGroupViewModel = StateObject(
            wrappedValue: JoinGroupViewModel(
                joinGroupUseCase: joinGroupUseCase,
                languageService: languageService
            ) {
                rootVM.onGroupJoined()
            }
        )
        _incomingRequestsViewModel = StateObject(
            wrappedValue: IncomingFriendRequestsViewModel(
                fetchIncomingUseCase: fetchIncomingFriendRequestsUseCase,
                acceptUseCase: acceptFriendRequestUseCase,
                rejectUseCase: rejectFriendRequestUseCase,
                onRelationshipChanged: { userId, status in
                    relationshipChanged(userId, status)
                    Task { await onBadgeCountsChanged?() }
                }
            )
        )
        _outgoingRequestsViewModel = StateObject(
            wrappedValue: OutgoingFriendRequestsViewModel(
                fetchOutgoingUseCase: fetchOutgoingFriendRequestsUseCase,
                cancelUseCase: cancelFriendRequestUseCase,
                onRelationshipChanged: relationshipChanged
            )
        )
        _blockedUsersViewModel = StateObject(
            wrappedValue: BlockedUsersViewModel(
                fetchBlockedUsersUseCase: fetchBlockedUsersUseCase,
                unblockUserUseCase: unblockUserUseCase,
                onRelationshipChanged: relationshipChanged
            )
        )
        _peopleYouMayKnowViewModel = StateObject(
            wrappedValue: PeopleYouMayKnowViewModel(
                fetchPeopleYouMayKnowUseCase: FetchPeopleYouMayKnowUseCase(
                    fetchMyGroupsUseCase: fetchMyGroupsUseCase,
                    fetchGroupMembersUseCase: fetchGroupMembersUseCase,
                    fetchMyFriendsUseCase: fetchMyFriendsUseCase,
                    fetchIncomingFriendRequestsUseCase: fetchIncomingFriendRequestsUseCase,
                    fetchOutgoingFriendRequestsUseCase: fetchOutgoingFriendRequestsUseCase,
                    fetchBlockedUsersUseCase: fetchBlockedUsersUseCase
                ),
                addFriendUseCase: addFriendUseCase,
                onRelationshipChanged: relationshipChanged
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
                    } else if isSearchFieldFocused {
                        recentSearchesContent
                    } else {
                        combinedDirectoryContent
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay(alignment: .top) {
                    SplickScrollTopFadeOverlay(mode: .compactBelowNav)
                }
            }
            .dismissKeyboardOnTap()
            .background(SplickBrandAtmosphere())
            .splickFastPageSlide()
            .onPreferenceChange(PullToRefreshActivePreferenceKey.self) { isActive in
                DispatchQueue.main.async {
                    isPullRefreshing = isActive
                }
            }
            .splickTabScreenHeader(languageService.text(.friendsTitle), showsBell: false)
            .onChange(of: viewModel.searchQuery) { newValue in
                viewModel.onSearchQueryChanged(newValue)
            }
            .onChange(of: isSearchFieldFocused) { focused in
                if focused, !hasSearchText {
                    Task { await viewModel.searchHistory?.refresh() }
                }
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
                        generateInviteCodeUseCase: generateGroupInviteCodeUseCase,
                        generateGroupQrUseCase: generateGroupQrUseCase,
                        revokeGroupQrUseCase: revokeGroupQrUseCase,
                        updateGroupUseCase: updateGroupUseCase,
                        updateGroupAvatarUseCase: updateGroupAvatarUseCase,
                        uploadGroupAvatarUseCase: uploadGroupAvatarUseCase,
                        transferOwnershipUseCase: transferGroupOwnershipUseCase,
                        fetchMyFriendsUseCase: fetchMyFriendsUseCase,
                        searchUsersUseCase: searchUsersUseCase,
                        addFriendUseCase: addFriendUseCase,
                        inviteFriendsUseCase: inviteFriendsToGroupUseCase,
                        fetchGroupUseCase: fetchGroupUseCase,
                        approveMemberUseCase: approveGroupMemberUseCase,
                        rejectMemberUseCase: rejectGroupMemberUseCase,
                        removeMemberUseCase: removeGroupMemberUseCase,
                        leaveGroupUseCase: leaveGroupUseCase,
                        deleteGroupUseCase: deleteGroupUseCase,
                        languageService: languageService
                    )
                }
            }
            .sheet(item: $profileRoute) { route in
                FriendUserProfileView(
                    viewModel: profileDependencies.makeViewModel(
                        user: route.user,
                        currentUserId: currentUserSummary?.id,
                        initialFriendStatus: route.initialFriendStatus,
                        onRelationshipChanged: { userId, status in
                            viewModel.handleRelationshipChanged(userId: userId, status: status)
                        },
                        onFriendSummaryUpdated: { user in
                            viewModel.updateFriendSummary(user)
                        }
                    )
                )
            }
            .sheet(isPresented: $showCreateGroup) {
                CreateGroupSheet(
                    friends: viewModel.friends,
                    fetchMyFriendsUseCase: fetchMyFriendsUseCase,
                    createGroupUseCase: createGroupUseCase,
                    inviteFriendsUseCase: inviteFriendsToGroupUseCase,
                uploadGroupAvatarUseCase: uploadGroupAvatarUseCase,
                updateGroupAvatarUseCase: updateGroupAvatarUseCase,
                openLinkedGroupConversation: openLinkedGroupConversation,
                languageService: languageService
                ) { group, _ in
                    viewModel.onGroupCreated(group)
                    showCreateGroup = false
                }
                .environmentObject(languageService)
            }
            .sheet(isPresented: $showIncomingRequests, onDismiss: {
                Task { await viewModel.refreshIncomingRequestCount() }
            }) {
                IncomingFriendRequestsSheet(
                    viewModel: incomingRequestsViewModel,
                    onProfileTap: openUserProfile
                )
            }
            .sheet(isPresented: $showOutgoingRequests, onDismiss: {
                Task { await viewModel.refreshOutgoingRequestCount() }
            }) {
                OutgoingFriendRequestsSheet(
                    viewModel: outgoingRequestsViewModel,
                    onProfileTap: openUserProfile
                )
            }
            .sheet(isPresented: $showBlockedUsers, onDismiss: {
                Task { await blockedUsersViewModel.load() }
            }) {
                BlockedUsersSheet(
                    viewModel: blockedUsersViewModel,
                    onProfileTap: openUserProfile
                )
            }
            .fullScreenCover(isPresented: $showNearbyRadar, onDismiss: {
                viewModel.stopRadarSession()
            }) {
                NearbyRadarSheet(
                    permissionNeeded: viewModel.nearbyPermissionNeeded,
                    users: viewModel.nearbyUsers,
                    loading: viewModel.nearbyLoading,
                    locationDisabled: viewModel.nearbyLocationDisabled,
                    onClose: {
                        showNearbyRadar = false
                        viewModel.stopRadarSession()
                    },
                    onRequestLocation: {
                        viewModel.requestNearbyLocationAccess()
                    },
                    onOpenUser: { result in
                        openUserProfile(user: result.user, status: result.friendStatus)
                    },
                    actionForResult: actionForSearchResult
                )
                .environmentObject(languageService)
            }
            .sheet(isPresented: $showPeopleYouMayKnow) {
                PeopleYouMayKnowSheet(
                    viewModel: peopleYouMayKnowViewModel,
                    currentUserId: currentUserSummary?.id,
                    onProfileTap: openUserProfile
                )
                .task {
                    await peopleYouMayKnowViewModel.load(
                        currentUserId: currentUserSummary?.id,
                        snapshot: viewModel.peopleYouMayKnowSnapshot(
                            blocked: blockedUsersViewModel.blockedUsers
                        )
                    )
                }
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
            Task {
                async let directory: Void = viewModel.load(userId: currentUserSummary?.id)
                async let blocked: Void = blockedUsersViewModel.load()
                _ = await (directory, blocked)
                hasCompletedInitialLoad = true
                if isTabActive, scenePhase == .active {
                    viewModel.startVisiblePolling()
                }
                // PYMK scans group members (N API calls) — only when user opens that sheet.
            }
        }
        .onChange(of: isTabActive) { active in
            updateFriendsVisibility(isActive: active, phase: scenePhase)
        }
        .onChange(of: scenePhase) { phase in
            updateFriendsVisibility(isActive: isTabActive, phase: phase)
        }
        .onReceive(NotificationCenter.default.publisher(for: .friendshipsDirectoryDidChange)) { _ in
            Task { await onBadgeCountsChanged?() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .groupsDirectoryDidChange)) { _ in
            Task { await viewModel.loadGroups(isPullToRefresh: true) }
        }
        .onReceive(sameTabTapPublisher) { _ in
            guard sameTabTapHandlingEnabled else { return }
            if tabBarScrollState?.isAtTop ?? true {
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
        .onChange(of: pendingUserProfileUserId?.wrappedValue) { userId in
            guard let userId else { return }
            pendingUserProfileUserId?.wrappedValue = nil
            openUserProfileFromNotification(userId: userId)
        }
        .onChange(of: pendingUserProfileUsername?.wrappedValue) { username in
            guard let username, !username.isEmpty else { return }
            pendingUserProfileUsername?.wrappedValue = nil
            Task { await openUserProfileFromUsername(username) }
        }
        .onAppear {
            if let userId = pendingUserProfileUserId?.wrappedValue {
                pendingUserProfileUserId?.wrappedValue = nil
                openUserProfileFromNotification(userId: userId)
            } else if let username = pendingUserProfileUsername?.wrappedValue, !username.isEmpty {
                pendingUserProfileUsername?.wrappedValue = nil
                Task { await openUserProfileFromUsername(username) }
            }
        }
        .onDisappear {
            if showNearbyRadar {
                showNearbyRadar = false
                viewModel.stopRadarSession()
            }
            // Do not stop visible polling here — sheets / profile pushes can fire onDisappear
            // while the Friends tab is still selected. Polling is gated by isTabActive + scenePhase.
        }
    }

    private func updateFriendsVisibility(isActive: Bool, phase: ScenePhase) {
        guard hasCompletedInitialLoad else { return }
        if isActive, phase == .active {
            viewModel.onFriendsVisible()
        } else {
            viewModel.onFriendsHidden()
        }
    }

    private func openUserProfile(user: UserSummary, status: FriendRelationStatus) {
        profileRoute = UserProfileRoute(user: user, initialFriendStatus: status)
    }

    private func openUserProfileFromNotification(userId: UUID) {
        if let friend = viewModel.friends.first(where: { $0.id == userId }) {
            openUserProfile(user: friend, status: .friends)
            return
        }
        openUserProfile(
            user: UserSummary(id: userId, username: "", displayName: ""),
            status: .none
        )
    }

    private func openUserProfileFromUsername(_ username: String) async {
        let normalized = username.trimmingCharacters(in: .whitespacesAndNewlines)
        if let friend = viewModel.friends.first(where: {
            $0.username.caseInsensitiveCompare(normalized) == .orderedSame
        }) {
            openUserProfile(user: friend, status: .friends)
            return
        }
        do {
            let results = try await searchUsersUseCase.execute(query: normalized, page: 0, size: 20)
            if let match = results.first(where: {
                $0.user.username.caseInsensitiveCompare(normalized) == .orderedSame
            }) {
                openUserProfile(user: match.user, status: match.friendStatus)
                return
            }
        } catch {
            viewModel.alertMessage = error.localizedDescription
        }
    }

    private var sameTabTapPublisher: AnyPublisher<Void, Never> {
        tabBarScrollState?.sameTabTapSubject.eraseToAnyPublisher()
            ?? Empty().eraseToAnyPublisher()
    }

    private var friendRequestsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
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

                friendRequestShortcut(
                    icon: "dot.radiowaves.left.and.right",
                    title: languageService.text(.friendsNearbyTitle),
                    count: 0,
                    isHighlighted: false
                ) {
                    showNearbyRadar = true
                    viewModel.startRadarSession()
                }

                friendRequestShortcut(
                    icon: "person.2.circle",
                    title: languageService.text(.friendsPeopleYouMayKnowTitle),
                    count: peopleYouMayKnowViewModel.suggestionCount,
                    isHighlighted: peopleYouMayKnowViewModel.suggestionCount > 0
                ) {
                    showPeopleYouMayKnow = true
                }

                friendRequestShortcut(
                    icon: "hand.raised.fill",
                    title: languageService.text(.friendsBlockedTitle),
                    count: blockedUsersViewModel.blockedUsers.count,
                    isHighlighted: false
                ) {
                    showBlockedUsers = true
                }
            }
        }
        .padding(.top, SplickTheme.Spacing.xxs)
    }

    private var friendsDirectoryListHeader: some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.sm) {
            Text(languageService.text(.friendsListTitle))
                .font(SplickTheme.Typography.headline)
                .foregroundStyle(SplickTheme.Colors.textPrimary)
            friendsDirectoryTabBar
        }
        .padding(.top, SplickTheme.Spacing.sm)
        .padding(.bottom, SplickTheme.Spacing.xxxs)
    }

    private var friendsDirectoryTabBar: some View {
        HStack(spacing: 2) {
            directoryTabButton(.users, title: languageService.text(.friendsTabUsers))
            directoryTabButton(.all, title: languageService.text(.friendsTabAll))
            directoryTabButton(.groups, title: languageService.text(.friendsTabGroups))
        }
        .padding(3)
        .background(SplickTheme.Colors.secondaryBackground)
        .clipShape(Capsule(style: .continuous))
    }

    private func directoryTabButton(_ tab: FriendsDirectoryTab, title: String) -> some View {
        let selected = viewModel.directoryTab == tab
        return Button {
            viewModel.directoryTab = tab
        } label: {
            Text(title)
                .font(.system(size: 14, weight: selected ? .semibold : .medium))
                .foregroundStyle(selected ? Color.white : SplickTheme.Colors.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    Capsule(style: .continuous)
                        .fill(selected ? SplickTheme.Colors.primaryGradientStart : Color.clear)
                )
        }
        .buttonStyle(.plain)
    }

    private func friendRequestShortcut(
        icon: String,
        title: String,
        count: Int,
        isHighlighted: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: SplickTheme.Spacing.xxxs) {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(
                            isHighlighted
                                ? SplickTheme.Colors.primaryGradientStart
                                : SplickTheme.Colors.textSecondary
                        )

                    Text(title)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(
                            isHighlighted
                                ? SplickTheme.Colors.primaryGradientStart
                                : SplickTheme.Colors.textSecondary
                        )
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.85)
                        .lineSpacing(0)
                        .frame(minWidth: 68)
                }
                .padding(.top, SplickTheme.Spacing.xxs)
                .padding(.bottom, SplickTheme.Spacing.xs)
                .padding(.horizontal, SplickTheme.Spacing.xs)
                .frame(minWidth: 84)
                .background(
                    isHighlighted
                        ? SplickTheme.Colors.primaryGradientStart.opacity(0.1)
                        : SplickTheme.Colors.secondaryBackground
                )
                .clipShape(Capsule(style: .continuous))

                if count > 0 {
                    friendRequestShortcutBadge(count: count)
                        .padding(.trailing, 8)
                        .padding(.top, 5)
                }
            }
            .frame(minWidth: 84)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            count > 0
                ? "\(title), \(count)"
                : title
        )
    }

    private func friendRequestShortcutBadge(count: Int) -> some View {
        Text(count > 99 ? "99+" : "\(count)")
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, count > 9 ? 3 : 4)
            .padding(.vertical, 1.5)
            .background {
                Capsule(style: .continuous)
                    .fill(SplickTheme.Colors.error)
            }
            .fixedSize()
    }

    private func actionForSearchResult(_ result: UserSearchResult) -> (() -> Void)? {
        switch result.friendStatus {
        case .none:
            return { viewModel.sendFriendRequest(to: result) }
        case .requestReceived:
            return { viewModel.acceptFriendRequest(from: result) }
        case .requestSent:
            return { viewModel.cancelFriendRequest(from: result) }
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
        // Match messaging inbox search capsule (`MessagingSearchChromeMetrics.rowHeight` = 44).
        HStack(spacing: SplickTheme.Spacing.xs) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(SplickTheme.Colors.textSecondary)

            TextField(languageService.text(.friendsSearchPlaceholder), text: $viewModel.searchQuery)
                .font(SplickTheme.Typography.callout)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .focused($isSearchFieldFocused)
                .submitLabel(.search)
                .onSubmit {
                    isSearchFieldFocused = false
                }

            if hasSearchText {
                Button(action: clearSearch) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(SplickTheme.Colors.textTertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(languageService.text(.commonClose))
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }

            if !hasSearchText {
                Button {
                    showQRScanner = true
                } label: {
                    Image(systemName: "qrcode.viewfinder")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(languageService.text(.friendsScanQRUnified))
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .animation(.easeOut(duration: 0.18), value: hasSearchText)
        .padding(.horizontal, SplickTheme.Spacing.md)
        .padding(.vertical, SplickTheme.Spacing.sm)
        .frame(maxWidth: .infinity, minHeight: 44)
        .background(SplickTheme.Colors.secondaryBackground)
        .clipShape(Capsule(style: .continuous))
    }

    private func clearSearch() {
        isSearchFieldFocused = false
        viewModel.searchQuery = ""
        viewModel.onSearchQueryChanged("")
    }

    @ViewBuilder
    private var recentSearchesContent: some View {
        if let history = viewModel.searchHistory {
            ScrollView {
                BoundRecentSearches(
                    session: history,
                    languageService: languageService,
                    onSelect: { item in
                        viewModel.searchQuery = item.query
                        viewModel.onSearchQueryChanged(item.query)
                    }
                )
                .padding(.horizontal, SplickTheme.Spacing.md)
                .padding(.top, SplickTheme.Spacing.md)
            }
        }
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
        case .claimBill(let token, let splitId):
            var components = URLComponents()
            components.scheme = "splick"
            components.host = "bill"
            components.path = "/\(token)"
            if let splitId {
                components.queryItems = [URLQueryItem(name: "split", value: splitId.uuidString)]
            }
            if let url = components.url {
                openURL(url)
            } else {
                viewModel.alertMessage = languageService.text(.friendsScanManualHint)
            }
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
        let items = viewModel.visibleSearchItems
        let itemIDs = items.map(\.id)

        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: SplickTheme.Spacing.xs) {
                    Color.clear
                        .frame(height: 0)
                        .id("friendsSearchScrollTop")
                        .background {
                            SplickRefreshableScrollBootstrap()
                        }

                    if items.isEmpty {
                        if viewModel.isSearchFetching {
                            searchFetchingIndicator
                                .padding(.top, SplickTheme.Spacing.xxl)
                        } else if case .failed(let message) = viewModel.searchState {
                            ErrorView(message: message) {
                                viewModel.onSearchQueryChanged(viewModel.searchQuery)
                            }
                            .padding(.top, SplickTheme.Spacing.lg)
                        } else {
                            searchEmptyState
                                .padding(.top, SplickTheme.Spacing.xxl)
                        }
                    } else {
                        ForEach(items) { item in
                            searchResultRow(item)
                                .transition(
                                    .asymmetric(
                                        insertion: .move(edge: .top).combined(with: .opacity),
                                        removal: .opacity
                                    )
                                )
                                .onAppear {
                                    Task {
                                        await viewModel.loadMoreSearchIfNeeded(currentItemID: item.id)
                                    }
                                }
                        }

                        if viewModel.isSearchFetching || viewModel.isLoadingMoreSearch {
                            searchFetchingIndicator
                                .padding(.vertical, SplickTheme.Spacing.sm)
                        }
                    }
                }
                .padding(.horizontal, SplickTheme.Spacing.md)
                .padding(.bottom, SplickTabBarMetrics.floatingClearance + SplickTheme.Spacing.md)
                .animation(suppressRefreshAnimations ? nil : searchRowAnimation, value: itemIDs)
                .transaction { transaction in
                    if suppressRefreshAnimations {
                        transaction.animation = nil
                    }
                }
            }
            .id("friendsSearchScroll")
            .splickScrollSoftTopEdge()
            .scrollDismissesKeyboard(.immediately)
            .tabBarHideOnScroll()
            .dismissKeyboardOnTap()
            .splickNativeRefreshable(controller: searchRefreshController) {
                await viewModel.refreshSearch(query: viewModel.searchQuery)
            }
            .onChange(of: searchScrollTopSignal) { _ in
                withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                    proxy.scrollTo("friendsSearchScrollTop", anchor: .top)
                }
                tabBarScrollState?.reset()
            }
        }
    }

    private var searchFetchingIndicator: some View {
        SplickSpinner()
            .frame(maxWidth: .infinity)
    }

    private var searchEmptyState: some View {
        EmptyStateView(
            icon: "magnifyingglass",
            title: languageService.text(.messagingSearchEmptyTitle),
            message: languageService.text(.friendsSearchEmptyMessage)
        )
    }

    @ViewBuilder
    private func searchResultRow(_ item: FriendsSearchItem) -> some View {
        switch item {
        case .user(let result):
            FriendRowView(
                user: result.user,
                friendStatus: result.friendStatus,
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
                    .frame(width: 40, height: 40)
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
            .splickCard(padding: SplickTheme.Spacing.xs)
        }
        .buttonStyle(.plain)
        .disabled(isJoiningGroupFromSearch)
    }

    @ViewBuilder
    private var combinedDirectoryContent: some View {
        let items = viewModel.visibleDirectoryItems
        let isInitialLoading: Bool = {
            let friendsPending = (viewModel.friendsState == .idle || viewModel.friendsState == .loading)
                && viewModel.friends.isEmpty
            let groupsPending = (viewModel.groupsState == .idle || viewModel.groupsState == .loading)
                && viewModel.groups.isEmpty
            switch viewModel.directoryTab {
            case .users:
                return friendsPending
            case .all:
                return friendsPending && groupsPending
            case .groups:
                return groupsPending
            }
        }()

        switch true {
        case isInitialLoading:
            LoadingView(message: languageService.text(.commonLoading))
                .padding(.top, SplickTheme.Spacing.sm)
        case items.isEmpty && directoryLoadFailed:
            ErrorView(message: directoryErrorMessage) {
                Task {
                    await viewModel.loadFriends(isPullToRefresh: false)
                    await viewModel.loadGroups(isPullToRefresh: false)
                }
            }
            .padding(.top, SplickTheme.Spacing.sm)
        default:
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: SplickTheme.Spacing.xs) {
                        Color.clear
                            .frame(height: 0)
                            .id("directoryScrollTop")
                            .background {
                                SplickRefreshableScrollBootstrap()
                            }
                        friendRequestsRow
                        friendsDirectoryListHeader
                        if items.isEmpty {
                            directoryEmptyStateCard
                        } else {
                            ForEach(items) { item in
                                directoryRow(item)
                                    .onAppear {
                                        Task {
                                            await viewModel.loadMoreFriendsIfNeeded(currentItemID: item.id)
                                        }
                                    }
                            }

                            if viewModel.isLoadingMoreFriends {
                                SplickSpinner()
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, SplickTheme.Spacing.sm)
                            }
                        }
                    }
                    .padding(.horizontal, SplickTheme.Spacing.md)
                    .padding(.bottom, SplickTabBarMetrics.floatingClearance + SplickTheme.Spacing.md)
                    .transaction { transaction in
                        if suppressRefreshAnimations {
                            transaction.animation = nil
                        }
                    }
                }
                .id("friendsDirectoryScroll")
                .splickScrollSoftTopEdge()
                .scrollDismissesKeyboard(.immediately)
                .tabBarHideOnScroll()
                .dismissKeyboardOnTap()
                .splickNativeRefreshable(controller: directoryRefreshController) {
                    await viewModel.refresh()
                    await blockedUsersViewModel.load()
                }
                .onChange(of: scrollTopSignal) { _ in
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                        proxy.scrollTo("directoryScrollTop", anchor: .top)
                    }
                    tabBarScrollState?.reset()
                }
            }
        }
    }

    private var directoryEmptyStateCard: some View {
        let content = directoryEmptyContent
        return VStack(spacing: SplickTheme.Spacing.md) {
            Image(systemName: content.icon)
                .font(.system(size: 40))
                .foregroundStyle(SplickTheme.Colors.textTertiary)

            Text(languageService.text(content.title))
                .font(SplickTheme.Typography.title)
                .foregroundStyle(SplickTheme.Colors.textPrimary)
                .multilineTextAlignment(.center)

            Text(languageService.text(content.message))
                .font(SplickTheme.Typography.body)
                .foregroundStyle(SplickTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)

            if content.showsCreateGroup {
                SplickButton(languageService.text(.friendsCreateGroup), style: .primary) {
                    showCreateGroup = true
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, SplickTheme.Spacing.xl)
        .padding(.horizontal, SplickTheme.Spacing.md)
        .splickCard()
    }

    private var directoryEmptyContent: (icon: String, title: L10nKey, message: L10nKey, showsCreateGroup: Bool) {
        switch viewModel.directoryTab {
        case .users:
            return ("person.2", .friendsUsersEmptyTitle, .friendsUsersEmptyMessage, false)
        case .all:
            return ("person.2", .friendsDirectoryEmptyTitle, .friendsDirectoryEmptyMessage, true)
        case .groups:
            return ("person.3", .friendsGroupsEmptyTitle, .friendsGroupsEmptyMessage, true)
        }
    }

    private var directoryLoadFailed: Bool {
        switch viewModel.directoryTab {
        case .users:
            if case .failed = viewModel.friendsState { return viewModel.friends.isEmpty }
        case .all:
            if case .failed = viewModel.friendsState, case .failed = viewModel.groupsState {
                return true
            }
        case .groups:
            if case .failed = viewModel.groupsState { return viewModel.groups.isEmpty }
        }
        return false
    }

    private var directoryErrorMessage: String {
        switch viewModel.directoryTab {
        case .users:
            if case .failed(let message) = viewModel.friendsState { return message }
        case .all:
            if case .failed(let message) = viewModel.friendsState { return message }
            if case .failed(let message) = viewModel.groupsState { return message }
        case .groups:
            if case .failed(let message) = viewModel.groupsState { return message }
        }
        return languageService.text(.friendsGenericError)
    }

    @ViewBuilder
    private func directoryRow(_ item: FriendsDirectoryItem) -> some View {
        switch item {
        case .friend(let friend):
            FriendRowView(
                user: friend,
                onProfileTap: {
                    profileRoute = UserProfileRoute(user: friend, initialFriendStatus: .friends)
                }
            )
        case .group(let group):
            NavigationLink(value: group.id) {
                GroupRowView(group: group)
            }
            .buttonStyle(.plain)
        }
    }
}

private struct BoundRecentSearches: View {
    @ObservedObject var session: SearchHistorySession
    let languageService: LanguageService
    let onSelect: (SearchHistoryItem) -> Void

    var body: some View {
        RecentSearchesSection(
            items: session.items,
            languageService: languageService,
            onSelect: onSelect,
            onDelete: { session.delete($0) },
            onClearAll: { session.clear() }
        )
    }
}

