//
//  CoupleSyncCoordinator.swift
//  Matchly
//

import CloudKit
import Combine
import Foundation
import OSLog

extension Notification.Name {
    static let coupleDataDidChange = Notification.Name("coupleDataDidChange")
    static let coupleMessageDidArrive = Notification.Name("coupleMessageDidArrive")
    static let couplePartnerLinked = Notification.Name("couplePartnerLinked")
}

@MainActor
final class CoupleSyncCoordinator: ObservableObject {
    static let shared = CoupleSyncCoordinator()

    @Published private(set) var partnerPrograms: [CoupleProgramSnapshot] = []
    @Published private(set) var isSyncing = false
    @Published private(set) var lastSyncError: String?
    @Published private(set) var lastPublishError: String?
    @Published private(set) var lastSyncedAt: Date?

    private let logger = Logger(subsystem: "com.matchly", category: "CoupleSync")
    private var pollTask: Task<Void, Never>?
    private var activeCoupleID: String?

    private init() {}

    func startMonitoringIfNeeded(dataManager: DataManager) async {
        guard let couple = dataManager.preferences.couple, couple.isLinked else {
            stopMonitoring()
            return
        }

        await repairSharedCoupleIDIfNeeded(dataManager: dataManager)
        guard let activeCouple = dataManager.preferences.couple, activeCouple.isLinked else { return }

        guard activeCoupleID != activeCouple.id else {
            await refreshAll(dataManager: dataManager)
            return
        }
        activeCoupleID = activeCouple.id

        await CoupleNotificationService.shared.requestAuthorizationIfNeeded()
        await CoupleNotificationService.shared.registerCoupleSubscriptions(coupleID: activeCouple.id)
        repairLegacyRankPairOrientation(dataManager: dataManager, couple: activeCouple)
        await refreshAll(dataManager: dataManager)

        pollTask?.cancel()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(20))
                guard let self else { return }
                await self.refreshAll(dataManager: dataManager)
            }
        }
    }

    func stopMonitoring() {
        pollTask?.cancel()
        pollTask = nil
        activeCoupleID = nil
        partnerPrograms = []
    }

    func refreshAll(dataManager: DataManager) async {
        guard let couple = dataManager.preferences.couple,
              couple.isLinked,
              AuthManager.shared.isCloudKitAvailable,
              let myRecordName = AuthManager.shared.cloudKitUserRecordName else {
            return
        }

        isSyncing = true
        defer { isSyncing = false }

        let partnerRecordName = partnerRecordName(for: couple, myRecordName: myRecordName)
        guard let partnerRecordName else { return }

        do {
            try await publishOwnData(dataManager: dataManager)
        } catch {
            // Still attempt to fetch partner data even if our publish failed.
        }

        do {
            partnerPrograms = try await CouplesCloudManager.fetchPartnerPrograms(
                coupleID: couple.id,
                partnerRecordName: partnerRecordName
            )

            if let remote = try await CouplesCloudManager.fetchRankList(coupleID: couple.id) {
                let shouldApplyRemote = remote.lastEditorRecordName != myRecordName
                    || dataManager.preferences.couplesRankPairs.isEmpty
                if shouldApplyRemote, remote.pairs != dataManager.preferences.couplesRankPairs {
                    dataManager.preferences.couplesRankPairs = remote.pairs
                    dataManager.savePreferences()
                }
            }

            if let remotePrefs = try await CouplesCloudManager.fetchSharedPreferences(coupleID: couple.id) {
                var normalized = remotePrefs
                normalized.normalizeGeography()
                if normalized != dataManager.preferences.couplesPreferences {
                    dataManager.preferences.couplesPreferences = normalized
                    dataManager.savePreferences()
                }
            }

            lastSyncedAt = Date()
            lastSyncError = nil
            NotificationCenter.default.post(name: .coupleDataDidChange, object: nil)
        } catch {
            lastSyncError = CouplesCloudManager.userFacingMessage(for: error)
            logger.debug("Couple sync failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func publishOwnData(dataManager: DataManager) async throws {
        guard let couple = dataManager.preferences.couple,
              couple.isLinked,
              let myRecordName = AuthManager.shared.cloudKitUserRecordName else { return }

        do {
            try await CouplesCloudManager.publishOwnPrograms(
                coupleID: couple.id,
                ownerRecordName: myRecordName,
                programs: dataManager.programs
            )
            try await CouplesCloudManager.publishRankList(
                coupleID: couple.id,
                pairs: dataManager.preferences.couplesRankPairs,
                editorRecordName: myRecordName
            )
            try await CouplesCloudManager.publishSharedPreferences(
                coupleID: couple.id,
                preferences: dataManager.preferences.couplesPreferences,
                editorRecordName: myRecordName
            )
            lastSyncedAt = Date()
            lastPublishError = nil
        } catch {
            lastPublishError = CouplesCloudManager.userFacingMessage(for: error)
            logger.debug("Publish couple data failed: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }

    func handleRemoteNotification(userInfo: [AnyHashable: Any], dataManager: DataManager) async {
        let notification = CKNotification(fromRemoteNotificationDictionary: userInfo)
        if notification?.subscriptionID?.contains("couple-message") == true {
            NotificationCenter.default.post(name: .coupleMessageDidArrive, object: nil)
        }
        await refreshAll(dataManager: dataManager)
    }

    private func partnerRecordName(for couple: Couple, myRecordName: String) -> String? {
        if couple.user1ID == myRecordName {
            return couple.user2ID
        }
        if couple.user2ID == myRecordName {
            return couple.user1ID
        }
        return couple.user2ID ?? couple.user1ID
    }

    private func repairSharedCoupleIDIfNeeded(dataManager: DataManager) async {
        guard let couple = dataManager.preferences.couple,
              let registration = try? await CoupleLinkingService.fetchRegistration(for: couple.coupleCode),
              registration.coupleID != couple.id else { return }

        dataManager.preferences.couple = Couple(copying: couple, id: registration.coupleID)
        dataManager.savePreferences()
        activeCoupleID = registration.coupleID
        logger.info("Repaired couple ID to shared CloudKit value")
    }

    /// Older builds stored rank pairs from the editor's perspective instead of canonical couple.user1ID slots.
    private func repairLegacyRankPairOrientation(dataManager: DataManager, couple: Couple) {
        guard let myRecord = AuthManager.shared.cloudKitUserRecordName,
              myRecord != couple.user1ID else { return }

        let pairs = dataManager.preferences.couplesRankPairs
        guard !pairs.isEmpty else { return }

        let myProgramIDs = Set(dataManager.programs.map(\.id))
        let slot1Overlap = pairs.compactMap(\.user1ProgramID).filter { myProgramIDs.contains($0) }.count
        let slot2Overlap = pairs.compactMap(\.user2ProgramID).filter { myProgramIDs.contains($0) }.count

        guard slot1Overlap > slot2Overlap else { return }

        dataManager.preferences.couplesRankPairs = pairs.map { CouplesRankPairPerspective.swapUserSlots($0) }
        dataManager.savePreferences()
        logger.info("Repaired legacy couples rank pair orientation")
    }
}
