import SwiftUI

public enum SplickRevealMotion {
    /// Bouncy expand — lower damping = more overshoot.
    public static let expand = Animation.spring(response: 0.40, dampingFraction: 0.52, blendDuration: 0.06)
    public static let collapse = Animation.spring(response: 0.36, dampingFraction: 0.62, blendDuration: 0.05)
    /// Matches `collapse` settle time — used to dismiss overlay after the spring finishes.
    public static let collapseDuration: TimeInterval = 0.44
}

/// Shared root coordinate space for anchored overlays (bell, notifications) across tab pager pages.
public enum SplickScreenCoordinateSpace {
    public static let name = "splick.screen"
}

public enum SplickAnchoredRevealStyle: Equatable {
    case popover(cardWidth: CGFloat = 340)
    case fullscreen
}

/// Expands content from an anchor control. The close (X) button sits at the anchor corner on the revealed panel.
public struct SplickAnchoredRevealOverlay<Content: View>: View {
    @Binding var isPresented: Bool
    let anchorFrame: CGRect
    let style: SplickAnchoredRevealStyle
    let controlSize: CGFloat
    let accent: Color
    let dimmingOpacity: Double
    @ViewBuilder let content: (_ dismiss: @escaping () -> Void) -> Content

    @State private var revealProgress: CGFloat = 0

    public init(
        isPresented: Binding<Bool>,
        anchorFrame: CGRect,
        style: SplickAnchoredRevealStyle,
        controlSize: CGFloat = 30,
        accent: Color = SplickTheme.Colors.primaryGradientStart,
        dimmingOpacity: Double = 0.18,
        @ViewBuilder content: @escaping (_ dismiss: @escaping () -> Void) -> Content
    ) {
        _isPresented = isPresented
        self.anchorFrame = anchorFrame
        self.style = style
        self.controlSize = controlSize
        self.accent = accent
        self.dimmingOpacity = dimmingOpacity
        self.content = content
    }

