import SwiftUI
import UIKit
import DesignSystem

/// Always-visible emoji row. Tap = +1 with bounce; long-press + drag = hover scale + release to add.
struct InlineReactionBar: View {
    let onReact: (String) -> Void
    var onDragRelease: ((String, CGRect) -> Void)?
    let onCustomEmoji: () -> Void

    var body: some View {
        InlineReactionBarHost(
            onReact: onReact,
            onDragRelease: onDragRelease,
            onCustomEmoji: onCustomEmoji
        )
        .frame(height: 40)
    }
}

// MARK: - UIKit

private struct InlineReactionBarHost: UIViewRepresentable {
    let onReact: (String) -> Void
    let onDragRelease: ((String, CGRect) -> Void)?
    let onCustomEmoji: () -> Void

    func makeUIView(context: Context) -> InlineReactionBarControl {
        let view = InlineReactionBarControl()
        view.onReact = onReact
        view.onDragRelease = onDragRelease
        view.onCustomEmoji = onCustomEmoji
        return view
    }

    func updateUIView(_ uiView: InlineReactionBarControl, context: Context) {
        uiView.onReact = onReact
        uiView.onDragRelease = onDragRelease
        uiView.onCustomEmoji = onCustomEmoji
    }
}

private final class InlineReactionBarControl: UIView {
    var onReact: ((String) -> Void)?
    var onDragRelease: ((String, CGRect) -> Void)?
    var onCustomEmoji: (() -> Void)?

    private let emojis = ["❤️", "😂", "😮", "😢", "😡", "👏"]
    private let slotSize: CGFloat = 36
    private let slotSpacing: CGFloat = 4

    private var emojiViews: [UILabel] = []
    private var plusContainer: UIView?
    private var slotStack: UIStackView!
    private var highlightedIndex: Int?
    private var isDragSelecting = false
    private let impactFeedback = UIImpactFeedbackGenerator(style: .light)
    private let selectionFeedback = UISelectionFeedbackGenerator()

    override init(frame: CGRect) {
        super.init(frame: frame)
        buildBar()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        buildBar()
    }

