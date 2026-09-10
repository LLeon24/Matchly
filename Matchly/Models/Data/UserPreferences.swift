//
//  UserPreferences.swift
//  Matchly
//
//  Created by Leoh N. Leon II on 11/14/25.
//

import Foundation

struct UserPreferences: Codable, Hashable {
    var specialty: String? // Deprecated - use specialties array instead
    var specialties: [String] = [] // Support multiple specialties (dual applying)
    /// ERAS fellowship subspecialty codes selected during onboarding (fellowship track only).
    var fellowshipSpecialtyCodes: [String] = []
    /// Residency or Fellowship — drives default program search track.
    var applyingTrack: String = ProgramTrainingLevelFilter.residency.rawValue
    var hasCompletedOnboarding: Bool = false
    /// Interactive tab-bar tour shown once after onboarding (replayable from Settings).
    var hasCompletedFeatureTour: Bool = false
    /// Spotlight tour for the Couple tab when couples matching is first activated.
    var hasCompletedCoupleFeatureTour: Bool = false
    /// Opens program search once after onboarding when the user has no programs yet.
    var shouldPromptFirstProgramAdd: Bool = false
    
    // User profile
    var profile: UserProfile = UserProfile()
    
    // User account
    var userID: String = UUID().uuidString // Unique identifier for this user
    var nrmpID: String? // NRMP ID for couples matching
    
    // Couples matching
    var couple: Couple? // Current couple relationship
    var couplesPreferences: CouplesPreferences = CouplesPreferences()
    var couplesRankPairs: [CouplesRankPair] = [] // Paired rank list for couples matching
    /// Local timestamp of the last couples rank list edit (used to resolve CloudKit conflicts).
    var couplesRankListUpdatedAt: Date?
    var sentInvites: [CoupleInvite] = [] // Invites sent by this user
    var receivedInvites: [CoupleInvite] = [] // Invites received by this user
    
    // Questionnaire customization
    var enabledSectionIds: Set<String> = [] // Empty = all enabled by default
    var enabledQuestionIds: Set<String> = [] // Empty = all enabled by default
    var customSections: [CustomQuestionnaireSection] = [] // User-created custom sections
    var customQuestionsInSections: [String: [CustomQuestionnaireItem]] = [:] // Custom questions added to standard sections (key = section ID)
    
    /// Percentage weights keyed by section id (`matchly.section.a`, custom section ids). Empty = equal weights.
    var sectionWeights: [String: Double] = [:]
    /// Question ids that use equal standard weighting instead of the section's custom slider weight.
    var weightExcludedQuestionIds: Set<String> = []
    
    // Applicant's preferred / most familiar EMR (an EMRSystem.rawValue).
    // Optional for backward compatibility. When set, programs are scored on how
    // well their EMR matches this preference (equal weight with other scored factors).
    var preferredEMR: String?
    
    // Calendar sync preference
    var enableCalendarSync: Bool = false // Whether user wants to sync interviews to calendar
    
    // Red flag ranking preference
    var includeRedFlaggedProgramsInRankList: Bool = true // Whether to include red flagged programs in rank list
    
    // Dashboard customization
    var dashboardLayout: DashboardLayout = DashboardLayout()
    var dashboardPreferences: DashboardPreferences = DashboardPreferences()

    /// App light/dark appearance. Auto follows the system setting.
    var appearanceMode: AppearanceMode = .auto

    /// Per-program interview prep selections (questions, top must-ask, checklist).
    var interviewPrepByProgram: [String: InterviewPrepState] = [:]
    /// One-time cleanup after interview prep switched to explicit add-only question lists.
    var interviewPrepCuratedListMigrated: Bool = false
    /// Reusable question list applied to new programs via Load default questions.
    var interviewPrepDefaultQuestions: InterviewPrepDefaultQuestions?
}

enum AppearanceMode: String, Codable, CaseIterable, Identifiable {
    case auto
    case light
    case dark

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .auto: return "Auto"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
}

struct InterviewPrepDefaultQuestions: Codable, Hashable {
    var selectedQuestionIds: Set<String> = []
    var customQuestions: [InterviewPrepCustomQuestion] = []
    var priorityQuestionIds: [String] = []
    var questionListOrder: [String] = []

