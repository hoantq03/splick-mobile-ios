import SwiftUI
import Combine
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

struct MainTabView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var container: DependencyContainer
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var tabBarScrollState = TabBarScrollState()
    @State private var badgeCounts: TabBadgeCounts = .zero
    /// Tabs instantiated at least once — avoids keeping every root view in memory on older devices.
    @State private var mountedTabs: Set<Tab> = [.feed]
    @State private var badgeRefreshTask: Task<Void, Never>?

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

    var body: some View {
        ZStack {
            keptTabContent
            cameraTabContent
        }
        .onAppear { badgeCounts = container.badgeCountService.counts }
        .onReceive(container.badgeCountService.$counts) { badgeCounts = $0 }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea(edges: .bottom)
        .modifier(FloatingTabBarContentPadding(isEnabled: appState.selectedTab != .camera))
        .environment(\.openProfileSettings) {
            appState.showProfileSettings = true
        }
        .environment(\.openPostCaptureFlow) {
            appState.selectedTab = .camera
        }
        .environment(\.currentUserSummary, currentUserSummary)
        .environment(\.tabBarScrollState, tabBarScrollState)
        .overlay(alignment: .bottom) {
            if appState.selectedTab != .camera {
                SplickTabBar(
                    selectedTab: $appState.selectedTab,
                    badgeCounts: badgeCounts,
                    tabBarIsVisible: tabBarScrollState.isVisible
                )
                    .equatable()
                    .offset(y: tabBarScrollState.isVisible ? 0 : TabBarLayout.tabBarSlideDistance)
                    .opacity(tabBarScrollState.isVisible ? 1 : 0)
                    .modifier(TabBarVisibilityAnimationModifier(isVisible: tabBarScrollState.isVisible))
                    .allowsHitTesting(tabBarScrollState.isVisible)
                    .zIndex(50)
            }
        }
        .onChange(of: appState.selectedTab, perform: handleSelectedTabChange)
        .task(id: scenePhase) {
            switch scenePhase {
            case .active:
                container.badgeCountService.startPolling()
            case .background, .inactive:
                container.badgeCountService.stopPolling()
            @unknown default:
                break
            }
        }
        .task {
            await container.badgeCountService.refresh()
            if scenePhase == .active {
                container.badgeCountService.startPolling()
            }
        }
        .sheet(isPresented: $appState.showProfileSettings) {
            ProfileSettingsView()
        }
        .tint(SplickTheme.Colors.primaryGradientStart)
    }

    // Keep tab roots alive so switching tabs does not tear down heavy SwiftUI trees (iPhone 11).
    @ViewBuilder
    private var keptTabContent: some View {
        ZStack {
            feedTabRoot
            expensesTabRoot
            friendsTabRoot
            notificationsTabRoot
        }
    }

    @ViewBuilder
    private var cameraTabContent: some View {
        if appState.selectedTab == .camera {
            PostCaptureFlowView(onDismiss: {
                appState.selectedTab = .feed
            })
            .ignoresSafeArea()
        }
    }

    @ViewBuilder
    private var feedTabRoot: some View {
        if mountedTabs.contains(.feed) {
            FeedView(
                viewModel: container.feedViewModel,
                photoAlbumViewModel: container.photoAlbumViewModel,
                fetchFriendsUseCase: container.fetchFriendsUseCase,
                fetchMyFriendsUseCase: container.fetchMyFriendsUseCase,
                fetchMyGroupsUseCase: container.fetchMyGroupsUseCase,
                profileDependencies: container.friendUserProfileDependencies,
                navigationPath: $appState.feedNavigationPath,
                pendingPostId: appState.pendingPostId,
                onPendingPostHandled: {
                    appState.clearPendingPostNavigation()
                },
                isTabActive: appState.selectedTab == .feed
            )
            .opacity(appState.selectedTab == .feed ? 1 : 0)
            .allowsHitTesting(appState.selectedTab == .feed)
            .accessibilityHidden(appState.selectedTab != .feed)
        }
    }

    @ViewBuilder
    private var expensesTabRoot: some View {
        if mountedTabs.contains(.expenses) {
            ExpenseListView(
                viewModel: container.expenseListViewModel,
                userSearchUseCase: FriendsUserSearchAdapter(
                    fetchFriendsUseCase: container.fetchFriendsUseCase
                ),
                currentUserId: appState.currentUser?.id
            )
            .opacity(appState.selectedTab == .expenses ? 1 : 0)
            .allowsHitTesting(appState.selectedTab == .expenses)
            .accessibilityHidden(appState.selectedTab != .expenses)
        }
    }

    @ViewBuilder
    private var friendsTabRoot: some View {
        if mountedTabs.contains(.friends) {
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
            onBadgeCountsChanged: { await container.badgeCountService.refresh() }
            )
            .opacity(appState.selectedTab == .friends ? 1 : 0)
            .allowsHitTesting(appState.selectedTab == .friends)
            .accessibilityHidden(appState.selectedTab != .friends)
        }
    }

    @ViewBuilder
    private var notificationsTabRoot: some View {
        if mountedTabs.contains(.notifications) {
            NotificationListView(
                viewModel: container.notificationListViewModel,
                onNavigateToPost: { postId in
                    appState.openPostFromNotification(postId)
                }
            )
            .opacity(appState.selectedTab == .notifications ? 1 : 0)
            .allowsHitTesting(appState.selectedTab == .notifications)
            .accessibilityHidden(appState.selectedTab != .notifications)
        }
    }

    private func handleSelectedTabChange(_ tab: Tab) {
        if tab != .camera && tab != .profile {
            mountedTabs.insert(tab)
        }
        Log.debug("Tab selected", category: .ui, metadata: ["tab": tab.rawValue])
        if tab == .camera {
            tabBarScrollState.hide(flushToBottom: true)
        } else {
            tabBarScrollState.reset()
        }
        if tab == .notifications || tab == .friends || tab == .expenses {
            scheduleBadgeRefresh()
        }
    }

    private func scheduleBadgeRefresh() {
        badgeRefreshTask?.cancel()
        badgeRefreshTask = Task {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            await container.badgeCountService.refresh()
        }
    }
}

