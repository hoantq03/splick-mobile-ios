import SwiftUI
import GoogleSignIn
import DesignSystem
import Localization

@main
struct SplickApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var container = DependencyContainer.shared

    init() {
        ImagePipelineConfigurator.configureIfNeeded()
        GoogleSignInConfiguration.configureIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environmentObject(container)
                .environmentObject(container.languageService)
                .languageService(container.languageService)
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
    }
}
