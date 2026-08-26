//
//  AppDelegate.swift
//  Matchly
//

import UIKit
import FirebaseCore
import GoogleSignIn

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }

        if let clientID = FirebaseApp.app()?.options.clientID {
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        }

        Task { @MainActor in
            // Yield so MatchlyApp + root view singleton init finishes before Firebase sync.
            await Task.yield()
            AuthManager.shared.syncWithFirebaseSession()
        }

        if FeatureFlags.couplesMatchEnabled {
            CoupleNotificationService.shared.configure()
        }

        KeyboardDismissAccessoryManager.installIfNeeded()
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        // CloudKit routes push via APS automatically when subscriptions are active.
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        // Simulator often fails remote registration; CloudKit polling still works.
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        guard FeatureFlags.couplesMatchEnabled else {
            completionHandler(.noData)
            return
        }
        CoupleNotificationService.shared.handleRemoteNotification(
            userInfo,
            completionHandler: completionHandler
        )
    }
}
