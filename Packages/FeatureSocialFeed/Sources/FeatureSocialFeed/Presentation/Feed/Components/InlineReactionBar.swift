import SwiftUI
import UIKit
import Common
import DesignSystem
import SplickDomain

private struct ReactionBarFrameKey: PreferenceKey {
    static var defaultValue: CGRect = .zero

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let next = nextValue()
        if next != .zero { value = next }
    }
}

/// Always-visible emoji row. Tap or long-press to react; a swipe/scroll never drops an emoji.
struct InlineReactionBar: View {
    @ObservedObject private var preferences = QuickReactionPreferences.shared

    let onReact: (String) -> Void
    var onDragRelease: ((String, CGRect) -> Void)?
    let onCustomEmoji: () -> Void

    @State private var highlightedIndex: Int?
    @State private var isDragSelecting = false
    @State private var cancelledForScroll = false
    @State private var barFrame: CGRect = .zero
    @State private var bounceIndex: Int?

    private let slotSize: CGFloat = 36
    private let slotSpacing: CGFloat = 4
    /// Long-press hover (doubled from 1.45 / -10).
    private let hoverScale: CGFloat = 2.9
    private let hoverLift: CGFloat = -20
    /// Fail the long-press if the finger moves this far — lets the feed scroll win.
    private let longPressDuration: TimeInterval = 0.4
    private let scrollCancelDistance: CGFloat = 16
    /// Keep the fly (pop + fall ≈ 0.67s) visible before the feed diff remounts the card.
    private let reactionCommitDelay: TimeInterval = 0.55
    private static let selectionFeedback = UISelectionFeedbackGenerator()
    private static let impactFeedback = UIImpactFeedbackGenerator(style: .light)

    private var slotCount: Int {
        preferences.quickEmojis.count + 1
    }

    var body: some View {
        HStack(spacing: slotSpacing) {
            ForEach(Array(preferences.quickEmojis.enumerated()), id: \.offset) { index, emoji in
                emojiSlot(emoji: emoji, index: index)
            }
            plusButton
        }
        .frame(height: 40, alignment: .leading)
        .background(
            GeometryReader { geo in
                Color.clear.preference(
                    key: ReactionBarFrameKey.self,
                    value: geo.frame(in: .global)
                )
            }
        )
        .onPreferenceChange(ReactionBarFrameKey.self) { frame in
            guard frame != .zero, frame != barFrame else { return }
            // Defer @State write off PreferenceKey layout pass.
            DispatchQueue.main.async {
                guard frame != barFrame else { return }
                barFrame = frame
            }
        }
        .simultaneousGesture(longPressDragGesture)
        .onAppear {
            Self.selectionFeedback.prepare()
            Self.impactFeedback.prepare()
        }
    }

    private func emojiSlot(emoji: String, index: Int) -> some View {
        let isHighlighted = highlightedIndex == index
        let isBouncing = bounceIndex == index

        return EmojiView(value: emoji, size: slotSize)
            .frame(width: slotSize, height: slotSize)
            .scaleEffect(isHighlighted ? hoverScale : (isBouncing ? 1.22 : 1))
            .offset(y: isHighlighted ? hoverLift : 0)
            .zIndex(isHighlighted ? 1 : 0)
            .animation(.spring(response: 0.18, dampingFraction: 0.78), value: isHighlighted)
            .animation(.spring(response: 0.24, dampingFraction: 0.72), value: isBouncing)
            .contentShape(Rectangle())
            .onTapGesture {
                guard !isDragSelecting, !cancelledForScroll else { return }
                commitReaction(emoji: emoji, index: index)
            }
            .accessibilityAddTraits(.isButton)
    }

