import SwiftUI

/// Full-screen notification panel — panel scales from the bell; close (X) grows in place at the bell.
public struct SplickNotificationRevealOverlay<Content: View>: View {
    @Binding var isPresented: Bool
    let anchorFrame: CGRect
    let unreadCount: Int
    @ViewBuilder let content: (_ dismiss: @escaping () -> Void) -> Content

    @State private var isRevealed = false

    private let controlSize: CGFloat = 34

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
            let rootGlobal = proxy.frame(in: .global)
            let anchor = resolvedAnchor(rootGlobal: rootGlobal, containerSize: proxy.size)
            let anchorCenter = CGPoint(x: anchor.midX, y: anchor.midY)
            let safeTop = proxy.safeAreaInsets.top
            let bleedHeight = proxy.size.height + safeTop + proxy.safeAreaInsets.bottom
            let scaleAnchor = panelScaleAnchor(
                anchor: anchor,
                panelWidth: proxy.size.width,
                panelHeight: bleedHeight,
                safeAreaTop: safeTop
            )

            ZStack(alignment: .topLeading) {
                panelBody(anchor: anchor, bleedHeight: bleedHeight, width: proxy.size.width)
                    .scaleEffect(isRevealed ? 1 : 0.2, anchor: scaleAnchor)
                    .opacity(isRevealed ? 1 : 0)
                    .offset(y: -safeTop)

                closeButton
                    .scaleEffect(isRevealed ? 1 : 0.2)
                    .opacity(isRevealed ? 1 : 0)
                    .position(anchorCenter)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
            .animation(SplickRevealMotion.expand, value: isRevealed)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .onAppear {
            isRevealed = false
            withAnimation(SplickRevealMotion.expand) {
                isRevealed = true
            }
        }
    }

    @ViewBuilder
    private func panelBody(anchor: CGRect, bleedHeight: CGFloat, width: CGFloat) -> some View {
        ZStack(alignment: .top) {
            SplickTheme.Colors.background

            content(dismissAnimated)
                .padding(.top, anchor.maxY + SplickTheme.Spacing.xxs)
        }
        .frame(width: width, height: bleedHeight, alignment: .top)
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
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Close")
    }

    /// Maps the bell's top-trailing corner into panel-local unit space (accounts for safe-area offset).
    private func panelScaleAnchor(
        anchor: CGRect,
        panelWidth: CGFloat,
        panelHeight: CGFloat,
        safeAreaTop: CGFloat
    ) -> UnitPoint {
        let x = anchor.maxX / max(panelWidth, 1)
        let y = (anchor.midY + safeAreaTop) / max(panelHeight, 1)
        return UnitPoint(
            x: min(max(x, 0), 1),
            y: min(max(y, 0), 1)
        )
    }

    private func dismissAnimated() {
        guard isPresented else { return }
        withAnimation(SplickRevealMotion.collapse) {
            isRevealed = false
        }
        // Shorter than collapseDuration so the bell starts reappearing
        // while the panel is still finishing its collapse.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            isPresented = false
        }
    }

    private func resolvedAnchor(rootGlobal: CGRect, containerSize: CGSize) -> CGRect {
        guard anchorFrame.width > 1, anchorFrame.height > 1 else {
            let trailingPadding: CGFloat = 16
            let topPadding: CGFloat = 6
            return CGRect(
                x: containerSize.width - trailingPadding - controlSize,
                y: topPadding,
                width: controlSize,
                height: controlSize
            )
        }

        return CGRect(
            x: anchorFrame.minX - rootGlobal.minX,
            y: anchorFrame.minY - rootGlobal.minY,
            width: anchorFrame.width,
            height: anchorFrame.height
        )
    }
}
