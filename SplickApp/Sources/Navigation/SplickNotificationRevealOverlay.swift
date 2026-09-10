import SwiftUI
import DesignSystem

struct SplickNotificationRevealOverlay<Content: View>: View {
    @Binding var isPresented: Bool
    let anchorFrame: CGRect
    let unreadCount: Int
    @ViewBuilder let content: (@escaping () -> Void) -> Content

    @State private var showsCloseIcon = true

    private let toolbarButtonSize: CGFloat = 42
    private let toolbarIconFrameSize: CGFloat = 30
    private let toolbarBellFontSize: CGFloat = 17
    private let toolbarBadgeHeight: CGFloat = 20
    private let toolbarBadgeMinWidth: CGFloat = 20

    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                Color.clear
                    .frame(height: toolbarRevealHeight)
                    .allowsHitTesting(false)

                Color.black.opacity(0.18)
                    .onTapGesture {
                        dismiss()
                    }
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                content(dismiss)
            }
            .frame(maxWidth: min(UIScreen.main.bounds.width - 24, 420))
            .frame(maxHeight: min(UIScreen.main.bounds.height * 0.72, 560))
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(SplickTheme.Colors.secondaryBackground)
            )
            .padding(.top, topPadding)
            .padding(.trailing, 12)
            .shadow(color: .black.opacity(0.14), radius: 24, y: 14)
            .transition(.move(edge: .top).combined(with: .opacity))

            toolbarToggleButton
                .offset(x: max(anchorFrame.minX - 2, 0), y: max(anchorFrame.minY - 2, 0))
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.86), value: isPresented)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Notifications overlay \(unreadCount)")
        .onAppear {
            showsCloseIcon = true
        }
    }

    private var topPadding: CGFloat {
        let safeTop = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .safeAreaInsets.top ?? 0
        let anchorBasedPadding = anchorFrame.maxY > 1 ? anchorFrame.maxY + 8 : safeTop + 12
        return max(anchorBasedPadding, safeTop + 12)
    }

    private var toolbarRevealHeight: CGFloat {
        let safeTop = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .safeAreaInsets.top ?? 0
        return max(anchorFrame.maxY + 10, safeTop + 44)
    }

    private var toolbarToggleButton: some View {
        Button {
            dismiss()
        } label: {
            ZStack {
                Image(systemName: unreadCount > 0 ? "bell.fill" : "bell")
                    .font(.system(size: toolbarBellFontSize, weight: .medium))
                    .foregroundStyle(SplickTheme.Colors.textPrimary)
                    .frame(width: toolbarIconFrameSize, height: toolbarIconFrameSize)
                    .offset(x: -1, y: 1)
                    .opacity(showsCloseIcon ? 0 : 1)
                    .scaleEffect(showsCloseIcon ? 0.82 : 1)

                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(SplickTheme.Colors.textPrimary)
                    .frame(width: toolbarIconFrameSize, height: toolbarIconFrameSize)
                    .opacity(showsCloseIcon ? 1 : 0)
                    .scaleEffect(showsCloseIcon ? 1 : 0.82)
            }
            .frame(width: toolbarButtonSize, height: toolbarButtonSize)
            .overlay(alignment: .topTrailing) {
                if unreadCount > 0, !showsCloseIcon {
                    toolbarBadge
                        .offset(x: 2, y: -2)
                        .zIndex(10)
                }
            }
            .compositingGroup()
            .animation(.spring(response: 0.2, dampingFraction: 0.9), value: showsCloseIcon)
        }
        .buttonStyle(.plain)
    }

    private var toolbarBadge: some View {
        Text(unreadCount > 99 ? "99+" : "\(unreadCount)")
            .font(.system(size: unreadCount > 99 ? 8 : 9, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, unreadCount > 9 ? 5.5 : 3.5)
            .padding(.vertical, 1)
            .frame(
                minWidth: unreadCount > 9 ? toolbarBadgeMinWidth + 2 : toolbarBadgeMinWidth,
                minHeight: toolbarBadgeHeight
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

    private func dismiss() {
        withAnimation(.spring(response: 0.18, dampingFraction: 0.92)) {
            showsCloseIcon = false
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 110_000_000)
            withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
                isPresented = false
            }
        }
    }
}