    public var body: some View {
        GeometryReader { proxy in
            let overlayFrame = proxy.frame(in: .global)
            let anchorCenter = CGPoint(
                x: anchorFrame.midX - overlayFrame.minX,
                y: anchorFrame.midY - overlayFrame.minY
            )
            let anchorTopTrailing = CGPoint(
                x: anchorFrame.maxX - overlayFrame.minX,
                y: anchorFrame.minY - overlayFrame.minY
            )
            let layout = panelLayout(
                in: proxy.size,
                anchorTopTrailing: anchorTopTrailing
            )
            let diameter = max(layout.coverRadius * 2 * revealProgress, controlSize)
            let cornerControlCenter = CGPoint(
                x: anchorTopTrailing.x - controlSize / 2,
                y: anchorTopTrailing.y + controlSize / 2
            )
            let panelCenter = panelCenterPoint(
                layout: layout,
                anchorTopTrailing: anchorTopTrailing,
                containerSize: proxy.size
            )

            ZStack {
                Color.black.opacity(Double(revealProgress) * dimmingOpacity)
                    .ignoresSafeArea()
                    .onTapGesture { dismissAnimated() }

                revealedPanel(layout: layout, dismiss: dismissAnimated)
                    .position(panelCenter)
                    .mask {
                        Circle()
                            .frame(width: diameter, height: diameter)
                            .position(anchorCenter)
                    }

                closeButton(action: dismissAnimated)
                    .position(cornerControlCenter)
                    .zIndex(1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .ignoresSafeArea()
        .onAppear {
            revealProgress = 0
            withAnimation(SplickRevealMotion.expand) {
                revealProgress = 1
            }
        }
    }

    @ViewBuilder
    private func revealedPanel(layout: PanelLayout, dismiss: @escaping () -> Void) -> some View {
        content(dismiss)
            .frame(width: layout.size.width, alignment: .leading)
            .frame(maxHeight: layout.size.height, alignment: .top)
            .padding(.top, controlSize + SplickTheme.Spacing.xxs)
            .padding(.horizontal, SplickTheme.Spacing.md)
            .padding(.bottom, SplickTheme.Spacing.md)
            .frame(width: layout.size.width, height: layout.size.height, alignment: .top)
            .background(panelBackground)
            .clipShape(RoundedRectangle(cornerRadius: panelCornerRadius, style: .continuous))
    }

    private var panelBackground: some View {
        Group {
            switch style {
            case .popover:
                RoundedRectangle(cornerRadius: panelCornerRadius, style: .continuous)
                    .fill(SplickTheme.Colors.cardBackground)
                    .shadow(
                        color: SplickTheme.Shadow.card.color,
                        radius: SplickTheme.Shadow.card.radius,
                        x: SplickTheme.Shadow.card.x,
                        y: SplickTheme.Shadow.card.y
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: panelCornerRadius, style: .continuous)
                            .strokeBorder(accent.opacity(0.1), lineWidth: 1)
                    }
            case .fullscreen:
                SplickTheme.Colors.background
            }
        }
    }

    private var panelCornerRadius: CGFloat {
        switch style {
        case .popover:
            return SplickTheme.CornerRadius.card
        case .fullscreen:
            return 0
        }
    }

    private func closeButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(closeForeground)
                .frame(width: controlSize, height: controlSize)
                .background {
                    Circle()
                        .fill(closeBackground)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Close")
    }

    private var closeForeground: Color {
        switch style {
        case .popover:
            return accent
        case .fullscreen:
            return SplickTheme.Colors.textPrimary
        }
    }

    private var closeBackground: Color {
        switch style {
        case .popover:
            return accent.opacity(0.14)
        case .fullscreen:
            return SplickTheme.Colors.secondaryBackground
        }
    }

    private func dismissAnimated() {
        guard isPresented else { return }
        withAnimation(SplickRevealMotion.collapse) {
            revealProgress = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + SplickRevealMotion.collapseDuration) {
            isPresented = false
        }
    }

    private struct PanelLayout {
        let size: CGSize
        let coverRadius: CGFloat
    }

    private func panelLayout(
        in containerSize: CGSize,
        anchorTopTrailing: CGPoint
    ) -> PanelLayout {
        switch style {
        case .popover(let cardWidth):
            let width = min(cardWidth, containerSize.width - SplickTheme.Spacing.xl)
            let height = min(460, containerSize.height - anchorTopTrailing.y - SplickTheme.Spacing.md)
            return PanelLayout(
                size: CGSize(width: width, height: height),
                coverRadius: hypot(width, height)
            )

        case .fullscreen:
            let topY = max(anchorTopTrailing.y, 0)
            let height = containerSize.height - topY
            let anchorCenter = CGPoint(
                x: anchorTopTrailing.x - controlSize / 2,
                y: anchorTopTrailing.y + controlSize / 2
            )
            return PanelLayout(
                size: CGSize(width: containerSize.width, height: height),
                coverRadius: Self.radiusCovering(origin: anchorCenter, in: containerSize)
            )
        }
    }

    private static func radiusCovering(origin: CGPoint, in size: CGSize) -> CGFloat {
        let corners = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: size.width, y: 0),
            CGPoint(x: 0, y: size.height),
            CGPoint(x: size.width, y: size.height),
        ]
        return corners
            .map { hypot($0.x - origin.x, $0.y - origin.y) }
            .max() ?? size.width
    }

    private func panelCenterPoint(
        layout: PanelLayout,
        anchorTopTrailing: CGPoint,
        containerSize: CGSize
    ) -> CGPoint {
        switch style {
        case .fullscreen:
            return CGPoint(
                x: containerSize.width / 2,
                y: anchorTopTrailing.y + layout.size.height / 2
            )
        case .popover:
            return CGPoint(
                x: anchorTopTrailing.x - layout.size.width / 2,
                y: anchorTopTrailing.y + layout.size.height / 2
            )
        }
    }
}

private struct SplickRevealAnchorFrameKey: PreferenceKey {
    static var defaultValue: CGRect = .zero

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

public extension View {
    func splickRevealAnchorFrame(
        _ frame: Binding<CGRect>,
        in space: CoordinateSpace = .global
    ) -> some View {
        background {
            GeometryReader { proxy in
                Color.clear.preference(
                    key: SplickRevealAnchorFrameKey.self,
                    value: proxy.frame(in: space)
                )
            }
        }
        .onPreferenceChange(SplickRevealAnchorFrameKey.self) { frame.wrappedValue = $0 }
    }
}
