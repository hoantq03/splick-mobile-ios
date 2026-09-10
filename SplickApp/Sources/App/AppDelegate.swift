import Foundation
import UIKit
import UserNotifications
import Common

@MainActor
final class AppDelegate: NSObject, UIApplicationDelegate, @preconcurrency UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self

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
        // When woken for a background push (content-available), auto-hide the system banner
        // so later notifications are not blocked behind a sticky heads-up.
        if application.applicationState != .active {
            var backgroundTask = UIBackgroundTaskIdentifier.invalid
            backgroundTask = application.beginBackgroundTask(withName: "splick.banner-auto-dismiss") {
                if backgroundTask != .invalid {
                    application.endBackgroundTask(backgroundTask)
                    backgroundTask = .invalid
                }
            }
            coordinator.scheduleBannerAutoDismiss(userInfo: userInfo)
            Task { @MainActor in
                try? await Task.sleep(for: AppConstants.PushNotifications.bannerAutoDismissDelay)
                // Extra beat so dismiss + NSE/main-app retry can finish.
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
        if !options.isEmpty {
            coordinator.dismissPendingBanners(except: requestIdentifier)
            coordinator.scheduleBannerAutoDismiss(
                requestIdentifier: requestIdentifier,
                userInfo: userInfo
            )
        }
        completionHandler(options)
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
