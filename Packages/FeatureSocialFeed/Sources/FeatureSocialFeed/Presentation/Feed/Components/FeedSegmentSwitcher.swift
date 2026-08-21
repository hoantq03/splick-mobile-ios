import SwiftUI
import DesignSystem
import Localization

// MARK: - Principal toolbar component (nav bar, same row as avatar)

/// Expanded: three pill tabs with slide-indicator animation.
/// Collapsing (scroll down): inactive tabs + chrome fade out;
///   active label morphs — drifts from pill position to centre and grows 14 → 17 pt.
struct FeedNavPills: View {
    @Binding var selection: FeedContentSegment
    @ObservedObject var scrollState: FeedSegmentScrollState
    let feedLabel: String
    let albumLabel: String
    let streakLabel: String

    private var collapseProgress: CGFloat { scrollState.collapseProgress }
    private var t: CGFloat { FeedSegmentMorphLayout.smoothstep(collapseProgress) }
    private var activeLabel: String {
        switch selection {
        case .feed: return feedLabel
        case .album: return albumLabel
        case .streak: return streakLabel
        }
    }

    /// Horizontal offset of the active pill centre from the strip centre (equal-width segments).
    private var activeLabelStartX: CGFloat {
        switch selection {
        case .streak: return -FeedSegmentPillLayout.morphOffset
        case .feed: return 0
        case .album: return FeedSegmentPillLayout.morphOffset
        }
    }

    var body: some View {
        ZStack {
            // Full pill strip (chrome + all labels) — fades out together.
            pillsContent
                .opacity(1 - t)
                .allowsHitTesting(collapseProgress < 0.5)

            // Active label only — morphs: drifts to centre and grows.
            Text(activeLabel)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(SplickTheme.Colors.textPrimary)
                .scaleEffect((16 + 4 * t) / 20)
                .offset(x: activeLabelStartX * (1 - t))
                .opacity(t)
                .allowsHitTesting(false)
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.80), value: selection)
    }

    @ViewBuilder
    private var pillsContent: some View {
        if #available(iOS 26.0, *) {
            GlassPills(
                selection: $selection,
                feedLabel: feedLabel,
                albumLabel: albumLabel,
                streakLabel: streakLabel
            )
        } else {
            MaterialPills(
                selection: $selection,
                feedLabel: feedLabel,
                albumLabel: albumLabel,
                streakLabel: streakLabel
            )
        }
    }
}

// MARK: - Morph helpers

enum FeedSegmentMorphLayout {
    static func smoothstep(_ progress: CGFloat) -> CGFloat {
        let c = min(1, max(0, progress))
        return c * c * (3 - 2 * c)
    }
}

enum FeedSegmentPillLayout {
    /// Equal width per segment; sized for principal toolbar + avatar + bell.
    static let segmentWidth: CGFloat = 66
    static let segmentHeight: CGFloat = 34
    static let horizontalTextPadding: CGFloat = 8
    static let chromePadding: CGFloat = 3
    static let stripSegmentCount: CGFloat = 3
    static let stripWidth: CGFloat = (segmentWidth * stripSegmentCount) + (chromePadding * 2)
    static let stripHeight: CGFloat = segmentHeight + (chromePadding * 2)

    static var morphOffset: CGFloat { segmentWidth }
}

private enum FeedSegmentStripMotion {
    static let selectionSpring = Animation.spring(response: 0.28, dampingFraction: 0.80)
    static let pressSpring = Animation.spring(response: 0.22, dampingFraction: 0.72)
}

private let feedSegmentStripOrder: [FeedContentSegment] = [.streak, .feed, .album]

// MARK: - Material pills — iOS 16–25

private struct MaterialPills: View {
    @Binding var selection: FeedContentSegment
    let feedLabel: String
    let albumLabel: String
    let streakLabel: String

    @Namespace private var ns
    @State private var hoverSegment: FeedContentSegment?
    @State private var isInteracting = false

