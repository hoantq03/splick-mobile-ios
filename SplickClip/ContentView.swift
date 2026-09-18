//
//  ContentView.swift
//  SplickClip
//

import DesignSystem
import Localization
import Storage
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var viewModel: ClipInviteViewModel
    @EnvironmentObject private var themeService: ThemeService
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ProfileCardView()
            .environment(\.usesBrandAuthChrome, true)
            .splickVisualTheme(themeService.theme.visualTheme(systemIsDark: colorScheme == .dark))
            .task {
                await viewModel.prepareSession()
                themeService.refreshFromStorage()
                #if DEBUG
                try? await Task.sleep(nanoseconds: 350_000_000)
                await viewModel.loadProfileIfStillIdle(username: "tq.hoan03")
                #endif
            }
            .onChange(of: scenePhase) { phase in
                if phase == .active {
                    themeService.refreshFromStorage()
                }
            }
            .onChange(of: colorScheme) { _ in
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
