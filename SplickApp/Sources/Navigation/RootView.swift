import SwiftUI
import DesignSystem
import Common
import FeatureAuth

struct RootView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var container: DependencyContainer

    @State private var splashLayerActive = true

    private static let dismissAnimation = Animation.spring(
        response: 0.78,
        dampingFraction: 0.86,
        blendDuration: 0.22
    )

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                rootContent

                if splashLayerActive {
                    SplashScreenView()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .offset(y: appState.isShowingSplash ? 0 : -geometry.size.height)
                        .ignoresSafeArea()
                        .zIndex(1)
                        .allowsHitTesting(appState.isShowingSplash)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .ignoresSafeArea()
        .animation(Self.dismissAnimation, value: appState.isShowingSplash)
        .onChange(of: appState.isShowingSplash) { _, isShowing in
            if isShowing {
                splashLayerActive = true
            } else {
                Task {
                    try? await Task.sleep(for: AppConstants.Splash.dismissDuration)
                    splashLayerActive = false
                }
            }
        }
        .task(id: appState.isShowingSplash) {
            guard shouldRunSplashSequence else { return }
            await runSplashSequence()
        }
    }

    @ViewBuilder
    private var rootContent: some View {
        switch appState.authState {
        case .unknown:
            SplickTheme.Colors.background
                .ignoresSafeArea()

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

    private var shouldRunSplashSequence: Bool {
        switch appState.authState {
        case .unknown:
            return true
        case .unauthenticated:
            return appState.isShowingSplash
        case .authenticated:
            return false
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
                    verifyPhoneOtpUseCase: container.verifyPhoneOtpUseCase,
                    googleSignInUseCase: container.googleSignInUseCase,
                    googleSignInPresenter: GoogleSignInClient.shared
                ),
                registerViewModelFactory: {
                    RegisterViewModel(
                        registerUseCase: container.registerUseCase,
                        requestEmailOtpUseCase: container.requestEmailOtpUseCase,
                        requestPhoneOtpUseCase: container.requestPhoneOtpUseCase
                    )
                },
                forgotPasswordViewModelFactory: {
                    ForgotPasswordViewModel(
                        forgotPasswordUseCase: container.forgotPasswordUseCase,
                        resetPasswordUseCase: container.resetPasswordUseCase
                    )
                },
                onAuthenticated: { user in
                    container.languageService.applyFromServer(user.preferredLocale)
                    appState.setAuthenticated(user: user)
                }
            )
        }
    }

    private func runSplashSequence() async {
        async let minimumDisplay: Void = {
            try? await Task.sleep(for: AppConstants.Splash.minimumDisplayDuration)
        }()

        if case .unknown = appState.authState {
            await resolveInitialSession()
        }

        await minimumDisplay

        guard !Task.isCancelled else { return }
        guard appState.isShowingSplash else { return }
        appState.finishSplash()
    }

    private func resolveInitialSession() async {
        if let session = await container.restoreSessionUseCase.execute() {
            container.languageService.applyFromServer(session.user.preferredLocale)
            appState.setAuthenticated(user: session.user)
        } else {
            appState.setUnauthenticated(container: container)
        }
    }
}
