//
//  CouplesRankEngine.swift
//  Matchly
//
//  Suggests an NRMP-style couples rank list from both partners' programs and shared preferences.
//

import Foundation

enum CouplesRankEngine {
    struct ScoredPair: Hashable {
        let user1ProgramID: String
        let user2ProgramID: String
        let score: Double
    }

    /// Builds a one-to-one couples rank list ordered by combined utility.
    static func generateRankList(
        user1Programs: [CoupleProgramSnapshot],
        user2Programs: [CoupleProgramSnapshot],
        preferences: CouplesPreferences
    ) -> [CouplesRankPair] {
        guard !user1Programs.isEmpty, !user2Programs.isEmpty else { return [] }

        let weights = normalizedWeights(preferences)
        var scored: [ScoredPair] = []

        for p1 in user1Programs {
            for p2 in user2Programs {
                let score = pairScore(p1: p1, p2: p2, preferences: preferences, weights: weights)
                if score > -.infinity {
                    scored.append(ScoredPair(user1ProgramID: p1.id, user2ProgramID: p2.id, score: score))
                }
            }
        }

        scored.sort { $0.score > $1.score }

        var used1 = Set<String>()
        var used2 = Set<String>()
        var pairs: [CouplesRankPair] = []

        for candidate in scored {
            guard !used1.contains(candidate.user1ProgramID),
                  !used2.contains(candidate.user2ProgramID) else { continue }
            used1.insert(candidate.user1ProgramID)
            used2.insert(candidate.user2ProgramID)
            pairs.append(CouplesRankPair(
                rank: pairs.count + 1,
                user1ProgramID: candidate.user1ProgramID,
                user2ProgramID: candidate.user2ProgramID
            ))
        }

        // Remaining programs paired with No Match on the partner side.
        for p1 in user1Programs where !used1.contains(p1.id) {
            pairs.append(CouplesRankPair(
                rank: pairs.count + 1,
                user1ProgramID: p1.id,
                user2ProgramID: nil,
                user1NoMatch: false,
                user2NoMatch: true
            ))
            used1.insert(p1.id)
        }

        for p2 in user2Programs where !used2.contains(p2.id) {
            pairs.append(CouplesRankPair(
                rank: pairs.count + 1,
                user1ProgramID: nil,
                user2ProgramID: p2.id,
                user1NoMatch: true,
                user2NoMatch: false
            ))
            used2.insert(p2.id)
        }

        return pairs.enumerated().map { index, pair in
            var updated = pair
            updated.rank = index + 1
            return updated
        }
    }

    // MARK: - Scoring

    private static func normalizedWeights(_ preferences: CouplesPreferences) -> (
        scores: Double, geography: Double, hospital: Double, emr: Double, programType: Double
    ) {
        let raw = [
            preferences.weightIndividualScores,
            preferences.weightGeography,
            preferences.weightSameHospital,
            preferences.weightEMR,
            preferences.weightProgramType
        ]
        let total = max(raw.reduce(0, +), 0.01)
        return (
            raw[0] / total,
            raw[1] / total,
            raw[2] / total,
            raw[3] / total,
            raw[4] / total
        )
    }

    private static func pairScore(
        p1: CoupleProgramSnapshot,
        p2: CoupleProgramSnapshot,
        preferences: CouplesPreferences,
        weights: (scores: Double, geography: Double, hospital: Double, emr: Double, programType: Double)
    ) -> Double {
        let miles = GeocodingHelper.approximateDistanceInMiles(between: p1, and: p2)

        if miles > Double(preferences.distanceTolerance) {
            return -.infinity
        }

        let maxScore = max(
            user1ProgramsMaxScoreHint(p1, p2),
            100.0
        )
        let scoreComponent = ((p1.finalScore + p2.finalScore) / 2.0) / maxScore

        let geoComponent = geographicComponent(p1: p1, p2: p2, miles: miles, preferences: preferences)
        let hospitalComponent = sameHospitalComponent(p1: p1, p2: p2, preferSame: preferences.preferSameHospital)
        let emrComponent = emrAlignmentComponent(p1: p1, p2: p2)
        let typeComponent = programTypeComponent(p1: p1, p2: p2, preferences: preferences)

        return weights.scores * scoreComponent
            + weights.geography * geoComponent
            + weights.hospital * hospitalComponent
            + weights.emr * emrComponent
            + weights.programType * typeComponent
    }

