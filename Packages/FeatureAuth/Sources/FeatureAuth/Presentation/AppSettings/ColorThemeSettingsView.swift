import SwiftUI
import DesignSystem
import Localization

public struct ColorThemeSettingsView: View {
    @EnvironmentObject private var languageService: LanguageService
    @EnvironmentObject private var themeService: ThemeService

    public init() {}

    public var body: some View {
        List {
            Section {
                ForEach(SplickColorTheme.allCases) { option in
                    Button {
                        themeService.setColorTheme(option)
                    } label: {
                        HStack(spacing: SplickTheme.Spacing.sm) {
                            SplickColorThemeIconPreview(theme: option)
                            Text(languageService.text(option.displayNameKey))
                                .foregroundStyle(SplickTheme.Colors.textPrimary)
                            Spacer()
                            if themeService.colorTheme == option {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(SplickThemeCatalog.brandPalette(for: themeService.colorTheme).accent)
                            }
                        }
                    }
                }
            } footer: {
                Text(languageService.text(.profileColorThemeHint))
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(languageService.text(.profileColorTheme))
        .navigationBarTitleDisplayMode(.inline)
    }
}
