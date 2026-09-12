//
//  QuestionnaireItem.swift
//  Matchly
//
//  Created on 11/14/25.
//

import Foundation

struct QuestionnaireQuestionRef: Equatable, Hashable {
    let sectionId: String
    let itemId: String

    var scrollID: String { "\(sectionId)-\(itemId)" }
}

struct QuestionnaireItem: Codable, Identifiable, Equatable {
    let id: String
    let question: String
    var programRating: Double = 0 // 0 = unrated, 1-5 = rating, 6 = N/A
    var notes: String = ""
    
    init(id: String = UUID().uuidString, question: String, programRating: Double = 0, notes: String = "") {
        self.id = id
        self.question = question
        self.programRating = programRating
        self.notes = notes
    }
}

struct QuestionnaireSection: Codable, Identifiable, Equatable {
    let id: String
    var title: String
    var items: [QuestionnaireItem]
    
    init(id: String = UUID().uuidString, title: String, items: [QuestionnaireItem]) {
        self.id = id
        self.title = title
        self.items = items
    }
}

struct Questionnaire: Codable, Equatable {
    var sections: [QuestionnaireSection]
    var customSections: [QuestionnaireSection] = [] // User-created custom sections (stored as QuestionnaireSection for consistency)
    
    // Helper to get section by index
    func section(at index: Int) -> QuestionnaireSection? {
        guard index >= 0 && index < sections.count else { return nil }
        return sections[index]
    }
    
    // Helper to get item by section and item index
    func item(sectionIndex: Int, itemIndex: Int) -> QuestionnaireItem? {
        guard let section = section(at: sectionIndex),
              itemIndex >= 0 && itemIndex < section.items.count else { return nil }
        return section.items[itemIndex]
    }
    
    init() {
        self.sections = Self.makeStandardSections()
    }

    /// Stable IDs so questionnaire customization prefs match every new program entry.
    static func makeStandardSections() -> [QuestionnaireSection] {
        [
            standardSection(
                id: "matchly.section.a",
                title: "Section A — Big-picture priorities",
                questions: [
                    "Overall \"fit\" / gut feeling from interview day",
                    "Desired geographic location / ability to live where I want",
                    "Career goals alignment (academic vs community, research vs clinical)",
                    "Reputation / program prestige",
                    "Fellowship opportunities and fellowship match record",
                    "Job placement / alumni network after residency"
                ]
            ),
            standardSection(
                id: "matchly.section.b",
                title: "Section B — Training quality & clinical experience",
                questions: [
                    "Clinical exposure — variety and complexity of cases",
                    "Procedural volume / hands-on opportunities",
                    "Quality of teaching (faculty commitment to education, protected teaching time)",
                    "Board pass rates and objective outcomes",
                    "Strength of simulation, procedural labs, and learning resources",
                    "Research opportunities & support (funding, mentors, time)"
                ]
            ),
            standardSection(
                id: "matchly.section.c",
                title: "Section C — Workload, schedule & lifestyle",
                questions: [
                    "Call schedule (frequency, night float vs home call)",
                    "Typical work hours / resident workload",
                    "Vacation / parental leave policies and flexibility",
                    "Opportunities for moonlighting or outside work",
                    "Salary, benefits, housing stipend if any",
                    "Cost of living in city / housing availability"
                ]
            ),
            standardSection(
                id: "matchly.section.d",
                title: "Section D — Culture, support & wellbeing",
                questions: [
                    "Resident camaraderie / morale",
                    "Program leadership accessibility & responsiveness (PD/APDs)",
                    "Psychological safety (ability to speak up, reporting mistreatment)",
                    "Diversity, equity & inclusion climate",
                    "Mentorship availability (senior resident and faculty mentors)",
                    "Wellness resources (counseling, time off, wellness stipend)"
                ]
            ),
            standardSection(
                id: "matchly.section.e",
                title: "Section E — Practical & logistic items",
                questions: [
                    "Clinic structure / outpatient continuity experience",
                    "Elective flexibility (ability to tailor training)",
                    "Availability of subspecialty rotations or niche experiences I care about",
                    "Call coverage/backup, how nights are covered",
                    "Housing/commute time from hospital",
                    "Spousal/partner support (job market, community)"
                ]
            ),
            standardSection(
                id: "matchly.section.f",
                title: "Section F — Red flags & dealbreakers",
                questions: [
                    "Did you observe or hear any concerning behavior from faculty or residents?",
                    "Are there concerning board pass rates, litigation issues, or program probation history?",
                    "Do you feel you could see yourself living in this city for the length of training?",
                    "Any scheduling or leave policies that would be a dealbreaker?"
                ]
            )
        ]
    }

