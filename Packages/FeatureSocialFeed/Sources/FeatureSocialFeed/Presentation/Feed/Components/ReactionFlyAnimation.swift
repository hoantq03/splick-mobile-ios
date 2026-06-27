import SwiftUI
import DesignSystem
import SplickDomain

struct FlyingEmojiFlight: Identifiable {
    let id = UUID()
    let emoji: String
    /// Tap location in global screen space — converted to card-local at render time.
    let startGlobal: CGPoint
    /// Destination in the post card's named coordinate space.
    let end: CGPoint
    let popVector: CGVector
    let lateralDrift: CGFloat
    let arcLift: CGFloat

    static func make(emoji: String, startGlobal: CGPoint, end: CGPoint) -> FlyingEmojiFlight {
        let angle = Double.random(in: (-5.0 / 6.0) * .pi ... (-1.0 / 6.0) * .pi)
        let distance = CGFloat.random(in: 22...40)
        return FlyingEmojiFlight(
            emoji: emoji,
            startGlobal: startGlobal,
            end: end,
            popVector: CGVector(
                dx: CGFloat(cos(angle)) * distance,
                dy: CGFloat(sin(angle)) * distance
            ),
            lateralDrift: CGFloat.random(in: -36...36),
            arcLift: CGFloat.random(in: 12...28)
        )
    }

    func startLocal(relativeTo cardOriginGlobal: CGPoint) -> CGPoint {
        CGPoint(
            x: startGlobal.x - cardOriginGlobal.x,
            y: startGlobal.y - cardOriginGlobal.y
        )
    }
}

/// Pop upward, arc toward target, shrink and fade (~0.22s total).
struct FlyingEmojiView: View {
    let flight: FlyingEmojiFlight
    let cardOriginGlobal: CGPoint
    let onComplete: () -> Void

    @State private var position: CGPoint = .zero
    @State private var scale: CGFloat = 1.35
    @State private var opacity: Double = 1

    private let glyphSize: CGFloat = 28

    var body: some View {
        EmojiView(value: flight.emoji, size: glyphSize)
            .frame(width: glyphSize, height: glyphSize)
            .scaleEffect(scale)
            .position(position)
            .opacity(opacity)
            .allowsHitTesting(false)
            .onAppear {
                let start = flight.startLocal(relativeTo: cardOriginGlobal)
                position = start
                runAnimation(from: start)
            }
    }

    private func runAnimation(from start: CGPoint) {
        let popEnd = CGPoint(
            x: start.x + flight.popVector.dx,
            y: start.y + flight.popVector.dy
        )
        let arcMid = CGPoint(
            x: (popEnd.x + flight.end.x) / 2 + flight.lateralDrift,
            y: (popEnd.y + flight.end.y) / 2 - flight.arcLift
        )
        let landPoint = CGPoint(
            x: flight.end.x + flight.lateralDrift * 0.35,
            y: flight.end.y
        )

        withAnimation(.spring(response: 0.06, dampingFraction: 0.62)) {
            scale = 1.55
            position = popEnd
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            withAnimation(.easeOut(duration: 0.09)) {
                position = arcMid
                scale = 0.58
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
            withAnimation(.easeIn(duration: 0.07)) {
                position = landPoint
                scale = 0.28
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.21) {
            withAnimation(.easeOut(duration: 0.05)) {
                opacity = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                onComplete()
            }
        }
    }
}

struct ReactionTargetAnchorsKey: PreferenceKey {
    static var defaultValue: [String: CGPoint] = [:]

    static func reduce(value: inout [String: CGPoint], nextValue: () -> [String: CGPoint]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

extension View {
    func reactionTargetAnchor(id: String) -> some View {
        background(
            GeometryReader { proxy in
                Color.clear.preference(
                    key: ReactionTargetAnchorsKey.self,
                    value: [id: CGPoint(x: proxy.frame(in: .named("postCard")).midX,
                                        y: proxy.frame(in: .named("postCard")).midY)]
                )
            }
        )
    }
}
