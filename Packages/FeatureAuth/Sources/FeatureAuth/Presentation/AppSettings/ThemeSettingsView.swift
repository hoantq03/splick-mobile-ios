import SwiftUI
import DesignSystem
import Localization

public struct ThemeSettingsView: View {
    @EnvironmentObject private var languageService: LanguageService
    @EnvironmentObject private var themeService: ThemeService

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SplickTheme.Spacing.xs) {
                Text(languageService.text(.profileTheme))
                    .font(SplickTheme.Typography.headline)
                    .foregroundStyle(SplickTheme.Colors.textPrimary)
                    .padding(.leading, SplickTheme.Spacing.sm)

                VStack(spacing: 0) {
                    ForEach(Array(AppTheme.allCases.enumerated()), id: \.element.id) { index, option in
                        Button {
                            themeService.setTheme(option)
                        } label: {
                            HStack(spacing: SplickTheme.Spacing.sm) {
                                SplickThemeIconPreview(theme: option)
                                Text(languageService.text(option.displayNameKey))
                                    .font(SplickTheme.Typography.body)
                                    .foregroundStyle(SplickTheme.Colors.textPrimary)
                                Spacer(minLength: 0)
                                if themeService.theme == option {
                                    Image(systemName: "checkmark")
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
                                }
                            }
                            .padding(.horizontal, SplickTheme.Spacing.md)
                            .padding(.vertical, SplickTheme.Spacing.sm + 2)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if index < AppTheme.allCases.count - 1 {
                            Divider()
                                .padding(.leading, 56)
                        }
                    }
                }
                .splickSettingsCardChrome()

                Text(languageService.text(.profileThemeIconHint))
                    .font(SplickTheme.Typography.caption)
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
                    .padding(.leading, SplickTheme.Spacing.sm)
                    .padding(.top, SplickTheme.Spacing.xxs)
            }
            .padding(.horizontal, SplickTheme.Spacing.xl)
            .padding(.vertical, SplickTheme.Spacing.lg)
        }
        .background(SplickTheme.Colors.background)
        .navigationTitle(languageService.text(.profileTheme))
        .navigationBarTitleDisplayMode(.inline)
    }
}
