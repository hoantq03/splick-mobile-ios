import SwiftUI
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
    let onDismiss: () -> Void
    let onOpen: () -> Void

    @State private var isRevealed = false
    @State private var isDismissing = false
    @State private var dismissIsArmed = false

    private static let dismissArmDelay: TimeInterval = 0.45
    private let horizontalMargin = SplickTheme.Spacing.md
    private let contentSpacing = SplickTheme.Spacing.sm

    var body: some View {
        GeometryReader { geometry in
            let cardHeight = min(max(geometry.size.height * 0.4, 220), 360)
            let cardFrame = previewCardFrame(
                containerSize: geometry.size,
                cardHeight: cardHeight
            )

            ZStack {
                Color.black
                    .opacity(isRevealed ? 0.52 : 0)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        guard dismissIsArmed else { return }
                        dismissAnimated(completion: onDismiss)
                    }

                liftedRow
                    .frame(
                        width: context.anchorFrame.width,
                        height: context.anchorFrame.height
                    )
                    .scaleEffect(isRevealed ? 1.06 : 1)
                    .position(
                        x: context.anchorFrame.midX,
                        y: context.anchorFrame.midY
                    )
                    .onTapGesture {
                        dismissAnimated(completion: onOpen)
                    }

                previewCard
                    .frame(width: cardFrame.width, height: cardFrame.height)
                    .scaleEffect(isRevealed ? 1 : 0.94, anchor: cardFrame.minY > context.anchorFrame.maxY ? .top : .bottom)
                    .opacity(isRevealed ? 1 : 0)
                    .position(x: cardFrame.midX, y: cardFrame.midY)
                    .onTapGesture {
                        dismissAnimated(completion: onOpen)
                    }
            }
        }
        .onAppear {
            withAnimation(MessageReactionTrayMotion.present) {
                isRevealed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.dismissArmDelay) {
                dismissIsArmed = true
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(languageService.text(.messagingConversationPeekA11y))
    }

    private var liftedRow: some View {
        ConversationRowView(
            conversation: context.conversation,
            reportsAnchorFrame: false
        )
        .background {
            RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.medium, style: .continuous)
                .fill(SplickTheme.Colors.background)
                .shadow(
                    color: .black.opacity(isRevealed ? 0.24 : 0),
                    radius: isRevealed ? 18 : 0,
                    y: isRevealed ? 8 : 0
                )
        }
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var previewCard: some View {
        Group {
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
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: SplickTheme.Spacing.xxs) {
                        ForEach(MessageTimelineGrouping.buildDisplayMessages(from: messages)) { item in
                            previewBubble(item)
                        }
                    }
                    .padding(SplickTheme.Spacing.md)
                }
            }
        }
        .background {
            RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.large, style: .continuous)
                .fill(SplickTheme.Colors.secondaryBackground)
                .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
        }
        .clipShape(
            RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.large, style: .continuous)
        )
        .contentShape(Rectangle())
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

    private func previewCardFrame(containerSize: CGSize, cardHeight: CGFloat) -> CGRect {
        let width = containerSize.width - horizontalMargin * 2
        let availableBelow = containerSize.height - context.anchorFrame.maxY - contentSpacing - horizontalMargin
        let availableAbove = context.anchorFrame.minY - contentSpacing - horizontalMargin
        let placeBelow = availableBelow >= min(cardHeight, 220) || availableBelow >= availableAbove
        let proposedY = placeBelow
            ? context.anchorFrame.maxY + contentSpacing
            : context.anchorFrame.minY - contentSpacing - cardHeight
        let clampedY = min(
            max(proposedY, horizontalMargin),
            containerSize.height - horizontalMargin - cardHeight
        )

        return CGRect(x: horizontalMargin, y: clampedY, width: width, height: cardHeight)
    }

    private func dismissAnimated(completion: @escaping () -> Void) {
        guard !isDismissing else { return }
        isDismissing = true
        withAnimation(MessageReactionTrayMotion.dismiss) {
            isRevealed = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + MessageReactionTrayMotion.dismissSettlingDelay) {
            completion()
        }
    }
}
