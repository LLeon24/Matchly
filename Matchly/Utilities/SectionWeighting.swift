//
//  SectionWeighting.swift
//  Matchly
//
//  Percentage-based questionnaire section weights (sum to 100).
//

import Foundation

enum SectionWeighting {
    static let sectionEId = "matchly.section.e"
    static let legacyEMRWeightKey = EMRScoring.weightKey

    /// Sections that participate in weighted scoring for the current preferences.
    static func weightableSections(preferences: UserPreferences) -> [QuestionnaireSection] {
        var questionnaire = Questionnaire()
        questionnaire.customSections = preferences.customSections.map { custom in
            QuestionnaireSection(
                id: custom.id,
                title: custom.title,
                items: custom.items.map { QuestionnaireItem(id: $0.id, question: $0.question) }
            )
        }
        return questionnaire.scoredSections(preferences: preferences)
    }

    /// Effective percentage weights keyed by section id (always sums to 100 for non-empty inputs).
    static func effectiveWeights(for preferences: UserPreferences) -> [String: Double] {
        redistributedWeights(stored: preferences.sectionWeights, preferences: preferences)
    }

    static func equalWeights(for sectionIDs: [String]) -> [String: Double] {
        guard !sectionIDs.isEmpty else { return [:] }
        let share = 100.0 / Double(sectionIDs.count)
        let weights = Dictionary(uniqueKeysWithValues: sectionIDs.map { ($0, share) })
        return distributeIntegerPercentages(weights, sectionIDs: sectionIDs)
    }

    /// Rebalances other sections when one slider changes, keeping the total at 100%.
    /// Sections already at 0 stay at 0 unless their own slider moves; freed weight flows
    /// only to sections that still carry weight.
    static func rebalance(
        changedSectionID: String,
        newValue: Double,
        current: [String: Double],
        sectionIDs: [String]
    ) -> [String: Double] {
        guard sectionIDs.contains(changedSectionID) else { return current }
        guard sectionIDs.count > 1 else { return equalWeights(for: sectionIDs) }

        let clamped = min(max(newValue.rounded(), 0), 100)

        // Sections explicitly at zero stay excluded when another slider moves.
        let zeroLocked = Set(
            sectionIDs.filter { $0 != changedSectionID && (current[$0] ?? 0) <= 0 }
        )

        var result: [String: Double] = [:]
        result[changedSectionID] = clamped

        let remaining = max(0, 100 - clamped)
        var recipients = sectionIDs.filter { $0 != changedSectionID && !zeroLocked.contains($0) }

        if recipients.isEmpty {
            // Every other section is zero — distribute remaining weight equally among them.
            recipients = sectionIDs.filter { $0 != changedSectionID }
            let share = remaining / Double(recipients.count)
            for id in recipients {
                result[id] = share
            }
        } else {
            let recipientTotal = recipients.reduce(0.0) { $0 + max(0, current[$1] ?? 0) }
            if recipientTotal <= 0 {
                let share = remaining / Double(recipients.count)
                for id in recipients {
                    result[id] = share
                }
            } else {
                for id in recipients {
                    let proportion = max(0, current[id] ?? 0) / recipientTotal
                    result[id] = remaining * proportion
                }
            }
            for id in zeroLocked {
                result[id] = 0
            }
        }

        return distributeIntegerPercentages(result, sectionIDs: sectionIDs)
    }

    /// Drops disabled sections and redistributes weight across remaining sections.
    /// Newly added sections receive a fair share: equal split when weights were default,
    /// or a proportional rebalance when the user previously customized sliders.
    static func redistributedWeights(
        stored: [String: Double],
        preferences: UserPreferences
    ) -> [String: Double] {
        let sectionIDs = weightableSections(preferences: preferences).map(\.id)
        guard !sectionIDs.isEmpty else { return [:] }

        let normalized = normalizedStoredWeights(stored, enabledSectionIDs: sectionIDs)
        if normalized.isEmpty {
            return equalWeights(for: sectionIDs)
        }

        let existingIDs = sectionIDs.filter { normalized.keys.contains($0) }
        let newSectionIDs = sectionIDs.filter { !normalized.keys.contains($0) }

        if !newSectionIDs.isEmpty {
            if usesEqualWeightDistribution(normalized, sectionIDs: existingIDs) {
                return equalWeights(for: sectionIDs)
            }
            return incorporateNewSections(
                normalized: normalized,
                stored: stored,
                existingIDs: existingIDs,
                newSectionIDs: newSectionIDs,
                sectionIDs: sectionIDs
            )
        }

        let filtered = sectionIDs.reduce(into: [String: Double]()) { partial, id in
            partial[id] = max(0, normalized[id] ?? 0)
        }
        let total = filtered.values.reduce(0, +)
        if total <= 0 {
            return equalWeights(for: sectionIDs)
        }
        return distributeIntegerPercentages(filtered, sectionIDs: sectionIDs)
    }

    /// True when every section's weight matches an equal split (within integer rounding tolerance).
    static func usesEqualWeightDistribution(_ weights: [String: Double], sectionIDs: [String]) -> Bool {
        guard !sectionIDs.isEmpty else { return true }
        let target = equalWeights(for: sectionIDs)
        return sectionIDs.allSatisfy { id in
            abs((weights[id] ?? 0) - (target[id] ?? 0)) <= 0.6
        }
    }

    /// Enabled questions in a section (respects questionnaire customization).
    static func scoreableQuestions(for section: QuestionnaireSection, preferences: UserPreferences) -> [QuestionnaireItem] {
        var questionnaire = Questionnaire()
        questionnaire.mergeCustomization(from: preferences)
        return questionnaire.enabledItems(for: section, preferences: preferences)
    }

