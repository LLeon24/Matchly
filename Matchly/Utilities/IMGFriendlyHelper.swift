//
//  IMGFriendlyHelper.swift
//  Matchly
//
//  Created on 11/14/25.
//

import Foundation

/// Helper class to identify and mark IMG-friendly residency programs
/// Based on known patterns, hospital systems, and program types that historically accept IMGs
class IMGFriendlyHelper {
    static let shared = IMGFriendlyHelper()
    
    // Known IMG-friendly hospital systems and patterns
    private let imgFriendlyHospitalPatterns: [String] = [
        "HCA", "Community", "Mercy", "St. ", "Saint ", "Methodist", "Baptist",
        "Memorial", "Regional", "County", "University Medical Center"
    ]
    
    // States with higher IMG acceptance rates (based on historical data)
    private let imgFriendlyStates: Set<String> = [
        "NY", "FL", "TX", "IL", "PA", "NJ", "MI", "OH", "CA", "GA"
    ]
    
    // Specialties that are generally more IMG-friendly
    private let imgFriendlySpecialties: Set<String> = [
        "Internal Medicine", "Family Medicine", "Psychiatry", "Pathology",
        "Pediatrics", "Emergency Medicine", "Neurology", "Anesthesiology"
    ]
    
    private init() {}
    
    /// Determines if a program is likely IMG-friendly based on patterns
    /// Returns: true if likely friendly, false if likely not, nil if unknown
    func assessIMGFriendliness(program: ResidencyProgramInfo) -> Bool? {
        // If already explicitly marked, use that
        if let explicitStatus = program.isIMGFriendly {
            return explicitStatus
        }
        
        var friendlyIndicators = 0
        let unfriendlyIndicators = 0
        
        // Check hospital name patterns
        let hospitalLower = program.hospital.lowercased()
        for pattern in imgFriendlyHospitalPatterns {
            if hospitalLower.contains(pattern.lowercased()) {
                friendlyIndicators += 1
                break
            }
        }
        
        // Check state
        if imgFriendlyStates.contains(program.state) {
            friendlyIndicators += 1
        }
        
        // Check specialty
        if imgFriendlySpecialties.contains(program.specialty) {
            friendlyIndicators += 1
        }
        
        // Determine result based on indicators
        if friendlyIndicators >= 2 {
            return true
        } else if unfriendlyIndicators > friendlyIndicators {
            return false
        } else {
            return nil // Unknown - needs explicit marking
        }
    }
    
    /// Marks programs as IMG-friendly based on assessment
    func markIMGFriendlyStatus(programs: inout [ResidencyProgramInfo]) {
        for i in 0..<programs.count {
            if programs[i].isIMGFriendly == nil {
                programs[i].isIMGFriendly = assessIMGFriendliness(program: programs[i])
            }
        }
    }
    
    /// Get count of IMG-friendly programs
    func countIMGFriendly(programs: [ResidencyProgramInfo]) -> Int {
        return programs.filter { $0.isIMGFriendly == true }.count
    }
    
    /// Get count of programs with unknown IMG status
    func countUnknownIMGStatus(programs: [ResidencyProgramInfo]) -> Int {
        return programs.filter { $0.isIMGFriendly == nil }.count
    }
    
    /// Assess IMG friendliness for a Program object (used in views)
    func assessIMGFriendlinessForProgram(_ program: Program) -> Bool? {
        // If already explicitly marked, use that
        if let explicitStatus = program.isIMGFriendly {
            return explicitStatus
        }
        
        // Convert Program to ResidencyProgramInfo for assessment
        let programInfo = ResidencyProgramInfo(
            id: program.id,
            name: program.name,
            hospital: program.hospital,
            city: program.city,
            state: program.state,
            specialty: program.specialty,
            type: program.type,
            accreditationID: program.accreditationID,
            websiteURL: program.websiteURL,
            contactEmail: program.contactEmail,
            contactPhone: program.contactPhone,
            programCoordinator: program.programCoordinator,
            programDirector: program.programDirector,
            address: program.address,
            isIMGFriendly: nil
        )
        
        return assessIMGFriendliness(program: programInfo)
    }
}

