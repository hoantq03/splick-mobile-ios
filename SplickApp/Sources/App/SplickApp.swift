import SwiftUI
import GoogleSignIn

@main
struct SplickApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var container = DependencyContainer.shared

    init() {
        GoogleSignInConfiguration.configureIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environmentObject(container)
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
    }
}
