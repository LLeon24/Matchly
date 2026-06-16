//
//  ProgramIdentity.swift
//  Matchly
//

import Foundation

enum ProgramIdentity {
    /// Returns true when two saved programs represent the same residency/fellowship listing.
    static func isSameProgram(_ lhs: Program, _ rhs: Program) -> Bool {
        if let match = matchOnAccreditationID(lhs.accreditationID, rhs.accreditationID) {
            return match
        }
        return normalizedSpecialty(lhs.specialty) == normalizedSpecialty(rhs.specialty)
            && normalizedHospital(lhs.hospital) == normalizedHospital(rhs.hospital)
            && normalizedLocation(lhs.city) == normalizedLocation(rhs.city)
            && normalizedLocation(lhs.state) == normalizedLocation(rhs.state)
    }

    static func isSameProgram(_ saved: Program, catalog: ResidencyProgramInfo) -> Bool {
        if let match = matchOnAccreditationID(saved.accreditationID, catalog.accreditationID) {
            return match
        }
        let mapped = CatalogProgramMapper.toSavedProgram(catalog)
        return isSameProgram(saved, mapped)
    }

    static func isDuplicate(_ candidate: Program, in programs: [Program]) -> Bool {
        programs.contains { isSameProgram($0, candidate) }
    }

    // MARK: - Private

    private static func matchOnAccreditationID(_ lhs: String?, _ rhs: String?) -> Bool? {
        guard let left = normalizedAccreditationID(lhs), let right = normalizedAccreditationID(rhs) else {
            return nil
        }
        return left == right
    }

    private static func normalizedAccreditationID(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    private static func normalizedSpecialty(_ specialty: String) -> String {
        SpecialtyFormatter.normalizedUserSpecialty(specialty)
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func normalizedHospital(_ hospital: String) -> String {
        var normalized = hospital.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.hasSuffix(" program") {
            normalized = String(normalized.dropLast(8)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        normalized = normalized.replacingOccurrences(
            of: #"\s+"#,
            with: " ",
            options: .regularExpression
        )
        return normalized
    }

    private static func normalizedLocation(_ value: String) -> String {
        value.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
