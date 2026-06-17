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

struct SignalConfiguration {
    let participates: Bool
    let isTiered: Bool
    let goldLimit: Int
    let silverLimit: Int
    let usesResidencyCAS: Bool
    let requiresSignalStatement: Bool

    static let none = SignalConfiguration(
        participates: false,
        isTiered: false,
        goldLimit: 0,
        silverLimit: 0,
        usesResidencyCAS: false,
        requiresSignalStatement: false
    )
}

struct SignalLimits {
    private enum SignalMode: Equatable {
        case none
        case singleLevel(total: Int)
        case tiered(gold: Int, silver: Int)
    }

    private static let residencyCASSpecialties = [
        "Emergency Medicine",
        "Obstetrics and Gynecology",
        "OB/GYN",
    ]

    private static let signalStatementSpecialties = [
        "Anesthesiology",
        "Plastic Surgery - Integrated",
        "Neurological Surgery",
    ]

    // ERAS 2027 + ResidencyCAS signaling limits (AAMC / ResidencyCAS published tables).
    // Tiered specialties use gold + silver; single-level stores the total in gold with silver = 0.
    private static let erasLimits: [String: SignalMode] = [
        // Tiered (gold + silver)
        "Anesthesiology": .tiered(gold: 5, silver: 10),
        "Child Neurology": .tiered(gold: 3, silver: 6),
        "Dermatology": .tiered(gold: 3, silver: 25),
        "Diagnostic Radiology and Interventional Radiology": .tiered(gold: 6, silver: 9),
        "Internal Medicine": .tiered(gold: 3, silver: 12),
        "Vascular Surgery - Integrated": .tiered(gold: 3, silver: 12),

        // Single-level ERAS specialties
        "Child Neurology & Neurodevelopmental Disabilities": .singleLevel(total: 3),
        "Family Medicine": .singleLevel(total: 5),
        "General Surgery": .singleLevel(total: 15),
        "Internal Medicine/Medical Genetics": .singleLevel(total: 3),
        "Internal Medicine/Pediatrics": .singleLevel(total: 5),
        "Internal Medicine/Psychiatry": .singleLevel(total: 2),
        "Interventional Radiology - Integrated": .singleLevel(total: 8),
        "Neurodevelopmental Disabilities": .singleLevel(total: 2),
        "Neurological Surgery": .singleLevel(total: 25),
        "Neurology": .singleLevel(total: 8),
        "Obstetrics and Gynecology": .singleLevel(total: 5),
        "Orthopedic Surgery": .singleLevel(total: 30),
        "Otolaryngology": .singleLevel(total: 25),
        "Pathology": .singleLevel(total: 5),
        "Pediatric Medical Genetics": .singleLevel(total: 3),
        "Pediatrics": .singleLevel(total: 5),
        "Pediatrics/Psychiatry/Child and Adolescent Psychiatry": .singleLevel(total: 3),
        "Physical Medicine and Rehabilitation": .singleLevel(total: 20),
        "Plastic Surgery - Integrated": .singleLevel(total: 20),
        "Psychiatry": .singleLevel(total: 10),
        "Public Health and General Preventive Medicine": .singleLevel(total: 3),
        "Radiation Oncology": .singleLevel(total: 4),
        "Thoracic Surgery - Integrated": .singleLevel(total: 4),
        "Transitional Year": .singleLevel(total: 12),
        "Urology": .singleLevel(total: 30),

        // ResidencyCAS (not ERAS, but applicants still track preference signals here)
        "Emergency Medicine": .singleLevel(total: 5),

        // ERAS specialties with no program signaling
        "Aerospace Medicine": .none,
        "Occupational and Environmental Medicine": .none,
        "Ophthalmology": .none,
        "Osteopathic Neuromusculoskeletal Medicine": .none,
        "Nuclear Medicine": .none,

        // July-cycle fellowship signaling (ERAS 2027)
        "Allergy/Immunology": .singleLevel(total: 5),
        "Cardiovascular Disease (IM)": .singleLevel(total: 20),
        "Critical Care (IM)": .singleLevel(total: 10),
        "Critical Care (Pediatrics)": .singleLevel(total: 3),
        "Consultation - Liaison Psychiatry": .singleLevel(total: 3),
        "Endocrinology (IM)": .singleLevel(total: 5),
        "Gastroenterology (IM)": .tiered(gold: 5, silver: 10),
        "Gastroenterology (Pediatrics)": .singleLevel(total: 3),
        "Hematology & Medical Oncology (IM)": .tiered(gold: 5, silver: 15),
        "Hospice & Palliative Care (Multi)": .singleLevel(total: 5),
        "Neonatal-Perinatal Medicine (Pediatrics)": .tiered(gold: 3, silver: 5),
        "Pediatric Cardiology": .tiered(gold: 3, silver: 5),
        "Pulmonary Disease & Critical Care (IM)": .singleLevel(total: 15),
        "Pulmonary (IM)": .singleLevel(total: 2),
        "Rheumatology (IM)": .singleLevel(total: 7),
        "Sleep Medicine": .singleLevel(total: 4),
        "Sports Medicine": .singleLevel(total: 3),
    ]

