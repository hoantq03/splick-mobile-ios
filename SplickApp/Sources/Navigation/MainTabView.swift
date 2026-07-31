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

private struct TabBarChromeAnimationToken: Equatable {
    let isChromePresented: Bool
    let isVisible: Bool
}

struct MainTabView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var container: DependencyContainer
    @EnvironmentObject private var pushNotificationCoordinator: PushNotificationCoordinator
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var tabBarScrollState = TabBarScrollState()
    @State private var badgeCounts: TabBadgeCounts = .zero
    /// Toggled to `true` by the bell button while the panel is open; the overlay's onChange
    /// observes this, resets it, and runs `dismissAnimated()` so the collapse animation plays
    /// before the overlay is removed from the hierarchy.
    @State private var notificationDismissRequest = false
    /// Set to `true` the moment the notification panel begins its collapse animation so the tab
    /// bar chrome can start sliding in immediately, in parallel with the overlay collapsing.
    /// Reset to `false` once `showNotifications` fully clears.
    @State private var notificationIsDismissing = false

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
        appState.selectedTab != .camera
            && appState.linkedPostPresentation == nil
            && (!appState.showNotifications || notificationIsDismissing)
    }

    private var tabBarChromeAnimationToken: TabBarChromeAnimationToken {
        TabBarChromeAnimationToken(
            isChromePresented: isTabBarChromePresented,
            isVisible: tabBarScrollState.isVisible
        )
    }

    private var tabBarInsetHeight: CGFloat {
        isTabBarChromePresented ? TabBarLayout.floatingClearance : 0
    }

    private var tabBarSlideOffset: CGFloat {
        guard isTabBarChromePresented else { return TabBarLayout.tabBarSlideDistance }
        return tabBarScrollState.isVisible ? 0 : TabBarLayout.tabBarSlideDistance
    }

    private var tabBarOpacity: Double {
        // Fade only when chrome leaves entirely (camera / overlays).
        // Scroll hide uses slide-down only so it doesn't look like a dissolve.
        isTabBarChromePresented ? 1 : 0
    }

    var body: some View {
        ZStack {
            // Fills the full screen (including safe areas) so system white never shows
            // through at the top (status bar) or bottom (home indicator) safe area regions.
            SplickTheme.Colors.background
                .ignoresSafeArea()

            MainTabContentPager(
                selectedTab: $appState.selectedTab,
                feed: { feedTabContent },
                expenses: { expensesTabContent },
                friends: { friendsTabContent },
                messages: { messagesTabContent },
                camera: { cameraTabContent }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if let presentation = appState.linkedPostPresentation {
                LinkedPostDetailOverlay(
                    presentation: presentation,
                    feedViewModel: container.feedViewModel,
                    fetchFriendsUseCase: container.fetchFriendsUseCase,
                    profileDependencies: container.friendUserProfileDependencies,
                    makeGifPickerViewModel: container.makeGifPickerViewModel(groupId:),
                    uploadCommentImage: { data, mimeType in
                        let upload = try await container.uploadCommentAttachment(data: data, mimeType: mimeType)
                        return UploadedMediaReference(
                            id: upload.id,
                            url: upload.url,
                            thumbnailURL: upload.thumbnailURL,
                            sizeBytes: upload.sizeBytes
                        )
                    },
                    onDismiss: {
                        withAnimation(LinkedPostMotion.spring) {
                            appState.dismissLinkedPostPresentation()
                        }
                    }
                )
                .environmentObject(container.languageService)
                .environmentObject(container.customEmojiStore)
                .environment(\.customEmojiDependencies, container.customEmojiDependencies)
                .transition(.move(edge: .trailing))
                .zIndex(1)
            }
        }
        .animation(LinkedPostMotion.spring, value: appState.linkedPostPresentation)
            .onAppear {
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
            .onReceive(container.messagingWebSocketClient.eventSubject) { event in
                if case .newMessage = event {
                    Task { await container.badgeCountService.refresh(force: true) }
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
            .environment(\.notificationUnreadCount, badgeCounts.notifications)
            .environment(\.notificationsPresented, appState.showNotifications && !notificationIsDismissing)
            .environment(\.openPostCaptureFlow) {
                appState.selectedTab = .camera
            }
            .environment(\.openLinkedPost) { postId, expandBillSplit in
                appState.openLinkedPost(postId, expandBillSplit: expandBillSplit)
            }
            .environment(\.openDirectMessage) { friendUserId in
                    await container.getOrCreateConversationId(friendUserId: friendUserId)
                }
            .environment(\.currentUserSummary, currentUserSummary)
            .environment(\.tabBarScrollState, tabBarScrollState)
            .overlay(alignment: .bottom) {
                SplickTabBar(
                    selectedTab: $appState.selectedTab,
                    badgeCounts: badgeCounts,
                    tabBarScrollState: tabBarScrollState
                )
                .equatable()
                .opacity(tabBarOpacity)
                .offset(y: tabBarSlideOffset)
                .allowsHitTesting(isTabBarChromePresented && tabBarScrollState.isVisible)
                .frame(height: tabBarInsetHeight)
                .clipped()
                .animation(TabBarMotion.slide, value: tabBarChromeAnimationToken)
                .ignoresSafeArea(edges: .bottom)
            }
            .onChange(of: appState.selectedTab, perform: handleSelectedTabChange)
            .onChange(of: appState.showNotifications) { isShown in
                if !isShown { notificationIsDismissing = false }
            }
        .task(id: scenePhase) {
            switch scenePhase {
            case .active:
                container.badgeCountService.startPolling()
                container.messagingWebSocketClient.connect()
                // Badges come from startup `apply` + 30s polling + force refresh on mutations.
                pushNotificationCoordinator.syncAppIconBadge(count: container.badgeCountService.counts.total)
            case .background:
                container.badgeCountService.stopPolling()
                container.messagingWebSocketClient.disconnect()
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
                DesignSystem.SplickNotificationRevealOverlay(
                    isPresented: $appState.showNotifications,
                    anchorFrame: appState.notificationAnchorFrame,
                    unreadCount: badgeCounts.notifications,
                    headerTitle: container.languageService.text(.notificationTitle),
                    closeAccessibilityLabel: container.languageService.text(.notificationBellAccessibility),
                    dismissRequest: $notificationDismissRequest,
                    onDismissStarted: { notificationIsDismissing = true }
                ) { dismiss in
                    NotificationListView(
                        viewModel: container.notificationListViewModel,
                        onNavigate: { target in
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + SplickRevealMotion.collapseDuration) {
                                appState.routeNotification(target: target)
                            }
                        },
                        onDismiss: dismiss,
                        presentedAsSheet: true
                    )
                    .environmentObject(container.languageService)
                }
                .zIndex(100)
            }
        }
        .tint(SplickTheme.Colors.primaryGradientStart)
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
            profileDependencies: container.friendUserProfileDependencies,
            makeGifPickerViewModel: container.makeGifPickerViewModel(groupId:),
            navigationPath: $appState.feedNavigationPath,
            pendingFeedPostNavigation: appState.pendingFeedPostNavigation,
            onPendingPostHandled: {
                appState.clearPendingPostNavigation()
            },
            isTabActive: appState.selectedTab == .feed
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
        .environment(\.sameTabTapHandlingEnabled, appState.selectedTab == .feed)
    }

    @ViewBuilder
    private var expensesTabContent: some View {
        ExpenseListView(
            viewModel: container.expenseListViewModel,
            currentUserId: appState.currentUser?.id,
            isTabActive: appState.selectedTab == .expenses,
            userSearchUseCase: container.expenseFriendSearchUseCase,
            profileDependencies: container.friendUserProfileDependencies,
            friendListViewModel: container.expenseFriendListViewModel,
            makeFriendDetailViewModel: { debt in
                container.makeExpenseFriendDetailViewModel(
                    debt: debt,
                    currentUserId: appState.currentUser?.id
                )
            }
        )
        .environment(\.sameTabTapHandlingEnabled, appState.selectedTab == .expenses)
    }

    @ViewBuilder
    private var friendsTabContent: some View {
        FriendsRootView(
            fetchMyFriendsUseCase: container.fetchMyFriendsUseCase,
            fetchMyGroupsUseCase: container.fetchMyGroupsUseCase,
            searchUsersUseCase: container.searchUsersUseCase,
            fetchUserProfileUseCase: container.fetchUserProfileUseCase,
            fetchFriendPaymentProfileUseCase: container.fetchFriendPaymentProfileUseCase,
            generateMyQrUseCase: container.generateMyQrUseCase,
            addFriendUseCase: container.addFriendUseCase,
            fetchIncomingFriendRequestsUseCase: container.fetchIncomingFriendRequestsUseCase,
            acceptFriendRequestUseCase: container.acceptFriendRequestUseCase,
            rejectFriendRequestUseCase: container.rejectFriendRequestUseCase,
            fetchOutgoingFriendRequestsUseCase: container.fetchOutgoingFriendRequestsUseCase,
            cancelFriendRequestUseCase: container.cancelFriendRequestUseCase,
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
            languageService: container.languageService,
            onBadgeCountsChanged: { await container.badgeCountService.refresh(force: true) },
            onDirectoryLoaded: { groups in
                container.widgetSyncBridge.syncGroups(groups)
            },
            onFriendRequestsLoaded: { requests in
                container.widgetSyncBridge.syncFriendRequests(requests)
            }
        )
        .environmentObject(container.customEmojiStore)
        .environment(\.customEmojiDependencies, container.customEmojiDependencies)
        .environment(\.sameTabTapHandlingEnabled, appState.selectedTab == .friends)
    }

    @ViewBuilder
    private var messagesTabContent: some View {
        MessagingTabRoot()
            .environment(\.sameTabTapHandlingEnabled, appState.selectedTab == .messages)
    }

    @ViewBuilder
    private var cameraTabContent: some View {
        PostCaptureFlowView(onDismiss: {
            appState.selectedTab = .feed
        })
        .ignoresSafeArea()
    }

    private func handleSelectedTabChange(_ tab: Tab) {
        Log.debug("Tab selected", category: .ui, metadata: ["tab": tab.rawValue])
        if tab == .camera {
            tabBarScrollState.hide(flushToBottom: true)
            return
        }
        // Defer chrome reset until the pager slide has mostly finished so reset
        // work does not contend with the offset animation on the main thread.
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(280))
            guard appState.selectedTab == tab else { return }
            tabBarScrollState.reset()
        }
        // Badge counts: startup apply + 30s polling + force refresh on mutations.
        // Do not refresh on every tab select — that races and floods /badge-counts.
    }
}

