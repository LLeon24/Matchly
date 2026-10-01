//
//  ProgramListLabel.swift
//  Matchly
//

import Foundation

enum ProgramListLabel {
    /// Primary title for My Programs rows (program name when set, otherwise hospital).
    static func primaryTitle(for program: Program) -> String {
        let name = program.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty {
            return name
        }
        let hospital = program.hospital.trimmingCharacters(in: .whitespacesAndNewlines)
        if hospital.isEmpty {
            return "Unnamed Program"
        }
        return HospitalNameFormatter.format(hospital)
    }

    /// Institution line when it adds information beyond the primary title (e.g. manual entry).
    static func secondarySubtitle(for program: Program) -> String? {
        let name = program.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let hospital = program.hospital.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !hospital.isEmpty else { return nil }

        let formattedHospital = HospitalNameFormatter.format(hospital)
        guard !titlesAreEquivalent(name, formattedHospital) else { return nil }
        return formattedHospital
    }

    static func nameSortKey(for program: Program) -> String {
        primaryTitle(for: program).lowercased()
    }

    private static func titlesAreEquivalent(_ lhs: String, _ rhs: String) -> Bool {
        normalize(lhs) == normalize(rhs)
    }

    private static func normalize(_ value: String) -> String {
        value
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
    }
}