    private static func standardSection(
        id: String,
        title: String,
        questions: [String]
    ) -> QuestionnaireSection {
        QuestionnaireSection(
            id: id,
            title: title,
            items: questions.enumerated().map { index, question in
                QuestionnaireItem(id: "\(id).q\(index + 1)", question: question)
            }
        )
    }

    private static func stableSectionId(forTitle title: String) -> String? {
        makeStandardSections().first { $0.title == title }?.id
    }

    static func stableItemId(forQuestion question: String, sectionTitle: String) -> String? {
        guard let section = makeStandardSections().first(where: { $0.title == sectionTitle }) else { return nil }
        return section.items.first { $0.question == question }?.id
    }

    private func sectionIsEnabled(_ section: QuestionnaireSection, preferences: UserPreferences, allSections: [QuestionnaireSection]) -> Bool {
        if preferences.enabledSectionIds.isEmpty {
            return true
        }
        if preferences.enabledSectionIds.contains(section.id) {
            return true
        }
        if let stableId = Self.stableSectionId(forTitle: section.title),
           preferences.enabledSectionIds.contains(stableId) {
            return true
        }
        let hasAnyMatch = allSections.contains { candidate in
            preferences.enabledSectionIds.contains(candidate.id) ||
            (Self.stableSectionId(forTitle: candidate.title).map { preferences.enabledSectionIds.contains($0) } ?? false)
        }
        return !hasAnyMatch
    }

    private func itemIsEnabled(
        _ item: QuestionnaireItem,
        section: QuestionnaireSection,
        preferences: UserPreferences,
        candidateItems: [QuestionnaireItem]
    ) -> Bool {
        if preferences.enabledQuestionIds.isEmpty {
            return true
        }
        if preferences.enabledQuestionIds.contains(item.id) {
            return true
        }
        if let stableId = Self.stableItemId(forQuestion: item.question, sectionTitle: section.title),
           preferences.enabledQuestionIds.contains(stableId) {
            return true
        }
        let hasAnyMatch = candidateItems.contains { candidate in
            preferences.enabledQuestionIds.contains(candidate.id) ||
            (Self.stableItemId(forQuestion: candidate.question, sectionTitle: section.title).map {
                preferences.enabledQuestionIds.contains($0)
            } ?? false)
        }
        return !hasAnyMatch
    }
    
    /// Enabled sections that contribute to the numeric score (excludes red flags).
    func scoredSections(preferences: UserPreferences) -> [QuestionnaireSection] {
        enabledSections(preferences: preferences).filter { !isRedFlagSection($0) }
    }

