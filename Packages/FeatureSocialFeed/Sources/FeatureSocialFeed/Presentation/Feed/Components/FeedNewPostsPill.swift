import SwiftUI
import UIKit
import DesignSystem
import Localization

struct FeedNewPostsPillOverlay: View {
    let count: Int
    let onTap: () -> Void

    /// iOS 26's Liquid Glass bar is taller than the 48pt metric that lines up on iOS 17.
    private var glassBarExtra: CGFloat {
        if #available(iOS 26.0, *) {
            return 16
        }
        return 0
    }

    var body: some View {
        GeometryReader { geometry in
            // Mirror the same coordinate origin as FeedScrollTopFadeOverlay:
            // ignoresSafeArea(.top) → frame starts at y=0 → safeAreaInsets.top includes
            // the actual status-bar + navigation-bar height reported by the OS.
            let topInset = geometry.safeAreaInsets.top
                + FeedSegmentChromeMetrics.navigationBarHeight
                + FeedSegmentChromeMetrics.segmentRowHeight
                + SplickTheme.Spacing.sm
                + glassBarExtra

            VStack(spacing: 0) {
                FeedNewPostsPill(count: count, onTap: onTap)
                    .padding(.top, topInset)
                Spacer(minLength: 0)
                    .allowsHitTesting(false)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .ignoresSafeArea(edges: .top)
        .allowsHitTesting(count > 0)
    }
}

/// Green liquid falls as a drop, bounces, then spreads into the pill.
/// The label stays crisp and only fades in once the drop has spread.
struct FeedNewPostsPill: View {
    @EnvironmentObject private var languageService: LanguageService
    let count: Int
    let onTap: () -> Void

    private enum MotionKind {
        case enter
        case exit
    }

    private struct Playback {
        let kind: MotionKind
        let start: Date
        let duration: TimeInterval
        let token: Int
    }

    @State private var isPresented = false
    @State private var displayedCount = 0
    @State private var restSize: CGSize = CGSize(width: 148, height: 34)
    @State private var playback: Playback?
    @State private var motionToken = 0
    @State private var pendingTap = false

    var body: some View {
        Group {
            if isPresented {
                pill
            }
        }
        .onAppear { handleCountChange(count) }
        .onChange(of: count) { newCount in
            handleCountChange(newCount)
        }
        .task(id: motionToken) {
            await finishWhenElapsed()
        }
    }

    private var pill: some View {
        label(opacity: 0)
            .accessibilityHidden(true)
            .background(restSizeReader)
            .overlay { animatedLayer }
            .contentShape(Capsule(style: .continuous))
            .onTapGesture(perform: handleTap)
            .accessibilityElement(children: .ignore)
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(languageService.format(.feedNewPostsCount, max(displayedCount, 1)))
    }

    /// Layout slot stays the final pill size. The drop moves inside the overlay.
    private var animatedLayer: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 120.0, paused: playback == nil)) { context in
            let pose = pose(at: context.date)
            ZStack {
                blob(pose)
                label(opacity: pose.textOpacity)
            }
        }
    }

    /// Capsule ends stay semicircles. Exit draws that shape directly so shrinking
    /// never squishes them into ellipses.
    @ViewBuilder
    private func blob(_ pose: DropPose) -> some View {
        let shape = pose.circular
            ? AnyShape(Capsule())
            : AnyShape(Capsule(style: .continuous))
        shape
            .fill(SplickTheme.Colors.success)
            .shadow(color: .black.opacity(0.16), radius: 6, y: 2)
            .frame(
                width: pose.circular ? pose.blobWidth : restSize.width,
                height: pose.circular ? pose.blobHeight : restSize.height
            )
            .scaleEffect(
                x: pose.circular ? 1 : pose.scaleX,
                y: pose.circular ? 1 : pose.scaleY,
                anchor: .center
            )
            .offset(y: pose.offsetY)
            .opacity(pose.blobOpacity)
    }

    private var restSizeReader: some View {
        GeometryReader { proxy in
            Color.clear.preference(key: PillRestSizeKey.self, value: proxy.size)
        }
        .onPreferenceChange(PillRestSizeKey.self) { size in
            guard size.width > 1, size.height > 1 else { return }
            restSize = size
        }
    }

    private func label(opacity: Double) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.up")
                .font(.system(size: 13, weight: .bold))
            Text(languageService.format(.feedNewPostsCount, max(displayedCount, 1)))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .contentTransition(.numericText())
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .opacity(opacity)
    }

    private func handleTap() {
        guard playback?.kind != .exit else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        pendingTap = true
        play(.exit)
    }

    private func handleCountChange(_ newCount: Int) {
        if newCount > 0 {
            let wasHidden = !isPresented || playback?.kind == .exit
            displayedCount = newCount
            if wasHidden {
                pendingTap = false
                play(.enter)
            }
        } else if isPresented, playback?.kind != .exit {
            pendingTap = false
            play(.exit)
        }
    }

    private func play(_ kind: MotionKind) {
        motionToken += 1
        isPresented = true
        playback = Playback(
            kind: kind,
            start: Date(),
            duration: kind == .enter ? 0.60 : 0.46,
            token: motionToken
        )
    }

    private func finishWhenElapsed() async {
        guard let playback else { return }
        let remaining = playback.duration - Date().timeIntervalSince(playback.start)
        if remaining > 0 {
            try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
        }
        guard !Task.isCancelled, self.playback?.token == playback.token else { return }
        switch playback.kind {
        case .enter:
            self.playback = nil
        case .exit:
            let shouldTap = pendingTap
            pendingTap = false
            self.playback = nil
            isPresented = false
            displayedCount = 0
            if shouldTap {
                onTap()
            }
        }
    }

    private func pose(at date: Date) -> DropPose {
        guard let playback else {
            return DropPose(scaleX: 1, scaleY: 1, offsetY: 0, textOpacity: 1, blobOpacity: 1)
        }
        let raw = date.timeIntervalSince(playback.start) / playback.duration
        let progress = CGFloat(min(max(raw, 0), 1))
        switch playback.kind {
        case .enter:
            return enterPose(progress)
        case .exit:
            return exitPose(progress)
        }
    }

    /// Drop falls, hits, bounces, then the green body spreads to the pill.
    private func enterPose(_ progress: CGFloat) -> DropPose {
        let width = max(restSize.width, 1)
        let height = max(restSize.height, 1)
        let drop = min(height, 16)
        let fallEnd: CGFloat = 0.40

        if progress <= fallEnd {
            let u = progress / fallEnd
            let fall = u * u
            let stretch = 1 + (0.55 * u)
            return DropPose(
                scaleX: drop / width,
                scaleY: (drop * stretch) / height,
                offsetY: lerp(-76, 6, fall),
                textOpacity: 0,
                blobOpacity: min(1, Double(u) / 0.2)
            )
        }

        let u = (progress - fallEnd) / (1 - fallEnd)
        let spread = 1 - pow(1 - u, 3)
        let bounce = sin(u * .pi) * exp(-2.4 * u)
        let squash = sin(u * .pi) * exp(-1.6 * u)
        let visualWidth = lerp(drop, width, spread) * (1 + 0.06 * squash)
        let visualHeight = lerp(drop * 1.35, height, spread) * (1 - 0.28 * squash)
        return DropPose(
            scaleX: visualWidth / width,
            scaleY: max(visualHeight, 8) / height,
            offsetY: lerp(6, 0, spread) - (14 * bounce),
            textOpacity: Double(spread * spread),
            blobOpacity: 1
        )
    }

    /// Text leaves, the two round ends draw together into one circle, then that circle hops and fades.
    private func exitPose(_ progress: CGFloat) -> DropPose {
        let width = max(restSize.width, 1)
        let height = max(restSize.height, 1)
        let textEnd: CGFloat = 0.14
        let gatherEnd: CGFloat = 0.50
        let hopEnd: CGFloat = 0.82

        if progress <= textEnd {
            let u = progress / textEnd
            return DropPose(
                offsetY: 0,
                textOpacity: Double(1 - u),
                blobOpacity: 1,
                blobWidth: width,
                blobHeight: height,
                circular: true
            )
        }

        if progress <= gatherEnd {
            let u = (progress - textEnd) / (gatherEnd - textEnd)
            let gathered = u * u * (3 - 2 * u)
            return DropPose(
                offsetY: 0,
                textOpacity: 0,
                blobOpacity: 1,
                blobWidth: max(height, lerp(width, height, gathered)),
                blobHeight: height,
                circular: true
            )
        }

        if progress <= hopEnd {
            let u = (progress - gatherEnd) / (hopEnd - gatherEnd)
            let hop = sin(u * .pi)
            return DropPose(
                offsetY: -16 * hop,
                textOpacity: 0,
                blobOpacity: 1,
                blobWidth: height,
                blobHeight: height,
                circular: true
            )
        }

        let u = (progress - hopEnd) / (1 - hopEnd)
        let fade = u * u * (3 - 2 * u)
        let diameter = height * (1 - 0.35 * fade)
        return DropPose(
            offsetY: lerp(0, -8, fade),
            textOpacity: 0,
            blobOpacity: Double(1 - fade),
            blobWidth: diameter,
            blobHeight: diameter,
            circular: true
        )
    }
}

private struct DropPose {
    var scaleX: CGFloat = 1
    var scaleY: CGFloat = 1
    var offsetY: CGFloat
    var textOpacity: Double
    var blobOpacity: Double
    /// Used when `circular` is true. Width stays ≥ height so the capsule ends remain semicircles.
    var blobWidth: CGFloat = 0
    var blobHeight: CGFloat = 0
    var circular: Bool = false
}

private func lerp(_ from: CGFloat, _ to: CGFloat, _ t: CGFloat) -> CGFloat {
    from + (to - from) * t
}

private struct PillRestSizeKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        let next = nextValue()
        if next.width > 1, next.height > 1 {
            value = next
        }
    }
}
