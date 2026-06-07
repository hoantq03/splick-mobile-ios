import SwiftUI
import DesignSystem
import Localization

// MARK: - Principal toolbar component (nav bar, same row as avatar)

/// Expanded: pill tabs with slide-indicator animation.
/// Collapsing (scroll down): inactive tab + chrome fade out;
///   active label morphs — drifts from pill position to centre and grows 14 → 17 pt.
struct FeedNavPills: View {
    @Binding var selection: FeedContentSegment
    let collapseProgress: CGFloat
    let feedLabel: String
    let albumLabel: String

    private var t: CGFloat { FeedSegmentMorphLayout.smoothstep(collapseProgress) }
    private var activeLabel: String { selection == .feed ? feedLabel : albumLabel }

    /// Approximate horizontal offset of the active pill centre from the ZStack centre.
    /// Pills are roughly 180 pt wide; each half ≈ 45 pt from centre.
    private var activeLabelStartX: CGFloat { selection == .feed ? -38 : 38 }

    var body: some View {
        ZStack {
            // Full pill strip (chrome + both labels) — fades out together.
            pillsContent
                .opacity(1 - t)
                .allowsHitTesting(collapseProgress < 0.5)

            // Active label only — morphs: drifts to centre and grows.
            Text(activeLabel)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(SplickTheme.Colors.textPrimary)
                .scaleEffect((14 + 3 * t) / 17)            // 14 pt (scaled) → 17 pt
                .offset(x: activeLabelStartX * (1 - t))    // pill pos → centre
                .opacity(t)
                .allowsHitTesting(false)
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.82), value: collapseProgress)
        .animation(.spring(response: 0.28, dampingFraction: 0.80), value: selection)
    }

    @ViewBuilder
    private var pillsContent: some View {
        if #available(iOS 26.0, *) {
            GlassPills(selection: $selection, feedLabel: feedLabel, albumLabel: albumLabel)
        } else {
            MaterialPills(selection: $selection, feedLabel: feedLabel, albumLabel: albumLabel)
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

// MARK: - Material pills — iOS 16–25

private struct MaterialPills: View {
    @Binding var selection: FeedContentSegment
    let feedLabel: String
    let albumLabel: String

    @Namespace private var ns

    var body: some View {
        HStack(spacing: 0) {
            pill(.feed, label: feedLabel)
            pill(.album, label: albumLabel)
        }
        .padding(3)
        .background(.ultraThinMaterial, in: Capsule(style: .continuous))
        .animation(.spring(response: 0.28, dampingFraction: 0.8), value: selection)
    }

    private func pill(_ segment: FeedContentSegment, label: String) -> some View {
        let isSelected = selection == segment
        return Button {
            selection = segment
        } label: {
            Text(label)
                .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
                .foregroundStyle(
                    isSelected
                        ? SplickTheme.Colors.textPrimary
                        : SplickTheme.Colors.textSecondary
                )
                .opacity(isSelected ? 1 : 0.55)
                .padding(.horizontal, 14)
                .frame(height: 28)
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

    @Namespace private var ns

    var body: some View {
        HStack(spacing: 0) {
            pill(.feed, label: feedLabel)
            pill(.album, label: albumLabel)
        }
        .padding(3)
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
                .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
                .foregroundStyle(
                    isSelected
                        ? SplickTheme.Colors.textPrimary
                        : SplickTheme.Colors.textSecondary
                )
                .opacity(isSelected ? 1 : 0.55)
                .padding(.horizontal, 14)
                .frame(height: 28)
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