    var body: some View {
        GeometryReader { proxy in
            HStack(spacing: 0) {
                pill(.streak, label: streakLabel)
                pill(.feed, label: feedLabel)
                pill(.album, label: albumLabel)
            }
            .padding(FeedSegmentPillLayout.chromePadding)
            .frame(width: proxy.size.width, height: proxy.size.height)
            .background(SplickTheme.Colors.cardBackground, in: Capsule(style: .continuous))
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(SplickTheme.Colors.primaryGradientStart.opacity(0.10), lineWidth: 1)
            }
            .contentShape(Capsule(style: .continuous))
            .simultaneousGesture(stripGesture(totalWidth: proxy.size.width))
        }
        .frame(width: FeedSegmentPillLayout.stripWidth, height: FeedSegmentPillLayout.stripHeight)
        .animation(FeedSegmentStripMotion.selectionSpring, value: selection)
        .animation(FeedSegmentStripMotion.pressSpring, value: hoverSegment)
        .animation(FeedSegmentStripMotion.pressSpring, value: isInteracting)
    }

    private func pill(_ segment: FeedContentSegment, label: String) -> some View {
        let isSelected = selection == segment
        let isEmphasized = isSelected && (hoverSegment == segment || (hoverSegment == nil && isInteracting))
        return Button {
            guard selection != segment else { return }
            withAnimation(FeedSegmentStripMotion.selectionSpring) {
                selection = segment
            }
        } label: {
            Text(label)
                .font(.system(size: 15, weight: isSelected ? .semibold : .medium))
                .foregroundStyle(
                    isSelected
                        ? SplickTheme.Colors.textPrimary
                        : SplickTheme.Colors.textSecondary
                )
                .opacity(isSelected ? 1 : 0.55)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .padding(.horizontal, FeedSegmentPillLayout.horizontalTextPadding)
                .frame(
                    width: FeedSegmentPillLayout.segmentWidth,
                    height: FeedSegmentPillLayout.segmentHeight
                )
                .scaleEffect(isEmphasized ? 1.03 : 1)
                .background {
                    if isSelected {
                        Capsule(style: .continuous)
                            .fill(SplickTheme.Colors.background)
                            .overlay {
                                Capsule(style: .continuous)
                                    .stroke(.white.opacity(isEmphasized ? 0.75 : 0.45), lineWidth: 0.8)
                            }
                            .scaleEffect(isEmphasized ? 1.08 : 1)
                            .matchedGeometryEffect(id: "indicator", in: ns)
                    }
                }
        }
        .buttonStyle(.plain)
        .hoverEffect(.lift)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func stripGesture(totalWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                isInteracting = true
                guard let segment = segment(at: value.location.x, totalWidth: totalWidth) else { return }
                hoverSegment = segment
                guard selection != segment else { return }
                withAnimation(FeedSegmentStripMotion.selectionSpring) {
                    selection = segment
                }
            }
            .onEnded { value in
                if let segment = segment(at: value.location.x, totalWidth: totalWidth) ?? hoverSegment,
                   selection != segment {
                    withAnimation(FeedSegmentStripMotion.selectionSpring) {
                        selection = segment
                    }
                }
                withAnimation(FeedSegmentStripMotion.pressSpring) {
                    hoverSegment = nil
                    isInteracting = false
                }
            }
    }

    private func segment(at locationX: CGFloat, totalWidth: CGFloat) -> FeedContentSegment? {
        let leading = FeedSegmentPillLayout.chromePadding
        let trailing = totalWidth - FeedSegmentPillLayout.chromePadding
        guard locationX >= leading, locationX <= trailing else { return nil }
        let relativeX = min(max(locationX - leading, 0), totalWidth - (FeedSegmentPillLayout.chromePadding * 2) - 1)
        let index = min(Int(relativeX / FeedSegmentPillLayout.segmentWidth), feedSegmentStripOrder.count - 1)
        return feedSegmentStripOrder[index]
    }
}

// MARK: - Glass pills — iOS 26+

@available(iOS 26.0, *)
private struct GlassPills: View {
    @Binding var selection: FeedContentSegment
    let feedLabel: String
    let albumLabel: String
    let streakLabel: String

    @Namespace private var ns
    @State private var hoverSegment: FeedContentSegment?
    @State private var isInteracting = false

