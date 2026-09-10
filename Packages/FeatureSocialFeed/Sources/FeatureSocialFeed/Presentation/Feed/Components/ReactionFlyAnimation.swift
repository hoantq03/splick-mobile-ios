import SwiftUI
import UIKit
import DesignSystem
import SplickDomain

fileprivate enum FlightLaunchStyle: CaseIterable {
    case straightUp
    case upLeft
    case upRight
}

struct FlyingEmojiFlight: Identifiable {
    let id = UUID()
    let emoji: String
    /// Full source slot frame in global screen space — lets the animation reuse the tapped emoji footprint.
    let sourceFrameGlobal: CGRect
    /// Destination in the post card's named coordinate space.
    let end: CGPoint
    fileprivate let launchStyle: FlightLaunchStyle
    let popVector: CGVector
    let lateralDrift: CGFloat
    let apexOvershoot: CGFloat

    static func make(emoji: String, sourceFrameGlobal: CGRect, end: CGPoint) -> FlyingEmojiFlight {
        let launchHorizontal: CGFloat
        let lateralDrift: CGFloat
        let launchStyle = FlightLaunchStyle.allCases.randomElement() ?? .straightUp

        switch launchStyle {
        case .upLeft:
            launchHorizontal = CGFloat.random(in: -58 ... -24)
            lateralDrift = CGFloat.random(in: -34 ... -10)
        case .upRight:
            launchHorizontal = CGFloat.random(in: 24 ... 58)
            lateralDrift = CGFloat.random(in: 10 ... 34)
        case .straightUp:
            launchHorizontal = CGFloat.random(in: -12 ... 12)
            lateralDrift = CGFloat.random(in: -18 ... 18)
        }
        let launchHeight = CGFloat.random(in: 92 ... 134)
        return FlyingEmojiFlight(
            emoji: emoji,
            sourceFrameGlobal: sourceFrameGlobal,
            end: end,
            launchStyle: launchStyle,
            popVector: CGVector(
                dx: launchHorizontal,
                dy: -launchHeight
            ),
            lateralDrift: lateralDrift,
            apexOvershoot: CGFloat.random(in: 6 ... 18)
        )
    }

    func startLocal(relativeTo cardOriginGlobal: CGPoint) -> CGPoint {
        CGPoint(
            x: sourceFrameGlobal.midX - cardOriginGlobal.x,
            y: sourceFrameGlobal.midY - cardOriginGlobal.y
        )
    }

    func sourceSize() -> CGFloat {
        max(20, min(sourceFrameGlobal.width, sourceFrameGlobal.height))
    }
}

/// Pop upward first, then fall naturally down into the avatar target.
/// Uses UIKit animation so ancestor SwiftUI `.transaction { animation = nil }`
/// (e.g. tab pagers) cannot strip the launch/fall phases.
struct FlyingEmojiView: View {
    let flight: FlyingEmojiFlight
    let cardOriginGlobal: CGPoint
    let onComplete: () -> Void

    var body: some View {
        FlyingEmojiUIKitFlight(
            flight: flight,
            cardOriginGlobal: cardOriginGlobal,
            onComplete: onComplete
        )
        .allowsHitTesting(false)
    }
}

// MARK: - UIKit-driven flight (immune to SwiftUI transaction animation = nil)

private struct FlyingEmojiUIKitFlight: UIViewRepresentable {
    let flight: FlyingEmojiFlight
    let cardOriginGlobal: CGPoint
    let onComplete: () -> Void

    func makeUIView(context: Context) -> FlyingEmojiHostView {
        let view = FlyingEmojiHostView()
        view.onComplete = onComplete
        view.start(flight: flight, cardOriginGlobal: cardOriginGlobal)
        return view
    }

    func updateUIView(_ uiView: FlyingEmojiHostView, context: Context) {
        uiView.onComplete = onComplete
        // Do not restart mid-flight when the card scrolls; position is card-local.
    }
}

private final class FlyingEmojiHostView: UIView {
    var onComplete: (() -> Void)?

    private var hosting: UIHostingController<EmojiView>?
    private var hasStarted = false

