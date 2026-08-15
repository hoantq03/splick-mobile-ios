import SwiftUI
import DesignSystem
import Localization

/// Principal toolbar pills for the expense tab — same morph/collapse UX as feed.
struct ExpenseNavPills: View {
    @Binding var selection: ExpenseContentSegment
    let collapseProgress: CGFloat
    let historyLabel: String
    let overviewLabel: String
    let friendsLabel: String

    private var t: CGFloat { FeedSegmentMorphLayout.smoothstep(collapseProgress) }

    private var activeLabel: String {
        switch selection {
        case .history: return historyLabel
        case .overview: return overviewLabel
        case .friends: return friendsLabel
        }
    }

    /// Horizontal offset of the active pill centre from the strip centre.
    private var activeLabelStartX: CGFloat {
        switch selection {
        case .history: return -FeedSegmentPillLayout.morphOffset
        case .overview: return 0
        case .friends: return FeedSegmentPillLayout.morphOffset
        }
    }

    var body: some View {
        ZStack {
            pillsContent
                .opacity(1 - t)
                .allowsHitTesting(collapseProgress < 0.5)

            Text(activeLabel)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(SplickTheme.Colors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .fixedSize(horizontal: true, vertical: false)
                .scaleEffect((16 + 4 * t) / 20)
                .offset(x: activeLabelStartX * (1 - t))
                .opacity(t)
                .allowsHitTesting(false)
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.82), value: collapseProgress)
        // Match pager spring so pill indicator and page offset share one motion feel.
        .animation(ExpensePagerMotion.slide, value: selection)
    }

    @ViewBuilder
    private var pillsContent: some View {
        if #available(iOS 26.0, *) {
            ExpenseGlassPills(
                selection: $selection,
                historyLabel: historyLabel,
                overviewLabel: overviewLabel,
                friendsLabel: friendsLabel
            )
        } else {
            ExpenseMaterialPills(
                selection: $selection,
                historyLabel: historyLabel,
                overviewLabel: overviewLabel,
                friendsLabel: friendsLabel
            )
        }
    }
}

// Reuse feed morph math (same 3-pill geometry).
private enum FeedSegmentMorphLayout {
    static func smoothstep(_ progress: CGFloat) -> CGFloat {
        let c = min(1, max(0, progress))
        return c * c * (3 - 2 * c)
    }
}

private enum FeedSegmentPillLayout {
    static let segmentWidth: CGFloat = 66
    static let segmentHeight: CGFloat = 34
    static let horizontalTextPadding: CGFloat = 8
    static let chromePadding: CGFloat = 3
    static let stripSegmentCount: CGFloat = 3
    static let stripWidth: CGFloat = (segmentWidth * stripSegmentCount) + (chromePadding * 2)
    static let stripHeight: CGFloat = segmentHeight + (chromePadding * 2)
    static var morphOffset: CGFloat { segmentWidth }
}

private enum ExpenseSegmentStripMotion {
    /// Keep press feedback snappy; selection motion is driven by ExpensePagerMotion.slide.
    static let pressSpring = Animation.spring(response: 0.22, dampingFraction: 0.72)
}

private struct ExpenseMaterialPills: View {
    @Binding var selection: ExpenseContentSegment
    let historyLabel: String
    let overviewLabel: String
    let friendsLabel: String

    @State private var hoverSegment: ExpenseContentSegment?
    @State private var isInteracting = false

    private var selectedIndex: Int {
        expenseSegmentStripOrder.firstIndex(of: selection) ?? 1
    }

