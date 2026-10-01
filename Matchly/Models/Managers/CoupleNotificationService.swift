//
//  CoupleNotificationService.swift
//  Matchly
//

import CloudKit
import Combine
import Foundation
import OSLog
import UIKit
import UserNotifications

@MainActor
final class CoupleNotificationService: NSObject, ObservableObject {
    static let shared = CoupleNotificationService()

    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    private let logger = Logger(subsystem: "com.matchly", category: "CoupleNotifications")
    private let container = CKContainer(identifier: AuthManager.cloudKitContainerID)
    private var registeredCoupleID: String?

    private override init() {
        super.init()
    }

    func configure() {
        UNUserNotificationCenter.current().delegate = self
        Task { await refreshAuthorizationStatus() }
    }

    func requestAuthorizationIfNeeded() async {
        await refreshAuthorizationStatus()
        guard authorizationStatus == .notDetermined else { return }

        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            if granted {
                UIApplication.shared.registerForRemoteNotifications()
            }
            await refreshAuthorizationStatus()
        } catch {
            logger.debug("Notification permission error: \(error.localizedDescription, privacy: .public)")
        }
    }

    func registerForRemoteNotifications() {
        UIApplication.shared.registerForRemoteNotifications()
    }

    func registerCoupleSubscriptions(coupleID: String) async {
        guard AuthManager.shared.isCloudKitAvailable else { return }
        guard registeredCoupleID != coupleID else { return }
        registeredCoupleID = coupleID

        await createSubscription(
            id: "couple-message-\(coupleID)",
            recordType: "CoupleMessageThread",
            predicate: NSPredicate(format: "coupleID == %@", coupleID),
            alertBody: "Your partner sent a new message."
        )

        await createSubscription(
            id: "couple-programs-\(coupleID)",
            recordType: "CoupleProgramBundle",
            predicate: NSPredicate(format: "coupleID == %@", coupleID),
            alertBody: "Your partner updated their program list."
        )

        await createSubscription(
            id: "couple-ranklist-\(coupleID)",
            recordType: "CoupleRankList",
            predicate: NSPredicate(format: "coupleID == %@", coupleID),
            alertBody: "Your couples rank list was updated."
        )
    }

    func handleRemoteNotification(
        _ userInfo: [AnyHashable: Any],
        completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        Task { @MainActor in
            await CoupleSyncCoordinator.shared.handleRemoteNotification(
                userInfo: userInfo,
                dataManager: DataManager.shared
            )

            if let notification = CKNotification(fromRemoteNotificationDictionary: userInfo),
               let subscriptionID = notification.subscriptionID {
                await deliverLocalNotificationIfNeeded(subscriptionID: subscriptionID)
            }

            completionHandler(.newData)
        }
    }

    // MARK: - Private

    private func refreshAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    private func createSubscription(
        id: String,
        recordType: String,
        predicate: NSPredicate,
        alertBody: String
    ) async {
        let subscription = CKQuerySubscription(
            recordType: recordType,
            predicate: predicate,
            subscriptionID: id,
            options: [.firesOnRecordCreation, .firesOnRecordUpdate]
        )

        let info = CKSubscription.NotificationInfo()
        info.alertLocalizationKey = alertBody
        info.soundName = "default"
        info.shouldSendContentAvailable = true
        subscription.notificationInfo = info

        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                container.publicCloudDatabase.save(subscription) { _, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
            }
            logger.info("Registered subscription \(id, privacy: .public)")
        } catch {
            logger.debug("Subscription \(id, privacy: .public) error: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func deliverLocalNotificationIfNeeded(subscriptionID: String) async {
        await refreshAuthorizationStatus()
        guard authorizationStatus == .authorized else { return }

        let content = UNMutableNotificationContent()
        if subscriptionID.contains("couple-message") {
            content.title = "Partner Chat"
            content.body = "Your partner sent a new message."
            NotificationCenter.default.post(name: .coupleMessageDidArrive, object: nil)
        } else if subscriptionID.contains("couple-programs") {
            content.title = "Couples Matching"
            content.body = "Your partner updated their program list."
        } else if subscriptionID.contains("couple-ranklist") {
            content.title = "Couples Rank List"
            content.body = "Your couples rank list was updated."
        } else {
            return
        }
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        try? await UNUserNotificationCenter.current().add(request)
    }
}

extension CoupleNotificationService: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        Task { @MainActor in
            await CoupleSyncCoordinator.shared.refreshAll(dataManager: DataManager.shared)
            completionHandler()
        }
    }
}
