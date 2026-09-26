import SwiftUI
import Combine
import PhotosUI
import UIKit
import StoreKit
import Common
import DesignSystem
import Localization
import SplickDomain
import FeatureAuth
import FeatureSocialFeed
import FeatureExpense
import FeatureMedia
import FeatureNotification
import FeatureFriends
import FeatureMessaging
import FeatureStickers

private struct TabBarChromeAnimationToken: Equatable {
    let isChromePresented: Bool
    let isVisible: Bool
    let animated: Bool
}

struct MainTabView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var container: DependencyContainer
    @EnvironmentObject private var pushNotificationCoordinator: PushNotificationCoordinator
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.splickBrandPalette) private var brandPalette
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.splickVisualTheme) private var splickVisualTheme
    @Environment(\.splickColorTheme) private var splickColorTheme
    @StateObject private var tabBarChrome = TabBarScrollStateHolder()
    @State private var badgeCounts: TabBadgeCounts = .zero
    /// Drives heavy tab work (loads, chrome) — updated after the pager slide settles
    /// so activation cost does not hitch the slide itself.
    @State private var settledPagerTab: Tab = .feed
    /// Updated immediately when leaving feed so video decode stops before the pager slide.
    @State private var feedPlaybackActive = true
    /// Toggled to `true` by the bell button while the panel is open; the overlay's onChange
    /// observes this, resets it, and runs `dismissAnimated()` so the collapse animation plays
    /// before the overlay is removed from the hierarchy.
    @State private var notificationDismissRequest = false
    /// Set to `true` the moment the notification panel begins its collapse animation so the tab
    /// bar chrome can start sliding in immediately, in parallel with the overlay collapsing.
    /// Reset to `false` once `showNotifications` fully clears.
    @State private var notificationIsDismissing = false
    @State private var inviteFriendsToGroupRequest: InviteFriendsToGroupRequest?
    /// Camera layer stays mounted until the UIKit water collapse finishes.
    @State private var cameraMounted = false
    /// Drives the UIKit radial mask (not a per-frame SwiftUI animatable).
    @State private var cameraExpanded = false
    /// Shutter lift/scale follow this; updated by the water mask display-link.
    /// Use `@State` (not `@StateObject`) so per-frame publishes do not rebuild this view
    /// and tear down the water representable mid-animation.
    @State private var cameraRevealProgress = CameraOpenRevealProgressSource()

    private var currentUserSummary: UserSummary? {
        appState.currentUser.map {
            UserSummary(
                id: $0.id,
                username: $0.username,
                displayName: $0.displayName,
                avatarURL: $0.avatarURL
            )
        }
    }

    private var isTabBarChromePresented: Bool {
        appState.linkedPostPresentation == nil
            && (!appState.showNotifications || notificationIsDismissing)
            && !(appState.selectedTab == .messages && appState.isMessagingThreadPresented)
    }

    private var showsCameraLayer: Bool {
        cameraMounted
    }

    /// Hosted pager roots refresh only when this changes — not when a chat thread
    /// hides the tab bar or other chrome-only AppState publishes fire.
    private var pagerContentEpoch: Int {
        var hasher = Hasher()
        hasher.combine(settledPagerTab)
        hasher.combine(feedPlaybackActive)
        hasher.combine(container.languageService.locale)
        hasher.combine(colorScheme == .dark)
        hasher.combine(splickVisualTheme)
        hasher.combine(splickColorTheme)
        hasher.combine(appState.pendingFeedPostNavigation?.postId)
        return hasher.finalize()
    }

    var body: some View {
        ZStack {
            // Fills the full screen (including safe areas) so system white never shows
            // through at the top (status bar) or bottom (home indicator) safe area regions.
            SplickBrandAtmosphere()
                // When a full-screen overlay is up, atmosphere must not absorb
                // pass-through taps that miss the overlay's content shape.
                .allowsHitTesting(
                    !appState.showNotifications && appState.linkedPostPresentation == nil
                )

            MainTabContentPager(
                selectedTab: $appState.selectedTab,
                onSlideSettled: handlePagerSlideSettled,
                contentEpoch: pagerContentEpoch,
                feed: { feedTabContent },
                expenses: { expensesTabContent },
                friends: { friendsTabContent },
                messages: { messagesTabContent }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // Linked post / notifications sit above the pager — never let the
            // underlying tab steal taps through transparent holes.
            .allowsHitTesting(
                !appState.showNotifications && appState.linkedPostPresentation == nil
            )
        }
            .onAppear {
                if appState.selectedTab.isPagerTab {
                    settledPagerTab = appState.selectedTab
                }
                feedPlaybackActive = appState.selectedTab == .feed
                if appState.selectedTab == .camera {
                    cameraMounted = true
                    cameraExpanded = true
                }
                Task { @MainActor in
                    badgeCounts = container.badgeCountService.counts
                    pushNotificationCoordinator.syncAppIconBadge(count: badgeCounts.total)
                }
            }
            .task(id: appState.currentUser?.id) {
                guard let userId = appState.currentUser?.id else { return }
                await container.appStartupCoordinator.bootstrap(
                    userId: userId,
                    repository: container.appStartupRepository,
                    badgeCountService: container.badgeCountService,
                    feedViewModel: container.feedViewModel,
                    conversationListViewModel: container.conversationListViewModel,
                    customEmojiStore: container.customEmojiStore,
                    customEmojiFetcher: container.customEmojiRepository,
                    streakViewModel: container.streakViewModel
                )
            }
            .onReceive(container.badgeCountService.$counts) { newCounts in
                Task { @MainActor in
                    badgeCounts = newCounts
                    pushNotificationCoordinator.syncAppIconBadge(count: newCounts.total)
                }
            }
            .onReceive(container.messagingWebSocketClient.eventsPublisher()) { event in
                switch event {
                case .newMessage:
                    Task { await container.badgeCountService.refresh(force: true) }
                case .presence(let userId, let isOnline, let lastSeenAt):
                    container.presenceStore.apply(
                        userId: userId,
                        isOnline: isOnline,
                        lastSeenAt: lastSeenAt
                    )
                default:
                    break
                }
            }
            .environment(\.openProfileSettings) {
                appState.showProfileSettings = true
            }
            .environment(\.openNotifications) { bellFrame in
                Task { @MainActor in
                    if appState.showNotifications {
                        notificationDismissRequest = true
                    } else {
                        appState.presentNotifications(from: bellFrame)
                    }
                }
            }
            .environment(\.notificationUnreadCount, badgeCounts.inbox)
            .environment(\.notificationsPresented, appState.showNotifications && !notificationIsDismissing)
            .environment(\.openPostCaptureFlow) {
                appState.selectedTab = .camera
            }
            .environment(\.openLinkedPost) { postId, expandBillSplit, scrollToPendingEvidence in
                appState.openLinkedPost(
                    postId,
                    expandBillSplit: expandBillSplit,
                    scrollToPendingEvidence: scrollToPendingEvidence
                )
            }
            .environment(\.fetchSharedPost) { postId in
                if let cached = container.feedViewModel.post(byId: postId) {
                    return cached
                }
                _ = await container.feedViewModel.ensurePostLoaded(id: postId)
                if let loaded = container.feedViewModel.post(byId: postId) {
                    return loaded
                }
                return try await container.fetchPostUseCase.execute(postId: postId)
            }
            .environment(\.openDirectMessage) { friendUserId in
                guard let conversationId = await container.getOrCreateConversationId(friendUserId: friendUserId) else {
                    return nil
                }
                appState.openConversation(conversationId)
                return conversationId
            }
            .environment(\.openGroupChat) { request in
                do {
                    let conversationId = try await container.getOrCreateSocialGroupConversation(
                        groupId: request.groupId,
                        name: request.name,
                        avatarURL: request.avatarURL,
                        memberUserIds: request.memberUserIds
                    )
                    appState.openConversation(conversationId)
                    return conversationId
                } catch {
                    return nil
                }
            }
            .environment(\.presentInviteFriendsToGroup) { request in
                inviteFriendsToGroupRequest = request
            }
            .environment(\.addMembersToGroupConversation) { groupId, userIds, shareChatHistory in
                await container.addMembersToGroupConversation(
                    groupId: groupId,
                    userIds: userIds,
                    shareChatHistory: shareChatHistory
                )
            }
            .environment(\.leaveSocialGroupMembership) { groupId in
                try await container.leaveGroupUseCase.execute(groupId: groupId)
            }
            .environment(\.leaveGroupConversation) { groupId in
                try await container.leaveMessagingGroupConversation(groupId: groupId)
            }
            .environment(\.transferGroupConversationAdmin) { groupId, newAdminUserId in
                try await container.transferMessagingGroupAdmin(
                    groupId: groupId,
                    newAdminUserId: newAdminUserId
                )
            }
            .environment(\.transferSocialGroupOwnership) { groupId, newOwnerId in
                _ = try await container.transferGroupOwnershipUseCase.execute(
                    groupId: groupId,
                    newOwnerId: newOwnerId
                )
            }
            .sheet(item: $inviteFriendsToGroupRequest) { request in
                InviteFriendsToGroupSheet(
                    groupId: request.groupId,
                    existingMemberIds: request.existingMemberIds,
                    currentUserId: appState.currentUser?.id,
                    fetchMyFriendsUseCase: container.fetchMyFriendsUseCase,
                    searchUsersUseCase: container.searchUsersUseCase,
                    addFriendUseCase: container.addFriendUseCase,
                    inviteFriendsUseCase: container.inviteFriendsToGroupUseCase,
                    languageService: container.languageService,
                    onInvited: { invitedIds, shareChatHistory in
                        Task {
                            await container.addMembersToGroupConversation(
                                groupId: request.groupId,
                                userIds: invitedIds,
                                shareChatHistory: shareChatHistory
                            )
                        }
                    }
                )
                .environmentObject(container.languageService)
            }
            .environment(\.currentUserSummary, currentUserSummary)
            .environment(\.tabBarScrollState, tabBarChrome.tabBar)
            .environmentObject(cameraRevealProgress)
            // Camera water → tab chrome → floating shutter on top (never clipped by tab frame).
            // Sibling overlays ignore child zIndex; later overlays paint on top.
            .overlay {
                if showsCameraLayer {
                    CameraOpenRevealContainer(
                        isExpanded: cameraExpanded,
                        cameraSize: SplickTabBarMetrics.cameraSize,
                        bottomInset: SplickTabBarMetrics.cameraRevealBottomInset,
                        progressSource: cameraRevealProgress,
                        onCollapseFinished: {
                            // Ignore late callbacks if the user reopened mid-collapse.
                            guard !cameraExpanded else { return }
                            cameraMounted = false
                            cameraRevealProgress.setValue(0)
                        }
                    ) {
                        cameraTabContent
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .environmentObject(cameraRevealProgress)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .ignoresSafeArea()
                    .allowsHitTesting(
                        cameraExpanded && appState.linkedPostPresentation == nil
                    )
                }
            }
            .overlay(alignment: .bottom) {
                MainTabBarChrome(
                    selectedTab: $appState.selectedTab,
                    badgeCounts: badgeCounts,
                    isChromePresented: isTabBarChromePresented,
                    cameraRevealProgress: cameraRevealProgress,
                    scrollState: tabBarChrome.tabBar,
                    cameraLayerVisible: showsCameraLayer
                )
            }
            .overlay {
                if showsCameraLayer {
                    CameraRevealFloatingShutter(
                        progressSource: cameraRevealProgress,
                        cameraSize: SplickTabBarMetrics.cameraSize,
                        bottomInset: SplickTabBarMetrics.cameraRevealBottomInset
                    )
                    // GeometryReader is full-screen and hittable by default —
                    // must not sit above a linked post / under transparent holes.
                    .allowsHitTesting(false)
                }
            }
            .onChange(of: appState.selectedTab, perform: handleSelectedTabChange)
            .onChange(of: appState.showNotifications) { isShown in
                if !isShown {
                    notificationIsDismissing = false
                } else {
                    Task { await container.notificationListViewModel.reloadOnOpen() }
                }
            }
        .task(id: scenePhase) {
            switch scenePhase {
            case .active:
                container.badgeCountService.startPolling()
                // Messaging socket lifecycle is owned by RootView (auth + scene phase).
                // Badges come from startup `apply` + 30s polling + force refresh on mutations.
                pushNotificationCoordinator.syncAppIconBadge(count: container.badgeCountService.counts.total)
            case .background:
                container.badgeCountService.stopPolling()
            case .inactive:
                break
            @unknown default:
                break
            }
        }
        .sheet(isPresented: $appState.showProfileSettings) {
            ProfileSettingsView()
        }
            .overlay {
                if appState.showNotifications {
                    NotificationRevealHost(
                        viewModel: container.notificationListViewModel,
                        languageService: container.languageService,
                        isPresented: $appState.showNotifications,
                        dismissRequest: $notificationDismissRequest,
                        notificationIsDismissing: $notificationIsDismissing,
                        anchorFrame: appState.notificationAnchorFrame,
                        onNavigate: { target in
                            appState.routeNotification(target: target)
                        }
                    )
                    .zIndex(100)
                }
            }
            // Modal cover — isolated from tab pager / camera / tab-bar hit testing.
            // Overlay presentation kept getting every tap swallowed by sibling layers
            // or by a UIKit pan installed on the nav controller.
            .fullScreenCover(item: $appState.linkedPostPresentation) { presentation in
                LinkedPostDetailOverlay(
                    presentation: presentation,
                    feedViewModel: container.feedViewModel,
                    fetchFriendsUseCase: container.fetchFriendsUseCase,
                    fetchMyGroupsUseCase: container.fetchMyGroupsUseCase,
                    fetchGroupMembersUseCase: container.fetchGroupMembersUseCase,
                    profileDependencies: container.friendUserProfileDependencies,
                    makeGifPickerViewModel: container.makeGifPickerViewModel(groupId:),
                    uploadCommentImage: { data, mimeType in
                        let upload = try await container.uploadCommentAttachment(
                            data: data,
                            mimeType: mimeType
                        )
                        return UploadedMediaReference(
                            id: upload.id,
                            url: upload.url,
                            thumbnailURL: upload.thumbnailURL,
                            sizeBytes: upload.sizeBytes
                        )
                    },
                    onDismiss: { _ in
                        appState.dismissLinkedPostPresentation()
                    }
                )
                .environmentObject(container.languageService)
                .environmentObject(container.customEmojiStore)
                .environment(\.customEmojiDependencies, container.customEmojiDependencies)
                .environment(\.currentUserSummary, currentUserSummary)
                .environment(\.tabBarScrollState, tabBarChrome.tabBar)
                .environment(\.gifKeywordSuggestFactory) {
                    container.makeGifKeywordSuggestController()
                }
            }
            .tint(brandPalette.accent)
    }

    @ViewBuilder
    private var feedTabContent: some View {
        FeedView(
            viewModel: container.feedViewModel,
            photoAlbumViewModel: container.photoAlbumViewModel,
            streakViewModel: container.streakViewModel,
            fetchFriendsUseCase: container.fetchFriendsUseCase,
            fetchMyFriendsUseCase: container.fetchMyFriendsUseCase,
            fetchMyGroupsUseCase: container.fetchMyGroupsUseCase,
            fetchGroupMembersUseCase: container.fetchGroupMembersUseCase,
            profileDependencies: container.friendUserProfileDependencies,
            makeGifPickerViewModel: container.makeGifPickerViewModel(groupId:),
            navigationStore: appState.feedNavigationStore,
            pendingFeedPostNavigation: appState.pendingFeedPostNavigation,
            onPendingPostHandled: {
                appState.clearPendingPostNavigation()
            },
            isTabActive: feedPlaybackActive
        )
        .environmentObject(container.customEmojiStore)
        .environment(\.customEmojiDependencies, container.customEmojiDependencies)
        .environment(
            \.imageAttachmentUpload,
            { data, mimeType in
                let upload = try await container.uploadCommentAttachment(data: data, mimeType: mimeType)
                return UploadedMediaReference(
                    id: upload.id,
                    url: upload.url,
                    thumbnailURL: upload.thumbnailURL,
                    sizeBytes: upload.sizeBytes
                )
            }
        )
        .environment(\.makeSharePostViewModel) { url in
            container.makeSharePostViewModel(shareURL: url, currentUserId: appState.currentUser?.id)
        }
        .environment(\.messagingGifPickerFactory) {
            container.makeGifPickerViewModel(groupId: nil)
        }
        .environment(\.gifKeywordSuggestFactory) {
            container.makeGifKeywordSuggestController()
        }
        .environment(\.sameTabTapHandlingEnabled, settledPagerTab == .feed)
    }

    @ViewBuilder
    private var expensesTabContent: some View {
        ExpenseListView(
            viewModel: container.expenseListViewModel,
            currentUserId: appState.currentUser?.id,
            currentUser: currentUserSummary,
            isTabActive: settledPagerTab == .expenses,
            fetchMyFriendsUseCase: container.fetchMyFriendsUseCase,
            fetchMyGroupsUseCase: container.fetchMyGroupsUseCase,
            fetchDebtSummaryUseCase: container.fetchDebtSummaryUseCase,
            profileDependencies: container.friendUserProfileDependencies,
            friendListViewModel: container.expenseFriendListViewModel,
            makeFriendDetailViewModel: { debt in
                container.makeExpenseFriendDetailViewModel(
                    debt: debt,
                    currentUserId: appState.currentUser?.id
                )
            },
            overviewViewModel: container.expenseOverviewViewModel
        )
        .environment(\.friendDisplayNameStore, container.friendDisplayNameStore)
        .environment(\.sameTabTapHandlingEnabled, settledPagerTab == .expenses)
    }

    @ViewBuilder
    private var friendsTabContent: some View {
        FriendsRootView(
            fetchMyFriendsUseCase: container.fetchMyFriendsUseCase,
            fetchMyGroupsUseCase: container.fetchMyGroupsUseCase,
            searchUsersUseCase: container.searchUsersUseCase,
            fetchUserProfileUseCase: container.fetchUserProfileUseCase,
            fetchUserPostsUseCase: container.fetchUserPostsUseCase,
            fetchFriendPaymentProfileUseCase: container.fetchFriendPaymentProfileUseCase,
            generateMyQrUseCase: container.generateMyQrUseCase,
            addFriendUseCase: container.addFriendUseCase,
            fetchIncomingFriendRequestsUseCase: container.fetchIncomingFriendRequestsUseCase,
            acceptFriendRequestUseCase: container.acceptFriendRequestUseCase,
            rejectFriendRequestUseCase: container.rejectFriendRequestUseCase,
            fetchOutgoingFriendRequestsUseCase: container.fetchOutgoingFriendRequestsUseCase,
            cancelFriendRequestUseCase: container.cancelFriendRequestUseCase,
            nearbyDiscoveryUseCase: container.nearbyDiscoveryUseCase,
            removeFriendUseCase: container.removeFriendUseCase,
            setFriendNicknameUseCase: container.setFriendNicknameUseCase,
            blockUserUseCase: container.blockUserUseCase,
            unblockUserUseCase: container.unblockUserUseCase,
            fetchBlockedUsersUseCase: container.fetchBlockedUsersUseCase,
            joinGroupUseCase: container.joinGroupUseCase,
            createGroupUseCase: container.createGroupUseCase,
            fetchGroupMembersUseCase: container.fetchGroupMembersUseCase,
            fetchGroupInviteCodeUseCase: container.fetchGroupInviteCodeUseCase,
            generateGroupInviteCodeUseCase: container.generateGroupInviteCodeUseCase,
            inviteFriendsToGroupUseCase: container.inviteFriendsToGroupUseCase,
            fetchGroupUseCase: container.fetchGroupUseCase,
            approveGroupMemberUseCase: container.approveGroupMemberUseCase,
            rejectGroupMemberUseCase: container.rejectGroupMemberUseCase,
            removeGroupMemberUseCase: container.removeGroupMemberUseCase,
            leaveGroupUseCase: container.leaveGroupUseCase,
            deleteGroupUseCase: container.deleteGroupUseCase,
            updateGroupUseCase: container.updateGroupUseCase,
            updateGroupAvatarUseCase: container.updateGroupAvatarUseCase,
            uploadGroupAvatarUseCase: container.uploadGroupAvatarUseCase,
            transferGroupOwnershipUseCase: container.transferGroupOwnershipUseCase,
            generateGroupQrUseCase: container.generateGroupQrUseCase,
            revokeGroupQrUseCase: container.revokeGroupQrUseCase,
            openLinkedGroupConversation: { groupId, name, memberIds in
                try await container.openLinkedGroupConversation(
                    groupId: groupId,
                    name: name,
                    memberUserIds: memberIds
                )
            },
            languageService: container.languageService,
            searchHistoryRepository: container.searchHistoryRepository,
            onBadgeCountsChanged: { await container.badgeCountService.refresh(force: true) },
            onDirectoryLoaded: { groups in
                container.widgetSyncBridge.syncGroups(groups)
            },
            onFriendRequestsLoaded: { requests in
                container.widgetSyncBridge.syncFriendRequests(requests)
            },
            pendingUserProfileUserId: $appState.pendingUserProfileNavigation,
            pendingUserProfileUsername: $appState.pendingUserProfileUsername,
            isTabActive: settledPagerTab == .friends
        )
        .environmentObject(container.customEmojiStore)
        .environment(\.customEmojiDependencies, container.customEmojiDependencies)
        .environment(\.sameTabTapHandlingEnabled, settledPagerTab == .friends)
    }

    @ViewBuilder
    private var messagesTabContent: some View {
        MessagingTabRoot(isTabActive: settledPagerTab == .messages)
            .environment(\.sameTabTapHandlingEnabled, settledPagerTab == .messages)
    }

    @ViewBuilder
    private var cameraTabContent: some View {
        PostCaptureFlowView(onDismiss: {
            appState.selectedTab = .feed
        })
    }

    private func handleSelectedTabChange(_ tab: Tab) {
        Log.debug("Tab selected", category: .ui, metadata: ["tab": tab.rawValue])
        if tab != .feed {
            FeedVideoPlaybackControl.suspend()
        }
        if tab == .camera {
            feedPlaybackActive = false
            cameraMounted = true
            cameraExpanded = true
            return
        }
        if cameraExpanded || cameraMounted {
            cameraExpanded = false
        }
        // Badge counts: startup apply + 30s polling + force refresh on mutations.
        // Do not refresh on every tab select — that races and floods /badge-counts.
    }

    private func handlePagerSlideSettled(_ tab: Tab) {
        guard appState.selectedTab == tab else { return }
        settledPagerTab = tab
        feedPlaybackActive = tab == .feed
        if tab == .messages,
           appState.isMessagingThreadPresented || appState.pendingMessagingNavigation != nil {
            tabBarChrome.tabBar.hide(flushToBottom: true)
        } else {
            tabBarChrome.tabBar.reset()
        }
    }
}

/// Shutter proxy above the water mask — full-screen so lift/scale is never clipped by the tab frame.
/// Visual only: the real shutter lives in the tab bar / camera layer.
private struct CameraRevealFloatingShutter: View {
    @ObservedObject var progressSource: CameraOpenRevealProgressSource
    let cameraSize: CGFloat
    let bottomInset: CGFloat

    var body: some View {
        let progress = progressSource.value
        GeometryReader { geo in
            let origin = CameraOpenRevealGeometry.origin(
                in: geo.size,
                cameraSize: cameraSize,
                bottomInset: bottomInset
            )
            let lift = CameraOpenRevealGeometry.shutterRowLift(progress: progress)
            let scale = CameraOpenRevealGeometry.shutterOpenScale(progress: progress)
            SplickCameraCaptureButton(size: cameraSize)
                .scaleEffect(scale)
                .position(x: origin.x, y: origin.y - lift)
                // Crossfade to the in-camera shutter at the end of the lift.
                .opacity(progress > 0.92 ? 0 : 1)
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }
}

/// Isolated so scroll-driven hide/show does not invalidate `MainTabView` (all four tabs).
private struct MainTabBarChrome: View {
    @Binding var selectedTab: Tab
    let badgeCounts: TabBadgeCounts
    let isChromePresented: Bool
    @ObservedObject var cameraRevealProgress: CameraOpenRevealProgressSource
    @ObservedObject var scrollState: TabBarScrollState
    var cameraLayerVisible: Bool = false
    @Environment(\.colorScheme) private var colorScheme
    /// Hit-testing lags hide animation so mid-slide taps are not dead; show enables immediately.
    @State private var hitTestingEnabled = true
    @State private var hideHitDisableGeneration = 0

    private var animationToken: TabBarChromeAnimationToken {
        TabBarChromeAnimationToken(
            isChromePresented: isChromePresented,
            isVisible: scrollState.isVisible,
            animated: scrollState.animatesVisibility
        )
    }

    private var insetHeight: CGFloat {
        isChromePresented ? TabBarLayout.floatingClearance : 0
    }

    private var slideOffset: CGFloat {
        guard isChromePresented else { return TabBarLayout.tabBarSlideDistance }
        return scrollState.isVisible ? 0 : TabBarLayout.tabBarSlideDistance
    }

    private var opacity: Double {
        isChromePresented ? 1 : 0
    }

    /// Crisp tab shutter sits above the soft water while it blooms / collapses.
    private var floatsAboveCameraWater: Bool {
        cameraLayerVisible && cameraRevealProgress.value < 0.99
    }

    var body: some View {
        SplickTabBar(
            selectedTab: $selectedTab,
            badgeCounts: badgeCounts,
            tabBarScrollState: scrollState,
            colorScheme: colorScheme,
            cameraRevealProgress: cameraRevealProgress.value
        )
        // Avoid .equatable() here — it can skip per-frame lift/scale updates.
        .opacity(opacity)
        .offset(y: slideOffset)
        // Keep centered layout inside floatingClearance (matches cameraRevealBottomInset).
        // Skip clipping while revealing so the tab camera can lift above the bar.
        .frame(height: insetHeight)
        .contentShape(Rectangle())
        .modifier(CameraRevealClipModifier(clip: !floatsAboveCameraWater))
        .animation(
            animationToken.animated ? TabBarMotion.slide : nil,
            value: animationToken
        )
        .ignoresSafeArea(edges: .bottom)
        .onAppear {
            syncHitTesting(visible: scrollState.isVisible, animated: scrollState.animatesVisibility)
        }
        .onChange(of: scrollState.isVisible) { visible in
            syncHitTesting(visible: visible, animated: scrollState.animatesVisibility)
        }
        .onChange(of: isChromePresented) { presented in
            if presented {
                syncHitTesting(visible: scrollState.isVisible, animated: scrollState.animatesVisibility)
            } else {
                hideHitDisableGeneration += 1
                hitTestingEnabled = false
            }
        }
        // Must be last: contentShape / ignoresSafeArea after this would steal
        // compose bottom-bar taps while the camera layer is up.
        .allowsHitTesting(
            isChromePresented
                && hitTestingEnabled
                && selectedTab != .camera
                && cameraRevealProgress.value < 0.02
        )
    }

    private func syncHitTesting(visible: Bool, animated: Bool) {
        if visible {
            hideHitDisableGeneration += 1
            hitTestingEnabled = true
            return
        }
        guard animated else {
            hideHitDisableGeneration += 1
            hitTestingEnabled = false
            return
        }
        // Keep hits during slide-out (bar still on screen); disable after settle.
        hideHitDisableGeneration += 1
        let generation = hideHitDisableGeneration
        hitTestingEnabled = true
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(TabBarMotion.slideSettleMilliseconds))
            guard generation == hideHitDisableGeneration else { return }
            guard !scrollState.isVisible else { return }
            hitTestingEnabled = false
        }
    }
}