    private var plusButton: some View {
        let plusIndex = preferences.quickEmojis.count
        let isHighlighted = highlightedIndex == plusIndex

        return Image(systemName: "plus")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(SplickTheme.Colors.textSecondary)
            .frame(width: slotSize, height: slotSize)
            .background(Circle().fill(SplickTheme.Colors.tertiaryBackground))
            .scaleEffect(isHighlighted ? hoverScale : 1)
            .offset(y: isHighlighted ? hoverLift : 0)
            .zIndex(isHighlighted ? 1 : 0)
            .animation(.spring(response: 0.18, dampingFraction: 0.78), value: isHighlighted)
            .contentShape(Rectangle())
            .onTapGesture {
                guard !isDragSelecting, !cancelledForScroll else { return }
                onCustomEmoji()
            }
            .accessibilityAddTraits(.isButton)
    }

    private var longPressDragGesture: some Gesture {
        LongPressGesture(minimumDuration: longPressDuration, maximumDistance: scrollCancelDistance)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .global))
            .onChanged { value in
                switch value {
                case .first(_):
                    cancelledForScroll = false
                case .second(true, let drag?):
                    guard !cancelledForScroll else { return }
                    if isVerticalScroll(drag) {
                        cancelSelectionForScroll()
                        return
                    }
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
                let shouldCommit = isDragSelecting && !cancelledForScroll
                let location: CGPoint? = {
                    if case .second(true, let drag?) = value { return drag.location }
                    return nil
                }()
                let keepCancelled = cancelledForScroll
                highlightedIndex = nil
                isDragSelecting = false
                FeedScrollLock.setLocked(false)
                if !keepCancelled {
                    cancelledForScroll = false
                }
                guard shouldCommit, let location else { return }
                commitDragSelection(at: location)
            }
    }

    private func isVerticalScroll(_ drag: DragGesture.Value) -> Bool {
        let dx = drag.translation.width
        let dy = drag.translation.height
        return abs(dy) > scrollCancelDistance && abs(dy) > abs(dx)
    }

    private func cancelSelectionForScroll() {
        cancelledForScroll = true
        highlightedIndex = nil
        if isDragSelecting {
            isDragSelecting = false
            FeedScrollLock.setLocked(false)
        }
    }

    private func updateHighlight(at point: CGPoint) {
        let index = slotIndex(at: point)
        guard index != highlightedIndex else { return }
        highlightedIndex = index
        if index != nil {
            Self.selectionFeedback.selectionChanged()
            Self.selectionFeedback.prepare()
        }
    }

    private func slotFrame(for index: Int) -> CGRect {
        CGRect(
            x: barFrame.minX + CGFloat(index) * (slotSize + slotSpacing),
            y: barFrame.minY,
            width: slotSize,
            height: slotSize
        )
    }

    private func slotIndex(at point: CGPoint) -> Int? {
        guard barFrame != .zero else { return nil }
        for index in 0..<slotCount where slotFrame(for: index).insetBy(dx: -4, dy: -8).contains(point) {
            return index
        }
        return nil
    }

    private func commitDragSelection(at point: CGPoint) {
        guard let index = slotIndex(at: point) else { return }
        Self.impactFeedback.impactOccurred()
        Self.impactFeedback.prepare()

        if index == preferences.quickEmojis.count {
            onCustomEmoji()
        } else if preferences.quickEmojis.indices.contains(index) {
            commitReaction(emoji: preferences.quickEmojis[index], index: index)
        }
    }

    private func commitReaction(emoji: String, index: Int) {
        Self.impactFeedback.impactOccurred()
        Self.impactFeedback.prepare()
        bounceIndex = index
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            if bounceIndex == index { bounceIndex = nil }
        }
        if let frame = barFrame == .zero ? nil : slotFrame(for: index) {
            onDragRelease?(emoji, frame)
        }

        // Let the local bounce/fly animation breathe before the feed diff updates.
        DispatchQueue.main.asyncAfter(deadline: .now() + reactionCommitDelay) {
            var transaction = Transaction()
            transaction.animation = nil
            withTransaction(transaction) {
                onReact(emoji)
            }
        }
    }
}