    private let launchDuration: TimeInterval = 0.19
    private let fallDuration: TimeInterval = 0.46
    private let apexHoldDuration: TimeInterval = 0.02

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isUserInteractionEnabled = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    func start(flight: FlyingEmojiFlight, cardOriginGlobal: CGPoint) {
        guard !hasStarted else { return }
        hasStarted = true

        let glyphSize = flight.sourceSize()
        let start = flight.startLocal(relativeTo: cardOriginGlobal)
        let apex = CGPoint(
            x: start.x + flight.popVector.dx,
            y: start.y + flight.popVector.dy - flight.apexOvershoot
        )
        // Land on the reactor avatar under the tray — never back onto the emoji tray.
        var end = flight.end
        let minAvatarRowY = start.y + 36
        if end.y < minAvatarRowY {
            end = CGPoint(x: end.x, y: minAvatarRowY)
        }
        let fall = CGPoint(
            x: end.x + flight.lateralDrift * 0.35,
            y: end.y
        )

        let rotationDirection: CGFloat = {
            switch flight.launchStyle {
            case .upLeft: return -1
            case .upRight: return 1
            case .straightUp: return flight.lateralDrift >= 0 ? 1 : -1
            }
        }()

        let emoji = EmojiView(value: flight.emoji, size: glyphSize)
        let host = UIHostingController(rootView: emoji)
        host.view.backgroundColor = .clear
        if #available(iOS 16.4, *) {
            host.safeAreaRegions = []
        }
        hosting = host
        addSubview(host.view)

        host.view.bounds = CGRect(x: 0, y: 0, width: glyphSize, height: glyphSize)
        host.view.center = start
        host.view.transform = .identity
        host.view.alpha = 1

        // Phase 1 — pop up and enlarge.
        UIView.animate(
            withDuration: launchDuration,
            delay: 0,
            usingSpringWithDamping: 0.72,
            initialSpringVelocity: 0.8,
            options: [.beginFromCurrentState, .allowUserInteraction, .curveEaseOut]
        ) {
            host.view.center = apex
            host.view.transform = CGAffineTransform(scaleX: 4, y: 4)
                .rotated(by: rotationDirection * 9 * .pi / 180)
        }

        // Phase 2 — fall toward avatar.
        UIView.animate(
            withDuration: fallDuration,
            delay: launchDuration + apexHoldDuration,
            options: [.beginFromCurrentState, .allowUserInteraction, .curveEaseInOut]
        ) {
            host.view.center = fall
            host.view.transform = CGAffineTransform(scaleX: 0.32, y: 0.32)
                .rotated(by: rotationDirection * -4 * .pi / 180)
        }

        // Phase 3 — settle into the badge and fade out.
        UIView.animate(
            withDuration: fallDuration * 0.18,
            delay: launchDuration + apexHoldDuration + fallDuration * 0.58,
            options: [.beginFromCurrentState, .allowUserInteraction, .curveEaseOut]
        ) {
            host.view.center = end
            host.view.transform = CGAffineTransform(scaleX: 0.14, y: 0.14)
            host.view.alpha = 0
        } completion: { [weak self] _ in
            self?.onComplete?()
        }
    }
}

struct ReactionTargetAnchorsKey: PreferenceKey {
    static var defaultValue: [String: CGPoint] = [:]

    static func reduce(value: inout [String: CGPoint], nextValue: () -> [String: CGPoint]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

enum ReactionAnchorPlacement {
    case center
    case topTrailing(xInset: CGFloat = 4, yInset: CGFloat = 4)
}

private struct ReactionAnchorTrackingEnabledKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var reactionAnchorTrackingEnabled: Bool {
        get { self[ReactionAnchorTrackingEnabledKey.self] }
        set { self[ReactionAnchorTrackingEnabledKey.self] = newValue }
    }
}

extension View {
    func reactionTargetAnchor(
        id: String,
        placement: ReactionAnchorPlacement = .center
    ) -> some View {
        modifier(ReactionTargetAnchorModifier(id: id, placement: placement))
    }
}

private struct ReactionTargetAnchorModifier: ViewModifier {
    let id: String
    let placement: ReactionAnchorPlacement
    @Environment(\.reactionAnchorTrackingEnabled) private var isEnabled

    func body(content: Content) -> some View {
        if isEnabled {
            content.background(
                GeometryReader { proxy in
                    let frame = proxy.frame(in: .named("postCard"))
                    let point: CGPoint = {
                        switch placement {
                        case .center:
                            return CGPoint(x: frame.midX, y: frame.midY)
                        case .topTrailing(let xInset, let yInset):
                            return CGPoint(x: frame.maxX - xInset, y: frame.minY + yInset)
                        }
                    }()
                    Color.clear.preference(
                        key: ReactionTargetAnchorsKey.self,
                        value: [id: point]
                    )
                }
            )
        } else {
            content
        }
    }
}
