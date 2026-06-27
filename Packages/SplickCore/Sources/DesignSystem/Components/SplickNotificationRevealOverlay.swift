import SwiftUI

/// Circular reveal for notifications — expands from the bell icon with feed-style spring bounce.
public struct SplickNotificationRevealOverlay<Content: View>: View {
    @Binding var isPresented: Bool
    let anchorFrame: CGRect
    let unreadCount: Int
    @ViewBuilder let content: (_ dismiss: @escaping () -> Void) -> Content

    @State private var revealProgress: CGFloat = 0

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
            let anchor = localAnchor(rootGlobal: rootGlobal, containerSize: proxy.size)
            let anchorCenter = CGPoint(x: anchor.midX, y: anchor.midY)
            let coverRadius = Self.radiusCovering(origin: anchorCenter, in: proxy.size)
            let diameter = max(coverRadius * 2 * revealProgress, controlSize)
            let morph = morphAmount(for: revealProgress)

            revealedPanel(
                anchor: anchor,
                containerSize: proxy.size,
                safeAreaInsets: proxy.safeAreaInsets
            )
            .mask {
                Circle()
                    .frame(width: diameter, height: diameter)
                    .position(anchorCenter)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .overlay(alignment: .topLeading) {
                morphControl(morph: morph, action: dismissAnimated)
                    .position(anchorCenter)
            }
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
    private func revealedPanel(
        anchor: CGRect,
        containerSize: CGSize,
        safeAreaInsets: EdgeInsets
    ) -> some View {
        let panelTop = anchor.minY
        // Extend through the home-indicator region so no feed/tab chrome peeks below.
        let panelHeight = containerSize.height - panelTop + safeAreaInsets.bottom

        content(dismissAnimated)
            .frame(width: containerSize.width, alignment: .leading)
            .frame(maxHeight: panelHeight, alignment: .top)
            .padding(.top, controlSize + SplickTheme.Spacing.xxs)
            .frame(width: containerSize.width, height: panelHeight, alignment: .top)
            .offset(y: panelTop)
            .background {
                SplickTheme.Colors.background
                    .ignoresSafeArea(edges: .bottom)
            }
    }

    private func morphControl(morph: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                ZStack {
                    Image(systemName: unreadCount > 0 ? "bell.badge.fill" : "bell")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(SplickTheme.Colors.textPrimary)
                        .opacity(1 - morph)

                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(SplickTheme.Colors.textPrimary)
                        .frame(width: controlSize, height: controlSize)
                        .background {
                            Circle()
                                .fill(SplickTheme.Colors.secondaryBackground)
                        }
                        .opacity(morph)
                }
                .frame(width: controlSize, height: controlSize)

                if unreadCount > 0, morph < 0.85 {
                    Text(unreadCount > 99 ? "99+" : "\(unreadCount)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(SplickTheme.Colors.error))
                        .offset(x: 6, y: -2)
                        .opacity(Double(1 - morph))
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Close")
    }

    private func morphAmount(for progress: CGFloat) -> CGFloat {
        min(max((progress - 0.18) / 0.42, 0), 1)
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

    private func localAnchor(rootGlobal: CGRect, containerSize: CGSize) -> CGRect {
        guard anchorFrame.width > 1, anchorFrame.height > 1 else {
            let side = controlSize
            let trailingPadding: CGFloat = 16
            let topPadding: CGFloat = 6
            return CGRect(
                x: containerSize.width - trailingPadding - side,
                y: topPadding,
                width: side,
                height: side
            )
        }

        return CGRect(
            x: anchorFrame.minX - rootGlobal.minX,
            y: anchorFrame.minY - rootGlobal.minY,
            width: anchorFrame.width,
            height: anchorFrame.height
        )
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
}
