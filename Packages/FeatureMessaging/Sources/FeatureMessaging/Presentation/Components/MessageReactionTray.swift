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

    private let slotSize: CGFloat = 36
    private let slotSpacing: CGFloat = 4
    private static let impactFeedback = UIImpactFeedbackGenerator(style: .light)

    var body: some View {
        HStack(spacing: slotSpacing) {
            ForEach(Array(preferences.quickEmojis.enumerated()), id: \.offset) { index, emoji in
                emojiSlot(emoji: emoji, index: index)
            }
            plusButton
        }
        .padding(.horizontal, SplickTheme.Spacing.sm)
        .padding(.vertical, SplickTheme.Spacing.xs)
        .background {
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
        }
        .onAppear {
            Self.impactFeedback.prepare()
        }
    }

    private func emojiSlot(emoji: String, index: Int) -> some View {
        let isBouncing = bounceIndex == index

        return Button {
            commitReaction(emoji: emoji, index: index)
        } label: {
            EmojiView(value: emoji, size: slotSize)
                .frame(width: slotSize, height: slotSize)
                .scaleEffect(isBouncing ? 1.22 : 1)
                .animation(.spring(response: 0.24, dampingFraction: 0.72), value: isBouncing)
        }
        .buttonStyle(.plain)
    }

    private var plusButton: some View {
        Button {
            onOpenFullPicker()
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(SplickTheme.Colors.textSecondary)
                .frame(width: slotSize, height: slotSize)
                .background(Circle().fill(SplickTheme.Colors.tertiaryBackground))
        }
        .buttonStyle(.plain)
    }

    private func commitReaction(emoji: String, index: Int) {
        Self.impactFeedback.impactOccurred()
        Self.impactFeedback.prepare()
        bounceIndex = index
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            if bounceIndex == index { bounceIndex = nil }
        }
        onReact(emoji)
        onDismiss()
    }
}

struct MessageBubbleFrameKey: PreferenceKey {
    static var defaultValue: [UUID: CGRect] = [:]

    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}
