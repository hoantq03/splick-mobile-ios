import SwiftUI
import DesignSystem

struct SplashScreenView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(hex: 0x5B6CFF).opacity(0.12),
                    SplickTheme.Colors.background,
                    Color(hex: 0x2A9D8F).opacity(0.1),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: SplickTheme.Spacing.md) {
                SplickLogoMark(size: 128, layout: .markOnly, style: .fullColor)
                Text("Splick")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(SplickTheme.Colors.primaryGradient)
                SplickSpinner(size: .large)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SplickTheme.Colors.background)
    }
}
