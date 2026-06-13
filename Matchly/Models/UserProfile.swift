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

