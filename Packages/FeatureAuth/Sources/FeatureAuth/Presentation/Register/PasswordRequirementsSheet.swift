import SwiftUI
import DesignSystem
import Common

struct PasswordRequirementsSheet: View {
    let result: PasswordStrengthResult
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Your password must meet all of the following:")
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
                            Text(item.rule.guideText)
                                .font(SplickTheme.Typography.body)
                                .foregroundStyle(SplickTheme.Colors.textPrimary)
                        }
                    }
                }
            }
            .navigationTitle(result.guideTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