    // Maps catalog / UI / legacy labels to the canonical keys in `erasLimits`.
    private static let specialtyAliases: [String: String] = [
        "IM": "Internal Medicine",
        "Anesthesia": "Anesthesiology",
        "Radiology": "Diagnostic Radiology and Interventional Radiology",
        "Diagnostic Radiology": "Diagnostic Radiology and Interventional Radiology",
        "Radiology-Diagnostic": "Diagnostic Radiology and Interventional Radiology",
        "Diagnostic Radiology/Nuclear Medicine": "Diagnostic Radiology and Interventional Radiology",
        "Surgery": "General Surgery",
        "OB/GYN": "Obstetrics and Gynecology",
        "Internal Medicine & Psychiatry": "Internal Medicine/Psychiatry",
        "Neurosurgery": "Neurological Surgery",
        "Orthopedics": "Orthopedic Surgery",
        "Orthopaedic Surgery": "Orthopedic Surgery",
        "Orthopedic Surgery": "Orthopedic Surgery",
        "ENT": "Otolaryngology",
        "Otolaryngology - Head and Neck Surgery": "Otolaryngology",
        "Pathology-Anatomic and Clinical": "Pathology",
        "PM&R": "Physical Medicine and Rehabilitation",
        "Plastic Surgery": "Plastic Surgery - Integrated",
        "Plastic Surgery-Integrated": "Plastic Surgery - Integrated",
        "Interventional Radiology": "Interventional Radiology - Integrated",
        "Interventional Radiology-Integrated": "Interventional Radiology - Integrated",
        "Thoracic Surgery": "Thoracic Surgery - Integrated",
        "Thoracic Surgery-Integrated": "Thoracic Surgery - Integrated",
        "Vascular Surgery-Integrated": "Vascular Surgery - Integrated",

        // Fellowship catalog / shorthand aliases
        "Allergy and Immunology": "Allergy/Immunology",
        "Cardiovascular Disease": "Cardiovascular Disease (IM)",
        "Cardiovascular Disease (Internal Medicine)": "Cardiovascular Disease (IM)",
        "Critical Care Medicine (Internal Medicine)": "Critical Care (IM)",
        "Pediatric Critical Care Medicine (Pediatrics)": "Critical Care (Pediatrics)",
        "Consultation-Liaison Psychiatry": "Consultation - Liaison Psychiatry",
        "Endocrinology, Diabetes, and Metabolism (Internal Medicine)": "Endocrinology (IM)",
        "Endocrinology": "Endocrinology (IM)",
        "Gastroenterology": "Gastroenterology (IM)",
        "Gastroenterology (Internal Medicine)": "Gastroenterology (IM)",
        "Pediatric Gastroenterology (Pediatrics)": "Gastroenterology (Pediatrics)",
        "Pediatric Gastroenterology": "Gastroenterology (Pediatrics)",
        "Hematology and Medical Oncology (Internal Medicine)": "Hematology & Medical Oncology (IM)",
        "Hematology and Medical Oncology": "Hematology & Medical Oncology (IM)",
        "Hematology (Internal Medicine)": "Hematology & Medical Oncology (IM)",
        "Hematology": "Hematology & Medical Oncology (IM)",
        "Medical Oncology (Internal Medicine)": "Hematology & Medical Oncology (IM)",
        "Medical Oncology": "Hematology & Medical Oncology (IM)",
        "Hospice and Palliative Medicine (Multidisciplinary)": "Hospice & Palliative Care (Multi)",
        "Hospice and Palliative Medicine": "Hospice & Palliative Care (Multi)",
        "Hospice and Palliative Care": "Hospice & Palliative Care (Multi)",
        "Neonatal-Perinatal Medicine (Pediatrics)": "Neonatal-Perinatal Medicine (Pediatrics)",
        "Pediatric Cardiology (Pediatrics)": "Pediatric Cardiology",
        "Pulmonary Disease and Critical Care Medicine (Internal Medicine)": "Pulmonary Disease & Critical Care (IM)",
        "Pulmonary Disease and Critical Care Medicine": "Pulmonary Disease & Critical Care (IM)",
        "Pulmonary Disease (Internal Medicine)": "Pulmonary (IM)",
        "Pulmonary Disease": "Pulmonary (IM)",
        "Rheumatology (Internal Medicine)": "Rheumatology (IM)",
        "Rheumatology": "Rheumatology (IM)",
        "Sleep Medicine (Multidisciplinary)": "Sleep Medicine",
    ]

    // ACGME specialty code (first 3 digits) → canonical fellowship signal bucket.
    private static let fellowshipCodeAliases: [String: String] = [
        "020": "Allergy/Immunology",
        "141": "Cardiovascular Disease (IM)",
        "142": "Critical Care (IM)",
        "323": "Critical Care (Pediatrics)",
        "409": "Consultation - Liaison Psychiatry",
        "143": "Endocrinology (IM)",
        "144": "Gastroenterology (IM)",
        "332": "Gastroenterology (Pediatrics)",
        "155": "Hematology & Medical Oncology (IM)",
        "145": "Hematology & Medical Oncology (IM)",
        "147": "Hematology & Medical Oncology (IM)",
        "540": "Hospice & Palliative Care (Multi)",
        "329": "Neonatal-Perinatal Medicine (Pediatrics)",
        "325": "Pediatric Cardiology",
        "156": "Pulmonary Disease & Critical Care (IM)",
        "149": "Pulmonary (IM)",
        "150": "Rheumatology (IM)",
        "520": "Sleep Medicine",
        "116": "Sports Medicine",
    ]

