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
                    "Breadth and depth of clinical exposure (variety of cases)",
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

    private static func stableItemId(forQuestion question: String, sectionTitle: String) -> String? {
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
    
    // Calculate total weighted score (0-100) - weighted average of all enabled sections
    // `programEMR` is the program's selected EMR (an EMRSystem.rawValue). When the
    // applicant has set a preferred EMR, the EMR match is folded in as one more
    // weighted factor, exactly like a questionnaire section.
    func totalWeightedScore(preferences: UserPreferences, programEMR: String? = nil) -> Double {
        var sectionScores: [(sectionId: String, averageScore: Double, weight: Double)] = []
        
        // Get all enabled sections (standard + custom, excluding red flags)
        let allSections = sections + customSections
        let enabledSections = allSections.filter { section in
            guard sectionIsEnabled(section, preferences: preferences, allSections: allSections) else {
                return false
            }
            if section.title.contains("Red flags") {
                return false
            }
            return true
        }
        
        guard !enabledSections.isEmpty else { return 0 }
        
        // Calculate average score for each enabled section
        for section in enabledSections {
            var sectionRatings: [Double] = []
            
            let candidateItems = section.items + (preferences.customQuestionsInSections[section.id]?.map {
                QuestionnaireItem(id: $0.id, question: $0.question)
            } ?? [])
            for item in section.items {
                guard itemIsEnabled(item, section: section, preferences: preferences, candidateItems: candidateItems) else {
                    continue
                }
                
                // Only count ratings 1-5, exclude N/A (6) and unrated (0)
                if item.programRating > 0 && item.programRating < 6 {
                    sectionRatings.append(item.programRating)
                }
            }
            
            guard !sectionRatings.isEmpty else { continue }
            
            let averageScore = sectionRatings.reduce(0, +) / Double(sectionRatings.count)
            
            // Get stable identifier for weight lookup (title for standard sections, ID for custom)
            let stableId: String
            if section.title.contains("Section A") || section.title.contains("Section B") || 
               section.title.contains("Section C") || section.title.contains("Section D") ||
               section.title.contains("Section E") || section.title.contains("Section F") {
                // Standard section - use title as stable ID
                stableId = section.title
            } else {
                // Custom section - use ID
                stableId = section.id
            }
            
            // Each scored section contributes equally to the final score.
            sectionScores.append((sectionId: stableId, averageScore: averageScore, weight: 1.0))
        }
        
        // EMR factor — treated as one more weighted "section". Scored only when the
        // match can be objectively determined (preferred EMR set + program EMR known
        // + neither side is "Other"/"Not sure"); otherwise it drops out like an
        // unrated section.
        if let emrRating = EMRScoring.rating(programEMR: programEMR, preferredEMR: preferences.preferredEMR) {
            sectionScores.append((sectionId: EMRScoring.weightKey, averageScore: emrRating, weight: 1.0))
        }
        
        guard !sectionScores.isEmpty else { return 0 }

        let equalWeight = 1.0 / Double(sectionScores.count)
        sectionScores = sectionScores.map { ($0.sectionId, $0.averageScore, equalWeight) }
        
        // Normalize weights to sum to 1.0
        let totalWeight = sectionScores.reduce(0) { $0 + $1.weight }
        guard totalWeight > 0 else { return 0 }
        
        // Calculate weighted average
        let weightedSum = sectionScores.reduce(0) { sum, score in
            let normalizedWeight = score.weight / totalWeight
            return sum + (score.averageScore * normalizedWeight)
        }
        
        // Scale from 0-5 to 0-100, then factor in how much of the questionnaire is answered
        // so a partially rated program can't max out at 100.
        let completion = questionnaireCompletionRatio(preferences: preferences)
        return weightedSum * 20 * completion
    }

    /// Average 1–5 rating for a standard questionnaire section (e.g. "Section B"), or nil if none answered.
    func standardSectionAverage(_ sectionPrefix: String, preferences: UserPreferences) -> Double? {
        let allSections = sections + customSections
        guard let section = allSections.first(where: { $0.title.hasPrefix(sectionPrefix) }) else {
            return nil
        }
        guard sectionIsEnabled(section, preferences: preferences, allSections: allSections) else {
            return nil
        }
        if section.title.localizedCaseInsensitiveContains("red flag") {
            return nil
        }

        var sectionRatings: [Double] = []
        let candidateItems = section.items + (preferences.customQuestionsInSections[section.id]?.map {
            QuestionnaireItem(id: $0.id, question: $0.question)
        } ?? [])

        for item in section.items {
            guard itemIsEnabled(item, section: section, preferences: preferences, candidateItems: candidateItems) else {
                continue
            }
            if item.programRating > 0 && item.programRating < 6 {
                sectionRatings.append(item.programRating)
            }
        }

        guard !sectionRatings.isEmpty else { return nil }
        return sectionRatings.reduce(0, +) / Double(sectionRatings.count)
    }

    /// Share of enabled, non–red-flag questions that have a deliberate answer.
    /// Counts 1–5 ratings and N/A (6) as complete; ignores disabled sections/questions.
    /// When nothing is enabled, returns 1.0 (nothing left to score).
    func questionnaireCompletionRatio(preferences: UserPreferences) -> Double {
        var answered = 0
        var total = 0
        let allSections = sections + customSections

        for section in allSections {
            if isRedFlagSection(section) { continue }
            guard sectionIsEnabled(section, preferences: preferences, allSections: allSections) else { continue }

            for item in enabledItems(for: section, preferences: preferences) {
                total += 1
                // 0 = unanswered; 1–5 = rated; 6 = N/A (still a deliberate answer)
                if item.programRating > 0 {
                    answered += 1
                }
            }
        }

        guard total > 0 else { return 1.0 }
        return Double(answered) / Double(total)
    }

    /// True when any enabled questionnaire item still needs an answer.
    func needsScoring(preferences: UserPreferences) -> Bool {
        questionnaireCompletionRatio(preferences: preferences) < 1.0
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

