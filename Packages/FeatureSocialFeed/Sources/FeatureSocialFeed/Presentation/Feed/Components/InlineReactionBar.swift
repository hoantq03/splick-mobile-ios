import SwiftUI
import UIKit
import Common
import DesignSystem
import SplickDomain

private struct ReactionSlotFramesKey: PreferenceKey {
    static var defaultValue: [Int: CGRect] = [:]

    static func reduce(value: inout [Int: CGRect], nextValue: () -> [Int: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

private extension View {
    func reactionSlotFrame(index: Int) -> some View {
        background(
            GeometryReader { geo in
                Color.clear.preference(
                    key: ReactionSlotFramesKey.self,
                    value: [index: geo.frame(in: .global)]
                )
            }
        )
    }
}

/// Always-visible emoji row. Tap = react with bounce; long-press + drag = hover scale + release to add.
struct InlineReactionBar: View {
    @ObservedObject private var preferences = QuickReactionPreferences.shared

    let onReact: (String) -> Void
    var onDragRelease: ((String, CGRect) -> Void)?
    let onCustomEmoji: () -> Void

    @State private var highlightedIndex: Int?
    @State private var isDragSelecting = false
    @State private var slotFrames: [Int: CGRect] = [:]
    @State private var bounceIndex: Int?

    private let slotSize: CGFloat = 36
    private let slotSpacing: CGFloat = 4

    var body: some View {
        HStack(spacing: slotSpacing) {
            ForEach(Array(preferences.quickEmojis.enumerated()), id: \.offset) { index, emoji in
                emojiSlot(emoji: emoji, index: index)
            }
            plusButton
        }
        .frame(height: 40, alignment: .leading)
        .onPreferenceChange(ReactionSlotFramesKey.self) { slotFrames = $0 }
        .simultaneousGesture(longPressDragGesture)
    }

    private func emojiSlot(emoji: String, index: Int) -> some View {
        let isHighlighted = highlightedIndex == index
        let isBouncing = bounceIndex == index

        return Button {
            guard !isDragSelecting else { return }
            commitReaction(emoji: emoji, index: index)
        } label: {
            EmojiView(value: emoji, size: slotSize)
                .frame(width: slotSize, height: slotSize)
                .scaleEffect(isHighlighted ? 1.5 : (isBouncing ? 1.28 : 1))
                .offset(y: isHighlighted ? -10 : (isBouncing ? -4 : 0))
                .animation(.spring(response: 0.12, dampingFraction: 0.68), value: isHighlighted)
                .animation(.spring(response: 0.05, dampingFraction: 0.62), value: isBouncing)
        }
        .buttonStyle(.plain)
        .reactionSlotFrame(index: index)
    }

    private var plusButton: some View {
        let plusIndex = preferences.quickEmojis.count
        let isHighlighted = highlightedIndex == plusIndex

        return Button {
            guard !isDragSelecting else { return }
            onCustomEmoji()
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(SplickTheme.Colors.textSecondary)
                .frame(width: slotSize, height: slotSize)
                .background(Circle().fill(SplickTheme.Colors.tertiaryBackground))
                .scaleEffect(isHighlighted ? 1.5 : 1)
                .offset(y: isHighlighted ? -10 : 0)
                .animation(.spring(response: 0.12, dampingFraction: 0.68), value: isHighlighted)
        }
        .buttonStyle(.plain)
        .reactionSlotFrame(index: plusIndex)
    }

    private var longPressDragGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.2)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .global))
            .onChanged { value in
                switch value {
                case .second(true, let drag?):
                    if !isDragSelecting {
                        isDragSelecting = true
                        FeedScrollLock.setLocked(true)
                    }
                    updateHighlight(at: drag.location)
                default:
                    break
                }
            }
            .onEnded { value in
                defer {
                    highlightedIndex = nil
                    isDragSelecting = false
                    FeedScrollLock.setLocked(false)
                }
                guard isDragSelecting else { return }
                if case .second(true, let drag?) = value {
                    commitDragSelection(at: drag.location)
                }
            }
    }

    private func updateHighlight(at point: CGPoint) {
        let index = slotIndex(at: point)
        guard index != highlightedIndex else { return }
        highlightedIndex = index
        if index != nil {
            UISelectionFeedbackGenerator().selectionChanged()
        }
    }

    private func slotIndex(at point: CGPoint) -> Int? {
        slotFrames.first { _, frame in
            frame.insetBy(dx: -4, dy: -8).contains(point)
        }?.key
    }

    private func commitDragSelection(at point: CGPoint) {
        guard let index = slotIndex(at: point) else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        if index == preferences.quickEmojis.count {
            onCustomEmoji()
        } else if preferences.quickEmojis.indices.contains(index) {
            commitReaction(emoji: preferences.quickEmojis[index], index: index)
        }
    }

    private func commitReaction(emoji: String, index: Int) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        bounceIndex = index
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            if bounceIndex == index { bounceIndex = nil }
        }
        if let frame = slotFrames[index] {
            onDragRelease?(emoji, frame)
        }
        onReact(emoji)
    }
}
