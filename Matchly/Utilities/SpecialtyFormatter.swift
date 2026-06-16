//
//  SpecialtyFormatter.swift
//  Matchly
//
//  Created on 11/14/25.
//

import SwiftUI

struct SpecialtyFormatter {
    /// The list of selectable specialties shown during onboarding and specialty selection.
    /// Single source of truth (previously duplicated across multiple views).
    static let commonSpecialties: [String] = [
        "Internal Medicine", "Family Medicine", "Emergency Medicine", "Pediatrics",
        "General Surgery", "OB/GYN", "Psychiatry", "Neurology", "Anesthesiology",
        "Radiology", "Pathology", "Orthopedics", "ENT", "Urology", "PM&R",
        "Dermatology", "Neurosurgery", "Child Neurology", "Nuclear Medicine",
        "Radiation Oncology", "Plastic Surgery", "Ophthalmology", "Interventional Radiology - Integrated",
        "Thoracic Surgery - Integrated", "Vascular Surgery - Integrated", "Transitional Year",
        "Aerospace Medicine", "Occupational and Environmental Medicine",
        "Public Health and General Preventive Medicine", "Osteopathic Neuromusculoskeletal Medicine"
    ]
    
    // Specialty abbreviations
    static let abbreviations: [String: String] = [
        "Internal Medicine": "IM",
        "Family Medicine": "FM",
        "Emergency Medicine": "EM",
        "Pediatrics": "Peds",
        "General Surgery": "GS",
        "OB/GYN": "OB/GYN",
        "Obstetrics and Gynecology": "OB/GYN",
        "Psychiatry": "Psych",
        "Neurology": "Neuro",
        "Anesthesiology": "Anes",
        "Radiology": "Rad",
        "Diagnostic Radiology": "Rad",
        "Radiology-Diagnostic": "Rad",
        "Pathology": "Path",
        "Orthopedics": "Ortho",
        "Orthopaedic Surgery": "Ortho",
        "ENT": "ENT",
        "Otolaryngology": "ENT",
        "Otolaryngology - Head and Neck Surgery": "ENT",
        "Urology": "Uro",
        "PM&R": "PM&R",
        "Physical Medicine and Rehabilitation": "PM&R",
        "Dermatology": "Derm",
        "Neurosurgery": "NS",
        "Neurological Surgery": "NS",
        "Child Neurology": "Child Neuro",
        "Nuclear Medicine": "Nuc Med",
        "Radiation Oncology": "Rad Onc",
        "Plastic Surgery": "Plastics",
        "Ophthalmology": "Ophth",
        "Interventional Radiology - Integrated": "IR",
        "Thoracic Surgery - Integrated": "CT Surg",
        "Vascular Surgery - Integrated": "Vasc Surg",
        "Transitional Year": "TY",
        "Aerospace Medicine": "Aero Med",
        "Occupational and Environmental Medicine": "Occ Med",
        "Public Health and General Preventive Medicine": "PHPM",
        "Osteopathic Neuromusculoskeletal Medicine": "ONMM"
    ]
    
    // Specialty colors - distinct colors for visual differentiation
    static let colors: [String: Color] = [
        "Internal Medicine": .blue,
        "Family Medicine": .green,
        "Emergency Medicine": .red,
        "Pediatrics": .pink,
        "General Surgery": .purple,
        "OB/GYN": .orange,
        "Obstetrics and Gynecology": .orange,
        "Psychiatry": .indigo,
        "Neurology": .teal,
        "Anesthesiology": .cyan,
        "Radiology": .mint,
        "Diagnostic Radiology": .mint,
        "Radiology-Diagnostic": .mint,
        "Pathology": .brown,
        "Orthopedics": .yellow,
        "Orthopaedic Surgery": .yellow,
        "ENT": .purple,
        "Otolaryngology": .purple,
        "Otolaryngology - Head and Neck Surgery": .purple,
        "Urology": .blue,
        "PM&R": .green,
        "Physical Medicine and Rehabilitation": .green,
        "Dermatology": .pink,
        "Neurosurgery": .indigo,
        "Neurological Surgery": .indigo,
        "Child Neurology": .teal,
        "Nuclear Medicine": .cyan,
        "Radiation Oncology": .orange,
        "Plastic Surgery": .pink,
        "Ophthalmology": .cyan,
        "Interventional Radiology - Integrated": .mint,
        "Thoracic Surgery - Integrated": .red,
        "Vascular Surgery - Integrated": .red,
        "Transitional Year": .gray,
        "Aerospace Medicine": .blue,
        "Occupational and Environmental Medicine": .green,
        "Public Health and General Preventive Medicine": .teal,
        "Osteopathic Neuromusculoskeletal Medicine": .brown
    ]
    
    static func abbreviation(for specialty: String) -> String {
        let normalized = normalizedCatalogName(specialty)
        return abbreviations[normalized] ?? abbreviations[specialty] ?? normalized
    }
    
