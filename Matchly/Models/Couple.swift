//
//  Couple.swift
//  Matchly
//
//  Created on 11/16/25.
//

import Foundation

struct Couple: Codable, Identifiable, Hashable {
    let id: String
    var user1ID: String // Current user's ID
    var user2ID: String? // Partner's ID (if linked)
    var user1Name: String
    var user2Name: String? // Partner's name
    var user1Email: String? // Current user's email
    var user2Email: String? // Partner's email
    var coupleCode: String // Unique code for linking
    var inviteLink: String? // Shareable invite link
    var isLinked: Bool {
        user2ID != nil && user2Name != nil
    }
    var status: CoupleStatus
    var createdAt: Date
    var linkedAt: Date?
    
    enum CoupleStatus: String, Codable, Hashable {
        case pending = "Pending" // Code generated, waiting for partner
        case linked = "Linked" // Both users linked
        case active = "Active" // Actively using couples matching
    }
    
    init(id: String = UUID().uuidString, user1ID: String, user1Name: String, user1Email: String? = nil, coupleCode: String = Couple.generateCoupleCode(), inviteLink: String? = nil, status: CoupleStatus = .pending, createdAt: Date = Date(), linkedAt: Date? = nil) {
        self.id = id
        self.user1ID = user1ID
        self.user2ID = nil
        self.user1Name = user1Name
        self.user2Name = nil
        self.user1Email = user1Email
        self.user2Email = nil
        self.coupleCode = coupleCode
        self.inviteLink = inviteLink ?? Couple.generateInviteLink(code: coupleCode)
        self.status = status
        self.createdAt = createdAt
        self.linkedAt = linkedAt
    }
    
    static func generateCoupleCode() -> String {
        // Generate a 6-character alphanumeric code
        let characters = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789" // Exclude confusing characters
        return String((0..<6).map { _ in characters.randomElement()! })
    }
    
    static func generateInviteLink(code: String) -> String {
        // Generate a shareable invite link
        // Format: matchly://couple/invite/{code}
        return "matchly://couple/invite/\(code)"
    }
    
    static func parseInviteLink(_ link: String) -> String? {
        // Extract code from invite link
        if link.contains("matchly://couple/invite/") {
            return String(link.suffix(6))
        }
        return nil
    }
}

struct CouplesRankPair: Codable, Identifiable, Hashable {
    let id: String
    var rank: Int // Position in the couples rank list
    var user1ProgramID: String? // Current user's program ID
    var user2ProgramID: String? // Partner's program ID
    var user1NoMatch: Bool // If true, user1 is willing to not match if user2 matches here
    var user2NoMatch: Bool // If true, user2 is willing to not match if user1 matches here
    var notes: String
    
    init(id: String = UUID().uuidString, rank: Int, user1ProgramID: String? = nil, user2ProgramID: String? = nil, user1NoMatch: Bool = false, user2NoMatch: Bool = false, notes: String = "") {
        self.id = id
        self.rank = rank
        self.user1ProgramID = user1ProgramID
        self.user2ProgramID = user2ProgramID
        self.user1NoMatch = user1NoMatch
        self.user2NoMatch = user2NoMatch
        self.notes = notes
    }
}

struct CouplesPreferences: Codable, Hashable {
    var geographicPriority: GeographicPriority = .balanced
    var programTypePriority: ProgramTypePriority = .balanced
    var distanceTolerance: Int = 50 // Maximum distance in miles between programs
    var mustMatchTogether: Bool = true // If false, allows individual matching if couple match fails
    
    enum GeographicPriority: String, Codable, CaseIterable, Hashable {
        case sameCity = "Same City"
        case sameState = "Same State"
        case sameRegion = "Same Region"
        case balanced = "Balanced"
        case flexible = "Flexible"
    }
    
    enum ProgramTypePriority: String, Codable, CaseIterable, Hashable {
        case bothAcademic = "Both Academic"
        case bothCommunity = "Both Community"
        case balanced = "Balanced"
        case flexible = "Flexible"
    }
}

