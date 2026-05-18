import SwiftUI
import DesignSystem
import SplickDomain
import FeatureSocialFeed
import FeatureExpense
import FeatureMedia
import FeatureNotification

struct MainTabView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var container: DependencyContainer

    var body: some View {
        TabView(selection: $appState.selectedTab) {
            FeedView(
                viewModel: FeedViewModel(
                    fetchFeedUseCase: container.fetchFeedUseCase,
                    reactToPostUseCase: container.reactToPostUseCase,
                    deletePostUseCase: container.deletePostUseCase,
                    currentUserId: appState.currentUser?.id,
                    currentUser: appState.currentUser.map {
                        UserSummary(
                            id: $0.id,
                            username: $0.username,
                            displayName: $0.displayName,
                            avatarURL: $0.avatarURL
                        )
                    }
                ),
                fetchFriendsUseCase: container.fetchFriendsUseCase
            )
            .tabItem {
                Label(Tab.feed.rawValue, systemImage: appState.selectedTab == .feed ? Tab.feed.selectedIcon : Tab.feed.icon)
            }
            .tag(Tab.feed)

            ExpenseListView(
                viewModel: ExpenseListViewModel(
                    fetchExpensesUseCase: container.fetchExpensesUseCase,
                    fetchDebtSummaryUseCase: container.fetchDebtSummaryUseCase
                )
            )
            .tabItem {
                Label(Tab.expenses.rawValue, systemImage: appState.selectedTab == .expenses ? Tab.expenses.selectedIcon : Tab.expenses.icon)
            }
            .tag(Tab.expenses)

            CameraView(
                viewModel: CameraViewModel(
                    uploadMediaUseCase: container.uploadMediaUseCase
                )
            )
            .tabItem {
                Label(Tab.camera.rawValue, systemImage: appState.selectedTab == .camera ? Tab.camera.selectedIcon : Tab.camera.icon)
            }
            .tag(Tab.camera)

            NotificationListView(
                viewModel: NotificationListViewModel(
                    fetchNotificationsUseCase: container.fetchNotificationsUseCase,
                    markReadUseCase: container.markNotificationReadUseCase
                )
            )
            .tabItem {
                Label(Tab.notifications.rawValue, systemImage: appState.selectedTab == .notifications ? Tab.notifications.selectedIcon : Tab.notifications.icon)
            }
            .tag(Tab.notifications)

            ProfilePlaceholderView()
                .tabItem {
                    Label(Tab.profile.rawValue, systemImage: appState.selectedTab == .profile ? Tab.profile.selectedIcon : Tab.profile.icon)
                }
                .tag(Tab.profile)
        }
        .tint(SplickTheme.Colors.primaryGradientStart)
    }
}

struct ProfilePlaceholderView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var container: DependencyContainer

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
                    }
                }
                .padding(.horizontal, SplickTheme.Spacing.xl)
            }
            .padding(.top, SplickTheme.Spacing.xxl)
            .navigationTitle("Profile")
        }
    }
}
