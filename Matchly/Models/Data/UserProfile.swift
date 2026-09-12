//
//  UserProfile.swift
//  Matchly
//
//  Created on 11/14/25.
//

import Foundation
import UIKit

struct UserProfile: Codable, Hashable {
    var firstName: String = ""
    var lastName: String = ""
    var aamcID: String? // Optional AAMC ID
    var photoData: Data? // Store photo as Data for Codable
    /// Set when the user picks a built-in avatar preset (cleared for custom photos).
    var avatarPresetID: String?

    var hasPhoto: Bool {
        photoData != nil
    }

    var name: String {
        [firstName, lastName]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    var displayName: String {
        name.isEmpty ? "Resident" : name
    }

    /// Used for compact dashboard greetings.
    var greetingFirstName: String {
        firstName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func splitLegacyName(_ full: String) -> (first: String, last: String) {
        let parts = full
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ", omittingEmptySubsequences: true)
            .map(String.init)
        guard let first = parts.first else { return ("", "") }
        let last = parts.count > 1 ? parts.dropFirst().joined(separator: " ") : ""
        return (first, last)
    }
}

// MARK: - Resilient decoding
// Missing keys fall back to defaults so decoding never throws (see Program.swift).
extension UserProfile {
    enum CodingKeys: String, CodingKey {
        case name
        case firstName
        case lastName
        case aamcID
        case photoData
        case avatarPresetID
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        firstName = try container.decodeIfPresent(String.self, forKey: .firstName) ?? ""
        lastName = try container.decodeIfPresent(String.self, forKey: .lastName) ?? ""
        aamcID = try container.decodeIfPresent(String.self, forKey: .aamcID)
        photoData = try container.decodeIfPresent(Data.self, forKey: .photoData)
        avatarPresetID = try container.decodeIfPresent(String.self, forKey: .avatarPresetID)

        if firstName.isEmpty, lastName.isEmpty {
            let legacyName = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
            if !legacyName.isEmpty {
                let split = Self.splitLegacyName(legacyName)
                firstName = split.first
                lastName = split.last
            }
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(firstName, forKey: .firstName)
        try container.encode(lastName, forKey: .lastName)
        try container.encodeIfPresent(aamcID, forKey: .aamcID)
        try container.encodeIfPresent(photoData, forKey: .photoData)
        try container.encodeIfPresent(avatarPresetID, forKey: .avatarPresetID)
    }
}