struct ProfileSettingsView: View {
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
    @EnvironmentObject private var pushNotificationCoordinator: PushNotificationCoordinator
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.requestReview) private var requestReview
    @State private var isSigningOut = false
    @State private var isRefreshingProfile = false
    @State private var isUpdatingLanguage = false
    @State private var profileError: String?
    @State private var showChangePassword = false
    @State private var showSessions = false
    @State private var showConnectedAccounts = false
    @State private var accountClosureAction: AccountClosureAction?
    @State private var showPaymentProfile = false
    @State private var showBirthdayPicker = false
    @State private var birthdayDraft = Calendar.current.date(byAdding: .year, value: -18, to: Date()) ?? Date()
    @State private var isSavingBirthday = false
    @State private var birthdayError: String?
    @State private var showChangeUsername = false
    @State private var showNotifications = false
    @State private var showTheme = false
    @State private var showAppIcon = false
    @State private var showWidget = false
    @State private var showLanguagePicker = false
    @State private var languageDraft = AppLocale.default
    @State private var showAvatarOptions = false
    @State private var showAvatarViewer = false
    @State private var showPhotoPicker = false
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
            .confirmationDialog(
                "",
                isPresented: $showAvatarOptions,
                titleVisibility: .hidden
            ) {
                if appState.currentUser?.avatarURL != nil || avatarPreviewImage != nil {
                    Button(languageService.text(.profileAvatarView)) {
                        showAvatarViewer = true
                    }
                }
                Button(languageService.text(.profileAvatarEdit)) {
                    showPhotoPicker = true
                }
                if appState.currentUser?.avatarURL != nil {
                    Button(languageService.text(.profileAvatarDelete), role: .destructive) {
                        Task { await removeAvatar() }
                    }
                }
                Button(languageService.text(.commonCancel), role: .cancel) {}
            }
            .photosPicker(
                isPresented: $showPhotoPicker,
                selection: $selectedPhotoItem,
                matching: .images
            )
            .onChange(of: selectedPhotoItem) { _ in
                Task { await onPhotoItemChanged() }
            }
            .sheet(isPresented: $showAvatarViewer) {
                avatarViewerSheet
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
            }
            .navigationDestination(isPresented: $showAppIcon) {
                AppIconSettingsView()
                    .environmentObject(languageService)
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
                                ProgressView()
                                    .tint(.white)
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

    private var avatarViewerSheet: some View {
        NavigationStack {
            Group {
                if let avatarPreviewImage {
                    Image(uiImage: avatarPreviewImage)
                        .resizable()
                        .scaledToFit()
                } else if let url = appState.currentUser?.avatarURL {
                    RemoteImage(
                url: url,
                maxPixelSize: RemoteImageMetrics.avatarMaxPixelWidth(pointSize: 96)
            ) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFit()
                        case .failure:
                            EmptyStateView(
                                icon: "person.crop.circle",
                                title: languageService.text(.profileAvatarView),
                                message: languageService.text(.profileRefreshFailed)
                            )
                        default:
                            ProgressView()
                        }
                    }
                } else {
                    EmptyStateView(
                        icon: "person.crop.circle",
                        title: languageService.text(.profileAvatarView),
                        message: languageService.text(.profileAvatarDelete)
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(SplickTheme.Colors.background)
            .navigationTitle(languageService.text(.profileAvatarView))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(languageService.text(.commonDone)) {
                        showAvatarViewer = false
                    }
                }
            }
        }
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
                    isDestructive: true,
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
                    icon: "paintbrush",
                    title: languageService.text(.profileTheme),
                    action: { showTheme = true }
                ),
                ProfileSettingsItem(
                    icon: "app",
                    title: languageService.text(.profileAppIcon),
                    action: { showAppIcon = true }
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
        guard let selectedPhotoItem else {
            avatarPreviewImage = nil
            return
        }
        guard let data = try? await selectedPhotoItem.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else {
            profileError = languageService.text(.profileRefreshFailed)
            return
        }
        avatarPreviewImage = image
        await uploadAvatar(image)
    }

    private func uploadAvatar(_ image: UIImage) async {
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
        } catch {
            profileError = languageService.localizedMessage(for: error)
            avatarPreviewImage = nil
            selectedPhotoItem = nil
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
        } catch {
            profileError = languageService.text(.profileRefreshFailed)
        }
    }
}

