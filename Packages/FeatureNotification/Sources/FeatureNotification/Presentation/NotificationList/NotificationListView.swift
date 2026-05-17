import SwiftUI
import DesignSystem
import Common
import SplickDomain

public struct NotificationListView: View {
    @StateObject private var viewModel: NotificationListViewModel

    public init(viewModel: @autoclosure @escaping () -> NotificationListViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel())
    }

    public var body: some View {
        NavigationStack {
            Group {
                switch viewModel.state {
                case .idle, .loading:
                    LoadingView(message: "Loading notifications...")

                case .loaded(let items) where items.isEmpty:
                    EmptyStateView(
                        icon: "bell.slash",
                        title: "No Notifications",
                        message: "You're all caught up! Notifications will appear here."
                    )

                case .loaded:
                    notificationList

                case .failed(let message):
                    ErrorView(message: message) {
                        Task { await viewModel.load() }
                    }
                }
            }
            .navigationTitle("Notifications")
            .toolbar {
                if viewModel.unreadCount > 0 {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Read All") {
                            Task { await viewModel.markAllAsRead() }
                        }
                        .font(SplickTheme.Typography.callout)
                    }
                }
            }
            .refreshable { await viewModel.load() }
        }
        .onFirstAppear {
            Task { await viewModel.load() }
        }
    }

    private var notificationList: some View {
        ScrollView {
            LazyVStack(spacing: SplickTheme.Spacing.xxs) {
                ForEach(viewModel.notifications) { notification in
                    NotificationRowView(notification: notification)
                        .onTapGesture {
                            Task { await viewModel.markAsRead(notification) }
                        }
                }
            }
            .padding(.horizontal, SplickTheme.Spacing.md)
        }
    }
}

struct NotificationRowView: View {
    let notification: AppNotification

    var body: some View {
        HStack(alignment: .top, spacing: SplickTheme.Spacing.sm) {
            Image(systemName: notification.type.icon)
                .font(.title3)
                .foregroundStyle(notification.isRead ? SplickTheme.Colors.textTertiary : SplickTheme.Colors.primaryGradientStart)
                .frame(width: 36, height: 36)
                .background(
                    (notification.isRead ? SplickTheme.Colors.textTertiary : SplickTheme.Colors.primaryGradientStart)
                        .opacity(0.1)
                )
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: SplickTheme.Spacing.xxxs) {
                Text(notification.title)
                    .font(notification.isRead ? SplickTheme.Typography.callout : SplickTheme.Typography.headline)
                    .foregroundStyle(SplickTheme.Colors.textPrimary)

                Text(notification.body)
                    .font(SplickTheme.Typography.caption)
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
                    .lineLimit(2)

                Text(notification.createdAt.relativeString)
                    .font(SplickTheme.Typography.caption)
                    .foregroundStyle(SplickTheme.Colors.textTertiary)
            }

            Spacer()

            if !notification.isRead {
                Circle()
                    .fill(SplickTheme.Colors.primaryGradientStart)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(SplickTheme.Spacing.sm)
        .background(notification.isRead ? Color.clear : SplickTheme.Colors.primaryGradientStart.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.small))
    }
}
