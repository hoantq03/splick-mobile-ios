import SwiftUI
import DesignSystem

struct ProfileCompactActionButton: View {
    let icon: String
    let title: String
    var tint: Color = SplickTheme.Colors.textPrimary
    var isDisabled = false
    let action: () -> Void

    private var shape: Capsule {
        Capsule(style: .continuous)
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: SplickTheme.Spacing.xxxs) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .medium))
                    .frame(height: 20)

                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, SplickTheme.Spacing.sm)
            .padding(.horizontal, SplickTheme.Spacing.xxxs)
            .foregroundStyle(tint)
            .background(SplickTheme.Colors.secondaryBackground, in: shape)
            .clipShape(shape)
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.45 : 1)
    }
}
