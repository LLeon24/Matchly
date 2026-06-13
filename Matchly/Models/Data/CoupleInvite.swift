//
//  CoupleInvite.swift
//  Matchly
//
//  Created on 11/16/25.
//

import Foundation

struct CoupleInvite: Codable, Identifiable, Hashable {
    let id: String
    let fromUserID: String
    let fromUserName: String
    let fromUserEmail: String?
    let toUserID: String?
    let toUserEmail: String? // Email to send invite to
    let coupleCode: String
    let inviteLink: String
    var status: InviteStatus
    let createdAt: Date
    var respondedAt: Date?
    
    enum InviteStatus: String, Codable, Hashable {
        case pending = "Pending"
        case accepted = "Accepted"
        case declined = "Declined"
        case expired = "Expired"
    }
    
    init(id: String = UUID().uuidString, fromUserID: String, fromUserName: String, fromUserEmail: String? = nil, toUserID: String? = nil, toUserEmail: String? = nil, coupleCode: String, inviteLink: String, status: InviteStatus = .pending, createdAt: Date = Date(), respondedAt: Date? = nil) {
        self.id = id
        self.fromUserID = fromUserID
        self.fromUserName = fromUserName
        self.fromUserEmail = fromUserEmail
        self.toUserID = toUserID
        self.toUserEmail = toUserEmail
        self.coupleCode = coupleCode
        self.inviteLink = inviteLink
        self.status = status
        self.createdAt = createdAt
        self.respondedAt = respondedAt
    }
    
    var isExpired: Bool {
        // Invites expire after 7 days
        let expirationDate = createdAt.addingTimeInterval(7 * 24 * 60 * 60)
        return Date() > expirationDate
    }
}

// MARK: - Resilient decoding
// Missing keys / unknown enum raw values fall back to defaults so decoding
// never throws (see Program.swift).

extension CoupleInvite {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        self.fromUserID = try container.decodeIfPresent(String.self, forKey: .fromUserID) ?? ""
        self.fromUserName = try container.decodeIfPresent(String.self, forKey: .fromUserName) ?? ""
        self.fromUserEmail = try container.decodeIfPresent(String.self, forKey: .fromUserEmail)
        self.toUserID = try container.decodeIfPresent(String.self, forKey: .toUserID)
        self.toUserEmail = try container.decodeIfPresent(String.self, forKey: .toUserEmail)
        self.coupleCode = try container.decodeIfPresent(String.self, forKey: .coupleCode) ?? ""
        self.inviteLink = try container.decodeIfPresent(String.self, forKey: .inviteLink) ?? ""
        self.status = try container.decodeIfPresent(InviteStatus.self, forKey: .status) ?? .pending
        self.createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        self.respondedAt = try container.decodeIfPresent(Date.self, forKey: .respondedAt)
    }
}

extension CoupleInvite.InviteStatus {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try? container.decode(String.self)
        self = raw.flatMap(CoupleInvite.InviteStatus.init(rawValue:)) ?? .pending
    }
}

