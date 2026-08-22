import SwiftUI
import UIKit
import DesignSystem
import Localization
import SplickDomain

struct ConversationPeekContext {
    let conversation: Conversation
    let anchorFrame: CGRect
    let currentUserId: UUID
}

struct ConversationPeekOverlay: View {
    @EnvironmentObject private var languageService: LanguageService

    let context: ConversationPeekContext
    let messages: [ChatMessage]
    let loadState: ConversationListViewModel.PeekLoadState
    var inboxTyping: InboxTypingState? = nil
    let onDismiss: () -> Void
    let onOpen: () -> Void
    let onDelete: () -> Void
    let onMute: () -> Void

    @State private var isRevealed = false
    @State private var isOptionsRevealed = false
    @State private var isDismissing = false
    @State private var dismissIsArmed = false

    private static let dismissArmDelay: TimeInterval = 0.45
    private static let actionImpact = UIImpactFeedbackGenerator(style: .light)
    private let edgeMargin = SplickTheme.Spacing.md
    private let contentGap = SplickTheme.Spacing.sm
    /// Extra drop below the Dynamic Island / status bar so chips are fully visible.
    private let extraBelowIsland = SplickTheme.Spacing.sm

    var body: some View {
        GeometryReader { geometry in
            let insets = geometry.safeAreaInsets
            let topInset = max(insets.top, Self.windowSafeAreaTop)
            let bottomInset = max(insets.bottom, Self.windowSafeAreaBottom)
            let chromeTop = topInset + extraBelowIsland
            let bottomPad = bottomInset + SplickTabBarMetrics.floatingClearance + edgeMargin
            let matchingRadius = max(
                Self.displayCornerRadius - edgeMargin,
                SplickTheme.CornerRadius.card
            )
            let previewShape = UnevenRoundedRectangle(
                topLeadingRadius: SplickTheme.CornerRadius.card,
                bottomLeadingRadius: matchingRadius,
                bottomTrailingRadius: matchingRadius,
                topTrailingRadius: SplickTheme.CornerRadius.card,
                style: .continuous
            )

            ZStack(alignment: .topLeading) {
                Color.black
                    .opacity(isRevealed ? 0.52 : 0)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        guard dismissIsArmed else { return }
                        dismissAnimated(completion: onDismiss)
                    }

                VStack(alignment: .leading, spacing: contentGap) {
                    optionsStack
                        .scaleEffect(
                            isOptionsRevealed ? 1 : 0.72,
                            anchor: .top
                        )
                        .opacity(isOptionsRevealed ? 1 : 0)
                        .offset(y: isOptionsRevealed ? 0 : -16)
                        .allowsHitTesting(isOptionsRevealed)

                    previewCard(shape: previewShape)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipShape(previewShape)
                        .compositingGroup()
                        .onTapGesture {
                            guard dismissIsArmed else { return }
                            dismissAnimated(completion: onOpen)
                        }
                }
                .padding(.top, chromeTop)
                .padding(.leading, insets.leading + edgeMargin)
                .padding(.trailing, insets.trailing + edgeMargin)
                .padding(.bottom, bottomPad)
                .scaleEffect(isRevealed ? 1 : 0.96, anchor: .top)
                .opacity(isRevealed ? 1 : 0)
                .allowsHitTesting(isRevealed)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(ConversationPeekMotion.appear) {
                isRevealed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + MessageReactionTrayMotion.optionsChromeDelay) {
                withAnimation(ConversationPeekMotion.appear) {
                    isOptionsRevealed = true
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.dismissArmDelay) {
                dismissIsArmed = true
            }
        }
        .transaction { transaction in
            if !isDismissing {
                transaction.disablesAnimations = false
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(languageService.text(.messagingConversationPeekA11y))
    }

    private var optionsStack: some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.xs) {
            optionChip(
                titleKey: .messagingChatDeleteConversation,
                systemImage: "trash",
                destructive: true,
                action: onDelete
            )
            optionChip(
                titleKey: .messagingChatMuteNotifications,
                systemImage: "bell.slash",
                destructive: false,
                action: onMute
            )
        }
    }

    private func optionChip(
        titleKey: L10nKey,
        systemImage: String,
        destructive: Bool,
        action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: SplickTheme.Spacing.xs) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
            Text(languageService.text(titleKey))
                .font(SplickTheme.Typography.callout.weight(.semibold))
        }
        .foregroundStyle(destructive ? SplickTheme.Colors.error : SplickTheme.Colors.textPrimary)
        .padding(.horizontal, SplickTheme.Spacing.md)
        .padding(.vertical, SplickTheme.Spacing.sm)
        .background {
            Capsule(style: .continuous)
                .fill(SplickTheme.Colors.cardBackground)
        }
        .contentShape(Capsule())
        .onTapGesture {
            Self.actionImpact.impactOccurred()
            action()
        }
    }

    private func previewCard(shape: UnevenRoundedRectangle) -> some View {
        VStack(spacing: 0) {
            ConversationRowView(
                conversation: context.conversation,
                reportsAnchorFrame: false,
                inboxTyping: inboxTyping
            )
            .padding(.horizontal, SplickTheme.Spacing.sm)

            Divider()

            previewBody
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background {
            shape
                .fill(SplickTheme.Colors.secondaryBackground)
                .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
        }
        .contentShape(shape)
    }

    @ViewBuilder
    private var previewBody: some View {
        switch loadState {
        case .idle, .loading:
            VStack(spacing: SplickTheme.Spacing.sm) {
                ProgressView()
                Text(languageService.text(.messagingChatLoading))
                    .font(SplickTheme.Typography.callout)
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .loaded where messages.isEmpty:
            previewStatus(
                systemImage: "bubble.left",
                message: languageService.text(.messagingConversationPeekEmpty)
            )

        case .failed:
            previewStatus(
                systemImage: "wifi.exclamationmark",
                message: languageService.text(.messagingConversationPeekError)
            )

        case .loaded:
            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: SplickTheme.Spacing.xxs) {
                        ForEach(MessageTimelineGrouping.buildDisplayMessages(from: messages)) { item in
                            VStack(spacing: 0) {
                                if item.showsTimeSeparator {
                                    MessageTimeSeparatorLabel(date: item.message.createdAt)
                                }
                                previewBubble(item)
                            }
                        }
                    }
                    .padding(SplickTheme.Spacing.md)
                }
                .onAppear {
                    if let lastItem = MessageTimelineGrouping.buildDisplayMessages(from: messages).last {
                        proxy.scrollTo(lastItem.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private func previewBubble(_ item: DisplayMessage) -> some View {
        let isOutgoing = item.message.senderId == context.currentUserId

        return HStack {
            if isOutgoing {
                Spacer(minLength: 44)
            }

            MessageBubble(
                displayMessage: item,
                isOutgoing: isOutgoing,
                currentUserId: context.currentUserId,
                presentation: .reactionFocusLift,
                onReact: { _ in },
                onRetry: nil,
                onLongPress: nil,
                onReply: nil
            )

            if !isOutgoing {
                Spacer(minLength: 44)
            }
        }
    }

    private func previewStatus(systemImage: String, message: String) -> some View {
        VStack(spacing: SplickTheme.Spacing.sm) {
            Image(systemName: systemImage)
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(SplickTheme.Colors.textTertiary)
            Text(message)
                .font(SplickTheme.Typography.callout)
                .foregroundStyle(SplickTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(SplickTheme.Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private static var displayCornerRadius: CGFloat {
        let screen = UIScreen.main
        if let radius = screen.value(forKey: "_displayCornerRadius") as? CGFloat, radius > 0 {
            return radius
        }
        if let radius = screen.value(forKey: "displayCornerRadius") as? CGFloat, radius > 0 {
            return radius
        }
        return SplickTheme.CornerRadius.extraLarge
    }

    private static var windowSafeAreaTop: CGFloat {
        windowSafeAreaInsets.top
    }

    private static var windowSafeAreaBottom: CGFloat {
        windowSafeAreaInsets.bottom
    }

    private static var windowSafeAreaInsets: UIEdgeInsets {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let window = scenes.flatMap(\.windows).first(where: \.isKeyWindow)
            ?? scenes.first?.windows.first
        return window?.safeAreaInsets ?? UIEdgeInsets(top: 59, left: 0, bottom: 34, right: 0)
    }

    private func dismissAnimated(completion: @escaping () -> Void) {
        guard !isDismissing else { return }
        isDismissing = true
        withAnimation(ConversationPeekMotion.dismiss) {
            isRevealed = false
            isOptionsRevealed = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + ConversationPeekMotion.dismissSettlingDelay) {
            completion()
        }
    }
}

private enum ConversationPeekMotion {
    /// Drop into the stacked layout with one soft overshoot.
    static let appear = Animation.spring(response: 0.38, dampingFraction: 0.62)
    /// Return to the list row without oscillating past it.
    static let dismiss = Animation.spring(response: 0.30, dampingFraction: 0.86)
    static let dismissSettlingDelay: TimeInterval = 0.28
}
