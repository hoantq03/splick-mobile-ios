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
            if presentedAsSheet {
                Task {
                    // Defer fetch until panel reveal starts — avoids jank without changing layout.
                    try? await Task.sleep(nanoseconds: 200_000_000)
                    guard viewModel.notifications.isEmpty else { return }
                    await viewModel.load()
                }
            } else {
                guard viewModel.notifications.isEmpty else { return }
                Task { await viewModel.load() }
            }
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
            LazyVStack(alignment: .leading, spacing: SplickTheme.Spacing.sm) {
                ForEach(viewModel.notificationSections) { section in
                    VStack(alignment: .leading, spacing: SplickTheme.Spacing.xxs) {
                        Text(languageService.text(section.section.l10nKey))
                            .font(SplickTheme.Typography.captionBold)
                            .foregroundStyle(SplickTheme.Colors.textSecondary)
                            .textCase(nil)
                            .padding(.top, SplickTheme.Spacing.xxs)

                        ForEach(section.notifications) { notification in
                            NotificationRowView(notification: notification)
                                .onTapGesture {
                                    Task {
                                        let target = await viewModel.handleTap(notification)
                                        onNavigate?(target)
                                    }
                                }
                                .onAppear {
                                    Task { await viewModel.loadMoreIfNeeded(current: notification) }
                                }
                        }
                    }
                }

                if viewModel.isLoadingMore {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, SplickTheme.Spacing.md)
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
                        .font(SplickTheme.Typography.headline)
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

                NotificationBodyText(notification: notification)
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
    private let badgeSize: CGFloat = 28

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            avatarContent
                .frame(width: avatarSize, height: avatarSize)
                .clipShape(Circle())

            Image(systemName: notification.type.icon)
                .font(.system(size: 14, weight: .bold))
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
                        .strokeBorder(Color.white, lineWidth: 2)
                }
                .offset(x: 2, y: 2)
        }
        .frame(width: avatarSize + 4, height: avatarSize + 4)
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

private struct NotificationBodyText: View {
    let notification: AppNotification

    private var segments: (actorName: String?, remainder: String) {
        NotificationActorPresentation.bodySegments(for: notification)
    }

    private var titleMatchesActorName: Bool {
        guard let actorName = segments.actorName else { return false }
        return notification.title.trimmingCharacters(in: .whitespacesAndNewlines)
            .caseInsensitiveCompare(actorName) == .orderedSame
    }

    var body: some View {
        if titleMatchesActorName, !segments.remainder.isEmpty {
            bodyText(segments.remainder)
        } else if let actorName = segments.actorName, !actorName.isEmpty {
            VStack(alignment: .leading, spacing: SplickTheme.Spacing.xxxs) {
                Text(actorName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(SplickTheme.Colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if !segments.remainder.isEmpty {
                    bodyText(segments.remainder)
                }
            }
        } else {
            MentionText(
                notification.body,
                fontSize: 13,
                plainColor: SplickTheme.Colors.textSecondary
            )
        }
    }

    private func bodyText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundColor(SplickTheme.Colors.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .multilineTextAlignment(.leading)
    }
}
