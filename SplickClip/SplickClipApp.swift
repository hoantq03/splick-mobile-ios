//
//  SplickClipApp.swift
//  SplickClip
//

import Localization
import Storage
import SwiftUI

@main
struct SplickClipApp: App {
    @StateObject private var languageService: LanguageService
    @StateObject private var themeService: ThemeService
    @StateObject private var viewModel: ClipInviteViewModel

    init() {
        let defaults = UserDefaultsService()
        let language = LanguageService(userDefaults: defaults)
        let theme = ThemeService(userDefaults: defaults)
        _languageService = StateObject(wrappedValue: language)
        _themeService = StateObject(wrappedValue: theme)
        _viewModel = StateObject(wrappedValue: ClipInviteViewModel(languageService: language))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(languageService)
                .environmentObject(themeService)
                .environmentObject(viewModel)
                .languageService(languageService)
                .preferredColorScheme(themeService.preferredColorScheme)
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                    guard let url = activity.webpageURL else { return }
                    viewModel.handleInviteURL(url)
                }
                .onOpenURL { url in
                    viewModel.handleInviteURL(url)
                }
        }
    }
}
