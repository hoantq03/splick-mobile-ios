import SwiftUI
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
struct FlyingEmojiView: View {
    let flight: FlyingEmojiFlight
    let cardOriginGlobal: CGPoint
    let onComplete: () -> Void

    @State private var animatedPosition: CGPoint = .zero
    @State private var animatedScale: CGFloat = 1
    @State private var animatedOpacity: Double = 1
    @State private var animatedRotation: Double = 0
    @State private var hasStarted = false

    private let launchDuration: TimeInterval = 0.19
    private let fallDuration: TimeInterval = 0.46
    private let apexHoldDuration: TimeInterval = 0.02

    var body: some View {
        EmojiView(value: flight.emoji, size: glyphSize)
            .frame(width: glyphSize, height: glyphSize)
            .scaleEffect(animatedScale)
            .rotationEffect(.degrees(animatedRotation))
            .position(hasStarted ? animatedPosition : startPoint)
            .opacity(animatedOpacity)
            .allowsHitTesting(false)
            .onAppear {
                runAnimation()
            }
    }

    private var startPoint: CGPoint {
        flight.startLocal(relativeTo: cardOriginGlobal)
    }

    private var glyphSize: CGFloat {
        flight.sourceSize()
    }
    
    private var apexPoint: CGPoint {
        let start = startPoint
        return CGPoint(
            x: start.x + flight.popVector.dx,
            y: start.y + flight.popVector.dy - flight.apexOvershoot
        )
    }

    private var fallPoint: CGPoint {
        CGPoint(
            x: flight.end.x + flight.lateralDrift,
            y: flight.end.y
        )
    }

    private var launchRotation: Double {
        rotationDirection * 9
    }

    private var fallRotation: Double {
        rotationDirection * -4
    }

    private var settledRotation: Double {
        0
    }

    private var rotationDirection: Double {
        switch flight.launchStyle {
        case .upLeft:
            return -1
        case .upRight:
            return 1
        case .straightUp:
            return flight.lateralDrift >= 0 ? 1 : -1
        }
    }
    
    private func runAnimation() {
        hasStarted = true
        animatedPosition = startPoint
        animatedScale = 1
        animatedOpacity = 1
        animatedRotation = 0

        withAnimation(.interpolatingSpring(stiffness: 260, damping: 24)) {
            animatedPosition = apexPoint
            animatedScale = 4
            animatedRotation = launchRotation
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + launchDuration + apexHoldDuration) {
            withAnimation(.timingCurve(0.18, 0.78, 0.28, 1, duration: fallDuration)) {
                animatedPosition = fallPoint
                animatedScale = 0.32
                animatedRotation = fallRotation
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + launchDuration + apexHoldDuration + fallDuration * 0.58) {
            withAnimation(.easeOut(duration: fallDuration * 0.18)) {
                animatedPosition = flight.end
                animatedScale = 0.14
                animatedOpacity = 0
                animatedRotation = settledRotation
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + launchDuration + apexHoldDuration + fallDuration) {
            onComplete()
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

extension View {
    func reactionTargetAnchor(
        id: String,
        placement: ReactionAnchorPlacement = .center
    ) -> some View {
        background(
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
    }
}
