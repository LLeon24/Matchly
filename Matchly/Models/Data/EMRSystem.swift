//
//  EMRSystem.swift
//  Matchly
//
//  Electronic Medical Record (EMR) systems used by residency programs,
//  plus the helper that converts an EMR match into a weighted-score rating.
//

import Foundation

/// Curated list of common hospital EMR (electronic medical record) systems,
/// plus ambiguous "Other" / "Not sure" choices.
///
/// Stored on `Program.emr` and `UserPreferences.preferredEMR` as the `rawValue`
/// String (not the enum) so that unknown/legacy values never break Codable
/// decoding of persisted data.
enum EMRSystem: String, CaseIterable, Identifiable, Codable {
    case epic = "Epic"
    case oracleCerner = "Oracle Health (Cerner)"
    case meditech = "MEDITECH"
    case veradigmAllscripts = "Veradigm (Allscripts)"
    case athenahealth = "athenahealth"
    case eClinicalWorks = "eClinicalWorks"
    case nextGen = "NextGen Healthcare"
    case cpsiEvident = "CPSI/Evident"
    case other = "Other"
    case notSure = "Not sure"

    var id: String { rawValue }

    var displayName: String { rawValue }

    /// `true` for a concrete, named EMR product. `false` for the ambiguous
    /// "Other" / "Not sure" choices, which cannot be objectively matched.
    var isSpecific: Bool {
        switch self {
        case .other, .notSure:
            return false
        default:
            return true
        }
    }
}

/// Converts a program's EMR + the applicant's preferred EMR into the same
/// 1–5 rating scale the rest of the questionnaire uses, so EMR can flow
/// through the existing weighted-section scoring mechanism.
enum EMRScoring {
    /// Stable key used both as the row title in the weights UI and as the
    /// key into `UserPreferences.sectionWeights`. Mirrors how standard
    /// questionnaire sections key their weight by their (stable) title.
    static let weightKey = "Electronic Medical Record (EMR)"

    /// Rating when the program's EMR matches the applicant's preferred EMR.
    static let matchRating: Double = 5

    /// Rating when the program uses a different (but known) EMR.
    static let mismatchRating: Double = 2

    /// Objective 1–5 rating for how well a program's EMR matches the
    /// applicant's preferred EMR.
    ///
    /// Returns `nil` (i.e. "do not score") when EMR cannot be objectively
    /// evaluated: no preferred EMR set, the program's EMR is unknown, or
    /// either side is the ambiguous "Other" / "Not sure" choice. A `nil`
    /// result is treated exactly like an unrated section and simply drops
    /// out of the weighted average.
    static func rating(programEMR: String?, preferredEMR: String?) -> Double? {
        guard let preferredRaw = preferredEMR,
              let preferred = EMRSystem(rawValue: preferredRaw),
              preferred.isSpecific else {
            return nil
        }

        guard let programRaw = programEMR,
              let program = EMRSystem(rawValue: programRaw),
              program.isSpecific else {
            return nil
        }

        return program == preferred ? matchRating : mismatchRating
    }
}
