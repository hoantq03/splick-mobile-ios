import SwiftUI
import DesignSystem
import SplickDomain
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
                    addFriendUseCase: container.addFriendUseCase,
                    joinGroupUseCase: container.joinGroupUseCase
                )

            case .camera:
                CameraView(
                    viewModel: CameraViewModel(
                        uploadMediaUseCase: container.uploadMediaUseCase
                    )
                )

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
                }

                Spacer()

                SplickButton("Sign Out", style: .destructive) {
                    Task {
                        try? await container.logoutUseCase.execute()
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
        }
    }
}
