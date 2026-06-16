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
        "Osteopathic Neuromusculoskeletal Medicine": "ONMM",
        // Common fellowship subspecialty abbreviations (catalog codes)
        "Cardiovascular Disease": "Cards",
        "Gastroenterology": "GI",
        "Pulmonary Disease and Critical Care Medicine": "Pulm/CCM",
        "Pulmonary Disease": "Pulm",
        "Hematology and Medical Oncology": "Hem/Onc",
        "Medical Oncology": "Med Onc",
        "Interventional Cardiology": "IC",
        "Critical Care Medicine": "CCM",
        "Geriatric Medicine": "Geriatrics",
        "Sports Medicine": "Sports Med",
        "Pediatric Emergency Medicine": "PEM",
        "Medical Toxicology": "Tox",
        "Hospice and Palliative Medicine": "HPM",
        "Sleep Medicine": "Sleep",
        "Pain Medicine": "Pain",
        "Addiction Medicine": "Addiction",
        "Epilepsy": "Epilepsy",
        "Vascular Neurology": "Vasc Neuro",
        "Clinical Neurophysiology": "Clin Neurophys",
        "Urogynecology and Reconstructive Pelvic Surgery": "Urogyn",
        "Gynecologic Oncology": "Gyn Onc",
        "Maternal-Fetal Medicine": "MFM",
        "Reproductive Endocrinology and Infertility": "REI",
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
        let displayName = catalogDisplayName(specialty)
        let normalized = normalizedCatalogName(displayName)
        return abbreviations[normalized] ?? abbreviations[displayName] ?? shortLabel(displayName)
    }

    /// Human-readable catalog label without the trailing ACGME code, e.g. `(140)`.
    static func catalogDisplayName(_ specialty: String) -> String {
        var name = specialty.trimmingCharacters(in: .whitespacesAndNewlines)
        if let open = name.lastIndex(of: "("), let close = name.lastIndex(of: ")"), open < close {
            let inner = name[name.index(after: open)..<close].trimmingCharacters(in: .whitespaces)
            if inner.count == 3, inner.allSatisfy(\.isNumber) {
                name = String(name[..<open]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return name
    }

    /// Compact badge label for search rows (avoids huge fellowship strings).
    static func catalogDisplayAbbreviation(for program: ResidencyProgramInfo) -> String {
        let displayName = catalogDisplayName(program.specialty)
        let abbrev = abbreviation(for: displayName)
        if abbrev.count <= 24 {
            return abbrev
        }
        return shortLabel(displayName)
    }

    private static func shortLabel(_ name: String) -> String {
        if name.count <= 24 { return name }
        let words = name.split(separator: " ")
        if words.count > 3 {
            return words.prefix(3).joined(separator: " ") + "…"
        }
        return String(name.prefix(22)) + "…"
    }

    /// Strips parenthetical segments for alias lookup (legacy).
    static func normalizedCatalogName(_ specialty: String) -> String {
        catalogDisplayName(specialty)
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
        let userBase = userSpecialty.trimmingCharacters(in: .whitespacesAndNewlines)

        switch program.trainingLevel {
        case .residency:
            return matchesResidency(userBase: userBase, program: program)
        case .fellowship:
            return matchesFellowship(userBase: userBase, program: program)
        }
    }

    static func matchesAny(userSpecialties: [String], program: ResidencyProgramInfo) -> Bool {
        userSpecialties.contains { matches(userSpecialty: $0, program: program) }
    }

    /// Exact specialty name comparison — avoids false positives like Neurology ⊂ Urology.
    static func namesMatchExact(_ lhs: String, _ rhs: String) -> Bool {
        lhs.trimmingCharacters(in: .whitespacesAndNewlines)
            .caseInsensitiveCompare(rhs.trimmingCharacters(in: .whitespacesAndNewlines)) == .orderedSame
    }

    private static func matchesResidency(userBase: String, program: ResidencyProgramInfo) -> Bool {
        if let programCode = ProgramTrainingLevelClassifier.specialtyCode(for: program) {
            let parentCodes = ACGMSpecialtyHierarchy.residencyCodes(forUserSpecialty: userBase)
            if !parentCodes.isEmpty, parentCodes.contains(programCode) {
                return true
            }
        }

        let programBase = normalizedCatalogName(program.specialty)
        if namesMatchExact(programBase, userBase) {
            return true
        }

        let aliases = catalogAliases[userBase] ?? [userBase]
        return aliases.contains { namesMatchExact(programBase, $0) }
    }

    private static func matchesFellowship(userBase: String, program: ResidencyProgramInfo) -> Bool {
        guard let programCode = ProgramTrainingLevelClassifier.specialtyCode(for: program) else {
            return false
        }

        let eligibleCodes = ACGMSpecialtyHierarchy.fellowshipCodes(forUserSpecialty: userBase)
        if eligibleCodes.contains(programCode) {
            return true
        }

        if ERASTrainingLevel.fellowshipNamesParent(userBase, program: program) {
            return true
        }

        if let parentCode = ACGMSpecialtyHierarchy.parentResidencyCode(for: program) {
            let parentCodes = ACGMSpecialtyHierarchy.residencyCodes(forUserSpecialty: userBase)
            if parentCodes.contains(parentCode) {
                return true
            }
        }

        // Legacy IM fellowship path (covered by hierarchy, kept for safety).
        if userBase == "Internal Medicine", internalMedicineFellowshipCodes.contains(programCode) {
            return true
        }

        return false
    }

    private static func namesMatch(_ lhs: String, _ rhs: String) -> Bool {
        namesMatchExact(lhs, rhs)
    }
}

