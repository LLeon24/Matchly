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

    /// Rebuilds a couple value with a canonical shared ID (e.g. from CloudKit registration).
    init(copying couple: Couple, id: String) {
        self.id = id
        self.user1ID = couple.user1ID
        self.user2ID = couple.user2ID
        self.user1Name = couple.user1Name
        self.user2Name = couple.user2Name
        self.user1Email = couple.user1Email
        self.user2Email = couple.user2Email
        self.coupleCode = couple.coupleCode
        self.inviteLink = couple.inviteLink
        self.status = couple.status
        self.createdAt = couple.createdAt
        self.linkedAt = couple.linkedAt
    }
    
    static func generateCoupleCode() -> String {
        // Generate a 6-character alphanumeric code
        let characters = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789" // Exclude confusing characters
        // Safe unwrap - characters string is never empty
        return String((0..<6).compactMap { _ in characters.randomElement() })
    }
    
    static func generateInviteLink(code: String) -> String {
        // Legacy deep-link format; QR and share text are the primary invite paths.
        return "matchly://couple/invite/\(code)"
    }

    static let qrPayloadPrefix = "MATCHLY-COUPLE:"

    /// Payload encoded in QR codes for in-person linking.
    static func qrPayload(for code: String) -> String {
        "\(qrPayloadPrefix)\(code.uppercased())"
    }

    /// Parses a QR scan, deep link, or raw 6-character code.
    static func parseLinkPayload(_ payload: String) -> String? {
        let trimmed = payload.trimmingCharacters(in: .whitespacesAndNewlines)
        if let fromLink = parseInviteLink(trimmed) {
            return fromLink
        }
        let upper = trimmed.uppercased()
        if upper.hasPrefix(qrPayloadPrefix) {
            let code = String(upper.dropFirst(qrPayloadPrefix.count))
            return code.count == 6 ? code : nil
        }
        if trimmed.count == 6, trimmed.allSatisfy({ $0.isLetter || $0.isNumber }) {
            return upper
        }
        return nil
    }

    static func inviteURL(for code: String) -> URL? {
        URL(string: generateInviteLink(code: code))
    }

    /// Short body paired with `inviteURL` when sharing via ShareLink (URL is the tappable item).
    static func shareInviteMessage(code: String, inviterName: String) -> String {
        """
        \(inviterName) invited you to link on Matchly for couples match.

        Open Matchly → Couples Matching → Enter Code, then use:
        \(code.uppercased())
        """
    }

    /// Subject line for the system share sheet.
    static func shareInviteSubject(inviterName: String) -> String {
        "\(inviterName) invited you on Matchly"
    }
    
    static func parseInviteLink(_ link: String) -> String? {
        // Extract code from invite link
        // Format: matchly://couple/invite/{code} or matchly://couple/invite/{code}?...
        let prefix = "matchly://couple/invite/"
        guard link.contains(prefix) else { return nil }
        
        // Find the start of the code
        guard let codeStartIndex = link.range(of: prefix)?.upperBound else { return nil }
        
        // Extract the code (everything after the prefix, up to any query parameters or end of string)
        let remaining = String(link[codeStartIndex...])
        let code: String
        if let queryIndex = remaining.firstIndex(of: "?") {
            code = String(remaining[..<queryIndex])
        } else if let fragmentIndex = remaining.firstIndex(of: "#") {
            code = String(remaining[..<fragmentIndex])
        } else {
            code = remaining
        }
        
        // Validate code is exactly 6 characters (alphanumeric)
        guard code.count == 6, code.allSatisfy({ $0.isLetter || $0.isNumber }) else {
            return nil
        }
        
        return code.uppercased()
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
    var mustMatchTogether: Bool = true
    var preferSameHospital: Bool = false
    var preferSameCity: Bool = false
    var preferSameState: Bool = true
    var prioritizeIndividualRankLists: Bool = true
    var distanceTolerance: Int = 100

    /// How strictly program locations must align when suggesting pairs.
    /// Same city implies same state; same state does not imply same city.
    enum GeographyStrictness: String, Codable, CaseIterable, Hashable {
        case withinDistance
        case sameState
        case sameCity

        var displayName: String {
            switch self {
            case .withinDistance: return "Within Max Distance"
            case .sameState: return "Same State"
            case .sameCity: return "Same City"
            }
        }

        var detail: String {
            switch self {
            case .withinDistance:
                return "Programs can be in different cities and states as long as they are within your distance limit."
            case .sameState:
                return "Programs must be in the same state. Different cities in that state are allowed."
            case .sameCity:
                return "Programs must be in the same city, which also means the same state."
            }
        }
    }

    var geographyStrictness: GeographyStrictness {
        get {
            if preferSameCity { return .sameCity }
            if preferSameState { return .sameState }
            return .withinDistance
        }
        set {
            switch newValue {
            case .withinDistance:
                preferSameCity = false
                preferSameState = false
            case .sameState:
                preferSameCity = false
                preferSameState = true
            case .sameCity:
                preferSameCity = true
                preferSameState = true
            }
        }
    }

    mutating func normalizeGeography() {
        if preferSameCity {
            preferSameState = true
        }
    }

    /// Legacy fields — kept for backward compatibility; UI uses toggles above.
    var geographicPriority: GeographicPriority = .balanced
    var programTypePriority: ProgramTypePriority = .balanced
    var weightIndividualScores: Double = 0.35
    var weightGeography: Double = 0.30
    var weightSameHospital: Double = 0.15
    var weightEMR: Double = 0.10
    var weightProgramType: Double = 0.10

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

// MARK: - Resilient decoding
// Missing keys / unknown enum raw values fall back to defaults so decoding
// never throws (see Program.swift).

extension Couple {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        self.user1ID = try container.decodeIfPresent(String.self, forKey: .user1ID) ?? ""
        self.user2ID = try container.decodeIfPresent(String.self, forKey: .user2ID)
        self.user1Name = try container.decodeIfPresent(String.self, forKey: .user1Name) ?? ""
        self.user2Name = try container.decodeIfPresent(String.self, forKey: .user2Name)
        self.user1Email = try container.decodeIfPresent(String.self, forKey: .user1Email)
        self.user2Email = try container.decodeIfPresent(String.self, forKey: .user2Email)
        let code = try container.decodeIfPresent(String.self, forKey: .coupleCode) ?? Couple.generateCoupleCode()
        self.coupleCode = code
        self.inviteLink = try container.decodeIfPresent(String.self, forKey: .inviteLink) ?? Couple.generateInviteLink(code: code)
        self.status = try container.decodeIfPresent(CoupleStatus.self, forKey: .status) ?? .pending
        self.createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        self.linkedAt = try container.decodeIfPresent(Date.self, forKey: .linkedAt)
    }
}

