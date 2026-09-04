import SwiftUI
import DesignSystem

struct TabBarBadgeView: View {
    let count: Int

    var body: some View {
        if count > 0 {
            Text(count > 99 ? "99+" : "\(count)")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, count > 9 ? 5 : 0)
                .frame(minWidth: 16, minHeight: 16)
                .background(
                    Capsule()
                        .fill(SplickTheme.Colors.primaryGradientStart)
                )
        }
    }
}
