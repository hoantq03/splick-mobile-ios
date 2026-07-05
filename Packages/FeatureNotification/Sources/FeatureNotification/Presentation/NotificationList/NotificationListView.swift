import SwiftUI
import DesignSystem
import Common
import Localization
import SplickDomain

public struct NotificationListView: View {
    @ObservedObject private var viewModel: NotificationListViewModel
    @EnvironmentObject private var languageService: LanguageService
    @Environment(\.dismiss) private var dismiss
    private let onNavigate: ((NotificationNavigationTarget) -> Void)?
    private let onDismiss: (() -> Void)?
    private let presentedAsSheet: Bool

    @State private var refreshController = SplickRefreshController()

    public init(
        viewModel: NotificationListViewModel,
        onNavigate: ((NotificationNavigationTarget) -> Void)? = nil,
        onNavigateToPost: ((UUID) -> Void)? = nil,
        onDismiss: (() -> Void)? = nil,
        presentedAsSheet: Bool = false
    ) {
        self._viewModel = ObservedObject(wrappedValue: viewModel)
        if let onNavigate {
            self.onNavigate = onNavigate
        } else if let onNavigateToPost {
            self.onNavigate = { target in
                if case .post(let postId) = target {
                    onNavigateToPost(postId)
                }
            }
        } else {
            self.onNavigate = nil
        }
        self.onDismiss = onDismiss
        self.presentedAsSheet = presentedAsSheet
    }

    public var body: some View {
        Group {
            if presentedAsSheet {
                overlayBody
            } else {
                NavigationStack {
                    listContent
                        .splickProfileToolbar(titleDisplayMode: .inline)
                        .toolbar {
                            if viewModel.unreadCount > 0 {
                                ToolbarItem(placement: .primaryAction) {
                                    markAllReadButton
                                }
                            }
                        }
                }
            }
        }
        .onFirstAppear {
            guard viewModel.notifications.isEmpty else { return }
            Task { await viewModel.load() }
        }
    }

    private var overlayBody: some View {
        VStack(spacing: 0) {
            overlayHeader
            listContent
        }
    }

    private var overlayHeader: some View {
        HStack(spacing: SplickTheme.Spacing.sm) {
            Spacer(minLength: 0)

            if viewModel.unreadCount > 0 {
                markAllReadButton
            }
        }
        .padding(.horizontal, SplickTheme.Spacing.md)
        .padding(.bottom, SplickTheme.Spacing.xxs)
    }

    private var markAllReadButton: some View {
        Button(languageService.text(.notificationReadAll)) {
            Task { await viewModel.markAllAsRead() }
        }
        .font(SplickTheme.Typography.callout)
    }

    @ViewBuilder
    private var listContent: some View {
        if case .failed(let message) = viewModel.state, viewModel.notifications.isEmpty {
            ErrorView(message: message) {
                Task { await viewModel.load() }
            }
        } else if viewModel.showsInitialLoading {
            LoadingView(message: languageService.text(.notificationLoading))
        } else if viewModel.notifications.isEmpty {
            EmptyStateView(
                icon: "bell.slash",
                title: languageService.text(.notificationEmptyTitle),
                message: languageService.text(.notificationEmptyMessage)
            )
        } else {
            notificationList
        }
    }

    private var notificationList: some View {
        ScrollView {
            LazyVStack(spacing: SplickTheme.Spacing.xxs) {
                ForEach(viewModel.notifications) { notification in
                    NotificationRowView(notification: notification)
                        .onTapGesture {
                            Task {
                                let target = await viewModel.handleTap(notification)
                                onNavigate?(target)
                            }
                        }
                }
            }
            .padding(.horizontal, SplickTheme.Spacing.md)
            .padding(.vertical, SplickTheme.Spacing.xs)
        }
        .tabBarHideOnScroll()
        .splickNativeRefreshable(controller: refreshController) {
            await viewModel.load(isPullToRefresh: true)
        }
    }
}

struct NotificationRowView: View {
    let notification: AppNotification

    var body: some View {
        HStack(alignment: .top, spacing: SplickTheme.Spacing.sm) {
            NotificationAvatarBadgeView(notification: notification)

            VStack(alignment: .leading, spacing: SplickTheme.Spacing.xxxs) {
                HStack(alignment: .firstTextBaseline, spacing: SplickTheme.Spacing.xxs) {
                    Text(notification.title)
                        .font(notification.isRead ? SplickTheme.Typography.callout : SplickTheme.Typography.headline)
                        .foregroundStyle(SplickTheme.Colors.textPrimary)
                        .lineLimit(2)

                    Spacer(minLength: 0)

                    if !notification.isRead {
                        Circle()
                            .fill(SplickTheme.Colors.primaryGradientStart)
                            .frame(width: 8, height: 8)
                            .padding(.top, 4)
                    }
                }

                MentionText(
                    notification.body,
                    fontSize: 13,
                    plainColor: SplickTheme.Colors.textSecondary
                )
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)

                Text(notification.createdAt.relativeString)
                    .font(SplickTheme.Typography.caption)
                    .foregroundStyle(SplickTheme.Colors.textTertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(SplickTheme.Spacing.sm)
        .background(
            notification.isRead
                ? Color.clear
                : SplickTheme.Colors.primaryGradientStart.opacity(0.04)
        )
        .clipShape(RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.small, style: .continuous))
    }
}

private struct NotificationAvatarBadgeView: View {
    let notification: AppNotification

    private let avatarSize: CGFloat = 48
    private let badgeSize: CGFloat = 20

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            avatarContent
                .frame(width: avatarSize, height: avatarSize)
                .clipShape(Circle())

            Image(systemName: notification.type.icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: badgeSize, height: badgeSize)
                .background(
                    Circle()
                        .fill(
                            notification.isRead
                                ? SplickTheme.Colors.textTertiary
                                : SplickTheme.Colors.primaryGradientStart
                        )
                )
                .overlay {
                    Circle()
                        .strokeBorder(Color.white, lineWidth: 1.5)
                }
                .offset(x: 2, y: 2)
        }
        .frame(width: avatarSize, height: avatarSize)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var avatarContent: some View {
        if NotificationActorPresentation.usesSystemAvatar(for: notification.type) {
            ZStack {
                SplickTheme.Colors.secondaryBackground
                SplickLogoMark(size: 28, style: .fullColor)
            }
        } else {
            AvatarView(
                name: NotificationActorPresentation.actorDisplayName(for: notification),
                size: .medium,
                userId: notification.actorUserId
            )
        }
    }
}
