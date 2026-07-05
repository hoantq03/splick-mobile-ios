import SwiftUI
import DesignSystem
import Localization
import SplickDomain

struct FriendRowView: View {
    @EnvironmentObject private var languageService: LanguageService
    let user: UserSummary
    var friendStatus: FriendRelationStatus?
    var isProcessing: Bool = false
    var onProfileTap: (() -> Void)?
    var onAddFriend: (() -> Void)?
    var onRejectFriend: (() -> Void)?
    var onUnblock: (() -> Void)?

    private let rowCornerRadius = SplickTheme.CornerRadius.pill
    private let actionIconSize: CGFloat = 36

    var body: some View {
        Group {
            if let onProfileTap, friendStatus == nil {
                rowContent
                    .contentShape(Rectangle())
                    .onTapGesture(perform: onProfileTap)
            } else {
                rowContent
            }
        }
        .splickCard(padding: SplickTheme.Spacing.sm, cornerRadius: rowCornerRadius)
    }

    private var rowContent: some View {
        HStack(spacing: SplickTheme.Spacing.sm) {
            profileSection
            Spacer(minLength: SplickTheme.Spacing.xs)
            if let friendStatus {
                relationAction(for: friendStatus)
            }
        }
    }

    @ViewBuilder
    private var profileSection: some View {
        if let onProfileTap, friendStatus != nil {
            profileContent
                .contentShape(Rectangle())
                .onTapGesture(perform: onProfileTap)
        } else {
            profileContent
        }
    }

    private var profileContent: some View {
        HStack(spacing: SplickTheme.Spacing.sm) {
            AvatarView(imageURL: user.avatarURL, name: user.displayName, size: .medium)

            VStack(alignment: .leading, spacing: SplickTheme.Spacing.xxxs) {
                Text(user.displayName)
                    .font(SplickTheme.Typography.headline)
                    .foregroundStyle(SplickTheme.Colors.textPrimary)
                if let subtitle = user.subtitle {
                    Text(subtitle)
                        .font(SplickTheme.Typography.caption)
                        .foregroundStyle(SplickTheme.Colors.textSecondary)
                }
                Text("@\(user.username)")
                    .font(SplickTheme.Typography.caption)
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
            }
        }
    }

    @ViewBuilder
    private func relationAction(for status: FriendRelationStatus) -> some View {
        if isProcessing {
            ProgressView()
                .controlSize(.regular)
                .frame(width: actionIconSize, height: actionIconSize)
        } else {
            switch status {
            case .friends:
                relationStatusIcon(
                    systemImage: "person.crop.circle.badge.checkmark",
                    accessibilityLabel: languageService.text(.friendsRelationFriend),
                    style: .friend
                )
            case .requestSent:
                relationIconButton(
                    systemImage: "arrow.uturn.backward.circle.fill",
                    accessibilityLabel: languageService.text(.friendsRecallRequest),
                    style: .destructive,
                    action: { onAddFriend?() }
                )
                .disabled(onAddFriend == nil)
            case .requestReceived:
                VStack(spacing: SplickTheme.Spacing.xxxs) {
                    relationActionButton(
                        title: languageService.text(.friendsAccept),
                        style: .primary,
                        action: { onAddFriend?() }
                    )
                    .disabled(onAddFriend == nil)

                    if onRejectFriend != nil {
                        Button(languageService.text(.friendsReject)) {
                            onRejectFriend?()
                        }
                        .font(SplickTheme.Typography.caption.weight(.semibold))
                        .foregroundStyle(SplickTheme.Colors.textSecondary)
                        .buttonStyle(.plain)
                        .disabled(onRejectFriend == nil)
                    }
                }
            case .blocked:
                if onUnblock != nil {
                    relationActionButton(
                        title: languageService.text(.friendsUnblock),
                        style: .primary,
                        action: { onUnblock?() }
                    )
                    .disabled(onUnblock == nil)
                }
            case .none:
                relationIconButton(
                    systemImage: "person.badge.plus",
                    accessibilityLabel: languageService.text(.friendsAddFriendAction),
                    style: .primary,
                    action: { onAddFriend?() }
                )
                .disabled(onAddFriend == nil)
            }
        }
    }

    private enum RelationActionStyle {
        case primary
        case destructive
        case friend
    }

    private func relationStatusIcon(
        systemImage: String,
        accessibilityLabel: String,
        style: RelationActionStyle
    ) -> some View {
        Image(systemName: systemImage)
            .font(.system(size: 17, weight: .semibold))
            .frame(width: actionIconSize, height: actionIconSize)
            .foregroundStyle(foregroundColor(for: style))
            .background(backgroundColor(for: style))
            .clipShape(Circle())
            .accessibilityLabel(accessibilityLabel)
    }

    private func relationIconButton(
        systemImage: String,
        accessibilityLabel: String,
        style: RelationActionStyle,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: style == .destructive ? 18 : 16, weight: .semibold))
                .frame(width: actionIconSize, height: actionIconSize)
                .foregroundStyle(foregroundColor(for: style))
                .background(backgroundColor(for: style))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }

    private func relationActionButton(
        title: String,
        style: RelationActionStyle,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(SplickTheme.Typography.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(minWidth: 68, minHeight: actionIconSize)
                .padding(.horizontal, SplickTheme.Spacing.xs)
                .foregroundStyle(foregroundColor(for: style))
                .background(backgroundColor(for: style))
                .clipShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func foregroundColor(for style: RelationActionStyle) -> Color {
        switch style {
        case .primary:
            return SplickTheme.Colors.primaryGradientStart
        case .destructive:
            return SplickTheme.Colors.error
        case .friend:
            return SplickTheme.Colors.success
        }
    }

    private func backgroundColor(for style: RelationActionStyle) -> Color {
        switch style {
        case .primary:
            return SplickTheme.Colors.primaryGradientStart.opacity(0.12)
        case .destructive:
            return SplickTheme.Colors.error.opacity(0.14)
        case .friend:
            return SplickTheme.Colors.success.opacity(0.14)
        }
    }
}
