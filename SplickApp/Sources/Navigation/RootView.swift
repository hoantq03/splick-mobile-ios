import SwiftUI
import DesignSystem
import Common
import FeatureAuth

struct RootView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var container: DependencyContainer

    var body: some View {
        Group {
            switch appState.authState {
            case .unknown:
                splashView

            case .unauthenticated:
                authFlow

            case .authenticated:
                MainTabView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: appState.authState)
    }

    private var splashView: some View {
        VStack(spacing: SplickTheme.Spacing.md) {
            Text("Splick")
                .font(SplickTheme.Typography.largeTitle)
                .foregroundStyle(SplickTheme.Colors.primaryGradient)

            ProgressView()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SplickTheme.Colors.background)
        .task {
            await checkExistingSession()
        }
    }

    private var authFlow: some View {
        NavigationStack {
            LoginView(
                viewModel: LoginViewModel(loginUseCase: container.loginUseCase),
                registerUseCase: container.registerUseCase,
                onAuthenticated: { user in
                    appState.setAuthenticated(user: user)
                }
            )
        }
    }

    private func checkExistingSession() async {
        if !AppConstants.Dev.useMockData {
            try? await Task.sleep(for: .seconds(1))
        }

        if await container.sessionManager.isAuthenticated(),
           let session = await container.sessionManager.currentSession() {
            appState.setAuthenticated(user: session.user)
        } else {
            appState.setUnauthenticated()
        }
    }
}
