import SwiftUI

private struct BellButtonFrameKey: PreferenceKey {
    static var defaultValue: CGRect = .zero

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

/// Toolbar bell that reports its global frame when tapped (for circular reveal transitions).
public struct NotificationBellButton: View {
    let unreadCount: Int
    let accessibilityLabel: String
    let onTap: (CGRect) -> Void

    @State private var bellFrame: CGRect = .zero

    public init(
        unreadCount: Int,
        accessibilityLabel: String,
        onTap: @escaping (CGRect) -> Void
    ) {
        self.unreadCount = unreadCount
        self.accessibilityLabel = accessibilityLabel
        self.onTap = onTap
    }

    public var body: some View {
        Button {
            onTap(bellFrame)
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: unreadCount > 0 ? "bell.badge.fill" : "bell")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(SplickTheme.Colors.textPrimary)
                    .frame(width: 34, height: 34)

                if unreadCount > 0 {
                    Text(unreadCount > 99 ? "99+" : "\(unreadCount)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(SplickTheme.Colors.error))
                        .offset(x: 6, y: -2)
                }
            }
            .background {
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: BellButtonFrameKey.self,
                        value: proxy.frame(in: .global)
                    )
                }
            }
            .onPreferenceChange(BellButtonFrameKey.self) { bellFrame = $0 }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}
