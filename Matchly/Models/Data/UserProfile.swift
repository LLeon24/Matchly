//
//  UserProfile.swift
//  Matchly
//
//  Created on 11/14/25.
//

import Foundation
import UIKit

struct UserProfile: Codable, Hashable {
    var name: String = ""
    var aamcID: String? // Optional AAMC ID
    var photoData: Data? // Store photo as Data for Codable
    
    var hasPhoto: Bool {
        photoData != nil
    }
    
    var displayName: String {
        name.isEmpty ? "Resident" : name
    }
}

// MARK: - Resilient decoding
// Missing keys fall back to defaults so decoding never throws (see Program.swift).
extension UserProfile {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        self.aamcID = try container.decodeIfPresent(String.self, forKey: .aamcID)
        self.photoData = try container.decodeIfPresent(Data.self, forKey: .photoData)
    }
}

