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
import FeatureMessaging

struct MainTabView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var container: DependencyContainer
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var tabBarScrollState = TabBarScrollState()
    @State private var badgeCounts: TabBadgeCounts = .zero
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
        selectedTabContent
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear { badgeCounts = container.badgeCountService.counts }
            .onReceive(container.badgeCountService.$counts) { badgeCounts = $0 }
            .onReceive(container.messagingWebSocketClient.eventSubject) { event in
                if case .newMessage = event {
                    Task { await container.badgeCountService.refresh() }
                }
            }
            .environment(\.openProfileSettings) {
                appState.showProfileSettings = true
            }
            .environment(\.openNotifications) {
                appState.showNotifications = true
            }
            .environment(\.notificationUnreadCount, badgeCounts.notifications)
            .environment(\.openPostCaptureFlow) {
                appState.selectedTab = .camera
            }
            .environment(\.openDirectMessage) { friendUserId in
                    await container.getOrCreateConversationId(friendUserId: friendUserId)
                }
            .environment(\.currentUserSummary, currentUserSummary)
            .environment(\.tabBarScrollState, tabBarScrollState)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if appState.selectedTab != .camera {
                    ZStack {
                        SplickTabBar(
                            selectedTab: $appState.selectedTab,
                            badgeCounts: badgeCounts
                        )
                        .equatable()
                        .opacity(tabBarScrollState.isVisible ? 1 : 0)
                        .offset(y: tabBarScrollState.isVisible ? 0 : TabBarLayout.tabBarSlideDistance)
                        .allowsHitTesting(tabBarScrollState.isVisible)
                    }
                    .frame(height: TabBarLayout.floatingClearance)
                    .animation(.easeInOut(duration: 0.28), value: tabBarScrollState.isVisible)
                }
            }
            .onChange(of: appState.selectedTab, perform: handleSelectedTabChange)
        .task(id: scenePhase) {
            switch scenePhase {
            case .active:
                container.badgeCountService.startPolling()
                container.messagingWebSocketClient.connect()
            case .background, .inactive:
                container.badgeCountService.stopPolling()
                container.messagingWebSocketClient.disconnect()
            @unknown default:
                break
            }
        }
        .task {
            await container.badgeCountService.refresh()
        }
        .sheet(isPresented: $appState.showProfileSettings) {
            ProfileSettingsView()
        }
        .sheet(isPresented: $appState.showNotifications) {
            NotificationListView(
                viewModel: container.notificationListViewModel,
                onNavigateToPost: { postId in
                    appState.showNotifications = false
                    appState.openPostFromNotification(postId)
                },
                presentedAsSheet: true
            )
            .environmentObject(container.languageService)
        }
        .tint(SplickTheme.Colors.primaryGradientStart)
    }

    @ViewBuilder
    private var selectedTabContent: some View {
        switch appState.selectedTab {
        case .feed:
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
                pendingPostId: appState.pendingPostId,
                onPendingPostHandled: {
                    appState.clearPendingPostNavigation()
                },
                isTabActive: true
            )

        case .expenses:
            ExpenseListView(
                viewModel: container.expenseListViewModel,
                userSearchUseCase: FriendsUserSearchAdapter(
                    fetchFriendsUseCase: container.fetchFriendsUseCase
                ),
                currentUserId: appState.currentUser?.id
            )

        case .friends:
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

        case .camera:
            PostCaptureFlowView(onDismiss: {
                appState.selectedTab = .feed
            })
            .ignoresSafeArea()

        case .messages:
            ConversationListView(viewModel: container.conversationListViewModel)
            .environmentObject(container.makeChatThreadViewModelFactory(
                currentUserId: appState.currentUser?.id ?? UUID()
            ))

        case .profile:
            EmptyView()
        }
    }

    private func handleSelectedTabChange(_ tab: Tab) {
        Log.debug("Tab selected", category: .ui, metadata: ["tab": tab.rawValue])
        if tab == .camera {
            tabBarScrollState.hide(flushToBottom: true)
        } else {
            tabBarScrollState.reset()
        }
        if tab == .messages || tab == .friends || tab == .expenses {
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
    @State private var myPaymentProfile: PaymentProfile?
    @State private var isLoadingPaymentProfile = false
    @State private var paymentProfileLoadError: String?

    var body: some View {
        NavigationStack {
            ScrollView {
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

                myPaymentProfileSection

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
            .onChange(of: showPaymentProfile) { isShowing in
                if !isShowing {
                    Task { await loadMyPaymentProfile() }
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
                            onProfileChanged: { profile in
                                myPaymentProfile = profile
                                paymentProfileLoadError = nil
                            }
                        )
                    )
                    .environmentObject(languageService)
                }
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
            .sheet(isPresented: $showChangePassword) {
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

    @ViewBuilder
    private var myPaymentProfileSection: some View {
        Group {
            if isLoadingPaymentProfile {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding(.vertical, SplickTheme.Spacing.md)
            } else if let myPaymentProfile {
                PaymentProfileSummaryView(
                    profile: myPaymentProfile,
                    title: languageService.text(.profilePaymentFriendSection)
                )
            } else if let paymentProfileLoadError {
                VStack(alignment: .leading, spacing: SplickTheme.Spacing.xs) {
                    Text(languageService.text(.profilePaymentFriendSection))
                        .font(SplickTheme.Typography.headline)
                    Text(paymentProfileLoadError)
                        .font(SplickTheme.Typography.caption)
                        .foregroundStyle(SplickTheme.Colors.error)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(SplickTheme.Spacing.md)
                .background(SplickTheme.Colors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.medium))
            } else {
                VStack(alignment: .leading, spacing: SplickTheme.Spacing.xs) {
                    Text(languageService.text(.profilePaymentFriendSection))
                        .font(SplickTheme.Typography.headline)
                    Text(languageService.text(.profilePaymentEmptySelf))
                        .font(SplickTheme.Typography.callout)
                        .foregroundStyle(SplickTheme.Colors.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(SplickTheme.Spacing.md)
                .background(SplickTheme.Colors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.medium))
            }
        }
        .padding(.horizontal, SplickTheme.Spacing.xl)
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
        await loadMyPaymentProfile()
    }

    private func loadMyPaymentProfile() async {
        isLoadingPaymentProfile = true
        paymentProfileLoadError = nil
        defer { isLoadingPaymentProfile = false }

        do {
            let profile = try await container.fetchMyPaymentProfileUseCase.execute()
            myPaymentProfile = profile.hasAnyContent ? profile : nil
        } catch NetworkError.notFound {
            myPaymentProfile = nil
        } catch {
            paymentProfileLoadError = error.localizedDescription
        }
    }
}