// MARK: - Main tab pager

private enum MainTabPagerMotion {
    /// Smooth slide without spring overshoot (overshoot reads as a hitch at the end).
    static let slide = Animation.easeInOut(duration: 0.28)
}

private extension Tab {
    static let pagerTabs: [Tab] = [.feed, .expenses, .friends, .messages]

    var isPagerTab: Bool {
        Self.pagerTabs.contains(self)
    }
}

private struct MainTabContentPager<Feed: View, Expenses: View, Friends: View, Messages: View, Camera: View>: View {
    @Binding var selectedTab: Tab
    @ViewBuilder var feed: () -> Feed
    @ViewBuilder var expenses: () -> Expenses
    @ViewBuilder var friends: () -> Friends
    @ViewBuilder var messages: () -> Messages
    @ViewBuilder var camera: () -> Camera

    var body: some View {
        MainTabOffsetPager(
            selectedTab: $selectedTab,
            feed: feed,
            expenses: expenses,
            friends: friends,
            messages: messages,
            camera: camera
        )
    }
}

private struct MainTabOffsetPager<Feed: View, Expenses: View, Friends: View, Messages: View, Camera: View>: View {
    @Binding var selectedTab: Tab
    @ViewBuilder var feed: () -> Feed
    @ViewBuilder var expenses: () -> Expenses
    @ViewBuilder var friends: () -> Friends
    @ViewBuilder var messages: () -> Messages
    @ViewBuilder var camera: () -> Camera

