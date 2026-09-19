//
//  StateMapping.swift
//  Matchly
//
//  Created on 12/6/25.
//

import Foundation

/// Centralized state name to abbreviation mapping utility
enum StateMapping {
    /// State name to abbreviation mapping
    static let stateToAbbrev: [String: String] = [
        "alabama": "AL", "alaska": "AK", "arizona": "AZ", "arkansas": "AR",
        "california": "CA", "colorado": "CO", "connecticut": "CT", "delaware": "DE",
        "florida": "FL", "georgia": "GA", "hawaii": "HI", "idaho": "ID",
        "illinois": "IL", "indiana": "IN", "iowa": "IA", "kansas": "KS",
        "kentucky": "KY", "louisiana": "LA", "maine": "ME", "maryland": "MD",
        "massachusetts": "MA", "michigan": "MI", "minnesota": "MN", "mississippi": "MS",
        "missouri": "MO", "montana": "MT", "nebraska": "NE", "nevada": "NV",
        "new hampshire": "NH", "new jersey": "NJ", "new mexico": "NM", "new york": "NY",
        "north carolina": "NC", "north dakota": "ND", "ohio": "OH", "oklahoma": "OK",
        "oregon": "OR", "pennsylvania": "PA", "rhode island": "RI", "south carolina": "SC",
        "south dakota": "SD", "tennessee": "TN", "texas": "TX", "utah": "UT",
        "vermont": "VT", "virginia": "VA", "washington": "WA", "west virginia": "WV",
        "wisconsin": "WI", "wyoming": "WY", "district of columbia": "DC", "puerto rico": "PR"
    ]
    
    /// Abbreviation to state name mapping (reverse lookup)
    static let abbrevToState: [String: String] = {
        var mapping: [String: String] = [:]
        for (name, abbrev) in stateToAbbrev {
            mapping[abbrev.uppercased()] = name.capitalized
        }
        return mapping
    }()
    
    /// Get abbreviation for a state name
    static func abbreviation(for stateName: String) -> String? {
        return stateToAbbrev[stateName.lowercased()]
    }
    
    /// Get state name for an abbreviation
    static func stateName(for abbreviation: String) -> String? {
        return abbrevToState[abbreviation.uppercased()]
    }
    
    /// Check if two state strings match (handles both full names and abbreviations)
    static func matches(_ state1: String, _ state2: String) -> Bool {
        let state1Lower = state1.lowercased()
        let state2Lower = state2.lowercased()
        
        // Direct match
        if state1Lower == state2Lower {
            return true
        }
        
        // Check if state1 is full name that maps to state2's abbreviation
        if let abbrev1 = stateToAbbrev[state1Lower], abbrev1.uppercased() == state2.uppercased() {
            return true
        }
        
        // Check if state2 is full name that maps to state1's abbreviation
        if let abbrev2 = stateToAbbrev[state2Lower], abbrev2.uppercased() == state1.uppercased() {
            return true
        }
        
        return false
    }
    
    /// Normalize state string to abbreviation
    static func normalize(_ state: String) -> String {
        if let abbrev = abbreviation(for: state) {
            return abbrev
        }
        return state.uppercased()
    }
}




