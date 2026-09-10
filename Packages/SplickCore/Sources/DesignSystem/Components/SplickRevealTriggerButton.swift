import SwiftUI

/// Compact trigger that becomes hidden while its anchored reveal panel is open.
public struct SplickRevealTriggerButton: View {
    @Binding var anchorFrame: CGRect
    let systemImage: String
    let isPresented: Bool
    var showsBadge: Bool = false
    var accent: Color = SplickTheme.Colors.primaryGradientStart
    var inactiveForeground: Color = SplickTheme.Colors.textSecondary
    var inactiveBackground: Color = SplickTheme.Colors.secondaryBackground
    let accessibilityLabel: String
    let action: () -> Void

    public init(
        anchorFrame: Binding<CGRect>,
        systemImage: String,
        isPresented: Bool,
        showsBadge: Bool = false,
        accent: Color = SplickTheme.Colors.primaryGradientStart,
        inactiveForeground: Color = SplickTheme.Colors.textSecondary,
        inactiveBackground: Color = SplickTheme.Colors.secondaryBackground,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) {
        _anchorFrame = anchorFrame
        self.systemImage = systemImage
        self.isPresented = isPresented
        self.showsBadge = showsBadge
        self.accent = accent
        self.inactiveForeground = inactiveForeground
        self.inactiveBackground = inactiveBackground
        self.accessibilityLabel = accessibilityLabel
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(showsBadge || isPresented ? accent : inactiveForeground)
                    .frame(width: 30, height: 30)
                    .background {
                        Circle()
                            .fill(
                                showsBadge || isPresented
                                    ? accent.opacity(0.14)
                                    : inactiveBackground
                            )
                    }

                if showsBadge && !isPresented {
                    Circle()
                        .fill(accent)
                        .frame(width: 7, height: 7)
                        .offset(x: 2, y: -1)
                }
            }
            .splickRevealAnchorFrame($anchorFrame)
        }
        .buttonStyle(.plain)
        .opacity(isPresented ? 0 : 1)
        .allowsHitTesting(!isPresented)
        .accessibilityLabel(accessibilityLabel)
    }
}
