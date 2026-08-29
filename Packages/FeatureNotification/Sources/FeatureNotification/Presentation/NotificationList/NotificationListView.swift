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
        .alert(
            languageService.text(.friendsIncomingTitle),
            isPresented: Binding(
                get: { viewModel.friendRequestAlertMessage != nil },
                set: { if !$0 { viewModel.friendRequestAlertMessage = nil } }
            )
        ) {
            Button(languageService.text(.commonOK), role: .cancel) {
                viewModel.friendRequestAlertMessage = nil
            }
        } message: {
            Text(viewModel.friendRequestAlertMessage ?? "")
        }
        .onFirstAppear {
            viewModel.reloadFriendRequestOutcomes()
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
                            NotificationRowView(
                                notification: notification,
                                friendRequestOutcome: viewModel.friendRequestOutcome(for: notification),
                                isProcessingFriendRequest: viewModel.isProcessingFriendRequest(notification),
                                onAcceptFriendRequest: viewModel.showsFriendRequestActions(for: notification)
                                    ? {
                                        Task<Void, Never> {
                                            await viewModel.acceptFriendRequest(notification)
                                        }
                                    }
                                    : nil,
                                onRejectFriendRequest: viewModel.showsFriendRequestActions(for: notification)
                                    ? {
                                        Task<Void, Never> {
                                            await viewModel.rejectFriendRequest(notification)
                                        }
                                    }
                                    : nil,
                                onRowTap: {
                                    Task {
                                        let target = await viewModel.handleTap(notification)
                                        onNavigate?(target)
                                    }
                                }
                            )
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
    var friendRequestOutcome: FriendRequestInboxOutcome? = nil
    var isProcessingFriendRequest: Bool = false
    var onAcceptFriendRequest: (() -> Void)? = nil
    var onRejectFriendRequest: (() -> Void)? = nil
    var onRowTap: (() -> Void)? = nil
    @EnvironmentObject private var languageService: LanguageService

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

    private var timestampText: some View {
        Text(notification.createdAt.relativeString)
            .font(SplickTheme.Typography.caption)
            .foregroundColor(SplickTheme.Colors.textTertiary)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .layoutPriority(1)
    }

    private var showsFriendRequestActions: Bool {
        friendRequestOutcome != nil
            || isProcessingFriendRequest
            || onAcceptFriendRequest != nil
            || onRejectFriendRequest != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: SplickTheme.Spacing.sm) {
                NotificationAvatarBadgeView(notification: notification)

                VStack(alignment: .leading, spacing: SplickTheme.Spacing.xxxs) {
                    if showsCategoryTitle {
                        HStack(alignment: .firstTextBaseline, spacing: SplickTheme.Spacing.xs) {
                            Text(notification.title)
                                .font(SplickTheme.Typography.headline)
                                .foregroundColor(SplickTheme.Colors.textPrimary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)

                            timestampText
                        }
                    }

                    HStack(alignment: .firstTextBaseline, spacing: SplickTheme.Spacing.xxs) {
                        NotificationInlineBodyText(notification: notification)
                            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)

                        if !showsCategoryTitle {
                            timestampText
                        }

                        if !notification.isRead {
                            Circle()
                                .fill(SplickTheme.Colors.primaryGradientStart)
                                .frame(width: 8, height: 8)
                                .alignmentGuide(.firstTextBaseline) { dimensions in
                                    dimensions[VerticalAlignment.center]
                                }
                        }
                    }
                }
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                onRowTap?()
            }

            if showsFriendRequestActions {
                friendRequestActions
                    .padding(.top, 10)
                    .padding(.leading, NotificationTypeBadge.canvasSize + SplickTheme.Spacing.sm)
            }
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

private extension NotificationRowView {
    @ViewBuilder
    var friendRequestActions: some View {
        if let friendRequestOutcome {
            Text(
                languageService.text(
                    friendRequestOutcome == .accepted
                        ? .notificationFriendRequestAccepted
                        : .notificationFriendRequestRejected
                )
            )
            .font(SplickTheme.Typography.caption.weight(.semibold))
            .foregroundStyle(
                friendRequestOutcome == .accepted
                    ? SplickTheme.Colors.success
                    : SplickTheme.Colors.textSecondary
            )
            .lineLimit(1)
        } else if isProcessingFriendRequest {
            ProgressView()
                .controlSize(.regular)
                .frame(width: 22, height: 22)
        } else if onAcceptFriendRequest != nil || onRejectFriendRequest != nil {
            HStack(spacing: SplickTheme.Spacing.xs) {
                if let onAcceptFriendRequest {
                    friendRequestActionButton(
                        title: languageService.text(.friendsAccept),
                        foreground: .white,
                        background: SplickTheme.Colors.success,
                        action: onAcceptFriendRequest
                    )
                }
                if let onRejectFriendRequest {
                    friendRequestActionButton(
                        title: languageService.text(.friendsReject),
                        foreground: SplickTheme.Colors.textPrimary,
                        background: SplickTheme.Colors.secondaryBackground,
                        action: onRejectFriendRequest
                    )
                }
            }
        }
    }

    func friendRequestActionButton(
        title: String,
        foreground: Color,
        background: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(SplickTheme.Typography.caption.weight(.semibold))
                .foregroundStyle(foreground)
                .padding(.horizontal, SplickTheme.Spacing.md)
                .padding(.vertical, 6)
                .background(background)
                .clipShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

private struct NotificationAvatarBadgeView: View {
    let notification: AppNotification

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            avatarContent
                .frame(width: NotificationTypeBadge.avatarSize, height: NotificationTypeBadge.avatarSize)
                .clipShape(Circle())

            Image(systemName: notification.type.icon)
                .font(.system(size: NotificationTypeBadge.iconPointSize, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: NotificationTypeBadge.badgeSize, height: NotificationTypeBadge.badgeSize)
                .background {
                    Circle()
                        .fill(NotificationTypeBadge.fill(for: notification.type, isRead: notification.isRead))
                }
                .overlay {
                    Circle()
                        .strokeBorder(SplickTheme.Colors.background, lineWidth: NotificationTypeBadge.ringWidth)
                }
                .offset(x: NotificationTypeBadge.overhang, y: NotificationTypeBadge.overhang)
        }
        .frame(width: NotificationTypeBadge.canvasSize, height: NotificationTypeBadge.canvasSize)
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
        wrappingBody
            .lineLimit(3)
            .truncationMode(.tail)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var wrappingBody: some View {
        if let actorName = segments.actorName, !actorName.isEmpty {
            inlineActorMessage(actorName: actorName, remainder: segments.remainder)
        } else {
            Text(notification.body)
                .font(.system(size: 13))
                .foregroundColor(SplickTheme.Colors.textSecondary)
        }
    }

    private func inlineActorMessage(actorName: String, remainder: String) -> Text {
        if remainder.isEmpty {
            Text(actorName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(SplickTheme.Colors.textPrimary)
        } else {
            Text(actorName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(SplickTheme.Colors.textPrimary)
            + Text(" \(remainder)")
                .font(.system(size: 13))
                .foregroundColor(SplickTheme.Colors.textSecondary)
        }
    }
}
