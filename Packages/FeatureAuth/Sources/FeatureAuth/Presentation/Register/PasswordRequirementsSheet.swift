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
                            Text(languageService.passwordRuleText(item.rule))
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
}