    var isEmpty: Bool {
        questionListOrder.isEmpty
    }

    static func from(prepState: InterviewPrepState) -> InterviewPrepDefaultQuestions {
        InterviewPrepDefaultQuestions(
            selectedQuestionIds: prepState.selectedQuestionIds,
            customQuestions: prepState.customQuestions,
            priorityQuestionIds: prepState.priorityQuestionIds,
            questionListOrder: prepState.questionListOrder
        )
    }

    func prepState(matching validQuestionnaireIds: Set<String>) -> InterviewPrepState {
        let validCustomIds = Set(customQuestions.map(\.id))
        let allValidIds = validQuestionnaireIds.union(validCustomIds)

        let order = questionListOrder.filter { allValidIds.contains($0) }
        let selected = selectedQuestionIds
            .intersection(validQuestionnaireIds)
            .intersection(Set(order))
        var priority = priorityQuestionIds.filter { allValidIds.contains($0) }
        if priority.count > 5 {
            priority = Array(priority.prefix(5))
        }

        return InterviewPrepState(
            selectedQuestionIds: selected,
            customQuestions: customQuestions,
            priorityQuestionIds: priority,
            questionListOrder: order,
            askedQuestionIds: [],
            checkedChecklistItems: []
        )
    }
}

struct InterviewPrepCustomQuestion: Codable, Hashable, Identifiable {
    var id: String
    var question: String

    init(id: String = "prep-custom-\(UUID().uuidString)", question: String) {
        self.id = id
        self.question = question
    }
}

struct InterviewPrepState: Codable, Hashable {
    /// Questionnaire question IDs the user explicitly added to their prep list.
    var selectedQuestionIds: Set<String> = []
    /// User-written questions for this interview.
    var customQuestions: [InterviewPrepCustomQuestion] = []
    /// Up to five must-ask questions, in priority order (questionnaire or custom IDs).
    var priorityQuestionIds: [String] = []
    /// Display order for questions on the prep list.
    var questionListOrder: [String] = []
    /// Questions marked as asked during the interview.
    var askedQuestionIds: Set<String> = []
    var checkedChecklistItems: Set<String> = []
}

extension InterviewPrepState {
    enum CodingKeys: String, CodingKey {
        case selectedQuestionIds
        case customQuestions
        case priorityQuestionIds
        case questionListOrder
        case askedQuestionIds
        case checkedChecklistItems
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        selectedQuestionIds = try container.decodeIfPresent(Set<String>.self, forKey: .selectedQuestionIds) ?? []
        customQuestions = try container.decodeIfPresent([InterviewPrepCustomQuestion].self, forKey: .customQuestions) ?? []
        priorityQuestionIds = try container.decodeIfPresent([String].self, forKey: .priorityQuestionIds) ?? []
        questionListOrder = try container.decodeIfPresent([String].self, forKey: .questionListOrder) ?? []
        askedQuestionIds = try container.decodeIfPresent(Set<String>.self, forKey: .askedQuestionIds) ?? []
        checkedChecklistItems = try container.decodeIfPresent(Set<String>.self, forKey: .checkedChecklistItems) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(selectedQuestionIds, forKey: .selectedQuestionIds)
        try container.encode(customQuestions, forKey: .customQuestions)
        try container.encode(priorityQuestionIds, forKey: .priorityQuestionIds)
        try container.encode(questionListOrder, forKey: .questionListOrder)
        try container.encode(askedQuestionIds, forKey: .askedQuestionIds)
        try container.encode(checkedChecklistItems, forKey: .checkedChecklistItems)
    }

    /// Removes legacy auto-populated questionnaire questions; keeps only user-typed custom questions.
    mutating func migrateToCuratedQuestionListOnly() {
        let customIds = Set(customQuestions.map(\.id))
        questionListOrder = questionListOrder.filter { customIds.contains($0) }
        selectedQuestionIds = []
        priorityQuestionIds = priorityQuestionIds.filter { customIds.contains($0) }
        askedQuestionIds = askedQuestionIds.filter { customIds.contains($0) }
    }
}