    static func color(for specialty: String) -> Color {
        let normalized = normalizedCatalogName(specialty)
        return colors[normalized] ?? colors[specialty] ?? .purple
    }
    
    static func displayNameWithAbbreviation(_ specialty: String) -> String {
        let abbrev = abbreviation(for: specialty)
        if abbrev == specialty {
            return specialty
        }
        return "\(specialty) (\(abbrev))"
    }

    /// Strips ACGME catalog suffixes like `" (140)"` from specialty labels.
    static func normalizedCatalogName(_ specialty: String) -> String {
        var name = specialty.trimmingCharacters(in: .whitespacesAndNewlines)
        if let openParen = name.lastIndex(of: "(") {
            name = String(name[..<openParen]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return name
    }

    /// Maps onboarding / UI specialty labels to ACGME catalog base names.
    private static let catalogAliases: [String: [String]] = [
        "Internal Medicine": ["Internal Medicine"],
        "Family Medicine": ["Family Medicine"],
        "Emergency Medicine": ["Emergency Medicine"],
        "Pediatrics": ["Pediatrics"],
        "General Surgery": ["Surgery", "General Surgery"],
        "OB/GYN": ["Obstetrics and Gynecology", "OB/GYN"],
        "Psychiatry": ["Psychiatry"],
        "Neurology": ["Neurology"],
        "Anesthesiology": ["Anesthesiology"],
        "Radiology": ["Radiology-Diagnostic", "Diagnostic Radiology", "Radiology", "Diagnostic Radiology/Nuclear Medicine"],
        "Pathology": ["Pathology-Anatomic and Clinical", "Pathology"],
        "Orthopedics": ["Orthopaedic Surgery", "Orthopedics"],
        "ENT": ["Otolaryngology - Head and Neck Surgery", "Otolaryngology", "ENT"],
        "Urology": ["Urology"],
        "PM&R": ["Physical Medicine and Rehabilitation", "PM&R"],
        "Dermatology": ["Dermatology"],
        "Neurosurgery": ["Neurological Surgery", "Neurosurgery"],
        "Child Neurology": ["Child Neurology"],
        "Nuclear Medicine": ["Nuclear Medicine"],
        "Radiation Oncology": ["Radiation Oncology"],
        "Plastic Surgery": ["Plastic Surgery-Integrated", "Plastic Surgery", "Plastic Surgery - Integrated"],
        "Ophthalmology": ["Ophthalmology"],
        "Interventional Radiology - Integrated": ["Interventional Radiology - Integrated", "Interventional Radiology-Integrated"],
        "Thoracic Surgery - Integrated": ["Thoracic Surgery - Integrated", "Thoracic Surgery-Integrated"],
        "Vascular Surgery - Integrated": ["Vascular Surgery - Integrated", "Vascular Surgery-Integrated"],
        "Transitional Year": ["Transitional Year"],
        "Aerospace Medicine": ["Aerospace Medicine"],
        "Occupational and Environmental Medicine": ["Occupational and Environmental Medicine"],
        "Public Health and General Preventive Medicine": ["Public Health and General Preventive Medicine"],
        "Osteopathic Neuromusculoskeletal Medicine": ["Osteopathic Neuromusculoskeletal Medicine"],
    ]

    /// IM subspecialty fellowship codes (parent specialty for fellowship applicants).
    private static let internalMedicineFellowshipCodes: Set<String> = [
        "141", "142", "143", "144", "145", "146", "147", "148", "149", "150", "151", "152", "153", "154", "155", "156", "157", "158", "159",
    ]

    static func matches(userSpecialty: String, program: ResidencyProgramInfo) -> Bool {
        let programBase = normalizedCatalogName(program.specialty)
        let userBase = userSpecialty.trimmingCharacters(in: .whitespacesAndNewlines)

        if namesMatch(programBase, userBase) {
            return program.trainingLevel == .residency
        }

        let aliases = catalogAliases[userBase] ?? [userBase]
        for alias in aliases {
            if namesMatch(programBase, alias) {
                return program.trainingLevel == .residency
            }
        }

        // Fellowship applicants choosing a parent specialty (e.g. IM → cardiology fellowships).
        if userBase == "Internal Medicine",
           let code = ProgramTrainingLevelClassifier.specialtyCode(for: program),
           internalMedicineFellowshipCodes.contains(code) {
            return true
        }

        return false
    }

    static func matchesAny(userSpecialties: [String], program: ResidencyProgramInfo) -> Bool {
        userSpecialties.contains { matches(userSpecialty: $0, program: program) }
    }

    private static func namesMatch(_ lhs: String, _ rhs: String) -> Bool {
        lhs.caseInsensitiveCompare(rhs) == .orderedSame
            || lhs.localizedCaseInsensitiveContains(rhs)
            || rhs.localizedCaseInsensitiveContains(lhs)
    }
}

