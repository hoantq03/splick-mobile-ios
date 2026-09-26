import SwiftUI
import UIKit
import Common
import DesignSystem
import SplickDomain

struct MessageReactionTray: View {
    @ObservedObject private var preferences = QuickReactionPreferences.shared

    let onReact: (String) -> Void
    let onOpenFullPicker: () -> Void
    let onDismiss: () -> Void

    @State private var bounceIndex: Int?
    @State private var revealedSlotCount = 0

    private let slotSize: CGFloat = 36
    private let slotSpacing: CGFloat = 4
    private static let impactFeedback = UIImpactFeedbackGenerator(style: .light)

    init(
        onReact: @escaping (String) -> Void,
        onOpenFullPicker: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.onReact = onReact
        self.onOpenFullPicker = onOpenFullPicker
        self.onDismiss = onDismiss
    }

    private var totalSlots: Int {
        preferences.quickEmojis.count + 1
    }

    var body: some View {
        HStack(spacing: slotSpacing) {
            ForEach(Array(preferences.quickEmojis.enumerated()), id: \.offset) { index, emoji in
                emojiSlot(emoji: emoji, index: index)
            }
            plusButton(index: preferences.quickEmojis.count)
        }
        .padding(.horizontal, SplickTheme.Spacing.sm)
        .padding(.vertical, SplickTheme.Spacing.xs)
            .background {
                Capsule(style: .continuous)
                    .fill(SplickTheme.Colors.cardBackground)
                    .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
            }
        .onAppear {
            Self.impactFeedback.prepare()
            withAnimation(MessageReactionTrayMotion.emojiSlot) {
                revealedSlotCount = totalSlots
            }
        }
    }

    private func emojiSlot(emoji: String, index: Int) -> some View {
        let isBouncing = bounceIndex == index
        let isVisible = index < revealedSlotCount

        return Button {
            commitReaction(emoji: emoji, index: index)
        } label: {
            EmojiView(value: emoji, size: slotSize)
                .frame(width: slotSize, height: slotSize)
                .scaleEffect(isVisible ? 1 : 0)
                .opacity(isVisible ? 1 : 0)
                .animation(MessageReactionTrayMotion.emojiSlot, value: isVisible)
                .reactionTapBounce(isActive: isBouncing)
        }
        .buttonStyle(.plain)
    }

    private func plusButton(index: Int) -> some View {
        let isVisible = index < revealedSlotCount

        return Button {
            onOpenFullPicker()
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(SplickTheme.Colors.textSecondary)
                .frame(width: slotSize, height: slotSize)
                .background(Circle().fill(SplickTheme.Colors.tertiaryBackground))
                .scaleEffect(isVisible ? 1 : 0)
                .opacity(isVisible ? 1 : 0)
                .animation(MessageReactionTrayMotion.emojiSlot, value: isVisible)
        }
        .buttonStyle(.plain)
    }

    private func commitReaction(emoji: String, index: Int) {
        Self.impactFeedback.impactOccurred()
        Self.impactFeedback.prepare()
        bounceIndex = index
        DispatchQueue.main.asyncAfter(deadline: .now() + ReactionTapBounce.settleDelay) {
            if bounceIndex == index { bounceIndex = nil }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + ReactionTapBounce.commitDelay) {
            var transaction = Transaction()
            transaction.animation = nil
            withTransaction(transaction) {
                onReact(emoji)
            }
            onDismiss()
        }
    }
}