    static func configuration(for specialty: String, accreditationID: String? = nil) -> SignalConfiguration {
        let bucket = resolveCanonicalKey(for: specialty, accreditationID: accreditationID)
        switch mode(for: specialty, accreditationID: accreditationID) {
        case .none:
            return .none
        case .singleLevel(let total):
            return SignalConfiguration(
                participates: true,
                isTiered: false,
                goldLimit: total,
                silverLimit: 0,
                usesResidencyCAS: usesResidencyCAS(bucket: bucket),
                requiresSignalStatement: requiresSignalStatement(bucket: bucket, specialty: specialty)
            )
        case .tiered(let gold, let silver):
            return SignalConfiguration(
                participates: true,
                isTiered: true,
                goldLimit: gold,
                silverLimit: silver,
                usesResidencyCAS: usesResidencyCAS(bucket: bucket),
                requiresSignalStatement: requiresSignalStatement(bucket: bucket, specialty: specialty)
            )
        }
    }

    /// Canonical bucket for counting signals across catalog-name variants.
    static func signalBucket(for specialty: String, accreditationID: String? = nil) -> String {
        resolveCanonicalKey(for: specialty, accreditationID: accreditationID)
            ?? SpecialtyFormatter.normalizedUserSpecialty(specialty)
    }

    static func participatesInSignaling(for specialty: String, accreditationID: String? = nil) -> Bool {
        configuration(for: specialty, accreditationID: accreditationID).participates
    }

    static func limits(for specialty: String, accreditationID: String? = nil) -> (gold: Int, silver: Int) {
        let config = configuration(for: specialty, accreditationID: accreditationID)
        return (gold: config.goldLimit, silver: config.silverLimit)
    }

    static func goldLimit(for specialty: String, accreditationID: String? = nil) -> Int {
        limits(for: specialty, accreditationID: accreditationID).gold
    }

    static func silverLimit(for specialty: String, accreditationID: String? = nil) -> Int {
        limits(for: specialty, accreditationID: accreditationID).silver
    }

    static func totalLimit(for specialty: String, accreditationID: String? = nil) -> Int {
        let limits = limits(for: specialty, accreditationID: accreditationID)
        return limits.gold + limits.silver
    }

    static func isTiered(for specialty: String, accreditationID: String? = nil) -> Bool {
        configuration(for: specialty, accreditationID: accreditationID).isTiered
    }

    static func singleLevelLimit(for specialty: String, accreditationID: String? = nil) -> Int {
        configuration(for: specialty, accreditationID: accreditationID).goldLimit
    }

    private static func mode(for specialty: String, accreditationID: String? = nil) -> SignalMode {
        guard let key = resolveCanonicalKey(for: specialty, accreditationID: accreditationID) else {
            return .none
        }
        return erasLimits[key] ?? .none
    }

    private static func usesResidencyCAS(bucket: String?) -> Bool {
        guard let bucket else { return false }
        return residencyCASSpecialties.contains(where: { namesMatch($0, bucket) })
    }

    private static func requiresSignalStatement(bucket: String?, specialty: String) -> Bool {
        if let bucket, signalStatementSpecialties.contains(where: { namesMatch($0, bucket) }) { return true }
        let normalized = SpecialtyFormatter.normalizedUserSpecialty(specialty)
        return signalStatementSpecialties.contains(where: { namesMatch($0, normalized) })
    }

    private static func namesMatch(_ lhs: String, _ rhs: String) -> Bool {
        lhs.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            == rhs.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }

    private static func resolveCanonicalKey(for specialty: String, accreditationID: String?) -> String? {
        let normalized = SpecialtyFormatter.normalizedUserSpecialty(specialty)
        guard !normalized.isEmpty else { return nil }

        if erasLimits[normalized] != nil {
            return normalized
        }

        if let code = acgmeSpecialtyCode(from: accreditationID),
           let canonical = fellowshipCodeAliases[code],
           erasLimits[canonical] != nil {
            return canonical
        }

        if let canonical = specialtyAliases[normalized],
           erasLimits[canonical] != nil {
            return canonical
        }

        let folded = normalized.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        if let (key, _) = erasLimits.first(where: {
            $0.key.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current) == folded
        }) {
            return key
        }
        if let (alias, canonical) = specialtyAliases.first(where: {
            $0.key.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current) == folded
        }), erasLimits[canonical] != nil {
            return canonical
        }

        return nil
    }

    private static func acgmeSpecialtyCode(from accreditationID: String?) -> String? {
        guard let accreditationID else { return nil }
        let trimmed = accreditationID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 3 else { return nil }
        return String(trimmed.prefix(3))
    }
}