struct DashboardPreferences: Codable, Hashable {
    // Welcome header style
    var welcomeHeaderStyle: WelcomeHeaderStyle = .default
    
    // Welcome header options
    var showProfilePicture: Bool = true
    var showSpecialtyCount: Bool = true
    var showQuickStats: Bool = false
    var showMotivationalMessage: Bool = true
    
    // Greeting style
    var greetingStyle: GreetingStyle = .timeBased

    /// What appears under the greeting in the dashboard header bar.
    var headerSubtitleMode: HeaderSubtitleMode = .motivational
    
    enum HeaderSubtitleMode: String, Codable, CaseIterable {
        case date = "Today's Date"
        case motivational = "Motivational"
        case specialtyCount = "Specialty Count"
    }
    
    enum WelcomeHeaderStyle: String, Codable, CaseIterable {
        case `default` = "Default"
        case compact = "Compact"
        case expanded = "Expanded"
        case stats = "With Stats"
    }
    
    enum GreetingStyle: String, Codable, CaseIterable {
        case timeBased = "Time-Based"
        case casual = "Casual"
        case formal = "Formal"
        case motivational = "Motivational"
    }
}

struct DashboardLayout: Codable, Hashable {
    /// Ordered list of section IDs (determines display order within each dashboard tab).
    var sectionOrder: [String] = Self.defaultSectionOrder

    /// Section IDs the user turned off. Empty means every section is visible.
    var disabledSections: Set<String> = []

    static let defaultSectionOrder: [String] = [
        "overviewHero",
        "needsAttention",
        "analytics",
        "quickActions",
        "programsCompare"
    ]

    static let dashboardSectionIDs: Set<String> = Set(defaultSectionOrder)

    static let defaultSections: Set<String> = Set(defaultSectionOrder)

    /// Maps legacy section IDs from the pre-tab dashboard to the current model.
    private static let legacySectionMigration: [String: String] = [
        "welcome": "overviewHero",
        "nextSteps": "needsAttention"
    ]

    static func normalizeSectionID(_ id: String) -> String? {
        if let mapped = legacySectionMigration[id] {
            return mapped
        }
        guard defaultSections.contains(id) else { return nil }
        return id
    }

    static func normalizeSectionOrder(_ order: [String]) -> [String] {
        let legacyDropIDs: Set<String> = [
            "overviewSignals",
            "upcomingInterviews",
            "interviewPipeline",
            "quickStats",
            "recentActivity",
            "programsScoreDist",
            "topPrograms"
        ]
        var normalized: [String] = []
        for id in order {
            if legacyDropIDs.contains(id) { continue }
            guard let mapped = normalizeSectionID(id) else { continue }
            if legacyDropIDs.contains(mapped) { continue }
            if !normalized.contains(mapped) {
                normalized.append(mapped)
            }
        }
        for id in defaultSectionOrder where !normalized.contains(id) {
            normalized.append(id)
        }
        return normalized
    }

    static func normalizeSectionIDs(_ ids: Set<String>) -> Set<String> {
        var normalized = Set<String>()
        for id in ids {
            if let mapped = normalizeSectionID(id) {
                normalized.insert(mapped)
            }
        }
        return normalized
    }

    static func normalizeEnabledSections(_ sections: Set<String>) -> Set<String> {
        normalizeSectionIDs(sections)
    }

    /// Converts a legacy enabled-sections set into the newer disabled-sections model.
    static func disabledSections(fromLegacyEnabledSections enabled: Set<String>) -> Set<String> {
        if enabled.isEmpty { return [] }
        let normalizedEnabled = normalizeSectionIDs(enabled)
        return defaultSections.subtracting(normalizedEnabled)
    }

    func orderedSectionIDs(in group: Set<String>) -> [String] {
        let order = sectionOrder.isEmpty ? Self.defaultSectionOrder : Self.normalizeSectionOrder(sectionOrder)
        return order.filter { group.contains($0) }
    }

    func isSectionEnabled(_ sectionId: String) -> Bool {
        guard let normalized = Self.normalizeSectionID(sectionId) else { return false }
        if disabledSections.isEmpty { return true }
        return !Self.normalizeSectionIDs(disabledSections).contains(normalized)
    }
}

