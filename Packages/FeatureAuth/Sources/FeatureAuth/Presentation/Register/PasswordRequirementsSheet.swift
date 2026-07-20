import SwiftUI
import DesignSystem
import Common
import Localization

struct PasswordRequirementsSheet: View {
    let result: PasswordStrengthResult
    @EnvironmentObject private var languageService: LanguageService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(languageService.text(.authPasswordRequirementsIntro))
                        .font(SplickTheme.Typography.callout)
                        .foregroundStyle(SplickTheme.Colors.textSecondary)
                        .listRowBackground(Color.clear)
                }

                Section {
                    ForEach(result.guideItems, id: \.rule) { item in
                        HStack(spacing: SplickTheme.Spacing.sm) {
                            Image(systemName: item.met ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(
                                    item.met ? SplickTheme.Colors.success : SplickTheme.Colors.textTertiary
                                )
                            Text(guideText(for: item.rule))
                                .font(SplickTheme.Typography.body)
                                .foregroundStyle(SplickTheme.Colors.textPrimary)
                        }
                    }
                }
            }
            .navigationTitle(languageService.text(.authPasswordRequirementsTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(languageService.text(.commonDone)) { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func guideText(for rule: PasswordRule) -> String {
        switch rule {
        case .minLength:
            return languageService.format(
                .authPasswordRuleMinLength,
                AppConstants.Validation.minPasswordLength
            )
        case .uppercase:
            return languageService.text(.authPasswordRuleUppercase)
        case .lowercase:
            return languageService.text(.authPasswordRuleLowercase)
        case .digit:
            return languageService.text(.authPasswordRuleDigit)
        case .specialCharacter:
            return languageService.text(.authPasswordRuleSpecial)
        }
    }
}