    var body: some View {
        GeometryReader { proxy in
            HStack(spacing: 0) {
                pill(.streak, label: streakLabel)
                pill(.feed, label: feedLabel)
                pill(.album, label: albumLabel)
            }
            .padding(FeedSegmentPillLayout.chromePadding)
            .frame(width: proxy.size.width, height: proxy.size.height)
            .background {
                Capsule(style: .continuous)
                    .fill(.clear)
                    .glassEffect(.regular)
                    .overlay {
                        Capsule(style: .continuous)
                            .stroke(.white.opacity(0.30), lineWidth: 0.8)
                    }
            }
            .contentShape(Capsule(style: .continuous))
            .simultaneousGesture(stripGesture(totalWidth: proxy.size.width))
        }
        .frame(width: FeedSegmentPillLayout.stripWidth, height: FeedSegmentPillLayout.stripHeight)
        .animation(FeedSegmentStripMotion.selectionSpring, value: selection)
        .animation(FeedSegmentStripMotion.pressSpring, value: hoverSegment)
        .animation(FeedSegmentStripMotion.pressSpring, value: isInteracting)
    }

    private func pill(_ segment: FeedContentSegment, label: String) -> some View {
        let isSelected = selection == segment
        let isEmphasized = isSelected && (hoverSegment == segment || (hoverSegment == nil && isInteracting))
        return Button {
            guard selection != segment else { return }
            withAnimation(FeedSegmentStripMotion.selectionSpring) {
                selection = segment
            }
        } label: {
            Text(label)
                .font(.system(size: 15, weight: isSelected ? .semibold : .medium))
                .foregroundStyle(
                    isSelected
                        ? SplickTheme.Colors.textPrimary
                        : SplickTheme.Colors.textSecondary
                )
                .opacity(isSelected ? 1 : 0.55)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .padding(.horizontal, FeedSegmentPillLayout.horizontalTextPadding)
                .frame(
                    width: FeedSegmentPillLayout.segmentWidth,
                    height: FeedSegmentPillLayout.segmentHeight
                )
                .scaleEffect(isEmphasized ? 1.03 : 1)
                .background {
                    if isSelected {
                        Capsule(style: .continuous)
                            .fill(.clear)
                            .glassEffect(.regular)
                            .overlay {
                                Capsule(style: .continuous)
                                    .stroke(.white.opacity(isEmphasized ? 0.55 : 0.32), lineWidth: 0.9)
                            }
                            .shadow(color: .white.opacity(isEmphasized ? 0.18 : 0.08), radius: isEmphasized ? 12 : 6, y: isEmphasized ? 4 : 2)
                            .scaleEffect(isEmphasized ? 1.10 : 1)
                            .matchedGeometryEffect(id: "indicator", in: ns)
                    }
                }
        }
        .buttonStyle(.plain)
        .hoverEffect(.lift)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func stripGesture(totalWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                isInteracting = true
                guard let segment = segment(at: value.location.x, totalWidth: totalWidth) else { return }
                hoverSegment = segment
                guard selection != segment else { return }
                withAnimation(FeedSegmentStripMotion.selectionSpring) {
                    selection = segment
                }
            }
            .onEnded { value in
                if let segment = segment(at: value.location.x, totalWidth: totalWidth) ?? hoverSegment,
                   selection != segment {
                    withAnimation(FeedSegmentStripMotion.selectionSpring) {
                        selection = segment
                    }
                }
                withAnimation(FeedSegmentStripMotion.pressSpring) {
                    hoverSegment = nil
                    isInteracting = false
                }
            }
    }

    private func segment(at locationX: CGFloat, totalWidth: CGFloat) -> FeedContentSegment? {
        let leading = FeedSegmentPillLayout.chromePadding
        let trailing = totalWidth - FeedSegmentPillLayout.chromePadding
        guard locationX >= leading, locationX <= trailing else { return nil }
        let relativeX = min(max(locationX - leading, 0), totalWidth - (FeedSegmentPillLayout.chromePadding * 2) - 1)
        let index = min(Int(relativeX / FeedSegmentPillLayout.segmentWidth), feedSegmentStripOrder.count - 1)
        return feedSegmentStripOrder[index]
    }
}
