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

    var body: some View {
        ZStack {
            rootContent

            if appState.needsLaunchLoading {
                SplashScreenView()
                    .transition(.opacity)
                    .zIndex(999)
            }
        }
            .ignoresSafeArea()
            .environment(\.suppressKeyboardAutoFocus, appState.needsLaunchLoading)
            .dismissKeyboardOnTap()
            .progressViewStyle(SplickProgressViewStyle())
            .animation(.easeOut(duration: 0.22), value: appState.needsLaunchLoading)
            .environment(\.launchRevealActive, !appState.needsLaunchLoading)
            .task {
                pushNotificationCoordinator.refreshAuthorizationStatus()
                await bootstrapSession()
            }
            .onChange(of: scenePhase) { phase in
                if phase == .active {
                    pushNotificationCoordinator.refreshAuthorizationStatus()
                }
                guard appState.isAuthenticated else { return }
                switch phase {
                case .active:
                    container.messagingWebSocketClient.reconnect()
                case .inactive:
                    break
                case .background:
                    container.messagingWebSocketClient.disconnect()
                @unknown default:
                    break
                }
            }
            .onReceive(pushNotificationCoordinator.$pendingDestination.compactMap { $0 }) { _ in
                consumePendingNotificationDestination()
            }
            .onChange(of: appState.isAuthenticated) { isAuthenticated in
                if isAuthenticated {
                    container.messagingWebSocketClient.connect()
                    consumePendingNotificationDestination()
                    if appState.pendingUserProfileNavigation != nil
                        || !(appState.pendingUserProfileUsername ?? "").isEmpty {
                        appState.selectedTab = .friends
                    }
                    Task { await claimPendingBillInviteIfNeeded() }
                } else {
                    container.messagingWebSocketClient.disconnect()
                }
            }
            .onAppear {
                consumePendingNotificationDestination()
                if appState.isAuthenticated {
                    container.messagingWebSocketClient.connect()
                    Task { await claimPendingBillInviteIfNeeded() }
                }
            }
    }

    // MARK: - Root content

    /// After launch loading, unauthenticated users go straight to login.
    @ViewBuilder
    private var rootContent: some View {
        switch appState.authState {
        case .unknown:
            SplickBrandAtmosphere()

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
                    authFlow
                        .transition(SplashMotion.unauthenticatedTransition)
                        .zIndex(0)
                }
            }
            .animation(SplashMotion.authStateSlide, value: appState.isAuthenticated)
            .animation(SplashMotion.authStateSlide, value: appState.needsOAuthProfileSetup)
        }
    }

    // MARK: - Flows

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
                    reactivateAccountUseCase: container.reactivateAccountUseCase,
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
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .background {
            SplickBrandAtmosphere()
        }
    }

    // MARK: - Session restore

    private func consumePendingNotificationDestination() {
        guard appState.isAuthenticated else { return }
        guard let destination = pushNotificationCoordinator.pendingDestination else { return }
        appState.routeRemoteNotification(destination)
        pushNotificationCoordinator.clearPendingDestination()
    }

    private func claimPendingBillInviteIfNeeded() async {
        guard appState.isAuthenticated else { return }
        guard let pending = appState.consumePendingBillInvite() else { return }
        do {
            let result = try await container.claimBillInvite(
                token: pending.token,
                splitId: pending.splitId
            )
            if let postId = result.postId {
                appState.openPostFromNotification(postId)
            } else {
                appState.selectedTab = .expenses
            }
        } catch {
            appState.storePendingBillInvite(pending.token, splitId: pending.splitId)
        }
    }

    private func bootstrapSession() async {
        if case .unknown = appState.authState {
            await restoreSessionLocalFirst()
        }

        guard appState.needsLaunchLoading else { return }
        try? await Task.sleep(for: AppConstants.Splash.minimumDisplayDuration)
        guard !Task.isCancelled else { return }
        appState.startLaunchSplashExit()
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
