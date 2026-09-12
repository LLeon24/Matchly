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
    /// `user1Programs` / `user2Programs` must align with canonical couple slots (couple.user1ID / couple.user2ID).
    static func generateRankList(
        user1Programs: [CoupleProgramSnapshot],
        user2Programs: [CoupleProgramSnapshot],
        preferences: CouplesPreferences
    ) -> [CouplesRankPair] {
        guard !user1Programs.isEmpty, !user2Programs.isEmpty else { return [] }

        let weights = resolvedWeights(preferences)
        var scored: [ScoredPair] = []

        for p1 in user1Programs {
            for p2 in user2Programs {
                let score = pairScore(
                    p1: p1,
                    p2: p2,
                    user1Count: user1Programs.count,
                    user2Count: user2Programs.count,
                    preferences: preferences,
                    weights: weights
                )
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

        if !preferences.mustMatchTogether {
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
        }

        return pairs.enumerated().map { index, pair in
            var updated = pair
            updated.rank = index + 1
            return updated
        }
    }

    // MARK: - Scoring

    private struct EngineWeights {
        let individualScore: Double
        let rankList: Double
        let geography: Double
        let hospital: Double
    }

    private static func resolvedWeights(_ preferences: CouplesPreferences) -> EngineWeights {
        let individual = preferences.prioritizeIndividualRankLists ? 0.20 : 0.35
        let rankList = preferences.prioritizeIndividualRankLists ? 0.40 : 0.10
        var geography = 0.15
        switch preferences.geographyStrictness {
        case .sameCity:
            geography += 0.25
        case .sameState:
            geography += 0.15
        case .withinDistance:
            break
        }
        let hospital = preferences.preferSameHospital ? 0.30 : 0.05

        let total = max(individual + rankList + geography + hospital, 0.01)
        return EngineWeights(
            individualScore: individual / total,
            rankList: rankList / total,
            geography: geography / total,
            hospital: hospital / total
        )
    }

    private static func pairScore(
        p1: CoupleProgramSnapshot,
        p2: CoupleProgramSnapshot,
        user1Count: Int,
        user2Count: Int,
        preferences: CouplesPreferences,
        weights: EngineWeights
    ) -> Double {
        let miles = GeocodingHelper.approximateDistanceInMiles(between: p1, and: p2)

        if miles > Double(preferences.distanceTolerance) {
            return -.infinity
        }

        switch preferences.geographyStrictness {
        case .sameCity:
            if !programsShareCity(p1, p2) { return -.infinity }
        case .sameState:
            if !programsShareState(p1, p2) { return -.infinity }
        case .withinDistance:
            break
        }

        let maxScore = max(p1.finalScore, p2.finalScore, 1)
        let scoreComponent = ((p1.finalScore + p2.finalScore) / 2.0) / maxScore
        let rankComponent = rankListComponent(
            p1: p1,
            p2: p2,
            user1Count: user1Count,
            user2Count: user2Count
        )
        let geoComponent = geographicComponent(p1: p1, p2: p2, miles: miles, preferences: preferences)
        let hospitalComponent = sameHospitalComponent(p1: p1, p2: p2, preferSame: preferences.preferSameHospital)

        return weights.individualScore * scoreComponent
            + weights.rankList * rankComponent
            + weights.geography * geoComponent
            + weights.hospital * hospitalComponent
    }

    private static func rankListComponent(
        p1: CoupleProgramSnapshot,
        p2: CoupleProgramSnapshot,
        user1Count: Int,
        user2Count: Int
    ) -> Double {
        let maxRank = Double(max(user1Count, user2Count, 1))
        let r1 = Double(max(p1.rankPosition, 1))
        let r2 = Double(max(p2.rankPosition, 1))
        let normalized1 = (maxRank - r1 + 1) / maxRank
        let normalized2 = (maxRank - r2 + 1) / maxRank
        return (normalized1 + normalized2) / 2.0
    }

    private static func geographicComponent(
        p1: CoupleProgramSnapshot,
        p2: CoupleProgramSnapshot,
        miles: Double,
        preferences: CouplesPreferences
    ) -> Double {
        let tolerance = max(Double(preferences.distanceTolerance), 1)
        let distanceScore = max(0, 1 - (miles / tolerance))
        let cityMatch = programsShareCity(p1, p2) ? 1.0 : 0.0
        let stateMatch = programsShareState(p1, p2) ? 1.0 : 0.0

        switch preferences.geographyStrictness {
        case .sameCity:
            return cityMatch
        case .sameState:
            if cityMatch > 0 { return 1.0 }
            if stateMatch > 0 { return 0.85 }
            return distanceScore * 0.5
        case .withinDistance:
            return max(distanceScore, cityMatch * 0.95, stateMatch * 0.8)
        }
    }

    private static func programsShareCity(_ p1: CoupleProgramSnapshot, _ p2: CoupleProgramSnapshot) -> Bool {
        !p1.city.isEmpty
            && p1.city.caseInsensitiveCompare(p2.city) == .orderedSame
            && programsShareState(p1, p2)
    }

    private static func programsShareState(_ p1: CoupleProgramSnapshot, _ p2: CoupleProgramSnapshot) -> Bool {
        !p1.state.isEmpty && p1.state.caseInsensitiveCompare(p2.state) == .orderedSame
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

    private static func normalizedHospitalKey(_ program: CoupleProgramSnapshot) -> String {
        program.hospital
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9]", with: "", options: .regularExpression)
    }

    private static func hospitalSystemKey(_ program: CoupleProgramSnapshot) -> String {
        let tokens = program.hospital
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 3 }
        return tokens.prefix(2).joined(separator: "-")
    }
}