// MARK: - Resilient decoding
//
// `UserPreferences` is persisted to UserDefaults/iCloud. A missing key in this
// type or ANY nested type would otherwise throw `keyNotFound` and cause
// `DataManager` to silently reset the user's saved preferences on the next app
// update that adds a property. These initializers decode every key with
// `decodeIfPresent(_:forKey:) ?? <default>` (defaults copied exactly from the
// property initializers above) so decoding never throws. Defined in extensions
// to preserve the synthesized memberwise initializers and `encode(to:)`.

extension UserPreferences {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.specialty = try container.decodeIfPresent(String.self, forKey: .specialty)
        self.specialties = try container.decodeIfPresent([String].self, forKey: .specialties) ?? []
        self.fellowshipSpecialtyCodes = try container.decodeIfPresent([String].self, forKey: .fellowshipSpecialtyCodes) ?? []
        self.applyingTrack = try container.decodeIfPresent(String.self, forKey: .applyingTrack)
            ?? ProgramTrainingLevelFilter.residency.rawValue
        self.hasCompletedOnboarding = try container.decodeIfPresent(Bool.self, forKey: .hasCompletedOnboarding) ?? false
        if let completedFeatureTour = try container.decodeIfPresent(Bool.self, forKey: .hasCompletedFeatureTour) {
            self.hasCompletedFeatureTour = completedFeatureTour
        } else {
            // Profiles saved before the guided tour existed already finished onboarding.
            self.hasCompletedFeatureTour = self.hasCompletedOnboarding
        }
        self.profile = try container.decodeIfPresent(UserProfile.self, forKey: .profile) ?? UserProfile()
        self.userID = try container.decodeIfPresent(String.self, forKey: .userID) ?? UUID().uuidString
        self.nrmpID = try container.decodeIfPresent(String.self, forKey: .nrmpID)
        self.couple = try container.decodeIfPresent(Couple.self, forKey: .couple)
        if let completedCoupleTour = try container.decodeIfPresent(Bool.self, forKey: .hasCompletedCoupleFeatureTour) {
            self.hasCompletedCoupleFeatureTour = completedCoupleTour
        } else {
            // Linked users who finished the main tour before the couple tour existed.
            self.hasCompletedCoupleFeatureTour = self.hasCompletedFeatureTour && (self.couple?.isLinked == true)
        }
        self.shouldPromptFirstProgramAdd = try container.decodeIfPresent(Bool.self, forKey: .shouldPromptFirstProgramAdd) ?? false
        self.couplesPreferences = try container.decodeIfPresent(CouplesPreferences.self, forKey: .couplesPreferences) ?? CouplesPreferences()
        self.couplesRankPairs = try container.decodeIfPresent([CouplesRankPair].self, forKey: .couplesRankPairs) ?? []
        self.couplesRankListUpdatedAt = try container.decodeIfPresent(Date.self, forKey: .couplesRankListUpdatedAt)
        self.sentInvites = try container.decodeIfPresent([CoupleInvite].self, forKey: .sentInvites) ?? []
        self.receivedInvites = try container.decodeIfPresent([CoupleInvite].self, forKey: .receivedInvites) ?? []
        self.enabledSectionIds = try container.decodeIfPresent(Set<String>.self, forKey: .enabledSectionIds) ?? []
        self.enabledQuestionIds = try container.decodeIfPresent(Set<String>.self, forKey: .enabledQuestionIds) ?? []
        self.customSections = try container.decodeIfPresent([CustomQuestionnaireSection].self, forKey: .customSections) ?? []
        self.customQuestionsInSections = try container.decodeIfPresent([String: [CustomQuestionnaireItem]].self, forKey: .customQuestionsInSections) ?? [:]
        self.sectionWeights = try container.decodeIfPresent([String: Double].self, forKey: .sectionWeights) ?? [:]
        self.weightExcludedQuestionIds = try container.decodeIfPresent(Set<String>.self, forKey: .weightExcludedQuestionIds) ?? []
        self.preferredEMR = try container.decodeIfPresent(String.self, forKey: .preferredEMR)
        self.enableCalendarSync = try container.decodeIfPresent(Bool.self, forKey: .enableCalendarSync) ?? false
        self.includeRedFlaggedProgramsInRankList = try container.decodeIfPresent(Bool.self, forKey: .includeRedFlaggedProgramsInRankList) ?? true
        self.dashboardLayout = try container.decodeIfPresent(DashboardLayout.self, forKey: .dashboardLayout) ?? DashboardLayout()
        self.dashboardPreferences = try container.decodeIfPresent(DashboardPreferences.self, forKey: .dashboardPreferences) ?? DashboardPreferences()
        self.appearanceMode = try container.decodeIfPresent(AppearanceMode.self, forKey: .appearanceMode) ?? .auto
        self.interviewPrepByProgram = try container.decodeIfPresent([String: InterviewPrepState].self, forKey: .interviewPrepByProgram) ?? [:]
        self.interviewPrepCuratedListMigrated = try container.decodeIfPresent(Bool.self, forKey: .interviewPrepCuratedListMigrated) ?? false
        self.interviewPrepDefaultQuestions = try container.decodeIfPresent(InterviewPrepDefaultQuestions.self, forKey: .interviewPrepDefaultQuestions)
    }

    /// Clears old auto-filled interview prep question lists once per install/profile.
    @discardableResult
    mutating func migrateInterviewPrepCuratedListsIfNeeded() -> Bool {
        guard !interviewPrepCuratedListMigrated else { return false }
        for programID in interviewPrepByProgram.keys {
            interviewPrepByProgram[programID]?.migrateToCuratedQuestionListOnly()
        }
        interviewPrepCuratedListMigrated = true
        return true
    }
}

