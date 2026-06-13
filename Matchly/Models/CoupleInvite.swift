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

