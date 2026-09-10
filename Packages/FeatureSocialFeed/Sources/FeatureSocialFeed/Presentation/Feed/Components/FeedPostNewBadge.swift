import SwiftUI
import UIKit
import DesignSystem
import Localization

/// Italic "NEW" marker that dissolves into green dust when dismissed.
/// Dust is drawn in a UIKit overlay (clipsToBounds = false) so it cannot
/// reflow the post card and is not clipped to the badge bounds.
struct FeedPostNewBadge: View {
    @EnvironmentObject private var languageService: LanguageService
    var visible: Bool
    var onDismissed: () -> Void = {}

    @State private var dissolving = false
    @State private var badgeOpacity: CGFloat = 1
    @State private var badgeScale: CGFloat = 1
    @State private var burstToken = 0
    @State private var dissolveTask: Task<Void, Never>?

    var body: some View {
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
            .overlay {
                DustBurstHost(token: burstToken, color: UIColor(SplickTheme.Colors.success))
                    .frame(width: 96, height: 64)
                    .allowsHitTesting(false)
            }
            .accessibilityLabel(languageService.text(.feedPostNewBadge))
            .accessibilityHidden(dissolving)
            .onChange(of: visible) { isVisible in
                if isVisible {
                    dissolveTask?.cancel()
                    dissolveTask = nil
                    dissolving = false
                    badgeOpacity = 1
                    badgeScale = 1
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
        badgeOpacity = 1
        badgeScale = 1
        burstToken += 1

        withAnimation(.easeOut(duration: 0.24)) {
            badgeOpacity = 0
            badgeScale = 0.9
        }

        dissolveTask?.cancel()
        dissolveTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 640_000_000)
            guard !Task.isCancelled else { return }
            dissolving = false
            onDismissed()
            dissolveTask = nil
        }
    }
}

private struct DustBurstHost: UIViewRepresentable {
    let token: Int
    let color: UIColor

    func makeUIView(context: Context) -> DustBurstView {
        let view = DustBurstView()
        view.dustColor = color
        return view
    }

    func updateUIView(_ uiView: DustBurstView, context: Context) {
        uiView.dustColor = color
        if token != context.coordinator.lastToken {
            context.coordinator.lastToken = token
            if token > 0 {
                uiView.play()
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        var lastToken = 0
    }
}

private final class DustBurstView: UIView {
    var dustColor: UIColor = .systemGreen

    private struct Spec {
        var angle: CGFloat
        var travel: CGFloat
        var radius: CGFloat
        var delay: CGFloat
    }

    private var specs: [Spec] = []
    private var progress: CGFloat = 0
    private var displayLink: CADisplayLink?
    private var startedAt: CFTimeInterval = 0
    private let duration: CFTimeInterval = 0.62

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
        isUserInteractionEnabled = false
        clipsToBounds = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    func play() {
        specs = (0..<20).map { _ in
            Spec(
                angle: CGFloat.random(in: 0...(2 * .pi)),
                travel: CGFloat.random(in: 14...40),
                radius: CGFloat.random(in: 2.2...4.6),
                delay: CGFloat.random(in: 0...0.14)
            )
        }
        progress = 0
        startedAt = CACurrentMediaTime()
        displayLink?.invalidate()
        let link = CADisplayLink(target: self, selector: #selector(tick))
        link.add(to: .main, forMode: .common)
        displayLink = link
        setNeedsDisplay()
    }

    @objc private func tick() {
        let t = min(1, (CACurrentMediaTime() - startedAt) / duration)
        progress = t
        setNeedsDisplay()
        if t >= 1 {
            displayLink?.invalidate()
            displayLink = nil
            specs = []
            setNeedsDisplay()
        }
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext(), !specs.isEmpty else { return }
        let origin = CGPoint(x: rect.midX, y: rect.midY)
        for spec in specs {
            let span = max(0.45, 1 - spec.delay)
            let t = max(0, min(1, (progress - spec.delay) / span))
            guard t > 0 else { continue }
            let eased = 1 - (1 - t) * (1 - t)
            let x = origin.x + cos(spec.angle) * spec.travel * eased
            let y = origin.y + sin(spec.angle) * spec.travel * eased - 8 * eased
            let alpha = max(0, 1 - t) * 0.92
            guard alpha > 0.03 else { continue }
            context.setFillColor(dustColor.withAlphaComponent(alpha).cgColor)
            let r = spec.radius * (1.05 - t * 0.35)
            context.fillEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
        }
    }

    deinit {
        displayLink?.invalidate()
    }
}
