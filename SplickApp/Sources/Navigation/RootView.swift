import SwiftUI
import DesignSystem
import Common
import FeatureAuth

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var container: DependencyContainer

    @State private var previousScenePhase: ScenePhase = .inactive

    private static let dismissAnimation = Animation.spring(
        response: 0.78,
        dampingFraction: 0.86,
        blendDuration: 0.22
    )

    var body: some View {
        ZStack {
            rootContent

            if appState.needsSplash {
                splashOverlay
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(999)
            }
        }
        .ignoresSafeArea()
        .animation(Self.dismissAnimation, value: appState.needsSplash)
        .onChange(of: scenePhase) { phase in
            defer { previousScenePhase = phase }

            guard phase == .active else { return }
            guard previousScenePhase == .background else { return }
            guard !appState.isAuthenticated else { return }
            appState.resetGuestSplashSession()
        }
        .task(id: appState.splashSessionID) {
            guard appState.needsSplash else { return }
            await runSplashSequence()
        }
    }

    // MARK: - Splash overlay (logo + spinner — shown while session restores)

    private var splashOverlay: some View {
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
                SplickSpinner(size: .large)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SplickTheme.Colors.background)
    }

    // MARK: - Root content

    /// The onboarding 4-page intro shows every time the user is not signed in,
    /// until they tap through to the end (`passOnboardingGate()`).
    /// After passing the gate this session, the login screen is shown.
    @ViewBuilder
    private var rootContent: some View {
        switch appState.authState {
        case .unknown:
            SplickTheme.Colors.background.ignoresSafeArea()

        case .unauthenticated:
            if appState.hasPassedOnboardingThisSession {
                authFlow
            } else {
                onboardingFlow
            }

        case .authenticated:
            MainTabView()
        }
    }

    // MARK: - Flows

    private var onboardingFlow: some View {
        OnboardingView {
            appState.passOnboardingGate()
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

    // MARK: - Session restore

    private func runSplashSequence() async {
        async let minimumDisplay: Void = {
            try? await Task.sleep(for: AppConstants.Splash.minimumDisplayDuration)
        }()

        if case .unknown = appState.authState {
            await resolveInitialSession()
        }

        await minimumDisplay

        guard !Task.isCancelled else { return }
        guard appState.needsSplash else { return }
        appState.completeLaunchSplash()
    }

    private func resolveInitialSession() async {
        if let session = await container.restoreSessionUseCase.execute() {
            container.languageService.applyFromServer(session.user.preferredLocale)
            appState.setAuthenticated(user: session.user)
        } else {
            appState.markUnauthenticated(container: container)
        }
    }
}
