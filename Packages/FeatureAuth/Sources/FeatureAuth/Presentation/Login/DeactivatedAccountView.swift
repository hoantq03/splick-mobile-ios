import SwiftUI
import DesignSystem
import Localization
import Common

struct DeactivatedAccountView: View {
    let info: DeactivatedAccountInfo
    let isLoading: Bool
    let errorMessage: String?
    let onReactivate: () -> Void
    let onUseAnotherAccount: () -> Void

    @EnvironmentObject private var languageService: LanguageService

    var body: some View {
        VStack(spacing: SplickTheme.Spacing.lg) {
            ZStack {
                Circle()
                    .fill(SplickTheme.Colors.warning.opacity(0.14))
                    .frame(width: 64, height: 64)
                Image(systemName: "pause.circle.fill")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(SplickTheme.Colors.warning)
            }

            Text(languageService.text(.deactivatedAccountTitle))
                .font(SplickTheme.Typography.title)
                .multilineTextAlignment(.center)

            VStack(spacing: SplickTheme.Spacing.sm) {
                Text(languageService.format(
                    .deactivatedAccountSince,
                    formatted(info.deactivatedAt)
                ))
                Text(languageService.format(
                    .deactivatedAccountDeletion,
                    formatted(info.scheduledDeletionAt)
                ))
            }
            .font(SplickTheme.Typography.callout)
            .foregroundStyle(SplickTheme.Colors.textSecondary)
            .multilineTextAlignment(.center)

            if let errorMessage, !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(SplickTheme.Typography.caption)
                    .foregroundStyle(SplickTheme.Colors.error)
                    .multilineTextAlignment(.center)
            }

            SplickButton(
                languageService.text(.deactivatedAccountReactivate),
                isLoading: isLoading,
                isDisabled: isLoading || info.reactivationToken.isEmpty
            ) {
                onReactivate()
            }

            SplickButton(
                languageService.text(.deactivatedAccountUseAnother),
                style: .secondary,
                isDisabled: isLoading
            ) {
                onUseAnotherAccount()
            }
        }
        .padding(.top, SplickTheme.Spacing.md)
    }

    private func formatted(_ date: Date?) -> String {
        guard let date else {
            return languageService.text(.deactivatedAccountUnknownDate)
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: languageService.locale.rawValue)
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
