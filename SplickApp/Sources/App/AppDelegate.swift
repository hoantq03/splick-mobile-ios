import Foundation
import UIKit
import UserNotifications
import Common
import Localization
import DesignSystem

@MainActor
final class AppDelegate: NSObject, UIApplicationDelegate, @preconcurrency UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        SplickHiddenScrollIndicators.apply()

        if let userInfo = launchOptions?[.remoteNotification] as? [AnyHashable: Any] {
            PushNotificationCoordinator.shared.handleRemoteNotification(userInfo: userInfo)
        }

        return true
    }

    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        .portrait
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        PushNotificationCoordinator.shared.handleDeviceTokenRegistration(deviceToken)
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        PushNotificationCoordinator.shared.handleDeviceTokenRegistrationFailure(error)
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        let coordinator = PushNotificationCoordinator.shared
        coordinator.handleRemoteNotification(
            userInfo: userInfo,
            queueDestination: false
        )
        // Retract the heads-up after a short delay; the quiet re-post keeps it in NC.
        if application.applicationState != .active,
           !PushNotificationCoordinator.isHeadsUpRetractedRetain(userInfo)
        {
            var backgroundTask = UIBackgroundTaskIdentifier.invalid
            backgroundTask = application.beginBackgroundTask(withName: "splick.banner-retract") {
                if backgroundTask != .invalid {
                    application.endBackgroundTask(backgroundTask)
                    backgroundTask = .invalid
                }
            }
            Task { @MainActor in
                // Newer push → hide previous heads-up immediately, then arm 2.5s for this one.
                await coordinator.retractStaleHeadsUpsImmediately(exceptUserInfo: userInfo)
                coordinator.scheduleBannerAutoDismiss(userInfo: userInfo)
                try? await Task.sleep(for: AppConstants.PushNotifications.bannerAutoDismissDelay)
                try? await Task.sleep(for: .milliseconds(600))
                if backgroundTask != .invalid {
                    application.endBackgroundTask(backgroundTask)
                    backgroundTask = .invalid
                }
            }
        }
        completionHandler(.newData)
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let coordinator = PushNotificationCoordinator.shared
        let requestIdentifier = notification.request.identifier
        let userInfo = notification.request.content.userInfo

        coordinator.handleRemoteNotification(
            userInfo: userInfo,
            queueDestination: false
        )
        let options = coordinator.foregroundPresentationOptions(userInfo: userInfo)
        guard options.contains(.banner) else {
            completionHandler(options)
            return
        }

        Task { @MainActor in
            // Rapid successive pushes: retract the previous banner now, keep full 2.5s only
            // when nothing newer arrives.
            await coordinator.retractStaleHeadsUpsImmediately(
                exceptRequestIdentifier: requestIdentifier,
                exceptUserInfo: userInfo
            )
            coordinator.scheduleBannerAutoDismiss(
                requestIdentifier: requestIdentifier,
                userInfo: userInfo
            )
            completionHandler(options)
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        Task { @MainActor in
            await PushNotificationCoordinator.shared.handleNotificationResponse(response)
            completionHandler()
        }
    }
}

enum AppIconSwitcher {
    static func apply(theme: AppTheme, colorTheme: SplickColorTheme, systemIsDark: Bool) {
        let application = UIApplication.shared
        guard application.supportsAlternateIcons else { return }
        let desired = colorTheme.alternateIconName(
            isDark: theme.usesDarkAppIcon(systemIsDark: systemIsDark)
        )
        let current = application.alternateIconName
        guard current != desired else { return }
        application.setAlternateIconName(desired)
    }
}
