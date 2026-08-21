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
                listContent
            } else {
                NavigationStack {
                    listContent
                        .navigationTitle(languageService.text(.notificationTitle))
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                if viewModel.unreadCount > 0 {
                                    markAllReadButton
                                }
                            }
                            ToolbarItem(placement: .topBarTrailing) {
                                Button {
                                    if let onDismiss {
                                        onDismiss()
                                    } else {
                                        dismiss()
                                    }
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(SplickTheme.Colors.textPrimary)
                                        .frame(width: 34, height: 34)
                                        .background(Circle().fill(SplickTheme.Colors.secondaryBackground.opacity(0.85)))
                                }
                                .accessibilityLabel(languageService.text(.notificationBellAccessibility))
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

    private var markAllReadButton: some View {
        Button(languageService.text(.notificationReadAll)) {
            Task { await viewModel.markAllAsRead() }
        }
        .font(SplickTheme.Typography.callout)
        .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
    }

    @ViewBuilder
    private var listContent: some View {
        VStack(spacing: 0) {
            categoryFilterBar
            Group {
                if case .failed(let message) = viewModel.state, viewModel.notifications.isEmpty {
                    ErrorView(message: message) {
                        Task { await viewModel.load() }
                    }
                } else if viewModel.showsInitialLoading {
                    LoadingView(message: languageService.text(.notificationLoading))
                } else if viewModel.notifications.isEmpty {
                    EmptyStateView(
                        icon: "bell.slash",
                        title: languageService.text(
                            viewModel.selectedCategory == .all
                                ? .notificationEmptyTitle
                                : .notificationFilterEmptyTitle
                        ),
                        message: languageService.text(
                            viewModel.selectedCategory == .all
                                ? .notificationEmptyMessage
                                : .notificationFilterEmptyMessage
                        )
                    )
                } else {
                    notificationList
                }
            }
        }
    }

    private var categoryFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: SplickTheme.Spacing.sm) {
                ForEach(NotificationListCategory.allCases, id: \.self) { category in
                    categoryChip(category)
                }
            }
            .padding(.horizontal, SplickTheme.Spacing.md)
            .padding(.vertical, SplickTheme.Spacing.sm)
        }
    }

    private func categoryChip(_ category: NotificationListCategory) -> some View {
        let selected = viewModel.selectedCategory == category
        return Button {
            Task { await viewModel.selectCategory(category) }
        } label: {
            Text(categoryTitle(category))
                .font(.system(size: 13, weight: selected ? .semibold : .medium))
                .foregroundStyle(
                    selected
                        ? SplickTheme.Colors.primaryGradientStart
                        : SplickTheme.Colors.textPrimary
                )
                .padding(.horizontal, SplickTheme.Spacing.md)
                .padding(.vertical, SplickTheme.Spacing.sm)
                .background(
                    Capsule(style: .continuous)
                        .fill(
                            selected
                                ? SplickTheme.Colors.primaryGradientStart.opacity(0.12)
                                : SplickTheme.Colors.secondaryBackground
                        )
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(categoryTitle(category))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func categoryTitle(_ category: NotificationListCategory) -> String {
        switch category {
        case .all: return languageService.text(.notificationFilterAll)
        case .expenses: return languageService.text(.notificationFilterExpenses)
        case .friends: return languageService.text(.notificationFilterFriends)
        case .posts: return languageService.text(.notificationFilterPosts)
        }
    }

    private var notificationList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: SplickTheme.Spacing.sm) {
                ForEach(viewModel.notificationSections) { section in
                    VStack(alignment: .leading, spacing: SplickTheme.Spacing.xxs) {
                        Text(languageService.text(section.section.l10nKey))
                            .font(SplickTheme.Typography.captionBold)
                            .foregroundColor(SplickTheme.Colors.textSecondary)
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

    private var bodySegments: (actorName: String?, remainder: String) {
        NotificationActorPresentation.bodySegments(for: notification)
    }

    private var titleMatchesActorName: Bool {
        guard let actorName = bodySegments.actorName else { return false }
        return notification.title.trimmingCharacters(in: .whitespacesAndNewlines)
            .caseInsensitiveCompare(actorName) == .orderedSame
    }

    private var showsCategoryTitle: Bool {
        !notification.title.isEmpty && !titleMatchesActorName
    }

    var body: some View {
        HStack(alignment: .center, spacing: SplickTheme.Spacing.sm) {
            NotificationAvatarBadgeView(notification: notification)

            VStack(alignment: .leading, spacing: SplickTheme.Spacing.xxxs) {
                if showsCategoryTitle {
                    Text(notification.title)
                        .font(SplickTheme.Typography.headline)
                        .foregroundColor(SplickTheme.Colors.textPrimary)
                        .lineLimit(1)
                }

                HStack(alignment: .center, spacing: SplickTheme.Spacing.xxs) {
                    NotificationInlineBodyText(notification: notification)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if !notification.isRead {
                        Circle()
                            .fill(SplickTheme.Colors.primaryGradientStart)
                            .frame(width: 8, height: 8)
                    }
                }

                Text(notification.createdAt.relativeString)
                    .font(SplickTheme.Typography.caption)
                    .foregroundColor(SplickTheme.Colors.textTertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(SplickTheme.Spacing.sm)
        .background {
            RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.card, style: .continuous)
                .fill(
                    notification.isRead
                        ? Color.clear
                        : SplickTheme.Colors.primaryGradientStart.opacity(0.08)
                )
        }
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
                .foregroundColor(.white)
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
                imageURL: notification.actorAvatarURL,
                name: NotificationActorPresentation.actorDisplayName(for: notification),
                size: .medium,
                userId: notification.actorUserId
            )
        }
    }
}

private struct NotificationInlineBodyText: View {
    let notification: AppNotification

    private var segments: (actorName: String?, remainder: String) {
        NotificationActorPresentation.bodySegments(for: notification)
    }

    var body: some View {
        if let actorName = segments.actorName, !actorName.isEmpty {
            inlineActorMessage(actorName: actorName, remainder: segments.remainder)
        } else {
            MentionText(
                notification.body,
                fontSize: 13,
                plainColor: SplickTheme.Colors.textSecondary
            )
        }
    }

    private func inlineActorMessage(actorName: String, remainder: String) -> some View {
        Group {
            if remainder.isEmpty {
                Text(actorName)
                    .font(SplickTheme.Typography.headline)
                    .foregroundColor(SplickTheme.Colors.textPrimary)
            } else {
                (Text(actorName)
                    .font(SplickTheme.Typography.headline)
                    .foregroundColor(SplickTheme.Colors.textPrimary)
                + Text(" \(remainder)")
                    .font(.system(size: 13))
                    .foregroundColor(SplickTheme.Colors.textSecondary)
                )
            }
        }
        .lineLimit(1)
        .truncationMode(.tail)
    }
}
