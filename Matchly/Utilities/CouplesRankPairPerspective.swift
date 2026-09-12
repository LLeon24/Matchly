//
//  CouplesRankPairPerspective.swift
//  Matchly
//
//  Rank pairs are stored in canonical form: user1 slot = couple.user1ID, user2 slot = couple.user2ID.
//

import Foundation

enum CouplesRankPairPerspective {
    static func swapUserSlots(_ pair: CouplesRankPair) -> CouplesRankPair {
        CouplesRankPair(
            id: pair.id,
            rank: pair.rank,
            user1ProgramID: pair.user2ProgramID,
            user2ProgramID: pair.user1ProgramID,
            user1NoMatch: pair.user2NoMatch,
            user2NoMatch: pair.user1NoMatch,
            notes: pair.notes
        )
    }

    static func canonicalize(
        pairs: [CouplesRankPair],
        couple: Couple,
        editorRecordName: String
    ) -> [CouplesRankPair] {
        guard editorRecordName != couple.user1ID else { return pairs }
        return pairs.map { swapUserSlots($0) }
    }

    static func programID(
        forRecordName recordName: String,
        in pair: CouplesRankPair,
        couple: Couple
    ) -> String? {
        if recordName == couple.user1ID {
            return pair.user1NoMatch ? nil : pair.user1ProgramID
        }
        if recordName == couple.user2ID {
            return pair.user2NoMatch ? nil : pair.user2ProgramID
        }
        return nil
    }

    static func isNoMatch(
        forRecordName recordName: String,
        in pair: CouplesRankPair,
        couple: Couple
    ) -> Bool {
        if recordName == couple.user1ID { return pair.user1NoMatch }
        if recordName == couple.user2ID { return pair.user2NoMatch }
        return false
    }

    static func makeCanonicalPair(
        couple: Couple,
        myRecordName: String,
        myProgramID: String?,
        partnerProgramID: String?,
        myNoMatch: Bool,
        partnerNoMatch: Bool,
        id: String = UUID().uuidString,
        rank: Int = 0,
        notes: String = ""
    ) -> CouplesRankPair {
        if myRecordName == couple.user1ID {
            return CouplesRankPair(
                id: id,
                rank: rank,
                user1ProgramID: myNoMatch ? nil : myProgramID,
                user2ProgramID: partnerNoMatch ? nil : partnerProgramID,
                user1NoMatch: myNoMatch,
                user2NoMatch: partnerNoMatch,
                notes: notes
            )
        }

        return CouplesRankPair(
            id: id,
            rank: rank,
            user1ProgramID: partnerNoMatch ? nil : partnerProgramID,
            user2ProgramID: myNoMatch ? nil : myProgramID,
            user1NoMatch: partnerNoMatch,
            user2NoMatch: myNoMatch,
            notes: notes
        )
    }
}
