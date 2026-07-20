import SwiftUI
import DesignSystem

struct ChatAddFriendBanner: View {
    let message: String
    let actionTitle: String?
    let actionSystemImage: String?
    let isProcessing: Bool
    let onAction: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: SplickTheme.Spacing.sm) {
            Text(message)
                .font(SplickTheme.Typography.caption)
                .foregroundStyle(SplickTheme.Colors.textSecondary)
                .multilineTextAlignment(.leading)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let actionTitle {
                Button(action: onAction) {
                    Label {
                        Text(actionTitle)
                            .font(SplickTheme.Typography.caption.weight(.semibold))
                            .lineLimit(1)
                    } icon: {
                        Image(systemName: actionSystemImage ?? "person.badge.plus")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .labelStyle(.titleAndIcon)
                    .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
                    .padding(.horizontal, SplickTheme.Spacing.sm)
                    .padding(.vertical, SplickTheme.Spacing.xxs + 2)
                    .background(
                        Capsule(style: .continuous)
                            .fill(SplickTheme.Colors.primaryGradientStart.opacity(0.12))
                    )
                }
                .buttonStyle(.plain)
                .disabled(isProcessing)
                .accessibilityLabel(actionTitle)
            }
        }
        .padding(.horizontal, SplickTheme.Spacing.md)
        .padding(.vertical, SplickTheme.Spacing.sm)
        .background {
            RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.card, style: .continuous)
                .fill(SplickTheme.Colors.secondaryBackground)
        }
        .padding(.horizontal, SplickTheme.Spacing.md)
        .padding(.top, SplickTheme.Spacing.sm)
        .padding(.bottom, SplickTheme.Spacing.xs)
    }
}
