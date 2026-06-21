import SwiftUI
import Combine
import PhotosUI
import UIKit
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
    @Environment(\.dismiss) private var dismiss
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

                    accountSettingsGroup
                    personalProfileSettingsGroup
                    appSettingsGroup

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
                AccountClosureSheet(
                    isPresented: Binding(
                        get: { accountClosureAction != nil },
                        set: { if !$0 { accountClosureAction = nil } }
                    ),
                    viewModel: AccountClosureSheetViewModel(
                        action: action,
                        verifyPasswordChangeUseCase: container.verifyPasswordChangeUseCase,
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

            Text("@\(user.username)")
                .font(SplickTheme.Typography.callout)
                .foregroundStyle(SplickTheme.Colors.textSecondary)
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
            RemoteImage(url: url) { phase in
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
                    RemoteImage(url: url) { phase in
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

                    SplickButton(
                        languageService.text(.profileSave),
                        isLoading: isSavingBirthday,
                        isDisabled: isSavingBirthday
                    ) {
                        Task { await saveBirthday() }
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