    /// True when the question is included in this section's custom slider weight (checked in Section Weights).
    static func itemUsesCustomSectionWeight(
        _ item: QuestionnaireItem,
        section: QuestionnaireSection,
        preferences: UserPreferences
    ) -> Bool {
        if preferences.weightExcludedQuestionIds.contains(item.id) {
            return false
        }
        if let stableId = Questionnaire.stableItemId(forQuestion: item.question, sectionTitle: section.title),
           preferences.weightExcludedQuestionIds.contains(stableId) {
            return false
        }
        return true
    }

    static func displayTitle(for section: QuestionnaireSection) -> String {
        if let separator = section.title.range(of: " — ") {
            return String(section.title[separator.upperBound...])
        }
        return section.title
    }

    // MARK: - Private

    private static func incorporateNewSections(
        normalized: [String: Double],
        stored: [String: Double],
        existingIDs: [String],
        newSectionIDs: [String],
        sectionIDs: [String]
    ) -> [String: Double] {
        let equalAll = equalWeights(for: sectionIDs)
        let newShareTotal = newSectionIDs.reduce(0.0) { $0 + (equalAll[$1] ?? 0) }

        let zeroLocked = Set(
            existingIDs.filter { isExplicitZero(sectionId: $0, stored: stored) }
        )

        var existingWeights = existingIDs.reduce(into: [String: Double]()) { partial, id in
            partial[id] = max(0, normalized[id] ?? 0)
        }
        existingWeights = distributeIntegerPercentages(existingWeights, sectionIDs: existingIDs)

        var result: [String: Double] = [:]
        for id in newSectionIDs {
            result[id] = equalAll[id] ?? 0
        }
        for id in zeroLocked {
            result[id] = 0
        }

        let budgetForExisting = max(0, 100 - newShareTotal)
        let adjustableExisting = existingIDs.filter { !zeroLocked.contains($0) }
        if adjustableExisting.isEmpty {
            return equalWeights(for: sectionIDs)
        }

        let adjustableTotal = adjustableExisting.reduce(0.0) { $0 + (existingWeights[$1] ?? 0) }
        if adjustableTotal <= 0 {
            let share = budgetForExisting / Double(adjustableExisting.count)
            for id in adjustableExisting {
                result[id] = share
            }
        } else {
            for id in adjustableExisting {
                let proportion = (existingWeights[id] ?? 0) / adjustableTotal
                result[id] = budgetForExisting * proportion
            }
        }

        return distributeIntegerPercentages(result, sectionIDs: sectionIDs)
    }

    private static func isExplicitZero(sectionId: String, stored: [String: Double]) -> Bool {
        if let value = stored[sectionId] {
            return value <= 0
        }
        let titleToId = Dictionary(
            uniqueKeysWithValues: Questionnaire.makeStandardSections().map { ($0.title, $0.id) }
        )
        for (key, value) in stored where value <= 0 {
            if titleToId[key] == sectionId {
                return true
            }
        }
        return false
    }

    private static func normalizedStoredWeights(
        _ stored: [String: Double],
        enabledSectionIDs: [String]
    ) -> [String: Double] {
        guard !stored.isEmpty else { return [:] }

        var mapped: [String: Double] = [:]
        let titleToId = Dictionary(
            uniqueKeysWithValues: Questionnaire.makeStandardSections().map { ($0.title, $0.id) }
        )

        for (key, value) in stored {
            if key == legacyEMRWeightKey { continue }
            if enabledSectionIDs.contains(key) {
                mapped[key] = value
            } else if let id = titleToId[key], enabledSectionIDs.contains(id) {
                mapped[id] = value
            }
        }
        return mapped
    }

    /// Scales raw weights to integer percentages summing to 100, spreading rounding fairly.
    private static func distributeIntegerPercentages(_ weights: [String: Double], sectionIDs: [String]) -> [String: Double] {
        guard !sectionIDs.isEmpty else { return [:] }

        let rawTotal = sectionIDs.reduce(0.0) { $0 + max(0, weights[$1] ?? 0) }
        if rawTotal <= 0 {
            return equalWeights(for: sectionIDs)
        }

        let scaled = sectionIDs.map { id -> (String, Double) in
            (id, max(0, weights[id] ?? 0) * 100.0 / rawTotal)
        }

        var floors = scaled.map { (id, value) -> (String, Int) in
            (id, Int(floor(value)))
        }
        var remainder = 100 - floors.reduce(0) { $0 + $1.1 }

        let fractionalOrder = scaled
            .filter { max(0, weights[$0.0] ?? 0) > 0 }
            .map { (id: $0.0, fraction: $0.1 - floor($0.1)) }
            .sorted { lhs, rhs in
                if lhs.fraction == rhs.fraction {
                    return sectionIDs.firstIndex(of: lhs.id) ?? 0 < sectionIDs.firstIndex(of: rhs.id) ?? 0
                }
                return lhs.fraction > rhs.fraction
            }

        var index = 0
        while remainder > 0, !fractionalOrder.isEmpty {
            let id = fractionalOrder[index % fractionalOrder.count].id
            if let floorIndex = floors.firstIndex(where: { $0.0 == id }) {
                floors[floorIndex].1 += 1
            }
            remainder -= 1
            index += 1
        }

        return Dictionary(uniqueKeysWithValues: floors.map { ($0.0, Double($0.1)) })
    }
}
