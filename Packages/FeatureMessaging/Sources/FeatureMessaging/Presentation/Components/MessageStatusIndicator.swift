import SwiftUI
import DesignSystem
import SplickDomain

struct MessageStatusIndicator: View {
    let status: MessageDeliveryStatus

    private let size: CGFloat = 14

    var body: some View {
        switch status {
        case .sending:
            Circle()
                .stroke(SplickTheme.Colors.textTertiary, lineWidth: 1.5)
                .frame(width: size, height: size)

        case .sent:
            ZStack {
                Circle()
                    .stroke(SplickTheme.Colors.primaryGradientStart, lineWidth: 1.5)
                Image(systemName: "checkmark")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
            }
            .frame(width: size, height: size)

        case .delivered, .read:
            ZStack {
                Circle()
                    .fill(SplickTheme.Colors.primaryGradientStart)
                Image(systemName: "checkmark")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundStyle(SplickTheme.Colors.background)
                    .blendMode(.destinationOut)
            }
            .compositingGroup()
            .frame(width: size, height: size)

        case .failed:
            EmptyView()
        }
    }
}
