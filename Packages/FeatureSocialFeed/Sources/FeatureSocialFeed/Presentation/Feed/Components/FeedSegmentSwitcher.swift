import SwiftUI
import DesignSystem
import Localization

// MARK: - Principal toolbar component (nav bar, same row as avatar)

/// Expanded: three pill tabs with slide-indicator animation.
/// Collapsing (scroll down): inactive tabs + chrome fade out;
///   active label morphs — drifts from pill position to centre and grows 14 → 17 pt.
struct FeedNavPills: View {
    @Binding var selection: FeedContentSegment
    let collapseProgress: CGFloat
    let feedLabel: String
    let albumLabel: String
    let streakLabel: String

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
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(SplickTheme.Colors.textPrimary)
                .scaleEffect((14 + 3 * t) / 17)
                .offset(x: activeLabelStartX * (1 - t))
                .opacity(t)
                .allowsHitTesting(false)
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.82), value: collapseProgress)
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
    /// Equal width per segment; kept compact for small phones (principal toolbar + avatar + bell).
    static let segmentWidth: CGFloat = 58
    static let segmentHeight: CGFloat = 28
    static let horizontalTextPadding: CGFloat = 6
    static let chromePadding: CGFloat = 2

    static var morphOffset: CGFloat { segmentWidth }
}

// MARK: - Material pills — iOS 16–25

private struct MaterialPills: View {
    @Binding var selection: FeedContentSegment
    let feedLabel: String
    let albumLabel: String
    let streakLabel: String

    @Namespace private var ns

    var body: some View {
        HStack(spacing: 0) {
            pill(.streak, label: streakLabel)
            pill(.feed, label: feedLabel)
            pill(.album, label: albumLabel)
        }
        .padding(FeedSegmentPillLayout.chromePadding)
        .background(.ultraThinMaterial, in: Capsule(style: .continuous))
        .animation(.spring(response: 0.28, dampingFraction: 0.8), value: selection)
    }

    private func pill(_ segment: FeedContentSegment, label: String) -> some View {
        let isSelected = selection == segment
        return Button {
            selection = segment
        } label: {
            Text(label)
                .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
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
                .background {
                    if isSelected {
                        Capsule(style: .continuous)
                            .fill(.regularMaterial)
                            .matchedGeometryEffect(id: "indicator", in: ns)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
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

    var body: some View {
        HStack(spacing: 0) {
            pill(.streak, label: streakLabel)
            pill(.feed, label: feedLabel)
            pill(.album, label: albumLabel)
        }
        .padding(FeedSegmentPillLayout.chromePadding)
        .background {
            Capsule(style: .continuous)
                .fill(.clear)
                .glassEffect(.regular)
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.8), value: selection)
    }

    private func pill(_ segment: FeedContentSegment, label: String) -> some View {
        let isSelected = selection == segment
        return Button {
            selection = segment
        } label: {
            Text(label)
                .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
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
                .background {
                    if isSelected {
                        Capsule(style: .continuous)
                            .fill(.clear)
                            .glassEffect(.regular)
                            .matchedGeometryEffect(id: "indicator", in: ns)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
