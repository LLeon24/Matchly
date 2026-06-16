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
    /// Residency or Fellowship — drives default program search track.
    var applyingTrack: String = ProgramTrainingLevelFilter.residency.rawValue
    var hasCompletedOnboarding: Bool = false
    
    // User profile
    var profile: UserProfile = UserProfile()
    
    // User account
    var userID: String = UUID().uuidString // Unique identifier for this user
    var nrmpID: String? // NRMP ID for couples matching
    
    // Couples matching
    var couple: Couple? // Current couple relationship
    var couplesPreferences: CouplesPreferences = CouplesPreferences()
    var couplesRankPairs: [CouplesRankPair] = [] // Paired rank list for couples matching
    var sentInvites: [CoupleInvite] = [] // Invites sent by this user
    var receivedInvites: [CoupleInvite] = [] // Invites received by this user
    
    // Questionnaire customization
    var enabledSectionIds: Set<String> = [] // Empty = all enabled by default
    var enabledQuestionIds: Set<String> = [] // Empty = all enabled by default
    var customSections: [CustomQuestionnaireSection] = [] // User-created custom sections
    var customQuestionsInSections: [String: [CustomQuestionnaireItem]] = [:] // Custom questions added to standard sections (key = section ID)
    
    // Section weights (0.0-1.0, should sum to 1.0 for all enabled sections)
    // Key is section ID, value is weight (0.0-1.0)
    // The EMR factor stores its importance here too, under EMRScoring.weightKey.
    var sectionWeights: [String: Double] = [:] // Empty = equal weights for all sections
    
    // Applicant's preferred / most familiar EMR (an EMRSystem.rawValue).
    // Optional for backward compatibility. When set, programs are scored on how
    // well their EMR matches this preference (weighted via sectionWeights[EMRScoring.weightKey]).
    var preferredEMR: String?
    
    // Calendar sync preference
    var enableCalendarSync: Bool = false // Whether user wants to sync interviews to calendar
    
    // Red flag ranking preference
    var includeRedFlaggedProgramsInRankList: Bool = true // Whether to include red flagged programs in rank list
    
    // Dashboard customization
    var dashboardLayout: DashboardLayout = DashboardLayout()
    var dashboardPreferences: DashboardPreferences = DashboardPreferences()
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
    // Ordered list of section IDs (determines display order)
    var sectionOrder: [String] = [
        "welcome",
        "quickActions",
        "nextSteps",
        "quickStats",
        "analytics",
        "topPrograms",
        "upcomingInterviews",
        "recentActivity"
    ]
    
    // Which sections are enabled (empty = all enabled by default)
    var enabledSections: Set<String> = []
    
    // Default enabled sections (all enabled by default)
    static let defaultSections: Set<String> = [
        "welcome",
        "quickActions",
        "nextSteps",
        "quickStats",
        "analytics",
        "topPrograms",
        "upcomingInterviews",
        "recentActivity"
    ]
    
    func isSectionEnabled(_ sectionId: String) -> Bool {
        // If enabledSections is empty, all sections are enabled by default
        if enabledSections.isEmpty {
            return Self.defaultSections.contains(sectionId)
        }
        return enabledSections.contains(sectionId)
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
        self.applyingTrack = try container.decodeIfPresent(String.self, forKey: .applyingTrack)
            ?? ProgramTrainingLevelFilter.residency.rawValue
        self.hasCompletedOnboarding = try container.decodeIfPresent(Bool.self, forKey: .hasCompletedOnboarding) ?? false
        self.profile = try container.decodeIfPresent(UserProfile.self, forKey: .profile) ?? UserProfile()
        self.userID = try container.decodeIfPresent(String.self, forKey: .userID) ?? UUID().uuidString
        self.nrmpID = try container.decodeIfPresent(String.self, forKey: .nrmpID)
        self.couple = try container.decodeIfPresent(Couple.self, forKey: .couple)
        self.couplesPreferences = try container.decodeIfPresent(CouplesPreferences.self, forKey: .couplesPreferences) ?? CouplesPreferences()
        self.couplesRankPairs = try container.decodeIfPresent([CouplesRankPair].self, forKey: .couplesRankPairs) ?? []
        self.sentInvites = try container.decodeIfPresent([CoupleInvite].self, forKey: .sentInvites) ?? []
        self.receivedInvites = try container.decodeIfPresent([CoupleInvite].self, forKey: .receivedInvites) ?? []
        self.enabledSectionIds = try container.decodeIfPresent(Set<String>.self, forKey: .enabledSectionIds) ?? []
        self.enabledQuestionIds = try container.decodeIfPresent(Set<String>.self, forKey: .enabledQuestionIds) ?? []
        self.customSections = try container.decodeIfPresent([CustomQuestionnaireSection].self, forKey: .customSections) ?? []
        self.customQuestionsInSections = try container.decodeIfPresent([String: [CustomQuestionnaireItem]].self, forKey: .customQuestionsInSections) ?? [:]
        self.sectionWeights = try container.decodeIfPresent([String: Double].self, forKey: .sectionWeights) ?? [:]
        self.preferredEMR = try container.decodeIfPresent(String.self, forKey: .preferredEMR)
        self.enableCalendarSync = try container.decodeIfPresent(Bool.self, forKey: .enableCalendarSync) ?? false
        self.includeRedFlaggedProgramsInRankList = try container.decodeIfPresent(Bool.self, forKey: .includeRedFlaggedProgramsInRankList) ?? true
        self.dashboardLayout = try container.decodeIfPresent(DashboardLayout.self, forKey: .dashboardLayout) ?? DashboardLayout()
        self.dashboardPreferences = try container.decodeIfPresent(DashboardPreferences.self, forKey: .dashboardPreferences) ?? DashboardPreferences()
    }
}

extension DashboardPreferences {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.welcomeHeaderStyle = try container.decodeIfPresent(WelcomeHeaderStyle.self, forKey: .welcomeHeaderStyle) ?? .default
        self.showProfilePicture = try container.decodeIfPresent(Bool.self, forKey: .showProfilePicture) ?? true
        self.showSpecialtyCount = try container.decodeIfPresent(Bool.self, forKey: .showSpecialtyCount) ?? true
        self.showQuickStats = try container.decodeIfPresent(Bool.self, forKey: .showQuickStats) ?? false
        self.showMotivationalMessage = try container.decodeIfPresent(Bool.self, forKey: .showMotivationalMessage) ?? true
        self.greetingStyle = try container.decodeIfPresent(GreetingStyle.self, forKey: .greetingStyle) ?? .timeBased
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

extension DashboardLayout {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // `sectionOrder` has a non-trivial default; fall back to a fresh instance's value.
        self.sectionOrder = try container.decodeIfPresent([String].self, forKey: .sectionOrder) ?? DashboardLayout().sectionOrder
        self.enabledSections = try container.decodeIfPresent(Set<String>.self, forKey: .enabledSections) ?? []
    }
}

