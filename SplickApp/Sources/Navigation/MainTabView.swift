import SwiftUI
import DesignSystem
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
    @StateObject private var tabBarScrollState = TabBarScrollState()

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
        Group {
            switch appState.selectedTab {
            case .feed:
                FeedView(
                    viewModel: FeedViewModel(
                        fetchFeedUseCase: container.fetchFeedUseCase,
                        reactToPostUseCase: container.reactToPostUseCase,
                        deletePostUseCase: container.deletePostUseCase,
                        currentUserId: appState.currentUser?.id,
                        currentUser: currentUserSummary
                    ),
                    fetchFriendsUseCase: container.fetchFriendsUseCase
                )

            case .expenses:
                ExpenseListView(
                    viewModel: ExpenseListViewModel(
                        fetchExpensesUseCase: container.fetchExpensesUseCase,
                        fetchDebtSummaryUseCase: container.fetchDebtSummaryUseCase,
                        currentUserId: appState.currentUser?.id
                    ),
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
                    revokeGroupQrUseCase: container.revokeGroupQrUseCase
                )

            case .camera:
                PostCaptureFlowView(onDismiss: {
                    appState.selectedTab = .feed
                })

            case .notifications:
                NotificationListView(
                    viewModel: NotificationListViewModel(
                        fetchNotificationsUseCase: container.fetchNotificationsUseCase,
                        markReadUseCase: container.markNotificationReadUseCase
                    )
                )

            case .profile:
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea(edges: .bottom)
        .modifier(FloatingTabBarContentPadding())
        .environment(\.openProfileSettings) {
            appState.showProfileSettings = true
        }
        .environment(\.openPostCaptureFlow) {
            appState.selectedTab = .camera
        }
        .environment(\.currentUserSummary, currentUserSummary)
        .environment(\.tabBarScrollState, tabBarScrollState)
        .overlay(alignment: .bottom) {
            SplickTabBar(selectedTab: $appState.selectedTab)
                .offset(y: tabBarScrollState.isVisible ? 0 : TabBarLayout.tabBarSlideDistance)
                .opacity(tabBarScrollState.isVisible ? 1 : 0)
                .animation(.easeInOut(duration: 0.28), value: tabBarScrollState.isVisible)
                .allowsHitTesting(tabBarScrollState.isVisible)
        }
        .onChange(of: appState.selectedTab) { tab in
            tabBarScrollState.reset()
            if tab == .camera {
                tabBarScrollState.show()
            }
        }
        .sheet(isPresented: $appState.showProfileSettings) {
            ProfileSettingsView()
        }
        .tint(SplickTheme.Colors.primaryGradientStart)
    }
}

struct ProfileSettingsView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var container: DependencyContainer
    @Environment(\.dismiss) private var dismiss
    @State private var isSigningOut = false
    @State private var isRefreshingProfile = false
    @State private var profileError: String?
    @State private var showChangePassword = false
    @State private var showSessions = false
    @State private var showConnectedAccounts = false
    @State private var showAccountSecurity = false
    @State private var showEditProfile = false

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
                    "Edit profile",
                    style: .secondary,
                    isDisabled: appState.currentUser == nil
                ) {
                    showEditProfile = true
                }
                .padding(.horizontal, SplickTheme.Spacing.xl)

                SplickButton(
                    "Change password",
                    style: .secondary,
                    isDisabled: appState.currentUser == nil
                ) {
                    showChangePassword = true
                }
                .padding(.horizontal, SplickTheme.Spacing.xl)

                SplickButton("Devices & sessions", style: .secondary) {
                    showSessions = true
                }
                .padding(.horizontal, SplickTheme.Spacing.xl)

                SplickButton("Connected accounts", style: .secondary) {
                    showConnectedAccounts = true
                }
                .padding(.horizontal, SplickTheme.Spacing.xl)

                SplickButton("Deactivate or delete account", style: .secondary) {
                    showAccountSecurity = true
                }
                .padding(.horizontal, SplickTheme.Spacing.xl)

                Spacer()

                SplickButton(
                    "Sign Out",
                    style: .destructive,
                    isLoading: isSigningOut,
                    isDisabled: isSigningOut
                ) {
                    Task {
                        isSigningOut = true
                        defer { isSigningOut = false }
                        await container.logoutUseCase.execute()
                        appState.setUnauthenticated()
                        dismiss()
                    }
                }
                .padding(.horizontal, SplickTheme.Spacing.xl)
            }
            .padding(.top, SplickTheme.Spacing.xxl)
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .refreshable {
                await refreshProfile()
            }
            .task {
                await refreshProfile()
            }
            .navigationDestination(isPresented: $showEditProfile) {
                if let user = appState.currentUser {
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
                        }
                    )
                }
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
                            appState.setUnauthenticated()
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
                            appState.setUnauthenticated()
                            dismiss()
                        }
                    )
                }
            }
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
        } catch {
            profileError = "Could not refresh profile."
        }
    }
}
