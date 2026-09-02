import SwiftUI
import DesignSystem
import Common
import FeatureAuth
import FeatureMedia

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
        .environment(\.suppressKeyboardAutoFocus, appState.needsSplash)
        .dismissKeyboardOnTap()
        .animation(SplashMotion.reveal, value: appState.needsSplash)
        .task {
            pushNotificationCoordinator.refreshAuthorizationStatus()
        }
        .onChange(of: scenePhase) { phase in
            defer { previousScenePhase = phase }

            guard phase == .active else { return }
            pushNotificationCoordinator.refreshAuthorizationStatus()

            guard previousScenePhase == .background else { return }
            guard !appState.isAuthenticated else { return }
            appState.resetGuestSplashSession()
        }
        .onReceive(pushNotificationCoordinator.$pendingDestination.compactMap { $0 }) { _ in
            consumePendingNotificationDestination()
        }
        .onChange(of: appState.isAuthenticated) { isAuthenticated in
            guard isAuthenticated else { return }
            consumePendingNotificationDestination()
        }
        .onAppear {
            consumePendingNotificationDestination()
        }
        .task(id: appState.splashSessionID) {
            await bootstrapSession()
        }
        .onChange(of: appState.isAuthenticated) { isAuthenticated in
            if isAuthenticated {
                container.messagingWebSocketClient.connect()
            } else {
                container.messagingWebSocketClient.disconnect()
            }
        }
        .onChange(of: scenePhase) { phase in
            guard appState.isAuthenticated else { return }
            switch phase {
            case .active:
                // Always tear down a possibly zombie socket. iOS often skips `.background`
                // (Control Center, app switcher) so `connect()` would no-op on a dead task.
                // Inbox/thread catch-up is silent (WS `.connected` + gap-fill), not pull-to-refresh.
                container.messagingWebSocketClient.reconnect()
            case .inactive:
                break
            case .background:
                container.messagingWebSocketClient.disconnect()
            @unknown default:
                break
            }
        }
        .onAppear {
            if appState.isAuthenticated {
                container.messagingWebSocketClient.connect()
            }
        }
        .onChange(of: appState.needsSplash) { needsSplash in
            guard needsSplash else { return }
            hideKeyboard()
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

        case .unauthenticated, .authenticated:
            ZStack {
                if appState.isAuthenticated {
                    if appState.needsOAuthProfileSetup, let user = appState.currentUser {
                        CompleteOAuthProfileView(
                            viewModel: CompleteOAuthProfileViewModel(
                                user: user,
                                updateProfileUseCase: container.updateProfileUseCase,
                                languageService: container.languageService,
                                uploadAvatar: { image in
                                    try await container.uploadUserAvatarUseCase.execute(image: image).url
                                }
                            ),
                            onFinished: { updated in
                                appState.updateAuthenticatedUser(updated)
                                appState.completeOAuthProfileSetup()
                            }
                        )
                        .transition(SplashMotion.authenticatedTransition)
                        .zIndex(1)
                    } else {
                        MainTabView()
                            .transition(SplashMotion.authenticatedTransition)
                            .zIndex(1)
                    }
                } else {
                    unauthenticatedContent
                        .transition(SplashMotion.unauthenticatedTransition)
                        .zIndex(0)
                }
            }
            .animation(SplashMotion.authStateSlide, value: appState.isAuthenticated)
            .animation(SplashMotion.authStateSlide, value: appState.needsOAuthProfileSetup)
        }
    }

    private var unauthenticatedContent: some View {
        ZStack {
            authFlow
                .opacity(appState.hasPassedOnboardingThisSession ? 1 : 0)
                .offset(x: appState.hasPassedOnboardingThisSession ? 0 : 28)
                .allowsHitTesting(appState.hasPassedOnboardingThisSession)
                .zIndex(appState.hasPassedOnboardingThisSession ? 1 : 0)

            onboardingFlow
                .opacity(appState.hasPassedOnboardingThisSession ? 0 : 1)
                .offset(x: appState.hasPassedOnboardingThisSession ? -28 : 0)
                .allowsHitTesting(!appState.hasPassedOnboardingThisSession)
                .zIndex(appState.hasPassedOnboardingThisSession ? 0 : 1)
        }
        .animation(SplashMotion.onboardingToLogin, value: appState.hasPassedOnboardingThisSession)
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
                    languageService: container.languageService,
                    googleSignInPresenter: GoogleSignInClient.shared,
                    appleSignInPresenter: AppleSignInClient.shared
                ),
                forgotPasswordViewModelFactory: {
                    ForgotPasswordViewModel(
                        forgotPasswordUseCase: container.forgotPasswordUseCase,
                        verifyResetPasswordOtpUseCase: container.verifyResetPasswordOtpUseCase,
                        resetPasswordUseCase: container.resetPasswordUseCase,
                        languageService: container.languageService
                    )
                },
                onAuthenticated: { user, needsOAuthProfileSetup in
                    container.languageService.applyFromServer(user.preferredLocale)
                    appState.setAuthenticated(user: user, needsOAuthProfileSetup: needsOAuthProfileSetup)
                    Task {
                        await pushNotificationCoordinator.ensureDeviceTokenRegistered()
                    }
                }
            )
        }
    }

    // MARK: - Session restore

    private func consumePendingNotificationDestination() {
        guard appState.isAuthenticated else { return }
        guard let destination = pushNotificationCoordinator.pendingDestination else { return }
        appState.routeRemoteNotification(destination)
        pushNotificationCoordinator.clearPendingDestination()
    }

    private func bootstrapSession() async {
        if case .unknown = appState.authState {
            await restoreSessionLocalFirst()
        }

        guard appState.needsSplash else { return }

        try? await Task.sleep(for: AppConstants.Splash.minimumDisplayDuration)
        guard !Task.isCancelled else { return }
        guard appState.needsSplash else { return }
        appState.completeLaunchSplash()
    }

    private func restoreSessionLocalFirst() async {
        if let session = await container.restoreSessionUseCase.restoreLocal() {
            container.languageService.applyFromServer(session.user.preferredLocale)
            appState.setAuthenticated(user: session.user)
            consumePendingNotificationDestination()
            Task {
                await confirmRemoteSession()
                await pushNotificationCoordinator.ensureDeviceTokenRegistered()
            }
            return
        }

        appState.markUnauthenticated(container: container)
    }

    private func confirmRemoteSession() async {
        switch await container.restoreSessionUseCase.confirmRemote() {
        case .updated(let session):
            container.languageService.applyFromServer(session.user.preferredLocale)
            appState.updateAuthenticatedUser(session.user)
        case .unchanged:
            break
        case .signedOut:
            appState.setUnauthenticated(container: container)
        }
    }
}
