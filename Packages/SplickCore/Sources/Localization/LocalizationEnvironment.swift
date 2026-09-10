import SwiftUI

private struct LanguageServiceKey: EnvironmentKey {
    static let defaultValue: LanguageService? = nil
}

public extension EnvironmentValues {
    var languageService: LanguageService? {
        get { self[LanguageServiceKey.self] }
        set { self[LanguageServiceKey.self] = newValue }
    }
}

public extension View {
    func languageService(_ service: LanguageService) -> some View {
        environment(\.languageService, service)
            .environment(\.locale, Locale(identifier: service.locale.rawValue))
    }
}
