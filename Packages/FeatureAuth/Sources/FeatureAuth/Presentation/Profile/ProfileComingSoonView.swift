import SwiftUI
import DesignSystem
import Localization

public struct ProfileComingSoonView: View {
    @EnvironmentObject private var languageService: LanguageService

    private let navigationTitleKey: L10nKey

    public init(navigationTitleKey: L10nKey) {
        self.navigationTitleKey = navigationTitleKey
    }

    public var body: some View {
        EmptyStateView(
            icon: "clock",
            title: languageService.text(.profileComingSoon),
            message: languageService.text(.profileComingSoonMessage)
        )
        .navigationTitle(languageService.text(navigationTitleKey))
        .navigationBarTitleDisplayMode(.inline)
    }
}