    private static func user1ProgramsMaxScoreHint(_ p1: CoupleProgramSnapshot, _ p2: CoupleProgramSnapshot) -> Double {
        max(p1.finalScore, p2.finalScore, 1)
    }

    private static func geographicComponent(
        p1: CoupleProgramSnapshot,
        p2: CoupleProgramSnapshot,
        miles: Double,
        preferences: CouplesPreferences
    ) -> Double {
        let tolerance = max(Double(preferences.distanceTolerance), 1)
        let distanceScore = max(0, 1 - (miles / tolerance))

        let cityMatch = p1.city.caseInsensitiveCompare(p2.city) == .orderedSame
            && !p1.city.isEmpty ? 1.0 : 0.0
        let stateMatch = p1.state.caseInsensitiveCompare(p2.state) == .orderedSame
            && !p1.state.isEmpty ? 0.85 : 0.0

        switch preferences.geographicPriority {
        case .sameCity:
            return cityMatch > 0 ? 1.0 : distanceScore * 0.4
        case .sameState:
            return stateMatch > 0 ? 1.0 : (cityMatch > 0 ? 0.9 : distanceScore * 0.5)
        case .sameRegion:
            return max(distanceScore, stateMatch * 0.9, cityMatch)
        case .balanced:
            return max(distanceScore, cityMatch * 0.95, stateMatch * 0.8)
        case .flexible:
            return max(distanceScore, 0.5)
        }
    }

    private static func sameHospitalComponent(
        p1: CoupleProgramSnapshot,
        p2: CoupleProgramSnapshot,
        preferSame: Bool
    ) -> Double {
        let sameHospital = normalizedHospitalKey(p1) == normalizedHospitalKey(p2)
            && !normalizedHospitalKey(p1).isEmpty
        let sameSystem = hospitalSystemKey(p1) == hospitalSystemKey(p2)
            && !hospitalSystemKey(p1).isEmpty

        if preferSame {
            return sameHospital ? 1.0 : (sameSystem ? 0.7 : 0.0)
        }
        return sameHospital ? 1.0 : (sameSystem ? 0.75 : 0.35)
    }

    private static func emrAlignmentComponent(p1: CoupleProgramSnapshot, p2: CoupleProgramSnapshot) -> Double {
        guard let e1 = p1.emr, let e2 = p2.emr, !e1.isEmpty, !e2.isEmpty else { return 0.5 }
        return e1 == e2 ? 1.0 : 0.2
    }

    private static func programTypeComponent(
        p1: CoupleProgramSnapshot,
        p2: CoupleProgramSnapshot,
        preferences: CouplesPreferences
    ) -> Double {
        let t1 = p1.type.lowercased()
        let t2 = p2.type.lowercased()
        let bothAcademic = t1.contains("academic") && t2.contains("academic")
        let bothCommunity = t1.contains("community") && t2.contains("community")

        switch preferences.programTypePriority {
        case .bothAcademic:
            return bothAcademic ? 1.0 : 0.3
        case .bothCommunity:
            return bothCommunity ? 1.0 : 0.3
        case .balanced:
            return t1 == t2 ? 1.0 : 0.55
        case .flexible:
            return 0.75
        }
    }

    private static func normalizedHospitalKey(_ program: CoupleProgramSnapshot) -> String {
        program.hospital
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9]", with: "", options: .regularExpression)
    }

    /// Rough health-system grouping from shared name tokens.
    private static func hospitalSystemKey(_ program: CoupleProgramSnapshot) -> String {
        let tokens = program.hospital
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 3 }
        return tokens.prefix(2).joined(separator: "-")
    }
}
