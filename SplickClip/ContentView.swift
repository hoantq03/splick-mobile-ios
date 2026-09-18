//
//  ContentView.swift
//  SplickClip
//

import DesignSystem
import Localization
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var viewModel: ClipInviteViewModel
    @EnvironmentObject private var themeService: ThemeService
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ProfileCardView()
            .splickVisualTheme(themeService.theme.visualTheme(systemIsDark: colorScheme == .dark))
            .task {
                await viewModel.prepareSession()
                themeService.applyUserInterfaceStyle()
            }
    }
}

#Preview {
    let language = LanguageService(userDefaults: UserDefaultsService())
    ContentView()
        .environmentObject(language)
        .environmentObject(ThemeService(userDefaults: UserDefaultsService()))
        .environmentObject(ClipInviteViewModel(languageService: language))
}
