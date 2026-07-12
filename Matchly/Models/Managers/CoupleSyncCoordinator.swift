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
    @Published private(set) var partnerProfilePhotoData: Data?
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

        let repaired = await repairCoupleFromRegistrationIfNeeded(dataManager: dataManager)
        guard let activeCouple = dataManager.preferences.couple, activeCouple.isLinked else { return }

        if repaired || activeCoupleID != activeCouple.id {
            activeCoupleID = activeCouple.id
            await CoupleNotificationService.shared.requestAuthorizationIfNeeded()
            await CoupleNotificationService.shared.registerCoupleSubscriptions(coupleID: activeCouple.id)
            repairLegacyRankPairOrientation(dataManager: dataManager, couple: activeCouple)
        } else {
            await refreshAll(dataManager: dataManager)
            return
        }

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

    /// Repairs couple state from CloudKit, starts polling, and performs an immediate sync.
    func ensureSyncStarted(dataManager: DataManager) async {
        await startMonitoringIfNeeded(dataManager: dataManager)
        await refreshAll(dataManager: dataManager)
    }

    func stopMonitoring() {
        pollTask?.cancel()
        pollTask = nil
        activeCoupleID = nil
        partnerPrograms = []
        partnerProfilePhotoData = nil
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
        guard let partnerRecordName else {
            lastSyncError = Self.partnerIdentityMessage
            return
        }

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
            partnerProfilePhotoData = try await CouplesCloudManager.fetchPartnerProfilePhoto(
                coupleID: couple.id,
                partnerRecordName: partnerRecordName
            )

            if let remote = try await CouplesCloudManager.fetchRankList(coupleID: couple.id) {
                let localUpdated = dataManager.preferences.couplesRankListUpdatedAt
                let remoteIsNewer = remote.updatedAt.map { remoteDate in
                    guard let localUpdated else { return true }
                    return remoteDate > localUpdated
                } ?? false
                let shouldApplyRemote = dataManager.preferences.couplesRankPairs.isEmpty
                    || remote.lastEditorRecordName != myRecordName
                    || remoteIsNewer
                if shouldApplyRemote, remote.pairs != dataManager.preferences.couplesRankPairs {
                    dataManager.preferences.couplesRankPairs = remote.pairs
                    dataManager.preferences.couplesRankListUpdatedAt = remote.updatedAt ?? Date()
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
            try await CouplesCloudManager.publishOwnProfilePhoto(
                coupleID: couple.id,
                ownerRecordName: myRecordName,
                photoData: dataManager.preferences.profile.photoData
            )
            dataManager.preferences.couplesRankListUpdatedAt = Date()
            dataManager.savePreferences()
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

    private static let partnerIdentityMessage =
        "Could not resolve your partner's iCloud identity. Open Couples Matching and re-link using your partner's QR code."

    private func partnerRecordName(for couple: Couple, myRecordName: String) -> String? {
        if couple.user1ID == myRecordName {
            return couple.user2ID
        }
        if couple.user2ID == myRecordName {
            return couple.user1ID
        }
        // Legacy links stored Apple login IDs instead of CloudKit record names.
        if let user2 = couple.user2ID, !user2.isEmpty, user2 != myRecordName {
            return user2
        }
        if !couple.user1ID.isEmpty, couple.user1ID != myRecordName {
            return couple.user1ID
        }
        return nil
    }

    /// Aligns local couple state with the CloudKit registration so both partners share the same
    /// couple ID, CloudKit record names, and display names (required for chat + program sync).
    @discardableResult
    private func repairCoupleFromRegistrationIfNeeded(dataManager: DataManager) async -> Bool {
        guard var couple = dataManager.preferences.couple else { return false }

        guard let registration = try? await CoupleLinkingService.fetchRegistration(for: couple.coupleCode) else {
            if couple.isLinked {
                lastSyncError = Self.environmentMismatchMessage
            }
            return false
        }

        var changed = false

        if couple.id != registration.coupleID {
            couple = Couple(copying: couple, id: registration.coupleID)
            activeCoupleID = nil
            changed = true
        }

        if couple.user1ID != registration.inviterRecordName {
            couple.user1ID = registration.inviterRecordName
            changed = true
        }
        if couple.user1Name != registration.inviterName {
            couple.user1Name = registration.inviterName
            changed = true
        }
        if let inviterEmail = registration.inviterEmail, couple.user1Email != inviterEmail {
            couple.user1Email = inviterEmail
            changed = true
        }

        if registration.isClaimed, let partnerRecord = registration.partnerRecordName {
            if couple.user2ID != partnerRecord {
                couple.user2ID = partnerRecord
                changed = true
            }
            if let partnerName = registration.partnerName, couple.user2Name != partnerName {
                couple.user2Name = partnerName
                changed = true
            }
            if let partnerEmail = registration.partnerEmail, couple.user2Email != partnerEmail {
                couple.user2Email = partnerEmail
                changed = true
            }
            if couple.status != .linked {
                couple.status = .linked
                changed = true
            }
            if couple.linkedAt == nil {
                couple.linkedAt = Date()
                changed = true
            }
        }

        guard changed else { return false }

        dataManager.preferences.couple = couple
        dataManager.savePreferences()
        lastSyncError = nil
        logger.info("Repaired couple from CloudKit registration")
        return true
    }

    private static var environmentMismatchMessage: String {
        #if DEBUG
        let build = "Xcode debug (CloudKit Development)"
        #else
        let build = "TestFlight or App Store (CloudKit Production)"
        #endif
        return """
        Could not find your couple invite in iCloud. Both partners must use the same app build type \
        (both from Xcode, or both from TestFlight). This device is running \(build). \
        If your partner uses a different build, deploy the CloudKit schema to Production in the dashboard.
        """
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
