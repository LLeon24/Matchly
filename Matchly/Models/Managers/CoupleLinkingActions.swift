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

        if let matchingInvite = dataManager.preferences.receivedInvites.first(where: {
            $0.coupleCode.uppercased() == code && $0.status == .pending && !$0.isExpired
        }) {
            acceptInvite(matchingInvite, dataManager: dataManager, authManager: authManager)
            return
        }

        guard authManager.isCloudKitAvailable else {
            throw CoupleLinkingError.iCloudRequired
        }

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

        var linkedCouple = Couple(
            user1ID: partnerRecordName,
            user1Name: partnerName,
            user1Email: authManager.currentUser?.email,
            coupleCode: registration.code,
            inviteLink: Couple.generateInviteLink(code: registration.code),
            status: .linked
        )
        linkedCouple.user2ID = registration.inviterRecordName
        linkedCouple.user2Name = registration.inviterName
        linkedCouple.user2Email = registration.inviterEmail
        linkedCouple.linkedAt = Date()

        dataManager.preferences.couple = linkedCouple
        dataManager.savePreferences()
    }

    private static func acceptInvite(
        _ invite: CoupleInvite,
        dataManager: DataManager,
        authManager: AuthManager
    ) {
        if let index = dataManager.preferences.receivedInvites.firstIndex(where: { $0.id == invite.id }) {
            var updatedInvite = invite
            updatedInvite.status = .accepted
            updatedInvite.respondedAt = Date()
            dataManager.preferences.receivedInvites[index] = updatedInvite
        }

        let userID = authManager.cloudKitUserRecordName
            ?? authManager.currentUser?.id
            ?? dataManager.preferences.userID

        var updatedCouple = Couple(
            user1ID: userID,
            user1Name: authManager.currentUser?.displayName
                ?? (dataManager.preferences.profile.name.isEmpty ? "You" : dataManager.preferences.profile.name),
            user1Email: authManager.currentUser?.email,
            coupleCode: invite.coupleCode,
            inviteLink: invite.inviteLink,
            status: .linked
        )
        updatedCouple.user2ID = invite.fromUserID
        updatedCouple.user2Name = invite.fromUserName
        updatedCouple.user2Email = invite.fromUserEmail
        updatedCouple.linkedAt = Date()
        dataManager.preferences.couple = updatedCouple
        dataManager.savePreferences()
    }
}
