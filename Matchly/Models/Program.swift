//
//  Program.swift
//  Matchly
//
//  Created by Leoh N. Leon II on 11/14/25.
//

import Foundation

struct Program: Identifiable, Codable {
    let id: String
    var specialty: String
    var name: String
    var hospital: String
    var city: String
    var state: String
    var address: String? // Full street address
    var type: String // Academic / Community / Hybrid
    var accreditationID: String? // ACGME Program Code
    
    var programQuality: ProgramQuality
    var cultureFit: CultureFit
    var location: Location
    var logistics: Logistics
    var careerAlignment: CareerAlignment
    var redFlags: RedFlags
    
    // New comprehensive questionnaire
    var questionnaire: Questionnaire
    
    var notes: String
    var interviewDate: Date?
    var voiceMemoURL: String?
    
    // Contact information (user-editable)
    var websiteURL: String?
    var contactEmail: String?
    var contactPhone: String?
    var programCoordinator: String?
    
    // IMG-friendly status
    var isIMGFriendly: Bool?
    
    // ERAS Signaling
    var signalType: SignalType = .none
    
    var finalScore: Double
    
    // Check if program has any red flags (Yes answers in red flags section)
    func hasRedFlags() -> Bool {
        // Check standard sections
        for section in questionnaire.sections {
            if section.title.contains("Red flags") || section.title.lowercased().contains("red flag") {
                for item in section.items {
                    // For red flags, rating == 1 means "Yes" (red flag)
                    if item.programRating == 1 {
                        return true
                    }
                }
            }
        }
        
        // Check custom sections
        for section in questionnaire.customSections {
            if section.title.contains("Red flags") || section.title.lowercased().contains("red flag") {
                for item in section.items {
                    // For red flags, rating == 1 means "Yes" (red flag)
                    if item.programRating == 1 {
                        return true
                    }
                }
            }
        }
        
        return false
    }
    
    init(
        id: String = UUID().uuidString,
        specialty: String,
        name: String = "",
        hospital: String = "",
        city: String = "",
        state: String = "",
        address: String? = nil,
        type: String = "Academic",
        accreditationID: String? = nil,
        programQuality: ProgramQuality = ProgramQuality(),
        cultureFit: CultureFit = CultureFit(),
        location: Location = Location(),
        logistics: Logistics = Logistics(),
        careerAlignment: CareerAlignment = CareerAlignment(),
        redFlags: RedFlags = RedFlags(),
        questionnaire: Questionnaire = Questionnaire(),
        notes: String = "",
        interviewDate: Date? = nil,
        voiceMemoURL: String? = nil,
        websiteURL: String? = nil,
        contactEmail: String? = nil,
        contactPhone: String? = nil,
        programCoordinator: String? = nil,
        isIMGFriendly: Bool? = nil,
        signalType: SignalType = .none,
        finalScore: Double = 0.0
    ) {
        self.id = id
        self.specialty = specialty
        self.name = name
        self.hospital = hospital
        self.city = city
        self.state = state
        self.address = address
        self.type = type
        self.accreditationID = accreditationID
        self.programQuality = programQuality
        self.cultureFit = cultureFit
        self.location = location
        self.logistics = logistics
        self.careerAlignment = careerAlignment
        self.redFlags = redFlags
        self.questionnaire = questionnaire
        self.notes = notes
        self.interviewDate = interviewDate
        self.voiceMemoURL = voiceMemoURL
        self.websiteURL = websiteURL
        self.contactEmail = contactEmail
        self.contactPhone = contactPhone
        self.programCoordinator = programCoordinator
        self.isIMGFriendly = isIMGFriendly
        self.signalType = signalType
        self.finalScore = finalScore
    }
}

struct ProgramQuality: Codable {
    var reputation: Double = 0
    var caseVolume: Double = 0
    var patientDiversity: Double = 0
    var curriculum: Double = 0
    var research: Double = 0
    var procedures: Double = 0
    var didactics: Double = 0
    
    func average() -> Double {
        let values = [reputation, caseVolume, patientDiversity, curriculum, research, procedures, didactics]
        let nonZeroValues = values.filter { $0 > 0 }
        guard !nonZeroValues.isEmpty else { return 0 }
        return nonZeroValues.reduce(0, +) / Double(nonZeroValues.count)
    }
}

struct CultureFit: Codable {
    var happiness: Double = 0
    var faculty: Double = 0
    var leadership: Double = 0
    var cohesion: Double = 0
    var interviewDay: Double = 0
    var gutFeeling: Double = 0
    
    func average() -> Double {
        let values = [happiness, faculty, leadership, cohesion, interviewDay, gutFeeling]
        let nonZeroValues = values.filter { $0 > 0 }
        guard !nonZeroValues.isEmpty else { return 0 }
        return nonZeroValues.reduce(0, +) / Double(nonZeroValues.count)
    }
}

struct Location: Codable {
    var costOfLiving: Double = 0
    var safety: Double = 0
    var support: Double = 0
    var commute: Double = 0
    var lifestyle: Double = 0
    
    func average() -> Double {
        let values = [costOfLiving, safety, support, commute, lifestyle]
        let nonZeroValues = values.filter { $0 > 0 }
        guard !nonZeroValues.isEmpty else { return 0 }
        return nonZeroValues.reduce(0, +) / Double(nonZeroValues.count)
    }
}

struct Logistics: Codable {
    var salary: Double = 0
    var benefits: Double = 0
    var housing: Double = 0
    var meals: Double = 0
    var vacation: Double = 0
    var moonlighting: Double = 0
    
    func average() -> Double {
        let values = [salary, benefits, housing, meals, vacation, moonlighting]
        let nonZeroValues = values.filter { $0 > 0 }
        guard !nonZeroValues.isEmpty else { return 0 }
        return nonZeroValues.reduce(0, +) / Double(nonZeroValues.count)
    }
}

struct CareerAlignment: Codable {
    var subspecialtyStrength: Double = 0
    var mentorship: Double = 0
    var fellowship: Double = 0
    var researchFit: Double = 0
    
    func average() -> Double {
        let values = [subspecialtyStrength, mentorship, fellowship, researchFit]
        let nonZeroValues = values.filter { $0 > 0 }
        guard !nonZeroValues.isEmpty else { return 0 }
        return nonZeroValues.reduce(0, +) / Double(nonZeroValues.count)
    }
}

struct RedFlags: Codable {
    var burnout: Double = 0
    var boardPass: Double = 0
    var instability: Double = 0
    var negativeExperience: Double = 0
    var complaints: Double = 0
    
    func total() -> Double {
        return burnout + boardPass + instability + negativeExperience + complaints
    }
}

