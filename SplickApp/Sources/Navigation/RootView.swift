import SwiftUI
import DesignSystem
import Common
import FeatureAuth

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var container: DependencyContainer
    @EnvironmentObject private var pushNotificationCoordinator: PushNotificationCoordinator

    @State private var previousScenePhase: ScenePhase = .inactive

    var body: some View {
        ZStack {
            rootContent
                .offset(y: appState.needsSplash ? 28 : 0)
                .opacity(appState.needsSplash ? 0.94 : 1)
                .animation(SplashMotion.reveal, value: appState.isLaunchSplashComplete)

            if appState.needsSplash {
                SplashScreenView()
                    .transition(SplashMotion.slideUpRemoval)
                    .zIndex(999)
            }
        }
        .ignoresSafeArea()
        .animation(SplashMotion.reveal, value: appState.needsSplash)
        .onChange(of: scenePhase) { phase in
            defer { previousScenePhase = phase }

            guard phase == .active else { return }
            pushNotificationCoordinator.refreshAuthorizationStatus()

            guard previousScenePhase == .background else { return }
            guard !appState.isAuthenticated else { return }
            appState.resetGuestSplashSession()
        }
        .onReceive(pushNotificationCoordinator.$pendingDestination.compactMap { $0 }) { destination in
            appState.routeRemoteNotification(destination)
            pushNotificationCoordinator.clearPendingDestination()
        }
        .task(id: appState.isAuthenticated) {
            guard appState.isAuthenticated else { return }
            await pushNotificationCoordinator.syncStoredDeviceTokenIfPossible()
        }
        .task(id: appState.splashSessionID) {
            guard appState.needsSplash else { return }
            await runSplashSequence()
        }
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
            ZStack {
                if appState.hasPassedOnboardingThisSession {
                    authFlow
                        .transition(SplashMotion.loginInsertion)
                } else {
                    onboardingFlow
                        .transition(SplashMotion.onboardingRemoval)
                }
            }
            .animation(SplashMotion.onboardingToLogin, value: appState.hasPassedOnboardingThisSession)

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
                    checkIdentifierUseCase: container.checkIdentifierUseCase,
                    loginUseCase: container.loginUseCase,
                    registerUseCase: container.registerUseCase,
                    requestEmailOtpUseCase: container.requestEmailOtpUseCase,
                    requestPhoneOtpUseCase: container.requestPhoneOtpUseCase,
                    verifyPhoneOtpUseCase: container.verifyPhoneOtpUseCase,
                    googleSignInUseCase: container.googleSignInUseCase,
                    appleSignInUseCase: container.appleSignInUseCase,
                    googleSignInPresenter: GoogleSignInClient.shared,
                    appleSignInPresenter: AppleSignInClient.shared
                ),
                forgotPasswordViewModelFactory: {
                    ForgotPasswordViewModel(
                        forgotPasswordUseCase: container.forgotPasswordUseCase,
                        verifyResetPasswordOtpUseCase: container.verifyResetPasswordOtpUseCase,
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
