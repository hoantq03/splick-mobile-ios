import SwiftUI
import DesignSystem

/// Original SF Symbol flame, with irregular flicker/lean so it reads as fire rather than a pulse.
struct StreakFlameView: View {
    let isLit: Bool
    var size: CGFloat = 67

    var body: some View {
        Group {
            if isLit {
                TimelineView(.animation(minimumInterval: 1.0 / 45.0, paused: false)) { timeline in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    let flicker = noise(t, 6.8, 11.4, 17.2)
                    let lean = noise(t, 2.05, 3.55, 5.4)
                    FlameIcon(
                        size: size,
                        scaleY: 1.0 + flicker * 0.08,
                        scaleX: 1.0 + lean * 0.045,
                        angle: lean * 5.2,
                        glow: 0.28 + flicker * 0.12,
                        green: 0.52 + flicker * 0.16
                    )
                }
            } else {
                Image(systemName: "flame")
                    .font(.system(size: size))
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

private struct FlameIcon: View {
    let size: CGFloat
    let scaleY: CGFloat
    let scaleX: CGFloat
    let angle: Double
    let glow: CGFloat
    let green: CGFloat

    var body: some View {
        ZStack {
            Image(systemName: "flame.fill")
                .font(.system(size: size * 0.95))
                .foregroundStyle(Color.orange.opacity(glow))
                .blur(radius: 5)
                .scaleEffect(x: scaleX * 1.08, y: scaleY * 1.1, anchor: .bottom)

            Image(systemName: "flame.fill")
                .font(.system(size: size))
                .foregroundStyle(
                    Color(red: 1.0, green: min(max(green, 0.42), 0.72), blue: 0.02)
                )
                .scaleEffect(x: scaleX, y: scaleY, anchor: .bottom)
                .rotationEffect(.degrees(angle), anchor: .bottom)
        }
    }
}

private func noise(_ t: TimeInterval, _ a: Double, _ b: Double, _ c: Double) -> CGFloat {
    CGFloat(0.52 * sin(t * a) + 0.31 * sin(t * b + 1.7) + 0.17 * sin(t * c + 4.1))
}

/// Streak numeral with the same irregular fire bloom as the flame icon.
struct StreakCountView: View {
    let count: Int
    private let fontSize: CGFloat = 94

    var body: some View {
        Group {
            if count > 0 {
                TimelineView(.animation(minimumInterval: 1.0 / 45.0, paused: false)) { timeline in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    let flicker = noise(t, 6.8, 11.4, 17.2)
                    let lean = noise(t, 2.05, 3.55, 5.4)
                    BurningCount(
                        text: "\(count)",
                        fontSize: fontSize,
                        scaleY: 1.0 + flicker * 0.08,
                        scaleX: 1.0 + lean * 0.045,
                        angle: lean * 3.2,
                        glow: 0.34 + flicker * 0.16,
                        green: 0.52 + flicker * 0.16
                    )
                }
            } else {
                countLabel("0")
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
            }
        }
        .accessibilityLabel("\(count)")
    }

    private func countLabel(_ text: String) -> some View {
        Group {
            if #available(iOS 17.0, *) {
                Text(text).contentTransition(.numericText())
            } else {
                Text(text)
            }
        }
        .font(.system(size: fontSize, weight: .black, design: .rounded))
        .fontWidth(.condensed)
        .kerning(-3)
    }
}

private struct BurningCount: View {
    let text: String
    let fontSize: CGFloat
    let scaleY: CGFloat
    let scaleX: CGFloat
    let angle: Double
    let glow: CGFloat
    let green: CGFloat

    var body: some View {
        let hot = Color(red: 1.0, green: min(max(green + 0.18, 0.55), 0.88), blue: 0.12)
        let ember = Color(red: 1.0, green: min(max(green, 0.42), 0.72), blue: 0.04)

        ZStack {
            countText
                .foregroundStyle(Color.orange.opacity(glow))
                .blur(radius: 10)
                .scaleEffect(x: scaleX * 1.12, y: scaleY * 1.14, anchor: .bottom)

            countText
                .foregroundStyle(
                    LinearGradient(
                        colors: [hot, ember, Color(red: 0.92, green: 0.28, blue: 0.04)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .scaleEffect(x: scaleX, y: scaleY, anchor: .bottom)
                .rotationEffect(.degrees(angle), anchor: .bottom)
        }
    }

    private var countText: some View {
        Group {
            if #available(iOS 17.0, *) {
                Text(text).contentTransition(.numericText())
            } else {
                Text(text)
            }
        }
        .font(.system(size: fontSize, weight: .black, design: .rounded))
        .fontWidth(.condensed)
        .kerning(-3)
    }
}