    @State private var pagerIndex: Int = 0
    @State private var activatedTabs: Set<Tab> = [.feed]
    /// Bumps on every tab request so a deferred slide can be cancelled by a newer tap.
    @State private var transitionGeneration: Int = 0

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let pageCount = CGFloat(Tab.pagerTabs.count)

            ZStack(alignment: .topLeading) {
                HStack(spacing: 0) {
                    tabPage(.feed, width: width, content: feed)
                    tabPage(.expenses, width: width, content: expenses)
                    tabPage(.friends, width: width, content: friends)
                    tabPage(.messages, width: width, content: messages)
                }
                .frame(width: width * pageCount, alignment: .leading)
                .offset(x: -CGFloat(pagerIndex) * width)
                .animation(MainTabPagerMotion.slide, value: pagerIndex)

                if selectedTab == .camera {
                    camera()
                        .frame(width: width)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .zIndex(1)
                }
            }
        }
        .ignoresSafeArea(edges: [.top, .bottom])
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(MainTabPagerMotion.slide, value: selectedTab == .camera)
        .onAppear {
            let initial = selectedTab.isPagerTab ? selectedTab : .feed
            activatedTabs.insert(initial)
            pagerIndex = Tab.pagerTabs.firstIndex(of: initial) ?? 0
            prewarmRemainingTabs()
        }
        .onChange(of: selectedTab) { newTab in
            guard newTab.isPagerTab else { return }
            moveToPagerTab(newTab)
        }
    }

    /// Mount the other pager tabs after first paint so later switches never pay a mount hitch mid-gesture.
    private func prewarmRemainingTabs() {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(400))
            guard activatedTabs.count < Tab.pagerTabs.count else { return }
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                activatedTabs.formUnion(Tab.pagerTabs)
            }
        }
    }

    private func moveToPagerTab(_ newTab: Tab) {
        let idx = Tab.pagerTabs.firstIndex(of: newTab) ?? 0
        guard idx != pagerIndex else {
            activatedTabs.insert(newTab)
            return
        }

        let from = pagerIndex
        let range = min(from, idx)...max(from, idx)
        let needsMount = range.contains { !activatedTabs.contains(Tab.pagerTabs[$0]) }

        transitionGeneration += 1
        let generation = transitionGeneration

        if needsMount {
            // Rare path before prewarm finishes: mount first, slide on the next turn.
            var mountTransaction = Transaction()
            mountTransaction.disablesAnimations = true
            withTransaction(mountTransaction) {
                for i in range {
                    activatedTabs.insert(Tab.pagerTabs[i])
                }
            }
            Task { @MainActor in
                await Task.yield()
                guard generation == transitionGeneration else { return }
                pagerIndex = idx
            }
        } else {
            pagerIndex = idx
        }
    }

    @ViewBuilder
    private func tabPage<T: View>(_ tab: Tab, width: CGFloat, @ViewBuilder content: () -> T) -> some View {
        Group {
            if activatedTabs.contains(tab) {
                content()
                    // Keep tab-switch animation on the pager offset only — not child layout/opacity.
                    .transaction { $0.animation = nil }
            } else {
                // Keep a stable-sized placeholder so HStack geometry stays correct
                // before the tab is visited for the first time.
                Color.clear
            }
        }
        .frame(width: width)
        .frame(maxHeight: .infinity)
        .allowsHitTesting(selectedTab == tab)
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