extension DashboardPreferences {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.welcomeHeaderStyle = try container.decodeIfPresent(WelcomeHeaderStyle.self, forKey: .welcomeHeaderStyle) ?? .default
        self.showProfilePicture = try container.decodeIfPresent(Bool.self, forKey: .showProfilePicture) ?? true
        self.showSpecialtyCount = try container.decodeIfPresent(Bool.self, forKey: .showSpecialtyCount) ?? true
        self.showQuickStats = try container.decodeIfPresent(Bool.self, forKey: .showQuickStats) ?? false
        // Locked for V1 — always time-based greeting with motivational subtitle.
        self.greetingStyle = .timeBased
        self.headerSubtitleMode = .motivational
        self.showMotivationalMessage = true
        self.showSpecialtyCount = false
    }
}

extension DashboardPreferences.WelcomeHeaderStyle {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try? container.decode(String.self)
        self = raw.flatMap(DashboardPreferences.WelcomeHeaderStyle.init(rawValue:)) ?? .default
    }
}

extension DashboardPreferences.GreetingStyle {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try? container.decode(String.self)
        self = raw.flatMap(DashboardPreferences.GreetingStyle.init(rawValue:)) ?? .timeBased
    }
}

extension DashboardPreferences.HeaderSubtitleMode {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try? container.decode(String.self)
        self = raw.flatMap(DashboardPreferences.HeaderSubtitleMode.init(rawValue:)) ?? .motivational
    }
}

extension DashboardLayout {
    private enum CodingKeys: String, CodingKey {
        case sectionOrder
        case disabledSections
        case enabledSections
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawOrder = try container.decodeIfPresent([String].self, forKey: .sectionOrder) ?? DashboardLayout.defaultSectionOrder
        self.sectionOrder = Self.normalizeSectionOrder(rawOrder)

        if let disabled = try container.decodeIfPresent(Set<String>.self, forKey: .disabledSections) {
            var healed = Self.normalizeSectionIDs(disabled)
            // Compare was added after legacy customization — don't keep it hidden by old prefs.
            healed.remove("programsCompare")
            healed.remove("analytics")
            self.disabledSections = healed
        } else {
            let legacyEnabled = try container.decodeIfPresent(Set<String>.self, forKey: .enabledSections) ?? []
            var migrated = Self.disabledSections(fromLegacyEnabledSections: legacyEnabled)
            migrated.remove("programsCompare")
            migrated.remove("analytics")
            self.disabledSections = migrated
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(sectionOrder, forKey: .sectionOrder)
        try container.encode(disabledSections, forKey: .disabledSections)
    }
}

