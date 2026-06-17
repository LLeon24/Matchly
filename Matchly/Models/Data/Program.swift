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
    var programDirector: String?
    
    // IMG-friendly status
    var isIMGFriendly: Bool?
    
    // Electronic Medical Record (EMR) the hospital uses.
    // Optional for backward compatibility with programs saved before EMR existed.
    // Stores an `EMRSystem.rawValue` String (nil = not selected).
    var emr: String?
    
    // ERAS Signaling
    var signalType: SignalType = .none
    /// Optional ERAS / ResidencyCAS signal statement text (e.g. Anesthesiology).
    var signalNote: String?
    
    var finalScore: Double
    
    // Check if program has been reviewed (has any questionnaire ratings)
    func hasBeenReviewed() -> Bool {
        return isReviewed
    }
    
    // Pre-calculated review status for sorting optimization (avoids repeated calculations)
    var isReviewed: Bool {
        return questionnaire.sections.contains { section in
            section.items.contains { $0.programRating > 0 && $0.programRating < 6 }
        } || questionnaire.customSections.contains { section in
            section.items.contains { $0.programRating > 0 && $0.programRating < 6 }
        }
    }
    
    // Pre-calculated interview status for sorting optimization
    var isInterviewed: Bool {
        return interviewDate != nil
    }
    
    // Check if program has any red flags (Yes answers in red flags section)
    func hasRedFlags() -> Bool {
        // Questions where "Yes" is positive (not a red flag) - should be inverted in red flag detection
        let positiveYesNoQuestions = [
            "Do you feel you could see yourself living"
        ]
        
        // Check standard sections
        for section in questionnaire.sections {
            if section.title.contains("Red flags") || section.title.lowercased().contains("red flag") {
                for item in section.items {
                    // Check if this is a positive question (where "Yes" is good, not a red flag)
                    let isPositiveQuestion = positiveYesNoQuestions.contains { item.question.contains($0) }
                    
                    if isPositiveQuestion {
                        // For positive questions: rating == 1 (Yes) is GOOD, rating == 2 (No) is a red flag
                        // rating == 0 means unrated, so we only check for "No" (rating == 2)
                        if item.programRating == 2 {
                            return true
                        }
                    } else {
                        // For standard red flag questions: rating == 1 (Yes) means red flag
                        // rating == 0 means unrated, so we only check for "Yes" (rating == 1)
                        if item.programRating == 1 {
                            return true
                        }
                    }
                }
            }
        }
        
        // Check custom sections
        for section in questionnaire.customSections {
            if section.title.contains("Red flags") || section.title.lowercased().contains("red flag") {
                for item in section.items {
                    // Check if this is a positive question (where "Yes" is good, not a red flag)
                    let isPositiveQuestion = positiveYesNoQuestions.contains { item.question.contains($0) }
                    
                    if isPositiveQuestion {
                        // For positive questions: rating == 1 (Yes) is GOOD, rating == 2 (No) is a red flag
                        // rating == 0 means unrated, so we only check for "No" (rating == 2)
                        if item.programRating == 2 {
                            return true
                        }
                    } else {
                        // For standard red flag questions: rating == 1 (Yes) means red flag
                        // rating == 0 means unrated, so we only check for "Yes" (rating == 1)
                        if item.programRating == 1 {
                            return true
                        }
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
        programDirector: String? = nil,
        isIMGFriendly: Bool? = nil,
        emr: String? = nil,
        signalType: SignalType = .none,
        signalNote: String? = nil,
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
        self.programDirector = programDirector
        self.isIMGFriendly = isIMGFriendly
        self.emr = emr
        self.signalType = signalType
        self.signalNote = signalNote
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

// MARK: - Resilient decoding
//
// Persisted models are stored in UserDefaults/iCloud as JSON. The synthesized
// `init(from:)` throws `keyNotFound` when a key is absent, which would happen
// whenever an app update introduces a new (even defaulted) property. That would
// cause `DataManager` to fail decoding old data and silently wipe the user's
// saved programs/preferences. To prevent that, every persisted type provides an
// explicit `init(from:)` that uses `decodeIfPresent(_:forKey:) ?? <default>` so
// a missing key falls back to the exact same default used by the memberwise
// initializer and decoding NEVER throws.
//
// These initializers live in extensions so the compiler-synthesized memberwise
// initializers (e.g. `ProgramQuality()`) and `encode(to:)` remain intact. The
// synthesized `CodingKeys` is used unchanged, so encoding output is unchanged.

extension Program {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        self.specialty = try container.decodeIfPresent(String.self, forKey: .specialty) ?? ""
        self.name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        self.hospital = try container.decodeIfPresent(String.self, forKey: .hospital) ?? ""
        self.city = try container.decodeIfPresent(String.self, forKey: .city) ?? ""
        self.state = try container.decodeIfPresent(String.self, forKey: .state) ?? ""
        self.address = try container.decodeIfPresent(String.self, forKey: .address)
        self.type = try container.decodeIfPresent(String.self, forKey: .type) ?? "Academic"
        self.accreditationID = try container.decodeIfPresent(String.self, forKey: .accreditationID)
        self.programQuality = try container.decodeIfPresent(ProgramQuality.self, forKey: .programQuality) ?? ProgramQuality()
        self.cultureFit = try container.decodeIfPresent(CultureFit.self, forKey: .cultureFit) ?? CultureFit()
        self.location = try container.decodeIfPresent(Location.self, forKey: .location) ?? Location()
        self.logistics = try container.decodeIfPresent(Logistics.self, forKey: .logistics) ?? Logistics()
        self.careerAlignment = try container.decodeIfPresent(CareerAlignment.self, forKey: .careerAlignment) ?? CareerAlignment()
        self.redFlags = try container.decodeIfPresent(RedFlags.self, forKey: .redFlags) ?? RedFlags()
        self.questionnaire = try container.decodeIfPresent(Questionnaire.self, forKey: .questionnaire) ?? Questionnaire()
        self.notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        self.interviewDate = try container.decodeIfPresent(Date.self, forKey: .interviewDate)
        self.voiceMemoURL = try container.decodeIfPresent(String.self, forKey: .voiceMemoURL)
        self.websiteURL = try container.decodeIfPresent(String.self, forKey: .websiteURL)
        self.contactEmail = try container.decodeIfPresent(String.self, forKey: .contactEmail)
        self.contactPhone = try container.decodeIfPresent(String.self, forKey: .contactPhone)
        self.programCoordinator = try container.decodeIfPresent(String.self, forKey: .programCoordinator)
        self.programDirector = try container.decodeIfPresent(String.self, forKey: .programDirector)
        self.isIMGFriendly = try container.decodeIfPresent(Bool.self, forKey: .isIMGFriendly)
        self.emr = try container.decodeIfPresent(String.self, forKey: .emr)
        self.signalType = try container.decodeIfPresent(SignalType.self, forKey: .signalType) ?? .none
        self.signalNote = try container.decodeIfPresent(String.self, forKey: .signalNote)
        self.finalScore = try container.decodeIfPresent(Double.self, forKey: .finalScore) ?? 0.0
    }
}

extension ProgramQuality {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.reputation = try container.decodeIfPresent(Double.self, forKey: .reputation) ?? 0
        self.caseVolume = try container.decodeIfPresent(Double.self, forKey: .caseVolume) ?? 0
        self.patientDiversity = try container.decodeIfPresent(Double.self, forKey: .patientDiversity) ?? 0
        self.curriculum = try container.decodeIfPresent(Double.self, forKey: .curriculum) ?? 0
        self.research = try container.decodeIfPresent(Double.self, forKey: .research) ?? 0
        self.procedures = try container.decodeIfPresent(Double.self, forKey: .procedures) ?? 0
        self.didactics = try container.decodeIfPresent(Double.self, forKey: .didactics) ?? 0
    }
}

extension CultureFit {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.happiness = try container.decodeIfPresent(Double.self, forKey: .happiness) ?? 0
        self.faculty = try container.decodeIfPresent(Double.self, forKey: .faculty) ?? 0
        self.leadership = try container.decodeIfPresent(Double.self, forKey: .leadership) ?? 0
        self.cohesion = try container.decodeIfPresent(Double.self, forKey: .cohesion) ?? 0
        self.interviewDay = try container.decodeIfPresent(Double.self, forKey: .interviewDay) ?? 0
        self.gutFeeling = try container.decodeIfPresent(Double.self, forKey: .gutFeeling) ?? 0
    }
}

extension Location {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.costOfLiving = try container.decodeIfPresent(Double.self, forKey: .costOfLiving) ?? 0
        self.safety = try container.decodeIfPresent(Double.self, forKey: .safety) ?? 0
        self.support = try container.decodeIfPresent(Double.self, forKey: .support) ?? 0
        self.commute = try container.decodeIfPresent(Double.self, forKey: .commute) ?? 0
        self.lifestyle = try container.decodeIfPresent(Double.self, forKey: .lifestyle) ?? 0
    }
}

extension Logistics {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.salary = try container.decodeIfPresent(Double.self, forKey: .salary) ?? 0
        self.benefits = try container.decodeIfPresent(Double.self, forKey: .benefits) ?? 0
        self.housing = try container.decodeIfPresent(Double.self, forKey: .housing) ?? 0
        self.meals = try container.decodeIfPresent(Double.self, forKey: .meals) ?? 0
        self.vacation = try container.decodeIfPresent(Double.self, forKey: .vacation) ?? 0
        self.moonlighting = try container.decodeIfPresent(Double.self, forKey: .moonlighting) ?? 0
    }
}

extension CareerAlignment {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.subspecialtyStrength = try container.decodeIfPresent(Double.self, forKey: .subspecialtyStrength) ?? 0
        self.mentorship = try container.decodeIfPresent(Double.self, forKey: .mentorship) ?? 0
        self.fellowship = try container.decodeIfPresent(Double.self, forKey: .fellowship) ?? 0
        self.researchFit = try container.decodeIfPresent(Double.self, forKey: .researchFit) ?? 0
    }
}

extension RedFlags {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.burnout = try container.decodeIfPresent(Double.self, forKey: .burnout) ?? 0
        self.boardPass = try container.decodeIfPresent(Double.self, forKey: .boardPass) ?? 0
        self.instability = try container.decodeIfPresent(Double.self, forKey: .instability) ?? 0
        self.negativeExperience = try container.decodeIfPresent(Double.self, forKey: .negativeExperience) ?? 0
        self.complaints = try container.decodeIfPresent(Double.self, forKey: .complaints) ?? 0
    }
}

