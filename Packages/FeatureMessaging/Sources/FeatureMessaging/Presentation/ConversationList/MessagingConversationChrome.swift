import SwiftUI
import DesignSystem
import Localization
import SplickDomain

enum MessagingSearchChromeAnimation {
    static let focusSpring = Animation.spring(response: 0.32, dampingFraction: 0.88, blendDuration: 0.06)
    static let resultsSpring = Animation.spring(response: 0.28, dampingFraction: 0.9, blendDuration: 0.05)
}

private enum MessagingSearchChromeMetrics {
    static let rowHeight: CGFloat = 44
    static let verticalPadding: CGFloat = SplickTheme.Spacing.sm
}

struct MessagingConversationChrome: View {
    let title: String
    @Binding var searchDraft: String
    let searchPlaceholder: String
    let cancelLabel: String
    let showsSearchSpinner: Bool
    @FocusState.Binding var isSearchFocused: Bool
    let onCancel: () -> Void

    @Environment(\.openProfileSettings) private var openProfileSettings
    @Environment(\.currentUserSummary) private var currentUserSummary
    @Environment(\.openNotifications) private var openNotifications
    @Environment(\.notificationUnreadCount) private var notificationUnreadCount
    @Environment(\.languageService) private var languageService

    var body: some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.sm) {
            if !isSearchFocused {
                profileActionsRow
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .move(edge: .top).combined(with: .opacity)
                        )
                    )

                Text(title)
                    .font(SplickTheme.Typography.largeTitle)
                    .foregroundStyle(SplickTheme.Colors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .move(edge: .top).combined(with: .opacity)
                        )
                    )
            }

            HStack(spacing: SplickTheme.Spacing.sm) {
                searchCapsule

                if isSearchFocused {
                    Button(action: onCancel) {
                        Text(cancelLabel)
                            .font(SplickTheme.Typography.callout.weight(.medium))
                            .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
                    }
                    .buttonStyle(.plain)
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .trailing).combined(with: .opacity)
                        )
                    )
                }
            }
        }
        .padding(.horizontal, SplickTheme.Spacing.md)
        .padding(.top, SplickTheme.Spacing.xs)
        .padding(.bottom, MessagingSearchChromeMetrics.verticalPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            SplickTheme.Colors.background
                .ignoresSafeArea(edges: .top)
        }
        .animation(MessagingSearchChromeAnimation.focusSpring, value: isSearchFocused)
    }

    @ViewBuilder
    private var profileActionsRow: some View {
        HStack {
            if let openProfileSettings, let user = currentUserSummary {
                Button(action: openProfileSettings) {
                    AvatarView(
                        imageURL: user.avatarURL,
                        name: user.displayName,
                        size: .small
                    )
                    .frame(width: 34, height: 34)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    languageService?.text(.profileSettingsAccessibility)
                        ?? L10n.string(.profileSettingsAccessibility, locale: .default)
                )
            }

            Spacer()

            if let openNotifications {
                Button(action: openNotifications) {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: notificationUnreadCount > 0 ? "bell.fill" : "bell")
                            .font(.system(size: 20, weight: .medium))
                            .frame(width: 34, height: 34)
                        if notificationUnreadCount > 0 {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 8, height: 8)
                                .offset(x: 2, y: -2)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    languageService?.text(.notificationBellAccessibility)
                        ?? L10n.string(.notificationBellAccessibility, locale: .default)
                )
            }
        }
    }

    private var searchCapsule: some View {
        HStack(spacing: SplickTheme.Spacing.xs) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(SplickTheme.Colors.textSecondary)

            TextField(searchPlaceholder, text: $searchDraft)
                .font(SplickTheme.Typography.callout)
                .focused($isSearchFocused)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .submitLabel(.search)

            if showsSearchSpinner {
                ProgressView()
                    .controlSize(.small)
                    .transition(.opacity.combined(with: .scale(scale: 0.85)))
            }
        }
        .padding(.horizontal, SplickTheme.Spacing.md)
        .padding(.vertical, SplickTheme.Spacing.sm)
        .frame(maxWidth: .infinity, minHeight: MessagingSearchChromeMetrics.rowHeight)
        .background(SplickTheme.Colors.secondaryBackground)
        .clipShape(Capsule(style: .continuous))
        .animation(MessagingSearchChromeAnimation.focusSpring, value: showsSearchSpinner)
    }
}