private struct CameraRevealClipModifier: ViewModifier {
    var clip: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if clip {
            content.clipped()
        } else {
            content
        }
    }
}

struct ProfileSettingsView: View {
    private enum AvatarSheetAction {
        case view
        case pickPhoto
    }

    private struct AvatarCropDraft: Identifiable {
        let id = UUID()
        let image: UIImage
    }

    private static let minimumBirthdayAgeYears = 13

    private static let birthDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter
    }()

    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var container: DependencyContainer
    @EnvironmentObject private var languageService: LanguageService
    @EnvironmentObject private var themeService: ThemeService
    @EnvironmentObject private var pushNotificationCoordinator: PushNotificationCoordinator
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.requestReview) private var requestReview
    @State private var isSigningOut = false
    @State private var isRefreshingProfile = false
    @State private var isUpdatingLanguage = false
    @State private var profileError: String?
    @State private var showChangePassword = false
    @State private var hasPasswordLogin: Bool?
    @State private var showSessions = false
    @State private var showConnectedAccounts = false
    @State private var accountClosureAction: AccountClosureAction?
    @State private var showPaymentProfile = false
    @State private var showOwnProfile = false
    @State private var showBirthdayPicker = false
    @State private var birthdayDraft = Calendar.current.date(byAdding: .year, value: -18, to: Date()) ?? Date()
    @State private var isSavingBirthday = false
    @State private var birthdayError: String?
    @State private var showChangeUsername = false
    @State private var showNotifications = false
    @State private var showTheme = false
    @State private var showColorTheme = false
    @State private var showWidget = false
    @State private var showLanguagePicker = false
    @State private var languageDraft = AppLocale.default
    @State private var showAvatarOptions = false
    @State private var pendingAvatarSheetAction: AvatarSheetAction?
    @State private var showAvatarViewer = false
    @State private var showPhotoPicker = false
    @State private var avatarCropDraft: AvatarCropDraft?
    @State private var pendingAvatarCropImage: UIImage?
    @State private var showEditDisplayName = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var avatarPreviewImage: UIImage?
    @State private var isUpdatingAvatar = false
    @State private var isSavingDisplayName = false
    @State private var displayNameDraft = ""
    @State private var displayNameError: String?
    @State private var showProfileInviteShare = false
    @State private var profileInviteShareUsername = ""
    @State private var showShareSplick = false
    @State private var presentedLegalDocument: LegalDocumentType?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: SplickTheme.Spacing.lg) {
                    if let user = appState.currentUser {
                        profileHeaderSection(user: user)
                    }

                    if let profileError {
                        Text(profileError)
                            .font(SplickTheme.Typography.caption)
                            .foregroundStyle(SplickTheme.Colors.error)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    personalProfileSettingsGroup
                    appSettingsGroup
                    accountSettingsGroup
                    aboutGroup

                    SplickButton(
                        languageService.text(.profileSignOut),
                        style: .destructive,
                        isLoading: isSigningOut,
                        isDisabled: isSigningOut
                    ) {
                        Task {
                            isSigningOut = true
                            defer { isSigningOut = false }
                            await pushNotificationCoordinator.unregisterCurrentDeviceToken()
                            await container.logoutUseCase.execute()
                            appState.setUnauthenticated(container: container)
                            dismiss()
                        }
                    }
                    .padding(.horizontal, SplickTheme.Spacing.xl)
                }
                .padding(.top, SplickTheme.Spacing.xl)
                .padding(.bottom, SplickTheme.Spacing.xl)
            }
            .navigationTitle(languageService.text(.profileTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(languageService.text(.commonDone)) { dismiss() }
                }
            }
            .refreshable {
                await refreshProfile()
            }
            .task {
                await refreshProfile()
            }
            .onChange(of: showConnectedAccounts) { isPresented in
                if !isPresented {
                    Task { await refreshPasswordLoginState() }
                }
            }
            .sheet(isPresented: $showAvatarOptions, onDismiss: {
                switch pendingAvatarSheetAction {
                case .view:
                    showAvatarViewer = true
                case .pickPhoto:
                    showPhotoPicker = true
                case .none:
                    break
                }
                pendingAvatarSheetAction = nil
            }) {
                avatarOptionsSheet
            }
            .photosPicker(
                isPresented: $showPhotoPicker,
                selection: $selectedPhotoItem,
                matching: .images
            )
            .onChange(of: selectedPhotoItem) { _ in
                Task { await onPhotoItemChanged() }
            }
            .onChange(of: showPhotoPicker) { isPresented in
                guard !isPresented, let pendingAvatarCropImage else { return }
                self.pendingAvatarCropImage = nil
                avatarCropDraft = AvatarCropDraft(image: pendingAvatarCropImage)
            }
            .sheet(item: $avatarCropDraft) { draft in
                ProfileAvatarCropSheet(sourceImage: draft.image) { cropped in
                    try await uploadAvatar(cropped)
                }
                .environmentObject(languageService)
            }
            .splickWindowFullScreenCover(isPresented: $showAvatarViewer) {
                AvatarFullScreenView(
                    url: appState.currentUser?.avatarURL,
                    placeholderName: appState.currentUser?.displayName ?? "",
                    onDismiss: { showAvatarViewer = false }
                )
            }
            .sheet(isPresented: $showEditDisplayName) {
                editDisplayNameSheet
            }
            .sheet(isPresented: $showBirthdayPicker) {
                birthdayPickerSheet
            }
            .sheet(isPresented: $showLanguagePicker) {
                languagePickerSheet
            }
            .sheet(isPresented: $showProfileInviteShare) {
                AppShareSheet(
                    message: AppConstants.Links.profileInvitePath(username: profileInviteShareUsername),
                    url: AppConstants.Links.profileInviteURL(username: profileInviteShareUsername)
                )
            }
            .sheet(isPresented: $showShareSplick) {
                AppShareSheet(
                    message: languageService.text(.profileShareSplickMessage),
                    url: AppConstants.Links.marketingURL
                )
            }
            .sheet(item: $presentedLegalDocument) { documentType in
                LegalDocumentSheet(documentType: documentType)
                    .environmentObject(languageService)
            }
            .sheet(isPresented: $showChangeUsername) {
                if let user = appState.currentUser {
                    ChangeUsernameSheet(
                        viewModel: ChangeUsernameSheetViewModel(
                            currentUsername: user.username,
                            checkUsernameAvailabilityUseCase: container.checkUsernameAvailabilityUseCase,
                            updateProfileUseCase: container.updateProfileUseCase,
                            languageService: languageService
                        ),
                        onSaved: { user in
                            appState.updateAuthenticatedUser(user)
                        }
                    )
                    .environmentObject(languageService)
                }
            }
            .sheet(isPresented: $showOwnProfile) {
                if let user = appState.currentUser {
                    FriendUserProfileView(
                        viewModel: container.friendUserProfileDependencies.makeViewModel(
                            user: UserSummary(
                                id: user.id,
                                username: user.username,
                                displayName: user.displayName,
                                avatarURL: user.avatarURL
                            ),
                            currentUserId: user.id
                        ),
                        showsPersonalPageChrome: true
                    )
                    .environmentObject(languageService)
                }
            }
            .sheet(isPresented: $showPaymentProfile) {
                NavigationStack {
                    PaymentProfileManageView(
                        viewModel: PaymentProfileManageViewModel(
                            fetchMyPaymentProfileUseCase: container.fetchMyPaymentProfileUseCase,
                            upsertMyPaymentProfileUseCase: container.upsertMyPaymentProfileUseCase,
                            deleteMyPaymentProfileUseCase: container.deleteMyPaymentProfileUseCase,
                            uploadPaymentQr: { image in
                                let result = try await container.uploadPaymentQrUseCase.execute(image: image)
                                return result.url
                            },
                            onProfileChanged: { _ in }
                        )
                    )
                    .environmentObject(languageService)
                }
            }
            .sheet(isPresented: $showChangePassword) {
                if let email = appState.currentUser?.email {
                    ChangePasswordView(
                        viewModel: ChangePasswordViewModel(
                            accountEmail: email,
                            initialHasPassword: appState.currentUser?.hasPassword ?? true,
                            changePasswordUseCase: container.changePasswordUseCase,
                            verifyPasswordChangeUseCase: container.verifyPasswordChangeUseCase,
                            requestEmailOtpUseCase: container.requestEmailOtpUseCase,
                            languageService: languageService
                        ),
                        onPasswordChanged: { user in
                            appState.updateAuthenticatedUser(user)
                        }
                    )
                    .environmentObject(languageService)
                }
            }
            .navigationDestination(isPresented: $showSessions) {
                SessionsView(
                    viewModel: SessionsViewModel(
                        listSessionsUseCase: container.listSessionsUseCase,
                        revokeSessionUseCase: container.revokeSessionUseCase,
                        revokeAllSessionsUseCase: container.revokeAllSessionsUseCase,
                        languageService: languageService,
                        onSignedOutEverywhere: {
                            appState.setUnauthenticated(container: container)
                            dismiss()
                        }
                    )
                )
            }
            .navigationDestination(isPresented: $showConnectedAccounts) {
                if let email = appState.currentUser?.email {
                    ConnectedAccountsView(
                        viewModel: ConnectedAccountsViewModel(
                            accountEmail: email,
                            getConnectedAccountsUseCase: container.getConnectedAccountsUseCase,
                            linkGoogleAccountUseCase: container.linkGoogleAccountUseCase,
                            unlinkGoogleAccountUseCase: container.unlinkGoogleAccountUseCase,
                            linkPhoneAccountUseCase: container.linkPhoneAccountUseCase,
                            linkEmailAccountUseCase: container.linkEmailAccountUseCase,
                            requestEmailOtpUseCase: container.requestEmailOtpUseCase,
                            googleSignInPresenter: GoogleSignInClient.shared,
                            languageService: languageService
                        )
                    )
                    .environmentObject(languageService)
                }
            }
            .sheet(item: $accountClosureAction) { action in
                if let email = appState.currentUser?.email {
                    AccountClosureSheet(
                        isPresented: Binding(
                            get: { accountClosureAction != nil },
                            set: { if !$0 { accountClosureAction = nil } }
                        ),
                        viewModel: AccountClosureSheetViewModel(
                            action: action,
                            accountEmail: email,
                            canUseEmailVerification: !email.hasSuffix("@phone.splick.local"),
                            verifyPasswordChangeUseCase: container.verifyPasswordChangeUseCase,
                            requestEmailOtpUseCase: container.requestEmailOtpUseCase,
                            deactivateAccountUseCase: container.deactivateAccountUseCase,
                            deleteAccountUseCase: container.deleteAccountUseCase,
                            languageService: languageService,
                            onCompleted: {
                                accountClosureAction = nil
                                appState.setUnauthenticated(container: container)
                                dismiss()
                            }
                        )
                    )
                    .environmentObject(languageService)
                }
            }
            .navigationDestination(isPresented: $showNotifications) {
                NotificationsSettingsView()
                    .environmentObject(languageService)
            }
            .navigationDestination(isPresented: $showTheme) {
                ThemeSettingsView()
                    .environmentObject(languageService)
                    .environmentObject(themeService)
            }
            .navigationDestination(isPresented: $showColorTheme) {
                ColorThemeSettingsView()
                    .environmentObject(languageService)
                    .environmentObject(themeService)
            }
            .navigationDestination(isPresented: $showWidget) {
                WidgetSettingsView()
                    .environmentObject(languageService)
            }
        }
    }

    @ViewBuilder
    private func profileHeaderSection(user: User) -> some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topTrailing) {
                Button {
                    showAvatarOptions = true
                } label: {
                    profileAvatarContent(user: user)
                        .frame(width: 96, height: 96)
                        .clipShape(Circle())
                        .overlay {
                            if isUpdatingAvatar {
                                Circle()
                                    .fill(Color.black.opacity(0.4))
                                SplickSpinner(usesBrandColors: false)
                            }
                        }
                        .overlay(alignment: .bottomTrailing) {
                            if !isUpdatingAvatar {
                                Circle()
                                    .fill(SplickTheme.Colors.success)
                                    .frame(width: 18, height: 18)
                                    .overlay {
                                        Circle()
                                            .strokeBorder(SplickTheme.Colors.background, lineWidth: 2)
                                    }
                                    .offset(x: 2, y: 2)
                            }
                        }
                }
                .buttonStyle(.plain)
                .disabled(isUpdatingAvatar)

                if !isUpdatingAvatar {
                    Button {
                        showAvatarOptions = true
                    } label: {
                        Image(systemName: "pencil.circle.fill")
                            .font(.system(size: 28))
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, SplickTheme.Colors.primary)
                            .background(Circle().fill(SplickTheme.Colors.background))
                    }
                    .buttonStyle(.plain)
                    .offset(x: 4, y: -4)
                }
            }

            Button {
                displayNameDraft = user.displayName
                displayNameError = nil
                showEditDisplayName = true
            } label: {
                HStack(spacing: SplickTheme.Spacing.xxs) {
                    Text(user.displayName)
                        .font(SplickTheme.Typography.title)
                        .foregroundStyle(SplickTheme.Colors.textPrimary)

                    Image(systemName: "pencil")
                        .font(.system(size: 14))
                        .foregroundStyle(SplickTheme.Colors.textSecondary)
                }
            }
            .buttonStyle(.plain)
            .padding(.top, SplickTheme.Spacing.xs)

            Button {
                profileInviteShareUsername = user.username
                showProfileInviteShare = true
            } label: {
                Text(AppConstants.Links.profileInvitePath(username: user.username))
                    .font(SplickTheme.Typography.callout)
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(languageService.text(.profileCopyInviteLink))
            .padding(.top, SplickTheme.Spacing.xxs)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func profileAvatarContent(user: User) -> some View {
        if let avatarPreviewImage {
            Image(uiImage: avatarPreviewImage)
                .resizable()
                .scaledToFill()
        } else if let url = user.avatarURL {
            RemoteImage(
                url: url,
                maxPixelSize: RemoteImageMetrics.avatarMaxPixelWidth(pointSize: 96)
            ) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                case .failure:
                    profileAvatarPlaceholder(name: user.displayName)
                default:
                    SplickSpinner(size: .small)
                }
            }
        } else {
            profileAvatarPlaceholder(name: user.displayName)
        }
    }

    private func profileAvatarPlaceholder(name: String) -> some View {
        ZStack {
            SplickTheme.Colors.primaryGradient
            Text(String(name.prefix(2)).uppercased())
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
        }
    }

    private var canViewAvatar: Bool {
        appState.currentUser?.avatarURL != nil || avatarPreviewImage != nil
    }

    private var canRemoveAvatar: Bool {
        appState.currentUser?.avatarURL != nil
    }

    private var avatarOptionsSheetHeight: CGFloat {
        var rows = 1
        if canViewAvatar { rows += 1 }
        if canRemoveAvatar { rows += 1 }
        return CGFloat(rows) * 52 + 48
    }

    private var avatarOptionsSheet: some View {
        VStack(spacing: 0) {
            if canViewAvatar {
                avatarOptionButton(title: languageService.text(.profileAvatarView)) {
                    pendingAvatarSheetAction = .view
                    showAvatarOptions = false
                }
            }

            avatarOptionButton(title: languageService.text(.profileAvatarEdit)) {
                pendingAvatarSheetAction = .pickPhoto
                showAvatarOptions = false
            }

            if canRemoveAvatar {
                avatarOptionButton(
                    title: languageService.text(.profileAvatarDelete),
                    isDestructive: true
                ) {
                    showAvatarOptions = false
                    Task { await removeAvatar() }
                }
            }
        }
        .padding(.horizontal, SplickTheme.Spacing.lg)
        .padding(.top, SplickTheme.Spacing.xs)
        .padding(.bottom, SplickTheme.Spacing.md)
        .presentationDetents([.height(avatarOptionsSheetHeight)])
        .presentationDragIndicator(.visible)
    }

    private func avatarOptionButton(
        title: String,
        isDestructive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(SplickTheme.Typography.body)
                .foregroundStyle(isDestructive ? SplickTheme.Colors.error : SplickTheme.Colors.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, SplickTheme.Spacing.sm)
        }
        .buttonStyle(.plain)
    }

    private var editDisplayNameSheet: some View {
        NavigationStack {
            VStack(spacing: SplickTheme.Spacing.lg) {
                SplickTextField(
                    languageService.text(.authDisplayName),
                    text: $displayNameDraft,
                    icon: "person"
                )
                .textInputAutocapitalization(.words)

                if let displayNameError {
                    Text(displayNameError)
                        .font(SplickTheme.Typography.caption)
                        .foregroundStyle(SplickTheme.Colors.error)
                        .multilineTextAlignment(.center)
                }

                SplickButton(
                    languageService.text(.profileSave),
                    isLoading: isSavingDisplayName,
                    isDisabled: isSavingDisplayName
                ) {
                    Task { await saveDisplayName() }
                }
            }
            .padding(SplickTheme.Spacing.md)
            .navigationTitle(languageService.text(.profileEditDisplayName))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(languageService.text(.commonCancel)) {
                        showEditDisplayName = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private var birthdayPickerSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: SplickTheme.Spacing.lg) {
                    DatePicker(
                        languageService.text(.profileBirthday),
                        selection: $birthdayDraft,
                        in: ...Date(),
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .labelsHidden()

                    if let birthdayError {
                        Text(birthdayError)
                            .font(SplickTheme.Typography.caption)
                            .foregroundStyle(SplickTheme.Colors.error)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(SplickTheme.Spacing.md)
            }
            .navigationTitle(languageService.text(.profileBirthday))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(languageService.text(.commonCancel)) {
                        showBirthdayPicker = false
                    }
                    .disabled(isSavingBirthday)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(languageService.text(.profileSave)) {
                        Task { await saveBirthday() }
                    }
                    .disabled(isSavingBirthday)
                }
            }
        }
        .presentationDetents([.large])
    }

    private var languagePickerSheet: some View {
        NavigationStack {
            List {
                ForEach(AppLocale.allCases) { locale in
                    Button {
                        languageDraft = locale
                    } label: {
                        HStack {
                            Text(languageService.text(locale.displayNameKey))
                                .foregroundStyle(SplickTheme.Colors.textPrimary)
                            Spacer()
                            if languageDraft == locale {
                                Image(systemName: "checkmark")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(SplickTheme.Colors.primary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(languageService.text(.profileLanguage))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(languageService.text(.commonCancel)) {
                        showLanguagePicker = false
                    }
                    .disabled(isUpdatingLanguage)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(languageService.text(.commonDone)) {
                        showLanguagePicker = false
                        if languageDraft != languageService.locale {
                            Task { await updateLanguage(languageDraft) }
                        }
                    }
                    .disabled(isUpdatingLanguage)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private var accountSettingsGroup: some View {
        ProfileSettingsGroup(
            title: languageService.text(.profileGroupAccount),
            items: [
                ProfileSettingsItem(
                    icon: "lock",
                    title: languageService.text(.profileChangePassword),
                    subtitle: hasPasswordLogin == false
                        ? languageService.text(.profileChangePasswordUnavailableShort)
                        : nil,
                    action: { showChangePassword = true }
                ),
                ProfileSettingsItem(
                    icon: "iphone.and.arrow.forward",
                    title: languageService.text(.profileDevicesSessions),
                    action: { showSessions = true }
                ),
                ProfileSettingsItem(
                    icon: "link",
                    title: languageService.text(.profileConnectedAccounts),
                    action: { showConnectedAccounts = true }
                ),
                ProfileSettingsItem(
                    icon: "pause.circle",
                    title: languageService.text(.profileDeactivate),
                    action: { accountClosureAction = .deactivate }
                ),
                ProfileSettingsItem(
                    icon: "trash",
                    title: languageService.text(.profileDeleteAccount),
                    action: { accountClosureAction = .delete }
                )
            ]
        )
        .padding(.horizontal, SplickTheme.Spacing.xl)
        .disabled(appState.currentUser == nil)
    }

    private var personalProfileSettingsGroup: some View {
        ProfileSettingsGroup(
            title: languageService.text(.profileGroupPersonal),
            items: [
                ProfileSettingsItem(
                    icon: "person.crop.circle",
                    title: languageService.text(.profilePersonalPage),
                    action: { showOwnProfile = true }
                ),
                ProfileSettingsItem(
                    icon: "qrcode",
                    title: languageService.text(.profileQrReceive),
                    action: { showPaymentProfile = true }
                ),
                ProfileSettingsItem(
                    icon: "calendar",
                    title: languageService.text(.profileBirthday),
                    subtitle: formattedBirthday(appState.currentUser?.dateOfBirth),
                    action: {
                        birthdayDraft = appState.currentUser?.dateOfBirth
                            ?? Calendar.current.date(byAdding: .year, value: -18, to: Date())
                            ?? Date()
                        birthdayError = nil
                        showBirthdayPicker = true
                    }
                ),
                ProfileSettingsItem(
                    icon: "at",
                    title: languageService.text(.profileChangeUsername),
                    subtitle: appState.currentUser.map { "@\($0.username)" },
                    action: { showChangeUsername = true }
                )
            ]
        )
        .padding(.horizontal, SplickTheme.Spacing.xl)
        .disabled(appState.currentUser == nil)
    }

    private var appSettingsGroup: some View {
        ProfileSettingsGroup(
            title: languageService.text(.profileGroupApp),
            items: [
                ProfileSettingsItem(
                    icon: "bell",
                    title: languageService.text(.profileNotifications),
                    action: { showNotifications = true }
                ),
                ProfileSettingsItem(
                    icon: "globe",
                    title: languageService.text(.profileLanguage),
                    subtitle: languageService.text(languageService.locale.displayNameKey),
                    action: {
                        languageDraft = languageService.locale
                        showLanguagePicker = true
                    }
                ),
                ProfileSettingsItem(
                    icon: "paintpalette",
                    title: languageService.text(.profileColorTheme),
                    subtitle: languageService.text(themeService.colorTheme.displayNameKey),
                    action: { showColorTheme = true }
                ),
                ProfileSettingsItem(
                    icon: "moon.stars",
                    title: languageService.text(.profileTheme),
                    subtitle: languageService.text(themeService.theme.displayNameKey),
                    action: { showTheme = true }
                ),
                ProfileSettingsItem(
                    icon: "square.grid.2x2",
                    title: languageService.text(.profileWidget),
                    action: { showWidget = true }
                )
            ]
        )
        .padding(.horizontal, SplickTheme.Spacing.xl)
    }

    private var aboutGroup: some View {
        ProfileSettingsGroup(
            title: languageService.text(.profileGroupAbout),
            items: [
                ProfileSettingsItem(
                    icon: "square.and.arrow.up",
                    title: languageService.text(.profileShareSplick),
                    action: { showShareSplick = true }
                ),
                ProfileSettingsItem(
                    icon: "star",
                    title: languageService.text(.profileRateSplick),
                    action: { requestReview() }
                ),
                ProfileSettingsItem(
                    icon: "doc.text",
                    title: languageService.text(.profileTermsOfService),
                    action: { presentedLegalDocument = .terms }
                ),
                ProfileSettingsItem(
                    icon: "hand.raised",
                    title: languageService.text(.profilePrivacyPolicy),
                    action: { presentedLegalDocument = .privacy }
                ),
                ProfileSettingsItem(
                    icon: "questionmark.circle",
                    title: languageService.text(.profileSupport),
                    action: { openURL(AppConstants.Links.supportURL) }
                )
            ]
        )
        .padding(.horizontal, SplickTheme.Spacing.xl)
    }

    private func onPhotoItemChanged() async {
        guard let selectedPhotoItem else { return }
        let item = selectedPhotoItem
        self.selectedPhotoItem = nil
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else {
            profileError = languageService.text(.profileAvatarLoadFailed)
            return
        }
        avatarCropDraft = nil
        let prepared = ImageCropRenderer.downsampled(image)
        if showPhotoPicker {
            pendingAvatarCropImage = prepared
        } else {
            avatarCropDraft = AvatarCropDraft(image: prepared)
        }
    }

    private func uploadAvatar(_ image: UIImage) async throws {
        guard !isUpdatingAvatar else { return }
        isUpdatingAvatar = true
        profileError = nil
        defer { isUpdatingAvatar = false }

        do {
            let uploaded = try await container.uploadUserAvatarUseCase.execute(image: image)
            let user = try await container.updateProfileUseCase.execute(
                displayName: nil,
                avatarUrl: uploaded.url.absoluteString,
                preferredLocale: nil
            )
            appState.updateAuthenticatedUser(user)
            selectedPhotoItem = nil
            avatarPreviewImage = nil
            avatarCropDraft = nil
        } catch {
            profileError = languageService.localizedMessage(for: error)
            avatarPreviewImage = nil
            selectedPhotoItem = nil
            throw error
        }
    }

    private func removeAvatar() async {
        guard !isUpdatingAvatar else { return }
        isUpdatingAvatar = true
        profileError = nil
        defer { isUpdatingAvatar = false }

        do {
            let user = try await container.updateProfileUseCase.execute(
                displayName: nil,
                avatarUrl: "",
                preferredLocale: nil
            )
            appState.updateAuthenticatedUser(user)
            avatarPreviewImage = nil
            selectedPhotoItem = nil
        } catch {
            profileError = languageService.localizedMessage(for: error)
        }
    }

    private func saveBirthday() async {
        guard !isSavingBirthday else { return }

        let minimumBirthDate = Calendar.current.date(
            byAdding: .year,
            value: -Self.minimumBirthdayAgeYears,
            to: Date()
        ) ?? Date()
        if birthdayDraft > minimumBirthDate {
            birthdayError = languageService.text(.profileBirthdayAgeError)
            return
        }

        isSavingBirthday = true
        birthdayError = nil
        defer { isSavingBirthday = false }

        do {
            let user = try await container.updateProfileUseCase.execute(
                displayName: nil,
                avatarUrl: nil,
                preferredLocale: nil,
                dateOfBirth: birthdayDraft
            )
            appState.updateAuthenticatedUser(user)
            showBirthdayPicker = false
        } catch {
            birthdayError = languageService.localizedMessage(for: error)
        }
    }

    private func formattedBirthday(_ date: Date?) -> String? {
        guard let date else { return nil }
        return Self.birthDateFormatter.string(from: date)
    }

    private func saveDisplayName() async {
        let trimmedName = displayNameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        guard !isSavingDisplayName else { return }

        isSavingDisplayName = true
        displayNameError = nil
        defer { isSavingDisplayName = false }

        do {
            let user = try await container.updateProfileUseCase.execute(
                displayName: trimmedName,
                avatarUrl: nil,
                preferredLocale: nil
            )
            appState.updateAuthenticatedUser(user)
            showEditDisplayName = false
        } catch {
            displayNameError = languageService.localizedMessage(for: error)
        }
    }

    private func updateLanguage(_ locale: AppLocale) async {
        guard !isUpdatingLanguage else { return }
        guard languageService.locale != locale else { return }
        isUpdatingLanguage = true
        defer { isUpdatingLanguage = false }
        profileError = nil
        languageService.setLocale(locale)
        guard appState.currentUser != nil else { return }
        do {
            let user = try await container.updateProfileUseCase.execute(
                displayName: nil,
                avatarUrl: nil,
                preferredLocale: locale.apiCode
            )
            appState.updateAuthenticatedUser(user)
            languageService.applyFromServer(user.preferredLocale)
        } catch {
            profileError = languageService.localizedMessage(for: error)
        }
    }

    private func refreshProfile() async {
        guard !isRefreshingProfile else { return }
        isRefreshingProfile = true
        defer { isRefreshingProfile = false }
        profileError = nil
        do {
            let user = try await container.refreshProfileUseCase.execute()
            appState.updateAuthenticatedUser(user)
            languageService.applyFromServer(user.preferredLocale)
            await syncDeviceTimezoneIfNeeded(user)
            await refreshPasswordLoginState()
        } catch {
            profileError = languageService.text(.profileRefreshFailed)
        }
    }

    private func refreshPasswordLoginState() async {
        hasPasswordLogin = appState.currentUser?.hasPassword ?? hasPasswordLogin ?? true
    }

    private func syncDeviceTimezoneIfNeeded(_ user: User) async {
        let deviceZone = TimeZone.current.identifier
        guard user.timezone != deviceZone else { return }
        do {
            let updated = try await container.updateProfileUseCase.execute(
                displayName: nil,
                avatarUrl: nil,
                preferredLocale: nil,
                dateOfBirth: nil,
                username: nil,
                timezone: deviceZone
            )
            appState.updateAuthenticatedUser(updated)
        } catch {
            Log.error("Failed to sync device timezone: \(error)", category: .auth)
        }
    }
}

private struct NotificationRevealHost: View {
    @ObservedObject var viewModel: NotificationListViewModel
    @ObservedObject var languageService: LanguageService
    @Binding var isPresented: Bool
    @Binding var dismissRequest: Bool
    @Binding var notificationIsDismissing: Bool
    let anchorFrame: CGRect
    let onNavigate: (NotificationNavigationTarget) -> Void

    var body: some View {
        DesignSystem.SplickNotificationRevealOverlay(
            isPresented: $isPresented,
            anchorFrame: anchorFrame,
            unreadCount: viewModel.unreadCount,
            headerTitle: languageService.text(.notificationTitle),
            leadingActionTitle: languageService.text(.notificationReadAll),
            onLeadingAction: {
                Task { await viewModel.markAllAsRead() }
            },
            closeAccessibilityLabel: languageService.text(.notificationBellAccessibility),
            dismissRequest: $dismissRequest,
            onDismissStarted: { notificationIsDismissing = true }
        ) { dismiss in
            NotificationListView(
                viewModel: viewModel,
                onNavigate: { target in
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + SplickRevealMotion.notificationCollapseDuration) {
                        onNavigate(target)
                    }
                },
                onDismiss: dismiss,
                presentedAsSheet: true
            )
            .environmentObject(languageService)
        }
    }
}

private struct AppShareSheet: UIViewControllerRepresentable {
    let message: String
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [message, url], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
