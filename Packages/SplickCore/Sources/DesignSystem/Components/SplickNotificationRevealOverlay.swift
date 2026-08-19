import SwiftUI

/// Full-screen notification panel that scales from the bell.
public struct SplickNotificationRevealOverlay<Content: View>: View {
    @Binding var isPresented: Bool
    @Binding private var dismissRequestStorage: Bool
    let anchorFrame: CGRect
    let unreadCount: Int
    let headerTitle: String?
    let leadingActionTitle: String?
    let onLeadingAction: (() -> Void)?
    let closeAccessibilityLabel: String
    let onDismissStarted: (() -> Void)?
    @ViewBuilder let content: (_ dismiss: @escaping () -> Void) -> Content

    @State private var isRevealed = false

    private let controlSize: CGFloat = 34

    public init(
        isPresented: Binding<Bool>,
        anchorFrame: CGRect,
        unreadCount: Int,
        headerTitle: String? = nil,
        leadingActionTitle: String? = nil,
        onLeadingAction: (() -> Void)? = nil,
        closeAccessibilityLabel: String = "Close notifications",
        dismissRequest: Binding<Bool> = .constant(false),
        onDismissStarted: (() -> Void)? = nil,
        @ViewBuilder content: @escaping (_ dismiss: @escaping () -> Void) -> Content
    ) {
        _isPresented = isPresented
        _dismissRequestStorage = dismissRequest
        self.anchorFrame = anchorFrame
        self.unreadCount = unreadCount
        self.headerTitle = headerTitle
        self.leadingActionTitle = leadingActionTitle
        self.onLeadingAction = onLeadingAction
        self.closeAccessibilityLabel = closeAccessibilityLabel
        self.onDismissStarted = onDismissStarted
        self.content = content
    }

    public var body: some View {
        GeometryReader { proxy in
            let safeTop = proxy.safeAreaInsets.top
            let scaleAnchor = resolvedScaleAnchor(proxy: proxy)
            let chromeBandHeight = chromeBand(safeTop: safeTop)
            let headerTopInset = max(safeTop + 8, chromeBandHeight - controlSize - SplickTheme.Spacing.xxs)
            let overlayFrame = proxy.frame(in: .global)
            let closeButtonCenter: CGPoint = {
                guard anchorFrame.width > 1, anchorFrame.height > 1 else {
                    return CGPoint(
                        x: proxy.size.width - SplickTheme.Spacing.md - controlSize / 2,
                        y: safeTop + controlSize / 2 + SplickTheme.Spacing.xxs
                    )
                }
                return CGPoint(
                    x: anchorFrame.midX - overlayFrame.minX,
                    y: anchorFrame.midY - overlayFrame.minY
                )
            }()

            ZStack(alignment: .topLeading) {
                panelBody(
                    chromeBandHeight: chromeBandHeight,
                    width: proxy.size.width,
                    height: proxy.size.height
                )
                .scaleEffect(isRevealed ? 1 : 0.01, anchor: scaleAnchor)
                .opacity(isRevealed ? 1 : 0)
                .allowsHitTesting(isRevealed)

                if let headerTitle {
                    Text(headerTitle)
                        .font(SplickTheme.Typography.title)
                        .foregroundStyle(SplickTheme.Colors.textPrimary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .frame(height: controlSize, alignment: .center)
                        .padding(.horizontal, 108)
                        .padding(.top, headerTopInset)
                        .opacity(isRevealed ? 1 : 0)
                        .allowsHitTesting(false)
                }

                if unreadCount > 0, let leadingActionTitle, let onLeadingAction {
                    Button(leadingActionTitle, action: onLeadingAction)
                        .buttonStyle(.plain)
                        .font(SplickTheme.Typography.callout)
                        .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
                        .frame(height: controlSize, alignment: .center)
                        .padding(.leading, SplickTheme.Spacing.md)
                        .padding(.top, headerTopInset)
                        .opacity(isRevealed ? 1 : 0)
                        .zIndex(3)
                }

                overlayCloseButton(action: dismissAnimated)
                    .position(closeButtonCenter)
                    .opacity(isRevealed ? 1 : 0)
                    .allowsHitTesting(isRevealed)
                    .zIndex(2)
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
        .onChange(of: dismissRequestStorage) { requested in
            guard requested else { return }
            Task { @MainActor in
                dismissRequestStorage = false
                dismissAnimated()
            }
        }
    }

    @ViewBuilder
    private func panelBody(
        chromeBandHeight: CGFloat,
        width: CGFloat,
        height: CGFloat
    ) -> some View {
        VStack(spacing: 0) {
            SplickTheme.Colors.background
                .frame(height: chromeBandHeight)
                .frame(maxWidth: .infinity)

            content(dismissAnimated)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .background(SplickTheme.Colors.background)
        }
        .frame(width: width, height: height, alignment: .top)
    }

    private func dismissAnimated() {
        guard isPresented else { return }
        // Signal immediately so parent chrome can begin its re-appear animation in parallel.
        onDismissStarted?()
        withAnimation(SplickRevealMotion.collapse) { isRevealed = false }
        // Wait for collapse spring to settle before unmounting — prevents overlay popping off mid-animation.
        DispatchQueue.main.asyncAfter(deadline: .now() + SplickRevealMotion.collapseDuration) {
            isPresented = false
        }
    }

    private func resolvedScaleAnchor(proxy: GeometryProxy) -> UnitPoint {
        guard anchorFrame.width > 1, anchorFrame.height > 1 else {
            return UnitPoint(
                x: (proxy.size.width - SplickTheme.Spacing.md - 17) / max(proxy.size.width, 1),
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
        let bellMinY = anchorFrame.minY
        return max(bellMinY + controlSize + SplickTheme.Spacing.xxs, safeTop + controlSize + SplickTheme.Spacing.sm)
    }

    private func overlayCloseButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(SplickTheme.Colors.secondaryBackground.opacity(0.85))
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(SplickTheme.Colors.textPrimary)
            }
            .frame(width: controlSize, height: controlSize)
            .contentShape(Rectangle().inset(by: -8))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(closeAccessibilityLabel)
    }
}