extension Couple.CoupleStatus {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try? container.decode(String.self)
        self = raw.flatMap(Couple.CoupleStatus.init(rawValue:)) ?? .pending
    }
}

extension CouplesRankPair {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        self.rank = try container.decodeIfPresent(Int.self, forKey: .rank) ?? 0
        self.user1ProgramID = try container.decodeIfPresent(String.self, forKey: .user1ProgramID)
        self.user2ProgramID = try container.decodeIfPresent(String.self, forKey: .user2ProgramID)
        self.user1NoMatch = try container.decodeIfPresent(Bool.self, forKey: .user1NoMatch) ?? false
        self.user2NoMatch = try container.decodeIfPresent(Bool.self, forKey: .user2NoMatch) ?? false
        self.notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
    }
}

extension CouplesPreferences {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.mustMatchTogether = try container.decodeIfPresent(Bool.self, forKey: .mustMatchTogether) ?? true
        self.preferSameHospital = try container.decodeIfPresent(Bool.self, forKey: .preferSameHospital) ?? false
        self.preferSameCity = try container.decodeIfPresent(Bool.self, forKey: .preferSameCity) ?? false
        self.preferSameState = try container.decodeIfPresent(Bool.self, forKey: .preferSameState) ?? true
        self.prioritizeIndividualRankLists = try container.decodeIfPresent(Bool.self, forKey: .prioritizeIndividualRankLists) ?? true
        self.distanceTolerance = try container.decodeIfPresent(Int.self, forKey: .distanceTolerance) ?? 100
        self.geographicPriority = try container.decodeIfPresent(GeographicPriority.self, forKey: .geographicPriority) ?? .balanced
        self.programTypePriority = try container.decodeIfPresent(ProgramTypePriority.self, forKey: .programTypePriority) ?? .balanced
        self.weightIndividualScores = try container.decodeIfPresent(Double.self, forKey: .weightIndividualScores) ?? 0.35
        self.weightGeography = try container.decodeIfPresent(Double.self, forKey: .weightGeography) ?? 0.30
        self.weightSameHospital = try container.decodeIfPresent(Double.self, forKey: .weightSameHospital) ?? 0.15
        self.weightEMR = try container.decodeIfPresent(Double.self, forKey: .weightEMR) ?? 0.10
        self.weightProgramType = try container.decodeIfPresent(Double.self, forKey: .weightProgramType) ?? 0.10

        if container.contains(.preferSameCity) == false {
            switch geographicPriority {
            case .sameCity:
                preferSameCity = true
                preferSameState = true
            case .sameState, .sameRegion:
                preferSameState = true
            default:
                break
            }
        }
        normalizeGeography()
    }
}

extension CouplesPreferences.GeographicPriority {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try? container.decode(String.self)
        self = raw.flatMap(CouplesPreferences.GeographicPriority.init(rawValue:)) ?? .balanced
    }
}

extension CouplesPreferences.ProgramTypePriority {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try? container.decode(String.self)
        self = raw.flatMap(CouplesPreferences.ProgramTypePriority.init(rawValue:)) ?? .balanced
    }
}