    private var emphasized: Bool {
        hoverSegment == selection || (hoverSegment == nil && isInteracting)
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(.regularMaterial)
                    .overlay {
                        Capsule(style: .continuous)
                            .stroke(.white.opacity(emphasized ? 0.75 : 0.45), lineWidth: 0.8)
                    }
                    .shadow(
                        color: .black.opacity(emphasized ? 0.10 : 0.05),
                        radius: emphasized ? 10 : 5,
                        y: emphasized ? 4 : 2
                    )
                    .frame(
                        width: FeedSegmentPillLayout.segmentWidth,
                        height: FeedSegmentPillLayout.segmentHeight
                    )
                    .scaleEffect(emphasized ? 1.08 : 1)
                    .offset(x: CGFloat(selectedIndex) * FeedSegmentPillLayout.segmentWidth)

                HStack(spacing: 0) {
                    pill(.history, label: historyLabel)
                    pill(.overview, label: overviewLabel)
                    pill(.friends, label: friendsLabel)
                }
            }
            .padding(FeedSegmentPillLayout.chromePadding)
            .frame(width: proxy.size.width, height: proxy.size.height)
            .background(.ultraThinMaterial, in: Capsule(style: .continuous))
            .contentShape(Capsule(style: .continuous))
            .simultaneousGesture(stripGesture(totalWidth: proxy.size.width))
        }
        .frame(width: FeedSegmentPillLayout.stripWidth, height: FeedSegmentPillLayout.stripHeight)
        .animation(ExpensePagerMotion.slide, value: selection)
        .animation(ExpenseSegmentStripMotion.pressSpring, value: hoverSegment)
        .animation(ExpenseSegmentStripMotion.pressSpring, value: isInteracting)
    }

    private func pill(_ segment: ExpenseContentSegment, label: String) -> some View {
        let isSelected = selection == segment
        let isEmphasized = isSelected && emphasized
        return Button {
            guard selection != segment else { return }
            // Pager owns the page spring; pill indicator follows via .animation(value:).
            selection = segment
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
                .minimumScaleFactor(0.75)
                .padding(.horizontal, FeedSegmentPillLayout.horizontalTextPadding)
                .frame(
                    width: FeedSegmentPillLayout.segmentWidth,
                    height: FeedSegmentPillLayout.segmentHeight
                )
                .scaleEffect(isEmphasized ? 1.03 : 1)
                .contentShape(Rectangle())
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
                selection = segment
            }
            .onEnded { value in
                if let segment = segment(at: value.location.x, totalWidth: totalWidth) ?? hoverSegment,
                   selection != segment {
                    selection = segment
                }
                withAnimation(ExpenseSegmentStripMotion.pressSpring) {
                    hoverSegment = nil
                    isInteracting = false
                }
            }
    }

    private func segment(at locationX: CGFloat, totalWidth: CGFloat) -> ExpenseContentSegment? {
        let leading = FeedSegmentPillLayout.chromePadding
        let trailing = totalWidth - FeedSegmentPillLayout.chromePadding
        guard locationX >= leading, locationX <= trailing else { return nil }
        let relativeX = min(
            max(locationX - leading, 0),
            totalWidth - (FeedSegmentPillLayout.chromePadding * 2) - 1
        )
        let index = min(Int(relativeX / FeedSegmentPillLayout.segmentWidth), expenseSegmentStripOrder.count - 1)
        return expenseSegmentStripOrder[index]
    }
}

@available(iOS 26.0, *)
private struct ExpenseGlassPills: View {
    @Binding var selection: ExpenseContentSegment
    let historyLabel: String
    let overviewLabel: String
    let friendsLabel: String

    @State private var hoverSegment: ExpenseContentSegment?
    @State private var isInteracting = false

    private var selectedIndex: Int {
        expenseSegmentStripOrder.firstIndex(of: selection) ?? 1
    }

    private var emphasized: Bool {
        hoverSegment == selection || (hoverSegment == nil && isInteracting)
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(.clear)
                    .glassEffect(.regular)
                    .overlay {
                        Capsule(style: .continuous)
                            .stroke(.white.opacity(emphasized ? 0.55 : 0.32), lineWidth: 0.9)
                    }
                    .shadow(
                        color: .white.opacity(emphasized ? 0.18 : 0.08),
                        radius: emphasized ? 12 : 6,
                        y: emphasized ? 4 : 2
                    )
                    .frame(
                        width: FeedSegmentPillLayout.segmentWidth,
                        height: FeedSegmentPillLayout.segmentHeight
                    )
                    .scaleEffect(emphasized ? 1.10 : 1)
                    .offset(x: CGFloat(selectedIndex) * FeedSegmentPillLayout.segmentWidth)

                HStack(spacing: 0) {
                    pill(.history, label: historyLabel)
                    pill(.overview, label: overviewLabel)
                    pill(.friends, label: friendsLabel)
                }
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
        .animation(ExpensePagerMotion.slide, value: selection)
        .animation(ExpenseSegmentStripMotion.pressSpring, value: hoverSegment)
        .animation(ExpenseSegmentStripMotion.pressSpring, value: isInteracting)
    }

    private func pill(_ segment: ExpenseContentSegment, label: String) -> some View {
        let isSelected = selection == segment
        let isEmphasized = isSelected && emphasized
        return Button {
            guard selection != segment else { return }
            // Pager owns the page spring; pill indicator follows via .animation(value:).
            selection = segment
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
                .minimumScaleFactor(0.75)
                .padding(.horizontal, FeedSegmentPillLayout.horizontalTextPadding)
                .frame(
                    width: FeedSegmentPillLayout.segmentWidth,
                    height: FeedSegmentPillLayout.segmentHeight
                )
                .scaleEffect(isEmphasized ? 1.03 : 1)
                .contentShape(Rectangle())
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
                selection = segment
            }
            .onEnded { value in
                if let segment = segment(at: value.location.x, totalWidth: totalWidth) ?? hoverSegment,
                   selection != segment {
                    selection = segment
                }
                withAnimation(ExpenseSegmentStripMotion.pressSpring) {
                    hoverSegment = nil
                    isInteracting = false
                }
            }
    }

    private func segment(at locationX: CGFloat, totalWidth: CGFloat) -> ExpenseContentSegment? {
        let leading = FeedSegmentPillLayout.chromePadding
        let trailing = totalWidth - FeedSegmentPillLayout.chromePadding
        guard locationX >= leading, locationX <= trailing else { return nil }
        let relativeX = min(
            max(locationX - leading, 0),
            totalWidth - (FeedSegmentPillLayout.chromePadding * 2) - 1
        )
        let index = min(Int(relativeX / FeedSegmentPillLayout.segmentWidth), expenseSegmentStripOrder.count - 1)
        return expenseSegmentStripOrder[index]
    }
}
