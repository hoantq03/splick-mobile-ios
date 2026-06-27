import SwiftUI

/// Full-screen notification panel — panel scales from the bell; close (X) grows in place at the bell.
public struct SplickNotificationRevealOverlay<Content: View>: View {
    @Binding var isPresented: Bool
    let anchorFrame: CGRect
    let unreadCount: Int
    @ViewBuilder let content: (_ dismiss: @escaping () -> Void) -> Content

    @State private var isRevealed = false

    private let controlSize: CGFloat = 34
    private var panelTransition: AnyTransition {
        .scale(scale: 0.2, anchor: .topTrailing)
            .combined(with: .opacity)
    }

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
            let bleedHeight = proxy.size.height + proxy.safeAreaInsets.top + proxy.safeAreaInsets.bottom

            ZStack(alignment: .topLeading) {
                if isRevealed {
                    ZStack(alignment: .top) {
                        SplickTheme.Colors.background

                        content(dismissAnimated)
                            .padding(.top, anchor.maxY + SplickTheme.Spacing.xxs)
                    }
                    .frame(width: proxy.size.width, height: bleedHeight, alignment: .top)
                    .offset(y: -proxy.safeAreaInsets.top)
                    .transition(panelTransition)
                    .animation(SplickRevealMotion.expand, value: isRevealed)
                }

                closeButton
                    .scaleEffect(isRevealed ? 1 : 0.2)
                    .opacity(isRevealed ? 1 : 0)
                    .animation(SplickRevealMotion.expand, value: isRevealed)
                    .position(anchorCenter)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
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

    private func dismissAnimated() {
        guard isPresented else { return }
        withAnimation(SplickRevealMotion.collapse) {
            isRevealed = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + SplickRevealMotion.collapseDuration) {
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
