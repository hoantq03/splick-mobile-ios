import SwiftUI

/// Full-screen notification panel that scales from the bell.
/// The close (X) button is pinned to the top-trailing safe-area corner
/// so it is always reachable regardless of which tab triggered the panel.
public struct SplickNotificationRevealOverlay<Content: View>: View {
    @Binding var isPresented: Bool
    let anchorFrame: CGRect
    let unreadCount: Int
    @ViewBuilder let content: (_ dismiss: @escaping () -> Void) -> Content

    @State private var isRevealed = false

    private let controlSize: CGFloat = 34
    private let trailingInset: CGFloat = SplickTheme.Spacing.md

    public init(
        isPresented: Binding<Bool>,
        anchorFrame: CGRect,
        unreadCount: Int,
        @ViewBuilder content: @escaping (_ dismiss: @escaping () -> Void) -> Content
    ) {
        _isPresented = isPresented
        self.anchorFrame = anchorFrame
        self.unreadCount = unreadCount
        self.content = content
    }

    public var body: some View {
        GeometryReader { proxy in
            let safeTop = proxy.safeAreaInsets.top
            // Bell is always top-trailing; use anchorFrame when valid, else estimate.
            let scaleAnchor = resolvedScaleAnchor(proxy: proxy)
            // Chrome height: enough to clear the nav bar + control.
            let chromeBandHeight = chromeBand(safeTop: safeTop)
            // Control top inset so it visually sits at the bell row.
            let controlTopInset = max(safeTop + 8, chromeBandHeight - controlSize - SplickTheme.Spacing.xxs)

            ZStack(alignment: .topLeading) {
                // Panel fills full height; chrome band is an empty spacer.
                panelBody(
                    chromeBandHeight: chromeBandHeight,
                    width: proxy.size.width,
                    height: proxy.size.height
                )
                .scaleEffect(isRevealed ? 1 : 0.01, anchor: scaleAnchor)
                .opacity(isRevealed ? 1 : 0)
                .allowsHitTesting(isRevealed)

                // X button: fixed top-trailing position, independent of anchorFrame math.
                closeButton
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.top, controlTopInset)
                    .padding(.trailing, trailingInset)
                    .opacity(isRevealed ? 1 : 0)
                    .allowsHitTesting(isRevealed)
                    .zIndex(1)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
            .animation(SplickRevealMotion.expand, value: isRevealed)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .allowsHitTesting(isRevealed)
        .onAppear {
            isRevealed = false
            withAnimation(SplickRevealMotion.expand) { isRevealed = true }
        }
        .onDisappear { isRevealed = false }
    }

    // MARK: - Subviews

    @ViewBuilder
    private func panelBody(
        chromeBandHeight: CGFloat,
        width: CGFloat,
        height: CGFloat
    ) -> some View {
        ZStack(alignment: .top) {
            SplickTheme.Colors.background

            VStack(spacing: 0) {
                Color.clear
                    .frame(height: chromeBandHeight)
                    .frame(maxWidth: .infinity)
                    .allowsHitTesting(false)

                content(dismissAnimated)
            }
        }
        .frame(width: width, height: height, alignment: .top)
    }

    private var closeButton: some View {
        Button(action: dismissAnimated) {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(SplickTheme.Colors.textPrimary)
                .frame(width: controlSize, height: controlSize)
                .background {
                    Circle()
                        .fill(SplickTheme.Colors.secondaryBackground)
                        .shadow(
                            color: SplickTheme.Shadow.card.color.opacity(0.35),
                            radius: 4,
                            y: 1
                        )
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Close")
    }

    // MARK: - Helpers

    private func dismissAnimated() {
        guard isPresented else { return }
        withAnimation(SplickRevealMotion.collapse) { isRevealed = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { isPresented = false }
    }

    /// Scale expands from the bell corner. Uses anchorFrame when valid; falls back to .topTrailing.
    private func resolvedScaleAnchor(proxy: GeometryProxy) -> UnitPoint {
        guard anchorFrame.width > 1, anchorFrame.height > 1 else {
            return UnitPoint(
                x: (proxy.size.width - trailingInset - controlSize / 2) / max(proxy.size.width, 1),
                y: (proxy.safeAreaInsets.top + 20) / max(proxy.size.height, 1)
            )
        }
        let overlayFrame = proxy.frame(in: .global)
        let ax = (anchorFrame.midX - overlayFrame.minX) / max(proxy.size.width, 1)
        let ay = (anchorFrame.midY - overlayFrame.minY) / max(proxy.size.height, 1)
        return UnitPoint(x: min(max(ax, 0), 1), y: min(max(ay, 0), 1))
    }

    private func chromeBand(safeTop: CGFloat) -> CGFloat {
        guard anchorFrame.height > 1 else {
            return safeTop + controlSize + SplickTheme.Spacing.sm
        }
        let overlayFrame: CGRect = .zero // offset doesn't matter; just need minY of bell
        let bellMinY = anchorFrame.minY
        return max(bellMinY + controlSize + SplickTheme.Spacing.xxs, safeTop + controlSize + SplickTheme.Spacing.sm)
    }
}