    /// Ensures custom questions/sections from preferences exist on this program questionnaire.
    mutating func mergeCustomization(from preferences: UserPreferences) {
        let standardTemplates = Questionnaire.makeStandardSections()
        let standardQuestionIdsBySection = Dictionary(
            uniqueKeysWithValues: standardTemplates.map { ($0.id, Set($0.items.map(\.id))) }
        )

        for sectionIndex in sections.indices {
            let sectionId = sections[sectionIndex].id
            let standardIds = standardQuestionIdsBySection[sectionId] ?? []
            let allowedCustomIds = Set(preferences.customQuestionsInSections[sectionId]?.map(\.id) ?? [])

            sections[sectionIndex].items = sections[sectionIndex].items.filter { item in
                if standardIds.contains(item.id) { return true }
                return allowedCustomIds.contains(item.id)
            }

            if let customQuestions = preferences.customQuestionsInSections[sectionId] {
                for customQuestion in customQuestions where !sections[sectionIndex].items.contains(where: { $0.id == customQuestion.id }) {
                    sections[sectionIndex].items.append(
                        QuestionnaireItem(id: customQuestion.id, question: customQuestion.question)
                    )
                }
            }
        }

        var mergedCustomSections: [QuestionnaireSection] = []
        var seenCustomSectionIDs = Set<String>()
        for customSection in preferences.customSections {
            guard !seenCustomSectionIDs.contains(customSection.id) else { continue }
            seenCustomSectionIDs.insert(customSection.id)

            let existingSection = customSections.first { $0.id == customSection.id }
            mergedCustomSections.append(
                QuestionnaireSection(
                    id: customSection.id,
                    title: customSection.title,
                    items: customSection.items.map { customItem in
                        if let existingItem = existingSection?.items.first(where: { $0.id == customItem.id }) {
                            return existingItem
                        }
                        return QuestionnaireItem(id: customItem.id, question: customItem.question)
                    }
                )
            )
        }
        customSections = mergedCustomSections
    }

    // Calculate total weighted score (0-100) using user-defined section weights.
    // Checked questions use the section slider weight; unchecked questions blend in at equal standard weight.
    // Program EMR is folded into Section E's custom-weight average when both sides are objectively scorable.
    func totalWeightedScore(preferences: UserPreferences, programEMR: String? = nil) -> Double {
        let scored = scoredSections(preferences: preferences)
        guard !scored.isEmpty else { return 0 }

        let weights = SectionWeighting.effectiveWeights(for: preferences)
        var customSectionRatings: [(id: String, ratings: [Double])] = []
        var standardRatings: [Double] = []

        for section in scored {
            var customRatings: [Double] = []
            let ratingByItemID = Dictionary(uniqueKeysWithValues: section.items.map { ($0.id, $0.programRating) })

            for item in enabledItems(for: section, preferences: preferences) {
                let rating = ratingByItemID[item.id] ?? item.programRating
                guard rating > 0 && rating < 6 else { continue }

                if SectionWeighting.itemUsesCustomSectionWeight(item, section: section, preferences: preferences) {
                    customRatings.append(rating)
                } else {
                    standardRatings.append(rating)
                }
            }

            if section.id == SectionWeighting.sectionEId,
               let emrRating = EMRScoring.rating(programEMR: programEMR, preferredEMR: preferences.preferredEMR) {
                customRatings.append(emrRating)
            }

            if !customRatings.isEmpty {
                customSectionRatings.append((section.id, customRatings))
            }
        }

        let prioritizedCount = customSectionRatings.reduce(0) { $0 + $1.ratings.count }
        let standardCount = standardRatings.count
        guard prioritizedCount + standardCount > 0 else { return 0 }

        let blendedAverage: Double
        if standardCount == 0 {
            blendedAverage = customWeightedAverage(customSectionRatings, weights: weights)
        } else if prioritizedCount == 0 {
            blendedAverage = standardRatings.reduce(0, +) / Double(standardCount)
        } else {
            let customScore = customWeightedAverage(customSectionRatings, weights: weights)
            let standardScore = standardRatings.reduce(0, +) / Double(standardCount)
            let totalCount = Double(prioritizedCount + standardCount)
            blendedAverage = (customScore * Double(prioritizedCount) + standardScore * Double(standardCount)) / totalCount
        }

        let completion = questionnaireCompletionRatio(preferences: preferences, programEMR: programEMR)
        return blendedAverage * 20 * completion
    }

