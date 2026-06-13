//
//  SignalLimits.swift
//  Matchly
//
//  Created on 11/15/25.
//

import Foundation

enum SignalType: String, Codable, CaseIterable {
    case none = "None"
    case gold = "Gold"
    case silver = "Silver"
    
    var displayName: String {
        return rawValue
    }
    
    var icon: String {
        switch self {
        case .none: return ""
        case .gold: return "star.fill"
        case .silver: return "star"
        }
    }
    
    var color: String {
        switch self {
        case .none: return "gray"
        case .gold: return "yellow"
        case .silver: return "gray"
        }
    }
}

// MARK: - Resilient decoding
// Unknown or missing raw values fall back to `.none` so decoding never throws.
extension SignalType {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try? container.decode(String.self)
        self = raw.flatMap(SignalType.init(rawValue:)) ?? .none
    }
}

struct SignalLimits {
    // Default ERAS signaling limits (these may vary by specialty and year)
    // Most specialties: 5 gold + 30 silver signals
    // Some specialties have different limits
    static let defaultGoldLimit = 5
    static let defaultSilverLimit = 30
    
    // Specialty-specific limits (ERAS 2025 signaling limits)
    // Format: (gold: Int, silver: Int)
    // For tiered: both gold and silver > 0
    // For single-level: gold = total signals, silver = 0
    static let specialtyLimits: [String: (gold: Int, silver: Int)] = [
        // Tiered (gold + silver)
        "Anesthesiology": (gold: 5, silver: 10),
        "Dermatology": (gold: 3, silver: 25),
        "Diagnostic Radiology and Interventional Radiology": (gold: 6, silver: 6),
        "Internal Medicine": (gold: 3, silver: 12),
        // Common variations/aliases for tiered
        "Anesthesia": (gold: 5, silver: 10),
        "Radiology": (gold: 6, silver: 6),
        "IM": (gold: 3, silver: 12),
        
        // Single-level signals (gold = total, silver = 0)
        "Child Neurology & Neurodevelopmental Disabilities": (gold: 3, silver: 0),
        "Emergency Medicine": (gold: 5, silver: 0),
        "Family Medicine": (gold: 5, silver: 0),
        "General Surgery": (gold: 15, silver: 0),
        "Internal Medicine & Psychiatry": (gold: 2, silver: 0),
        "Neurological Surgery": (gold: 25, silver: 0),
        "Neurology": (gold: 8, silver: 0),
        "Orthopaedic Surgery": (gold: 30, silver: 0),
        "Otolaryngology": (gold: 25, silver: 0),
        "Pathology": (gold: 5, silver: 0),
        "Pediatrics": (gold: 5, silver: 0),
        "Physical Medicine and Rehabilitation": (gold: 8, silver: 0),
        "Psychiatry": (gold: 10, silver: 0),
        "Public Health and General Preventive Medicine": (gold: 3, silver: 0),
        "Radiation Oncology": (gold: 4, silver: 0),
        "Thoracic Surgery": (gold: 3, silver: 0),
        "Transitional Year": (gold: 12, silver: 0),
        // Common variations/aliases for single-level
        "Neurosurgery": (gold: 25, silver: 0),
        "ENT": (gold: 25, silver: 0),
        "Otolaryngology - Head and Neck Surgery": (gold: 25, silver: 0),
        "Orthopedics": (gold: 30, silver: 0),
        "Orthopedic Surgery": (gold: 30, silver: 0),
        "PM&R": (gold: 8, silver: 0),
        "Surgery": (gold: 15, silver: 0),
        "Pathology-Anatomic and Clinical": (gold: 5, silver: 0),
        "Thoracic Surgery - Integrated": (gold: 3, silver: 0),
        "Obstetrics and Gynecology": (gold: 5, silver: 0),
        "OB/GYN": (gold: 5, silver: 0)
    ]
    
    static func goldLimit(for specialty: String) -> Int {
        return specialtyLimits[specialty]?.gold ?? defaultGoldLimit
    }
    
    static func silverLimit(for specialty: String) -> Int {
        return specialtyLimits[specialty]?.silver ?? defaultSilverLimit
    }
    
    static func totalLimit(for specialty: String) -> Int {
        let limits = limits(for: specialty)
        return limits.gold + limits.silver
    }
    
    static func limits(for specialty: String) -> (gold: Int, silver: Int) {
        return specialtyLimits[specialty] ?? (gold: defaultGoldLimit, silver: defaultSilverLimit)
    }
    
    // Check if specialty uses tiered (gold/silver) or single-level signals
    static func isTiered(for specialty: String) -> Bool {
        if let limits = specialtyLimits[specialty] {
            // If both gold and silver are > 0, it's tiered
            return limits.gold > 0 && limits.silver > 0
        }
        // Default: assume tiered
        return true
    }
    
    // Get total signal limit for single-level specialties
    static func singleLevelLimit(for specialty: String) -> Int {
        if let limits = specialtyLimits[specialty] {
            // For single-level, gold has the total and silver is 0
            if limits.silver == 0 {
                return limits.gold
            }
            // For tiered, return sum
            return limits.gold + limits.silver
        }
        return 5 // Default
    }
}

