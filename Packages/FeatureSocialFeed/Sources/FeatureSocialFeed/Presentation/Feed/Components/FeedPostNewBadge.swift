import SwiftUI
import DesignSystem
import Localization

/// Italic "NEW" marker that dissolves into green dust when dismissed.
/// Parent must keep this view mounted until `onDismissed` is called.
struct FeedPostNewBadge: View {
    @EnvironmentObject private var languageService: LanguageService
    var visible: Bool
    var onDismissed: () -> Void = {}

    @State private var dissolving = false
    @State private var badgeOpacity: CGFloat = 1
    @State private var badgeScale: CGFloat = 1
    @State private var dustProgress: CGFloat = 0
    @State private var particles: [DustSpec] = []
    @State private var dissolveTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            Text(languageService.text(.feedPostNewBadge))
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .italic()
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(SplickTheme.Colors.success)
                }
                .opacity(badgeOpacity)
                .scaleEffect(badgeScale)
                .accessibilityLabel(languageService.text(.feedPostNewBadge))
                .accessibilityHidden(dissolving)

            if dissolving {
                ForEach(particles) { spec in
                    DustParticleView(spec: spec, progress: dustProgress)
                }
            }
        }
        .frame(width: dissolving ? 88 : nil, height: dissolving ? 56 : nil)
        .zIndex(dissolving ? 4 : 0)
        .onChange(of: visible) { isVisible in
            if isVisible {
                dissolveTask?.cancel()
                dissolveTask = nil
                dissolving = false
                particles = []
                badgeOpacity = 1
                badgeScale = 1
                dustProgress = 0
            } else {
                startDissolveIfNeeded()
            }
        }
        .onAppear {
            if !visible {
                startDissolveIfNeeded()
            }
        }
        .onDisappear {
            dissolveTask?.cancel()
            dissolveTask = nil
        }
    }

    private func startDissolveIfNeeded() {
        guard !dissolving else { return }
        dissolving = true
        particles = DustSpec.burst()
        dustProgress = 0
        badgeOpacity = 1
        badgeScale = 1

        withAnimation(.easeOut(duration: 0.42)) {
            badgeOpacity = 0
            badgeScale = 0.72
        }

        dissolveTask?.cancel()
        dissolveTask = Task { @MainActor in
            let frames = 48
            let stepNanos: UInt64 = 16_000_000
            for frame in 1...frames {
                try? await Task.sleep(nanoseconds: stepNanos)
                guard !Task.isCancelled else { return }
                dustProgress = CGFloat(frame) / CGFloat(frames)
            }
            guard !Task.isCancelled else { return }
            dissolving = false
            particles = []
            dustProgress = 0
            onDismissed()
            dissolveTask = nil
        }
    }
}

private struct DustParticleView: View {
    let spec: DustSpec
    let progress: CGFloat

    var body: some View {
        let span = max(0.35, 1 - spec.delay)
        let t = max(0, min(1, (progress - spec.delay) / span))
        let eased = 1 - (1 - t) * (1 - t)
        let dx = cos(spec.angle) * spec.travel * eased
        let dy = sin(spec.angle) * spec.travel * eased - 12 * eased
        Circle()
            .fill(SplickTheme.Colors.success.opacity(Double(max(0, (1 - t) * 0.95))))
            .frame(width: spec.radius * 2, height: spec.radius * 2)
            .offset(x: dx, y: dy)
            .opacity(t <= 0 ? 0 : 1)
    }
}

private struct DustSpec: Identifiable {
    let id: Int
    let angle: CGFloat
    let travel: CGFloat
    let radius: CGFloat
    let delay: CGFloat

    static func burst(count: Int = 16) -> [DustSpec] {
        let upwardBias = -CGFloat.pi / 2
        return (0..<count).map { index in
            DustSpec(
                id: index,
                angle: upwardBias + CGFloat.random(in: -1.05...1.05) * .pi,
                travel: CGFloat.random(in: 22...56),
                radius: CGFloat.random(in: 1.8...3.6),
                delay: CGFloat.random(in: 0...0.16)
            )
        }
    }
}