    private func customWeightedAverage(
        _ sectionRatings: [(id: String, ratings: [Double])],
        weights: [String: Double]
    ) -> Double {
        let sectionAverages = sectionRatings.map { entry -> (id: String, average: Double) in
            (entry.id, entry.ratings.reduce(0, +) / Double(entry.ratings.count))
        }

        var applicableWeightTotal = 0.0
        for entry in sectionAverages {
            applicableWeightTotal += weights[entry.id] ?? 0
        }
        if applicableWeightTotal <= 0 {
            applicableWeightTotal = Double(sectionAverages.count)
        }

        return sectionAverages.reduce(0.0) { partial, entry in
            let rawWeight = weights[entry.id] ?? (100.0 / Double(sectionAverages.count))
            let normalizedWeight = rawWeight / applicableWeightTotal
            return partial + (entry.average * normalizedWeight)
        }
    }

    /// Average 1–5 rating for a standard questionnaire section (e.g. "Section B"), or nil if none answered.
    func standardSectionAverage(_ sectionPrefix: String, preferences: UserPreferences, programEMR: String? = nil) -> Double? {
        let allSections = sections + customSections
        guard let section = allSections.first(where: { $0.title.hasPrefix(sectionPrefix) }) else {
            return nil
        }
        guard sectionIsEnabled(section, preferences: preferences, allSections: allSections) else {
            return nil
        }
        if isRedFlagSection(section) {
            return nil
        }

        let ratings = sectionRatings(for: section, preferences: preferences, programEMR: programEMR)
        guard !ratings.isEmpty else { return nil }
        return ratings.reduce(0, +) / Double(ratings.count)
    }

    /// Share of enabled, non–red-flag questions that have a deliberate answer.
    /// Counts 1–5 ratings and N/A (6) as complete; ignores disabled sections/questions.
    /// When nothing is enabled, returns 1.0 (nothing left to score).
    func questionnaireCompletionRatio(preferences: UserPreferences, programEMR: String? = nil) -> Double {
        var answered = 0
        var total = 0
        let allSections = sections + customSections

        for section in allSections {
            if isRedFlagSection(section) { continue }
            guard sectionIsEnabled(section, preferences: preferences, allSections: allSections) else { continue }

            let ratingByItemID = Dictionary(uniqueKeysWithValues: section.items.map { ($0.id, $0.programRating) })
            for item in enabledItems(for: section, preferences: preferences) {
                total += 1
                let rating = ratingByItemID[item.id] ?? item.programRating
                if rating > 0 {
                    answered += 1
                }
            }

            if section.id == SectionWeighting.sectionEId, countsEMRForCompletion(preferredEMR: preferences.preferredEMR) {
                total += 1
                if programEMR != nil {
                    answered += 1
                }
            }
        }

        guard total > 0 else { return 1.0 }
        return Double(answered) / Double(total)
    }

    private func sectionRatings(
        for section: QuestionnaireSection,
        preferences: UserPreferences,
        programEMR: String?
    ) -> [Double] {
        var sectionRatings: [Double] = []
        let ratingByItemID = Dictionary(uniqueKeysWithValues: section.items.map { ($0.id, $0.programRating) })

        for item in enabledItems(for: section, preferences: preferences) {
            let rating = ratingByItemID[item.id] ?? item.programRating
            if rating > 0 && rating < 6 {
                sectionRatings.append(rating)
            }
        }

        if section.id == SectionWeighting.sectionEId,
           let emrRating = EMRScoring.rating(programEMR: programEMR, preferredEMR: preferences.preferredEMR) {
            sectionRatings.append(emrRating)
        }

        return sectionRatings
    }

    private func countsEMRForCompletion(preferredEMR: String?) -> Bool {
        guard let preferredRaw = preferredEMR,
              let preferred = EMRSystem(rawValue: preferredRaw) else {
            return false
        }
        return preferred.isSpecific
    }

    /// True when any enabled questionnaire item still needs an answer.
    func needsScoring(preferences: UserPreferences, programEMR: String? = nil) -> Bool {
        questionnaireCompletionRatio(preferences: preferences, programEMR: programEMR) < 1.0
    }

