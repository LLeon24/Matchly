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
        let sectionIDs = weightableSections(preferences: preferences).map(\.id)
        guard !sectionIDs.isEmpty else { return [:] }

        let stored = normalizedStoredWeights(preferences.sectionWeights, enabledSectionIDs: sectionIDs)
        if stored.isEmpty {
            return equalWeights(for: sectionIDs)
        }

        var filtered = sectionIDs.reduce(into: [String: Double]()) { partial, id in
            partial[id] = max(0, stored[id] ?? 0)
        }
        let total = filtered.values.reduce(0, +)
        if total <= 0 {
            return equalWeights(for: sectionIDs)
        }
        return distributeIntegerPercentages(filtered, sectionIDs: sectionIDs)
    }

    static func equalWeights(for sectionIDs: [String]) -> [String: Double] {
        guard !sectionIDs.isEmpty else { return [:] }
        let share = 100.0 / Double(sectionIDs.count)
        let weights = Dictionary(uniqueKeysWithValues: sectionIDs.map { ($0, share) })
        return distributeIntegerPercentages(weights, sectionIDs: sectionIDs)
    }

    /// Rebalances other sections when one slider changes, keeping the total at 100%.
    static func rebalance(
        changedSectionID: String,
        newValue: Double,
        current: [String: Double],
        sectionIDs: [String]
    ) -> [String: Double] {
        guard sectionIDs.contains(changedSectionID) else { return current }
        guard sectionIDs.count > 1 else { return equalWeights(for: sectionIDs) }

        let clamped = min(max(newValue.rounded(), 0), 100)
        var result = current
        result[changedSectionID] = clamped

        let others = sectionIDs.filter { $0 != changedSectionID }
        let remaining = max(0, 100 - clamped)
        let share = remaining / Double(others.count)
        for id in others {
            result[id] = share
        }

        return distributeIntegerPercentages(result, sectionIDs: sectionIDs)
    }

    /// Drops disabled sections and redistributes their weight across remaining sections.
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

        var filtered = sectionIDs.reduce(into: [String: Double]()) { partial, id in
            partial[id] = max(0, normalized[id] ?? 0)
        }
        let total = filtered.values.reduce(0, +)
        if total <= 0 {
            return equalWeights(for: sectionIDs)
        }
        return distributeIntegerPercentages(filtered, sectionIDs: sectionIDs)
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
