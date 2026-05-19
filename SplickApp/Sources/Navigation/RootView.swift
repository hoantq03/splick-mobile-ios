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
                if appState.hasCompletedOnboarding {
                    authFlow
                } else {
                    onboardingFlow
                }

            case .authenticated:
                MainTabView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: appState.authState)
    }

    private var splashView: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(hex: 0x5B6CFF).opacity(0.12),
                    SplickTheme.Colors.background,
                    Color(hex: 0x2A9D8F).opacity(0.1),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: SplickTheme.Spacing.md) {
                SplickLogoMark(size: 128, layout: .markOnly, style: .fullColor)
                Text("Splick")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(SplickTheme.Colors.primaryGradient)
                ProgressView()
                    .tint(SplickTheme.Colors.primaryGradientStart)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            await checkExistingSession()
        }
    }

    private var onboardingFlow: some View {
        OnboardingView {
            appState.completeOnboarding()
        }
    }

    private var authFlow: some View {
        NavigationStack {
            LoginView(
                viewModel: LoginViewModel(
                    loginUseCase: container.loginUseCase,
                    requestPhoneOtpUseCase: container.requestPhoneOtpUseCase,
                    verifyPhoneOtpUseCase: container.verifyPhoneOtpUseCase
                ),
                registerViewModelFactory: {
                    RegisterViewModel(
                        registerUseCase: container.registerUseCase,
                        requestEmailOtpUseCase: container.requestEmailOtpUseCase,
                        requestPhoneOtpUseCase: container.requestPhoneOtpUseCase
                    )
                },
                onAuthenticated: { user in
                    appState.setAuthenticated(user: user)
                }
            )
        }
    }

    private func checkExistingSession() async {
        if let session = await container.restoreSessionUseCase.execute() {
            appState.setAuthenticated(user: session.user)
        } else {
            appState.setUnauthenticated()
        }
    }
}
