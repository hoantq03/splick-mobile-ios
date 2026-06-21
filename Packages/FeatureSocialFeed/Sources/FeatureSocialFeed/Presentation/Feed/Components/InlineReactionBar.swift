import SwiftUI
import UIKit
import DesignSystem
import SplickDomain

/// Always-visible emoji row. Tap = +1 with bounce; long-press + drag = hover scale + release to add.
struct InlineReactionBar: View {
    @ObservedObject private var preferences = QuickReactionPreferences.shared
    @Environment(\.customEmojiStore) private var emojiStore

    let groupId: UUID?
    let onReact: (String) -> Void
    var onDragRelease: ((String, CGRect) -> Void)?
    let onCustomEmoji: () -> Void

    var body: some View {
        InlineReactionBarHost(
            emojis: preferences.quickEmojis,
            groupId: groupId,
            resolveURL: { value in
                guard let groupId else { return nil }
                return emojiStore.resolveColonCode(value, in: groupId)
            },
            onReact: onReact,
            onDragRelease: onDragRelease,
            onCustomEmoji: onCustomEmoji
        )
        .frame(height: 40)
    }
}

// MARK: - UIKit

private struct InlineReactionBarHost: UIViewRepresentable {
    let emojis: [String]
    let groupId: UUID?
    let resolveURL: (String) -> URL?
    let onReact: (String) -> Void
    var onDragRelease: ((String, CGRect) -> Void)?
    let onCustomEmoji: () -> Void

    func makeUIView(context: Context) -> InlineReactionBarControl {
        let view = InlineReactionBarControl()
        view.setEmojis(emojis, resolveURL: resolveURL)
        view.onReact = onReact
        view.onDragRelease = onDragRelease
        view.onCustomEmoji = onCustomEmoji
        return view
    }

    func updateUIView(_ uiView: InlineReactionBarControl, context: Context) {
        uiView.setEmojis(emojis, resolveURL: resolveURL)
        uiView.onReact = onReact
        uiView.onDragRelease = onDragRelease
        uiView.onCustomEmoji = onCustomEmoji
    }
}

private final class InlineReactionBarControl: UIView {
    var onReact: ((String) -> Void)?
    var onDragRelease: ((String, CGRect) -> Void)?
    var onCustomEmoji: (() -> Void)?

    private var emojis: [String] = QuickReactionPreferences.defaultEmojis
    private var resolveURL: ((String) -> URL?)?
    private let slotSize: CGFloat = 36
    private let slotSpacing: CGFloat = 4

    private var emojiSlots: [UIView] = []
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

    func setEmojis(_ newEmojis: [String], resolveURL: @escaping (String) -> URL?) {
        self.resolveURL = resolveURL
        guard newEmojis != emojis else { return }
        emojis = newEmojis
        rebuildEmojiViews()
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

        rebuildEmojiViews()

        let plus = UIView()
        plus.isUserInteractionEnabled = true
        plus.translatesAutoresizingMaskIntoConstraints = false
        plus.backgroundColor = UIColor(SplickTheme.Colors.tertiaryBackground)
        plus.layer.cornerRadius = slotSize / 2
        let plusIcon = UIImageView(image: UIImage(systemName: "plus"))
        plusIcon.tintColor = UIColor(SplickTheme.Colors.textSecondary)
        plusIcon.isUserInteractionEnabled = false
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

    private func rebuildEmojiViews() {
        guard let slotStack else { return }

        emojiSlots.forEach {
            slotStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        emojiSlots.removeAll()

        emojiSlots = emojis.enumerated().map { index, emoji in
            let slot = makeEmojiSlot(emoji: emoji, index: index)
            if let plusContainer, let plusIndex = slotStack.arrangedSubviews.firstIndex(of: plusContainer) {
                slotStack.insertArrangedSubview(slot, at: plusIndex)
            } else {
                slotStack.addArrangedSubview(slot)
            }
            return slot
        }
    }

    private func makeEmojiSlot(emoji: String, index: Int) -> UIView {
        let container = UIView()
        container.tag = index
        container.isUserInteractionEnabled = true
        container.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            container.widthAnchor.constraint(equalToConstant: slotSize),
            container.heightAnchor.constraint(equalToConstant: slotSize),
        ])

        switch EmojiKind.from(emoji) {
        case .unicode(let symbol):
            let label = UILabel()
            label.text = symbol
            label.font = .systemFont(ofSize: 24)
            label.textAlignment = .center
            label.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(label)
            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                label.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                label.topAnchor.constraint(equalTo: container.topAnchor),
                label.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            ])

        case .custom:
            let imageView = UIImageView()
            imageView.contentMode = .scaleAspectFit
            imageView.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(imageView)
            NSLayoutConstraint.activate([
                imageView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 4),
                imageView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -4),
                imageView.topAnchor.constraint(equalTo: container.topAnchor, constant: 4),
                imageView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -4),
            ])
            if let url = resolveURL?(emoji) {
                loadImage(url: url, into: imageView)
            }
        }

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleEmojiTap(_:)))
        container.addGestureRecognizer(tap)
        return container
    }

    private func loadImage(url: URL, into imageView: UIImageView) {
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data, let image = UIImage(data: data) else { return }
            DispatchQueue.main.async {
                imageView.image = image
            }
        }.resume()
    }

    @objc private func handleEmojiTap(_ gesture: UITapGestureRecognizer) {
        guard !isDragSelecting, let view = gesture.view else { return }
        commitReaction(at: view.tag)
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
        let allSlots: [UIView] = emojiSlots + (plusContainer.map { [$0] } ?? [])
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
        if index < emojiSlots.count {
            view = emojiSlots[index]
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
        guard index < emojiSlots.count else { return }
        let view = emojiSlots[index]
        impactFeedback.impactOccurred()
        view.layer.removeAllAnimations()
        view.transform = .identity
        UIView.animate(
            withDuration: 0.05,
            delay: 0,
            options: [.allowUserInteraction, .beginFromCurrentState],
            animations: {
                view.transform = CGAffineTransform(scaleX: 1.28, y: 1.28).translatedBy(x: 0, y: -4)
            },
            completion: { _ in
                UIView.animate(
                    withDuration: 0.04,
                    delay: 0,
                    options: [.allowUserInteraction, .beginFromCurrentState]
                ) {
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
        let label = emojiSlots[index]
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
