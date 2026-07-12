//
//  CoupleLinkingActions.swift
//  Matchly
//

import Foundation

@MainActor
enum CoupleLinkingActions {
    static func link(
        withCode rawCode: String,
        dataManager: DataManager,
        authManager: AuthManager
    ) async throws {
        guard let code = Couple.parseLinkPayload(rawCode) else {
            throw CoupleLinkingError.codeNotFound
        }

        if let couple = dataManager.preferences.couple,
           couple.coupleCode.uppercased() == code {
            throw CoupleLinkingError.cannotLinkOwnCode
        }

        guard authManager.isCloudKitAvailable else {
            throw CoupleLinkingError.iCloudRequired
        }

        await authManager.refreshCloudKitIdentity()

        guard let partnerRecordName = authManager.cloudKitUserRecordName else {
            throw CoupleLinkingError.identityUnavailable
        }

        let partnerName = authManager.currentUser?.displayName
            ?? (dataManager.preferences.profile.name.isEmpty ? "Partner" : dataManager.preferences.profile.name)

        let registration = try await CoupleLinkingService.claimCouple(
            code: code,
            partnerRecordName: partnerRecordName,
            partnerName: partnerName,
            partnerEmail: authManager.currentUser?.email
        )

        markInviteAccepted(code: code, dataManager: dataManager)

        applyLinkedCouple(
            registration: registration,
            partnerRecordName: partnerRecordName,
            partnerName: partnerName,
            partnerEmail: authManager.currentUser?.email,
            dataManager: dataManager
        )
    }

    static func acceptReceivedInvite(
        _ invite: CoupleInvite,
        dataManager: DataManager,
        authManager: AuthManager
    ) async throws {
        try await link(withCode: invite.coupleCode, dataManager: dataManager, authManager: authManager)
    }

    private static func applyLinkedCouple(
        registration: CoupleCodeRegistration,
        partnerRecordName: String,
        partnerName: String,
        partnerEmail: String?,
        dataManager: DataManager
    ) {
        var linkedCouple = Couple(
            id: registration.coupleID,
            user1ID: registration.inviterRecordName,
            user1Name: registration.inviterName,
            user1Email: registration.inviterEmail,
            coupleCode: registration.code,
            inviteLink: Couple.generateInviteLink(code: registration.code),
            status: .linked
        )
        linkedCouple.user2ID = partnerRecordName
        linkedCouple.user2Name = partnerName
        linkedCouple.user2Email = partnerEmail
        linkedCouple.linkedAt = Date()

        dataManager.preferences.couple = linkedCouple
        dataManager.savePreferences()

        Task {
            await CoupleSyncCoordinator.shared.ensureSyncStarted(dataManager: dataManager)
        }
    }

    private static func markInviteAccepted(code: String, dataManager: DataManager) {
        let normalized = code.uppercased()

        if let index = dataManager.preferences.receivedInvites.firstIndex(where: {
            $0.coupleCode.uppercased() == normalized && $0.status == .pending
        }) {
            var updatedInvite = dataManager.preferences.receivedInvites[index]
            updatedInvite.status = .accepted
            updatedInvite.respondedAt = Date()
            dataManager.preferences.receivedInvites[index] = updatedInvite
        }

        if let index = dataManager.preferences.sentInvites.firstIndex(where: {
            $0.coupleCode.uppercased() == normalized && $0.status == .pending
        }) {
            var sentInvite = dataManager.preferences.sentInvites[index]
            sentInvite.status = .accepted
            sentInvite.respondedAt = Date()
            dataManager.preferences.sentInvites[index] = sentInvite
        }
    }
}
