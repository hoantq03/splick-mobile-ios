import SwiftUI
import DesignSystem
import Localization

struct ConnectAccountSheetHeader: View {
    let kind: ConnectedAccountProviderKind
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: SplickTheme.Spacing.md) {
            ConnectedAccountProviderIcon(kind: kind, size: 56)

            VStack(spacing: SplickTheme.Spacing.xxs) {
                Text(title)
                    .font(SplickTheme.Typography.headline)
                    .foregroundStyle(SplickTheme.Colors.textPrimary)
                    .multilineTextAlignment(.center)

                Text(subtitle)
                    .font(SplickTheme.Typography.callout)
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, SplickTheme.Spacing.sm)
        .accessibilityElement(children: .combine)
    }
}

struct ConnectAccountReadOnlyField: View {
    let label: String
    let value: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.xxs) {
            Text(label)
                .font(SplickTheme.Typography.caption)
                .foregroundStyle(SplickTheme.Colors.textSecondary)
                .padding(.leading, SplickTheme.Spacing.sm)

            HStack(spacing: SplickTheme.Spacing.xs) {
                Image(systemName: icon)
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
                    .frame(width: 20)

                Text(value)
                    .font(SplickTheme.Typography.body)
                    .foregroundStyle(SplickTheme.Colors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "lock.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(SplickTheme.Colors.textSecondary.opacity(0.55))
                    .accessibilityHidden(true)
            }
            .padding(SplickTheme.Spacing.sm)
            .background(SplickTheme.Colors.secondaryBackground.opacity(0.92))
            .clipShape(RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.control, style: .continuous))
        }
    }
}

struct ConnectAccountSheetErrorBanner: View {
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: SplickTheme.Spacing.xs) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(SplickTheme.Colors.error)
            Text(message)
                .font(SplickTheme.Typography.caption)
                .foregroundStyle(SplickTheme.Colors.error)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(SplickTheme.Spacing.sm)
        .background(SplickTheme.Colors.error.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.control, style: .continuous))
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

struct ConnectAccountResendControl: View {
    let secondsRemaining: Int
    let isRequesting: Bool
    let resendLabel: String
    let countdownFormat: (Int) -> String
    let onResend: () -> Void

    var body: some View {
        Group {
            if secondsRemaining > 0 {
                Text(countdownFormat(secondsRemaining))
                    .font(SplickTheme.Typography.caption)
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .transition(.opacity)
            } else {
                Button(action: onResend) {
                    Text(resendLabel)
                        .font(SplickTheme.Typography.callout)
                        .fontWeight(.semibold)
                        .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
                }
                .buttonStyle(.plain)
                .disabled(isRequesting)
                .opacity(isRequesting ? 0.5 : 1)
                .frame(maxWidth: .infinity)
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: secondsRemaining)
    }
}
