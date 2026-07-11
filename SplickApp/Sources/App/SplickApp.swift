import SwiftUI
import GoogleSignIn
import DesignSystem
import Localization

@main
struct SplickApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appState = AppState()
    @StateObject private var container = DependencyContainer.shared
    @StateObject private var pushNotificationCoordinator = PushNotificationCoordinator.shared

    init() {
        ImagePipelineConfigurator.configureIfNeeded()
        GoogleSignInConfiguration.configureIfNeeded()
        let container = DependencyContainer.shared
        PushNotificationCoordinator.shared.configure(
            deviceTokenService: container.deviceTokenService,
            userDefaultsService: container.userDefaultsService,
            hasAccessToken: {
                await container.tokenProvider.accessToken() != nil
            }
        )
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environmentObject(container)
                .environmentObject(pushNotificationCoordinator)
                .environmentObject(container.languageService)
                .languageService(container.languageService)
                .onOpenURL { url in
                    if !appState.handleDeepLink(url) {
                        GIDSignIn.sharedInstance.handle(url)
                    }
                }
        }
    }
}
