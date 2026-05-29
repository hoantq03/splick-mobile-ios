import SwiftUI

struct FlyingEmojiFlight: Identifiable {
    let id = UUID()
    let emoji: String
    let start: CGPoint
    let end: CGPoint
    let popVector: CGVector
    let lateralDrift: CGFloat
    let arcLift: CGFloat

    static func make(emoji: String, start: CGPoint, end: CGPoint) -> FlyingEmojiFlight {
        let angle = Double.random(in: (-5.0 / 6.0) * .pi ... (-1.0 / 6.0) * .pi)
        let distance = CGFloat.random(in: 22...40)
        return FlyingEmojiFlight(
            emoji: emoji,
            start: start,
            end: end,
            popVector: CGVector(
                dx: CGFloat(cos(angle)) * distance,
                dy: CGFloat(sin(angle)) * distance
            ),
            lateralDrift: CGFloat.random(in: -36...36),
            arcLift: CGFloat.random(in: 12...28)
        )
    }
}

/// Pop upward, arc toward target, shrink and fade (~0.32s total).
struct FlyingEmojiView: View {
    let flight: FlyingEmojiFlight
    let onComplete: () -> Void

    @State private var position: CGPoint
    @State private var scale: CGFloat = 1.35
    @State private var opacity: Double = 1

    init(flight: FlyingEmojiFlight, onComplete: @escaping () -> Void) {
        self.flight = flight
        self.onComplete = onComplete
        _position = State(initialValue: flight.start)
    }

    private var popEnd: CGPoint {
        CGPoint(
            x: flight.start.x + flight.popVector.dx,
            y: flight.start.y + flight.popVector.dy
        )
    }

    private var arcMid: CGPoint {
        CGPoint(
            x: (popEnd.x + flight.end.x) / 2 + flight.lateralDrift,
            y: (popEnd.y + flight.end.y) / 2 - flight.arcLift
        )
    }

    private var landPoint: CGPoint {
        CGPoint(
            x: flight.end.x + flight.lateralDrift * 0.35,
            y: flight.end.y
        )
    }

    var body: some View {
        Text(flight.emoji)
            .font(.system(size: 28))
            .scaleEffect(scale)
            .position(position)
            .opacity(opacity)
            .allowsHitTesting(false)
            .onAppear { runAnimation() }
    }

    private func runAnimation() {
        withAnimation(.spring(response: 0.08, dampingFraction: 0.55)) {
            scale = 1.7
            position = popEnd
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            withAnimation(.easeOut(duration: 0.14)) {
                position = arcMid
                scale = 0.55
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            withAnimation(.easeIn(duration: 0.10)) {
                position = landPoint
                scale = 0.26
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
            withAnimation(.easeOut(duration: 0.08)) {
                opacity = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
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
