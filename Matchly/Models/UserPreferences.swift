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
    
    // Section weights (0.0-1.0, should sum to 1.0 for all enabled sections)
    // Key is section ID, value is weight (0.0-1.0)
    var sectionWeights: [String: Double] = [:] // Empty = equal weights for all sections
    
    // Calendar sync preference
    var enableCalendarSync: Bool = false // Whether user wants to sync interviews to calendar
    
    // Red flag ranking preference
    var includeRedFlaggedProgramsInRankList: Bool = true // Whether to include red flagged programs in rank list
}