    /// Enabled questions that still have no rating (programRating == 0).
    func unansweredQuestions(preferences: UserPreferences) -> [QuestionnaireQuestionRef] {
        var unanswered: [QuestionnaireQuestionRef] = []
        let allSections = sections + customSections

        for section in allSections {
            if isRedFlagSection(section) { continue }
            guard sectionIsEnabled(section, preferences: preferences, allSections: allSections) else { continue }

            for item in enabledItems(for: section, preferences: preferences) where item.programRating == 0 {
                unanswered.append(QuestionnaireQuestionRef(sectionId: section.id, itemId: item.id))
            }
        }

        return unanswered
    }

    func firstUnansweredQuestion(preferences: UserPreferences) -> QuestionnaireQuestionRef? {
        unansweredQuestions(preferences: preferences).first
    }

    /// First red-flag question the user marked Yes (or No on inverted positive questions).
    func firstFlaggedRedFlagQuestion() -> QuestionnaireQuestionRef? {
        let positiveYesNoQuestions = [
            "Do you feel you could see yourself living"
        ]

        for section in sections + customSections {
            guard isRedFlagSection(section) else { continue }
            for item in section.items {
                let isPositiveQuestion = positiveYesNoQuestions.contains { item.question.contains($0) }
                let isFlagged = isPositiveQuestion ? item.programRating == 2 : item.programRating == 1
                if isFlagged {
                    return QuestionnaireQuestionRef(sectionId: section.id, itemId: item.id)
                }
            }
        }
        return nil
    }

    func unansweredCount(preferences: UserPreferences) -> Int {
        unansweredQuestions(preferences: preferences).count
    }

    private func isRedFlagSection(_ section: QuestionnaireSection) -> Bool {
        let title = section.title.lowercased()
        return title.contains("red flags") || title.contains("red flag")
    }

    // Get enabled sections based on preferences (standard + custom)
    func enabledSections(preferences: UserPreferences) -> [QuestionnaireSection] {
        let allSections = sections + customSections
        return allSections.filter { section in
            sectionIsEnabled(section, preferences: preferences, allSections: allSections)
        }
    }
    
    // Get enabled items for a section based on preferences (includes custom questions added to standard sections)
    func enabledItems(for section: QuestionnaireSection, preferences: UserPreferences) -> [QuestionnaireItem] {
        var allItems = section.items
        let existingIDs = Set(section.items.map(\.id))

        // Add custom questions that were added to this standard section (skip duplicates already merged onto the program)
        if let customQuestions = preferences.customQuestionsInSections[section.id] {
            let customQuestionnaireItems = customQuestions.compactMap { customItem -> QuestionnaireItem? in
                guard !existingIDs.contains(customItem.id) else { return nil }
                return QuestionnaireItem(id: customItem.id, question: customItem.question)
            }
            allItems.append(contentsOf: customQuestionnaireItems)
        }

        return allItems.filter { item in
            itemIsEnabled(item, section: section, preferences: preferences, candidateItems: allItems)
        }
    }
    
    /// All enabled questionnaire prompts available for interview prep selection.
    func allPrepPrompts(preferences: UserPreferences) -> [(id: String, sectionTitle: String, question: String)] {
        var mergedCustomSections = customSections
        for prefSection in preferences.customSections {
            if let index = mergedCustomSections.firstIndex(where: { $0.id == prefSection.id }) {
                var section = mergedCustomSections[index]
                let existingIds = Set(section.items.map(\.id))
                for customItem in prefSection.items where !existingIds.contains(customItem.id) {
                    section.items.append(QuestionnaireItem(id: customItem.id, question: customItem.question))
                }
                mergedCustomSections[index] = section
            } else {
                mergedCustomSections.append(
                    QuestionnaireSection(
                        id: prefSection.id,
                        title: prefSection.title,
                        items: prefSection.items.map {
                            QuestionnaireItem(id: $0.id, question: $0.question)
                        }
                    )
                )
            }
        }

        let allSections = sections + mergedCustomSections
        let eligibleSections = allSections.filter { section in
            let title = section.title.lowercased()
            guard !title.contains("red flag") else { return false }
            return sectionIsEnabled(section, preferences: preferences, allSections: allSections)
        }

        return eligibleSections.flatMap { section in
            enabledItems(for: section, preferences: preferences).map { item in
                (id: item.id, sectionTitle: section.title, question: item.question)
            }
        }
    }

