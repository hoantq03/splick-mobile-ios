import SwiftUI
import DesignSystem

struct SplickNotificationRevealOverlay<Content: View>: View {
    @Binding var isPresented: Bool
    let anchorFrame: CGRect
    let unreadCount: Int
    @ViewBuilder let content: (@escaping () -> Void) -> Content

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.opacity(0.18)
                .ignoresSafeArea()
                .onTapGesture {
                    dismiss()
                }

            VStack(spacing: 0) {
                content(dismiss)
            }
            .frame(maxWidth: min(UIScreen.main.bounds.width - 24, 420))
            .frame(maxHeight: min(UIScreen.main.bounds.height * 0.72, 560))
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(SplickTheme.Colors.secondaryBackground)
            )
            .overlay(alignment: .topTrailing) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(SplickTheme.Colors.textSecondary)
                        .frame(width: 28, height: 28)
                        .background(
                            Circle()
                                .fill(SplickTheme.Colors.background)
                        )
                }
                .padding(SplickTheme.Spacing.sm)
            }
            .padding(.top, topPadding)
            .padding(.trailing, 12)
            .shadow(color: .black.opacity(0.14), radius: 24, y: 14)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.86), value: isPresented)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Notifications overlay \(unreadCount)")
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

    private func dismiss() {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
            isPresented = false
        }
    }
}
