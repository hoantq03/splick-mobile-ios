import SwiftUI
import UIKit

/// Full-screen notification panel. Header is a `safeAreaInset` so the list cannot
/// collapse it, and top padding comes from the key window (overlay parents often
/// report zero SwiftUI safe-area insets).
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

    private let closeHitSize: CGFloat = 44

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
        ZStack {
            SplickTheme.Colors.background
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .accessibilityHidden(true)

            content(dismissAnimated)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .safeAreaInset(edge: .top, spacing: 0) {
                    headerBar
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .scaleEffect(isRevealed ? 1 : 0.94, anchor: .top)
        .opacity(isRevealed ? 1 : 0)
        .onAppear {
                isRevealed = false
                withAnimation(SplickRevealMotion.notificationExpand) { isRevealed = true }
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

    private var headerBar: some View {
        HStack(spacing: SplickTheme.Spacing.sm) {
            Group {
                if unreadCount > 0, let leadingActionTitle, let onLeadingAction {
                    Button(leadingActionTitle, action: onLeadingAction)
                        .buttonStyle(.plain)
                        .font(SplickTheme.Typography.callout)
                        .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                } else {
                    Color.clear
                        .frame(width: closeHitSize, height: closeHitSize)
                }
            }
            .frame(width: 104, alignment: .leading)

            Text(headerTitle ?? "")
                .font(SplickTheme.Typography.headline)
                .foregroundStyle(SplickTheme.Colors.textPrimary)
                .lineLimit(1)
                .frame(maxWidth: .infinity)

            Button(action: dismissAnimated) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(SplickTheme.Colors.textPrimary)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle().fill(SplickTheme.Colors.secondaryBackground)
                    )
                    .frame(width: closeHitSize, height: closeHitSize)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(closeAccessibilityLabel)
        }
        .padding(.horizontal, SplickTheme.Spacing.md)
        .padding(.bottom, SplickTheme.Spacing.sm)
        .padding(.top, OverlayWindowMetrics.topSafeInset)
        .frame(maxWidth: .infinity)
        .background(SplickTheme.Colors.background)
    }

    private func dismissAnimated() {
        guard isPresented else { return }
        onDismissStarted?()
        withAnimation(SplickRevealMotion.notificationCollapse) { isRevealed = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + SplickRevealMotion.notificationCollapseDuration) {
            isPresented = false
        }
    }
}

private enum OverlayWindowMetrics {
    static var topSafeInset: CGFloat {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let window = scenes.flatMap(\.windows).first(where: \.isKeyWindow)
            ?? scenes.flatMap(\.windows).first
        return max(window?.safeAreaInsets.top ?? 59, 47)
    }
}