    /// Questions to consider on interview day, spread across enabled questionnaire sections.
    func prepPrompts(preferences: UserPreferences, maxCount: Int = 8) -> [(sectionTitle: String, question: String)] {
        guard maxCount > 0 else { return [] }

        let allSections = sections + customSections
        let eligibleSections = allSections.filter { section in
            let title = section.title.lowercased()
            guard !title.contains("red flag") else { return false }
            return sectionIsEnabled(section, preferences: preferences, allSections: allSections)
        }

        let sectionBuckets: [(title: String, items: [QuestionnaireItem])] = eligibleSections.compactMap { section in
            let items = enabledItems(for: section, preferences: preferences)
            guard !items.isEmpty else { return nil }
            return (section.title, items)
        }

        var results: [(sectionTitle: String, question: String)] = []
        var index = 0

        while results.count < maxCount {
            var addedAny = false
            for bucket in sectionBuckets {
                guard results.count < maxCount else { break }
                if index < bucket.items.count {
                    results.append((sectionTitle: bucket.title, question: bucket.items[index].question))
                    addedAny = true
                }
            }
            if !addedAny { break }
            index += 1
        }

        return results
    }

    // Calculate average score for a section (0-5)
    private func averageScore(for section: QuestionnaireSection) -> Double {
        let ratings = section.items.compactMap { $0.programRating > 0 ? $0.programRating : nil }
        guard !ratings.isEmpty else { return 0 }
        return ratings.reduce(0, +) / Double(ratings.count)
    }
}

// MARK: - Resilient decoding
// Missing keys fall back to defaults so decoding never throws (see Program.swift).

extension QuestionnaireItem {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        self.question = try container.decodeIfPresent(String.self, forKey: .question) ?? ""
        self.programRating = try container.decodeIfPresent(Double.self, forKey: .programRating) ?? 0
        self.notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
    }
}

extension QuestionnaireSection {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        self.title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        self.items = try container.decodeIfPresent([QuestionnaireItem].self, forKey: .items) ?? []
    }
}

extension Questionnaire {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // `sections` has no stored default; its default is the standard set built
        // by `Questionnaire()`. Fall back to that if the key is missing.
        self.sections = try container.decodeIfPresent([QuestionnaireSection].self, forKey: .sections) ?? Questionnaire().sections
        self.customSections = try container.decodeIfPresent([QuestionnaireSection].self, forKey: .customSections) ?? []
    }
}

enum QuestionnaireSectionNaming {
    static func letter(from title: String) -> Character? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.lowercased().hasPrefix("section ") else { return nil }
        let remainder = trimmed.dropFirst("section ".count)
        guard let letter = remainder.first, letter.isLetter else { return nil }
        return Character(String(letter).uppercased())
    }

    static func nextAvailableLetter(existingTitles: [String]) -> Character {
        let used = Set(existingTitles.compactMap { letter(from: $0) })
        for letter in "ABCDEFGHIJKLMNOPQRSTUVWXYZ" {
            if !used.contains(letter) {
                return letter
            }
        }
        return "Z"
    }

    static func customSectionTitle(letter: Character, subtitle: String) -> String {
        let trimmed = subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = trimmed.isEmpty ? "Custom priorities" : trimmed
        return "Section \(letter) — \(body)"
    }

    static func makeCustomSectionTitle(
        existingCustomSections: [CustomQuestionnaireSection],
        subtitle: String = "Custom priorities"
    ) -> String {
        let standardTitles = Questionnaire.makeStandardSections().map(\.title)
        let customTitles = existingCustomSections.map(\.title)
        let letter = nextAvailableLetter(existingTitles: standardTitles + customTitles)
        return customSectionTitle(letter: letter, subtitle: subtitle)
    }
}

