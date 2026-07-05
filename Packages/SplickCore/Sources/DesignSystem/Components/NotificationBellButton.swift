import SwiftUI

/// Toolbar bell that reports its global frame when tapped (for circular reveal transitions).
public struct NotificationBellButton: View {
    let unreadCount: Int
    let isPresented: Bool
    let accessibilityLabel: String
    let onTap: (CGRect) -> Void

    @State private var bellFrame: CGRect = .zero

    private static let bellContainerSize: CGFloat = 42
    private static let bellIconFrameSize: CGFloat = 30
    private static let bellIconFontSize: CGFloat = 17
    private static let badgeHeight: CGFloat = 20
    private static let badgeMinWidth: CGFloat = 20

    public init(
        unreadCount: Int,
        isPresented: Bool = false,
        accessibilityLabel: String,
        onTap: @escaping (CGRect) -> Void
    ) {
        self.unreadCount = unreadCount
        self.isPresented = isPresented
        self.accessibilityLabel = accessibilityLabel
        self.onTap = onTap
    }

    public var body: some View {
        Button {
            DispatchQueue.main.async {
                let frame = bellFrame
                guard frame.width > 1, frame.height > 1 else { return }
                onTap(frame)
            }
        } label: {
            ZStack {
                Image(systemName: unreadCount > 0 ? "bell.fill" : "bell")
                    .font(.system(size: Self.bellIconFontSize, weight: .medium))
                    .foregroundStyle(SplickTheme.Colors.textPrimary)
                    .frame(width: Self.bellIconFrameSize, height: Self.bellIconFrameSize)
                    .offset(x: -1, y: 1)
                    .opacity(isPresented ? 0 : 1)
                    .scaleEffect(isPresented ? 0.82 : 1)

                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(SplickTheme.Colors.textPrimary)
                    .frame(width: Self.bellIconFrameSize, height: Self.bellIconFrameSize)
                    .opacity(isPresented ? 1 : 0)
                    .scaleEffect(isPresented ? 1 : 0.82)
            }
                .frame(width: Self.bellContainerSize, height: Self.bellContainerSize)
                .overlay(alignment: .topTrailing) {
                    if unreadCount > 0, !isPresented {
                        badgeView
                            .offset(x: 2, y: -2)
                            .zIndex(10)
                    }
                }
                .compositingGroup()
                .animation(.spring(response: 0.24, dampingFraction: 0.86), value: isPresented)
        }
        .buttonStyle(.plain)
        .background {
            SplickGlobalFrameReader(frame: $bellFrame)
        }
        .accessibilityLabel(accessibilityLabel)
    }

    private var badgeView: some View {
        Text(unreadCount > 99 ? "99+" : "\(unreadCount)")
            .font(.system(size: unreadCount > 99 ? 8 : 9, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, unreadCount > 9 ? 5.5 : 3.5)
            .padding(.vertical, 1)
            .frame(
                minWidth: unreadCount > 9 ? Self.badgeMinWidth + 2 : Self.badgeMinWidth,
                minHeight: Self.badgeHeight
            )
            .background {
                Capsule(style: .continuous)
                    .fill(SplickTheme.Colors.error)
                    .overlay {
                        Capsule(style: .continuous)
                            .strokeBorder(.white.opacity(0.95), lineWidth: 1.5)
                    }
                    .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
            }
            .fixedSize()
    }
}
