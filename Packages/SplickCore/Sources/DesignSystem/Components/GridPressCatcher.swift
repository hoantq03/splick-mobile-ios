import SwiftUI
import UIKit

/// Tap and long-press target that does not claim the drag.
/// A `Button` or `LongPressGesture` wins the touch, so a swipe that starts on a
/// thumbnail never reaches the parent scroll view.
public struct GridPressCatcher: UIViewRepresentable {
    public var onTap: () -> Void
    public var onLongPress: () -> Void

    public init(onTap: @escaping () -> Void, onLongPress: @escaping () -> Void) {
        self.onTap = onTap
        self.onLongPress = onLongPress
    }

    public func makeUIView(context: Context) -> GridPressCatcherView {
        let view = GridPressCatcherView()
        view.onTap = onTap
        view.onLongPress = onLongPress
        return view
    }

    public func updateUIView(_ view: GridPressCatcherView, context: Context) {
        view.onTap = onTap
        view.onLongPress = onLongPress
    }

    public func sizeThatFits(
        _ proposal: ProposedViewSize,
        uiView: GridPressCatcherView,
        context: Context
    ) -> CGSize? {
        CGSize(width: proposal.width ?? 0, height: proposal.height ?? 0)
    }
}

public final class GridPressCatcherView: UIView {
    public var onTap: (() -> Void)?
    public var onLongPress: (() -> Void)?

    private var longPressTimer: Timer?
    private var originInWindow: CGPoint = .zero
    private var movedBeyondSlop = false
    private var didLongPress = false

    private static let movementSlop: CGFloat = 12
    private static let longPressDuration: TimeInterval = 0.45

    public override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        backgroundColor = .clear
        isAccessibilityElement = false
        isUserInteractionEnabled = true
        setContentHuggingPriority(.fittingSizeLevel, for: .horizontal)
        setContentHuggingPriority(.fittingSizeLevel, for: .vertical)
        setContentCompressionResistancePriority(.fittingSizeLevel, for: .horizontal)
        setContentCompressionResistancePriority(.fittingSizeLevel, for: .vertical)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) { nil }

    deinit {
        longPressTimer?.invalidate()
    }

    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        guard let touch = touches.first else { return }
        originInWindow = locationInWindow(of: touch)
        movedBeyondSlop = false
        didLongPress = false
        scheduleLongPress()
    }

    public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)
        guard let touch = touches.first else { return }
        noteMovement(of: touch)
    }

    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        if let touch = touches.first {
            noteMovement(of: touch)
        }
        let shouldTap = !movedBeyondSlop && !didLongPress
        cancelLongPress()
        if shouldTap {
            onTap?()
        }
    }

    public override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        cancelLongPress()
    }

    private func locationInWindow(of touch: UITouch) -> CGPoint {
        if let window {
            return touch.location(in: window)
        }
        return touch.location(in: self)
    }

    private func noteMovement(of touch: UITouch) {
        guard !movedBeyondSlop else { return }
        let point = locationInWindow(of: touch)
        let dx = point.x - originInWindow.x
        let dy = point.y - originInWindow.y
        guard dx * dx + dy * dy > Self.movementSlop * Self.movementSlop else { return }
        movedBeyondSlop = true
        cancelLongPress()
    }

    private func scheduleLongPress() {
        cancelLongPress()
        let timer = Timer(timeInterval: Self.longPressDuration, repeats: false) { [weak self] _ in
            self?.fireLongPress()
        }
        longPressTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func fireLongPress() {
        longPressTimer = nil
        guard !movedBeyondSlop, !didLongPress else { return }
        didLongPress = true
        onLongPress?()
    }

    private func cancelLongPress() {
        longPressTimer?.invalidate()
        longPressTimer = nil
    }
}
