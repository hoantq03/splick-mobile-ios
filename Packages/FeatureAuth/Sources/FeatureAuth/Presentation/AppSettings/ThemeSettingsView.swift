import SwiftUI
import DesignSystem
import Localization

public struct ThemeSettingsView: View {
    @EnvironmentObject private var languageService: LanguageService
    @EnvironmentObject private var themeService: ThemeService

    public init() {}

    public var body: some View {
        List {
            Section {
                ForEach(AppTheme.allCases) { option in
                    Button {
                        themeService.setTheme(option)
                    } label: {
                        HStack(spacing: SplickTheme.Spacing.sm) {
                            SplickThemeIconPreview(theme: option)
                            Text(languageService.text(option.displayNameKey))
                                .foregroundStyle(SplickTheme.Colors.textPrimary)
                            Spacer()
                            if themeService.theme == option {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
                            }
                        }
                    }
                }
            } footer: {
                Text(languageService.text(.profileThemeIconHint))
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(languageService.text(.profileTheme))
        .navigationBarTitleDisplayMode(.inline)
    }
}