    /// Pass touches outside emoji row through to the feed scroll view.
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard bounds.contains(point), let slotStack else { return nil }
        let pointInStack = convert(point, to: slotStack)
        guard slotStack.bounds.contains(pointInStack) else { return nil }
        return super.hitTest(point, with: event)
    }

    private func buildBar() {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = slotSpacing
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        slotStack = stack

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        emojiViews = emojis.map { emoji in
            let label = UILabel()
            label.text = emoji
            label.font = .systemFont(ofSize: 24)
            label.textAlignment = .center
            label.isUserInteractionEnabled = true
            label.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                label.widthAnchor.constraint(equalToConstant: slotSize),
                label.heightAnchor.constraint(equalToConstant: slotSize),
            ])

            let tap = UITapGestureRecognizer(target: self, action: #selector(handleEmojiTap(_:)))
            label.addGestureRecognizer(tap)
            stack.addArrangedSubview(label)
            return label
        }

        let plus = UIView()
        plus.translatesAutoresizingMaskIntoConstraints = false
        plus.backgroundColor = UIColor(SplickTheme.Colors.tertiaryBackground)
        plus.layer.cornerRadius = slotSize / 2
        let plusIcon = UIImageView(image: UIImage(systemName: "plus"))
        plusIcon.tintColor = UIColor(SplickTheme.Colors.textSecondary)
        plusIcon.translatesAutoresizingMaskIntoConstraints = false
        plus.addSubview(plusIcon)
        NSLayoutConstraint.activate([
            plus.widthAnchor.constraint(equalToConstant: slotSize),
            plus.heightAnchor.constraint(equalToConstant: slotSize),
            plusIcon.centerXAnchor.constraint(equalTo: plus.centerXAnchor),
            plusIcon.centerYAnchor.constraint(equalTo: plus.centerYAnchor),
        ])
        let plusTap = UITapGestureRecognizer(target: self, action: #selector(handlePlusTap))
        plus.addGestureRecognizer(plusTap)
        stack.addArrangedSubview(plus)
        plusContainer = plus

        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        longPress.minimumPressDuration = 0.2
        longPress.allowableMovement = 300
        longPress.delegate = self
        stack.addGestureRecognizer(longPress)
    }

    @objc private func handleEmojiTap(_ gesture: UITapGestureRecognizer) {
        guard !isDragSelecting, let label = gesture.view as? UILabel,
              let index = emojiViews.firstIndex(of: label) else { return }
        commitReaction(at: index)
    }

    @objc private func handlePlusTap() {
        guard !isDragSelecting else { return }
        onCustomEmoji?()
    }

    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        let location = gesture.location(in: slotStack)

        switch gesture.state {
        case .began:
            guard slotIndex(at: location, in: slotStack) != nil else { return }
            isDragSelecting = true
            impactFeedback.prepare()
            selectionFeedback.prepare()
            FeedScrollLock.setLocked(true)
            updateHighlight(at: location)
        case .changed:
            guard isDragSelecting else { return }
            updateHighlight(at: location)
        case .ended:
            guard isDragSelecting else { return }
            commitDragSelection()
            clearHighlight()
            isDragSelecting = false
            FeedScrollLock.setLocked(false)
        case .cancelled, .failed:
            clearHighlight()
            isDragSelecting = false
            FeedScrollLock.setLocked(false)
        default:
            break
        }
    }

    private func updateHighlight(at location: CGPoint) {
        let index = slotIndex(at: location, in: slotStack)
        guard index != highlightedIndex else { return }

        if let previous = highlightedIndex {
            animateSlot(at: previous, highlighted: false)
        }
        highlightedIndex = index
        if let index {
            animateSlot(at: index, highlighted: true)
            selectionFeedback.selectionChanged()
        }
    }

    private func clearHighlight() {
        if let previous = highlightedIndex {
            animateSlot(at: previous, highlighted: false)
        }
        highlightedIndex = nil
    }

    private func slotIndex(at location: CGPoint, in container: UIView) -> Int? {
        let allSlots: [UIView] = emojiViews + (plusContainer.map { [$0] } ?? [])
        for (index, view) in allSlots.enumerated() {
            let frame = view.convert(view.bounds, to: container).insetBy(dx: -4, dy: -8)
            if frame.contains(location) {
                return index
            }
        }
        return nil
    }

    private func animateSlot(at index: Int, highlighted: Bool) {
        let view: UIView?
        if index < emojiViews.count {
            view = emojiViews[index]
        } else {
            view = plusContainer
        }
        guard let view else { return }

        UIView.animate(
            withDuration: 0.12,
            delay: 0,
            usingSpringWithDamping: 0.68,
            initialSpringVelocity: 0.9
        ) {
            if highlighted {
                view.transform = CGAffineTransform(scaleX: 1.5, y: 1.5).translatedBy(x: 0, y: -10)
            } else {
                view.transform = .identity
            }
        }
    }

    private func bounceSlot(at index: Int) {
        guard index < emojiViews.count else { return }
        let view = emojiViews[index]
        impactFeedback.impactOccurred()
        view.layer.removeAllAnimations()
        UIView.animate(
            withDuration: 0.07,
            delay: 0,
            usingSpringWithDamping: 0.7,
            initialSpringVelocity: 1.2,
            animations: {
                view.transform = CGAffineTransform(scaleX: 1.35, y: 1.35).translatedBy(x: 0, y: -6)
            },
            completion: { _ in
                UIView.animate(withDuration: 0.05) {
                    if self.highlightedIndex != index {
                        view.transform = .identity
                    }
                }
            }
        )
    }

    private func commitDragSelection() {
        guard let index = highlightedIndex else { return }
        if index == emojis.count {
            onCustomEmoji?()
        } else if emojis.indices.contains(index) {
            commitReaction(at: index)
        }
        impactFeedback.impactOccurred()
    }

    private func commitReaction(at index: Int) {
        guard emojis.indices.contains(index) else { return }
        let emoji = emojis[index]
        let label = emojiViews[index]
        let globalFrame = label.convert(label.bounds, to: nil)
        bounceSlot(at: index)
        onDragRelease?(emoji, globalFrame)
        onReact?(emoji)
    }
}

extension InlineReactionBarControl: UIGestureRecognizerDelegate {
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
    ) -> Bool {
        false
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard gestureRecognizer is UILongPressGestureRecognizer, let slotStack else { return true }
        let location = touch.location(in: slotStack)
        return slotIndex(at: location, in: slotStack) != nil
    }
}
