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
                .modifier(ClipForcedColorSchemeModifier(scheme: themeService.preferredColorScheme))
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

/// When the user picked Light or Dark in Splick, push that into SwiftUI immediately.
/// When the preference is System, leave `colorScheme` unset so it tracks iOS appearance.
private struct ClipForcedColorSchemeModifier: ViewModifier {
    let scheme: ColorScheme?

    func body(content: Content) -> some View {
        if let scheme {
            content.environment(\.colorScheme, scheme)
        } else {
            content
        }
    }
}