/// Tab bar slide animation only on iOS 26+; older devices use instant updates for responsiveness.
private struct TabBarVisibilityAnimationModifier: ViewModifier {
    let isVisible: Bool

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.animation(.easeInOut(duration: 0.28), value: isVisible)
        } else {
            content
        }
    }
}

struct ProfileSettingsView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var container: DependencyContainer
    @EnvironmentObject private var languageService: LanguageService
    @Environment(\.dismiss) private var dismiss
    @State private var isSigningOut = false
    @State private var isRefreshingProfile = false
    @State private var isUpdatingLanguage = false
    @State private var profileError: String?
    @State private var showChangePassword = false
    @State private var showSessions = false
    @State private var showConnectedAccounts = false
    @State private var showAccountSecurity = false
    @State private var showEditProfile = false
    @State private var showPaymentProfile = false

    var body: some View {
        NavigationStack {
            VStack(spacing: SplickTheme.Spacing.lg) {
                if let user = appState.currentUser {
                    AvatarView(imageURL: user.avatarURL, name: user.displayName, size: .large)

                    Text(user.displayName)
                        .font(SplickTheme.Typography.title)

                    Text("@\(user.username)")
                        .font(SplickTheme.Typography.callout)
                        .foregroundStyle(SplickTheme.Colors.textSecondary)

                    Text(user.email)
                        .font(SplickTheme.Typography.caption)
                        .foregroundStyle(SplickTheme.Colors.textSecondary)
                }

                if let profileError {
                    Text(profileError)
                        .font(SplickTheme.Typography.caption)
                        .foregroundStyle(SplickTheme.Colors.error)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                SplickButton(
                    languageService.text(.profileEdit),
                    style: .secondary,
                    isDisabled: appState.currentUser == nil
                ) {
                    showEditProfile = true
                }
                .padding(.horizontal, SplickTheme.Spacing.xl)

                SplickButton(
                    languageService.text(.profilePaymentManage),
                    style: .secondary,
                    isDisabled: appState.currentUser == nil
                ) {
                    showPaymentProfile = true
                }
                .padding(.horizontal, SplickTheme.Spacing.xl)

                languageSection

                SplickButton(
                    languageService.text(.profileChangePassword),
                    style: .secondary,
                    isDisabled: appState.currentUser == nil
                ) {
                    showChangePassword = true
                }
                .padding(.horizontal, SplickTheme.Spacing.xl)

                SplickButton(languageService.text(.profileDevicesSessions), style: .secondary) {
                    showSessions = true
                }
                .padding(.horizontal, SplickTheme.Spacing.xl)

                SplickButton(languageService.text(.profileConnectedAccounts), style: .secondary) {
                    showConnectedAccounts = true
                }
                .padding(.horizontal, SplickTheme.Spacing.xl)

                SplickButton(languageService.text(.profileDeactivateDelete), style: .secondary) {
                    showAccountSecurity = true
                }
                .padding(.horizontal, SplickTheme.Spacing.xl)

                Spacer()

                SplickButton(
                    languageService.text(.profileSignOut),
                    style: .destructive,
                    isLoading: isSigningOut,
                    isDisabled: isSigningOut
                ) {
                    Task {
                        isSigningOut = true
                        defer { isSigningOut = false }
                        await container.logoutUseCase.execute()
                        appState.setUnauthenticated(container: container)
                        dismiss()
                    }
                }
                .padding(.horizontal, SplickTheme.Spacing.xl)
            }
            .padding(.top, SplickTheme.Spacing.xxl)
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
            .sheet(isPresented: $showEditProfile) {
                if let user = appState.currentUser {
                    NavigationStack {
                        EditProfileView(
                            viewModel: EditProfileViewModel(
                                user: user,
                                updateProfileUseCase: container.updateProfileUseCase,
                                uploadAvatar: { image in
                                    let result = try await container.uploadUserAvatarUseCase.execute(image: image)
                                    return result.url
                                }
                            ),
                            onProfileUpdated: { updated in
                                appState.updateAuthenticatedUser(updated)
                                showEditProfile = false
                            }
                        )
                    }
                }
            }
            .navigationDestination(isPresented: $showPaymentProfile) {
                PaymentProfileManageView(
                    viewModel: PaymentProfileManageViewModel(
                        fetchMyPaymentProfileUseCase: container.fetchMyPaymentProfileUseCase,
                        upsertMyPaymentProfileUseCase: container.upsertMyPaymentProfileUseCase,
                        deleteMyPaymentProfileUseCase: container.deleteMyPaymentProfileUseCase,
                        uploadPaymentQr: { image in
                            let result = try await container.uploadPaymentQrUseCase.execute(image: image)
                            return result.url
                        }
                    )
                )
            }
            .navigationDestination(isPresented: $showChangePassword) {
                if let email = appState.currentUser?.email {
                    ChangePasswordView(
                        viewModel: ChangePasswordViewModel(
                            accountEmail: email,
                            changePasswordUseCase: container.changePasswordUseCase,
                            requestEmailOtpUseCase: container.requestEmailOtpUseCase
                        ),
                        onPasswordChanged: { user in
                            appState.updateAuthenticatedUser(user)
                        }
                    )
                }
            }
            .navigationDestination(isPresented: $showSessions) {
                SessionsView(
                    viewModel: SessionsViewModel(
                        listSessionsUseCase: container.listSessionsUseCase,
                        revokeSessionUseCase: container.revokeSessionUseCase,
                        revokeAllSessionsUseCase: container.revokeAllSessionsUseCase,
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
                            googleSignInPresenter: GoogleSignInClient.shared
                        )
                    )
                }
            }
            .navigationDestination(isPresented: $showAccountSecurity) {
                if let email = appState.currentUser?.email {
                    AccountSecurityView(
                        accountEmail: email,
                        requestEmailOtpUseCase: container.requestEmailOtpUseCase,
                        deactivateAccountUseCase: container.deactivateAccountUseCase,
                        deleteAccountUseCase: container.deleteAccountUseCase,
                        onAccountClosed: {
                            appState.setUnauthenticated(container: container)
                            dismiss()
                        }
                    )
                }
            }
        }
    }

    private var languageSection: some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.sm) {
            Text(languageService.text(.profileLanguage))
                .font(SplickTheme.Typography.caption)
                .foregroundStyle(SplickTheme.Colors.textSecondary)
                .padding(.horizontal, SplickTheme.Spacing.xl)

            Picker(languageService.text(.profileLanguage), selection: Binding(
                get: { languageService.locale },
                set: { newLocale in
                    Task { await updateLanguage(newLocale) }
                }
            )) {
                ForEach(AppLocale.allCases) { locale in
                    Text(languageService.text(locale.displayNameKey)).tag(locale)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, SplickTheme.Spacing.xl)
            .disabled(isUpdatingLanguage || appState.currentUser == nil)
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
