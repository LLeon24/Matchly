//
//  ProgramIdentity.swift
//  Matchly
//

import Foundation

enum ProgramIdentity {
    /// Returns true when two saved programs represent the same residency/fellowship listing.
    static func isSameProgram(_ lhs: Program, _ rhs: Program) -> Bool {
        guard specialtiesMatch(lhs, rhs) else { return false }

        switch resolvedAccreditationMatch(lhs.accreditationID, rhs.accreditationID) {
        case .match:
            return true
        case .mismatch:
            return false
        case .unknown:
            return hospitalsAndLocationsMatch(lhs, rhs)
        }
    }

    static func isSameProgram(_ saved: Program, catalog: ResidencyProgramInfo) -> Bool {
        let mapped = CatalogProgramMapper.toSavedProgram(catalog)
        guard specialtiesMatch(saved, mapped) else { return false }

        let catalogAccreditationID = catalog.accreditationID ?? catalog.id
        switch resolvedAccreditationMatch(saved.accreditationID, catalogAccreditationID) {
        case .match:
            return true
        case .mismatch:
            return false
        case .unknown:
            return hospitalsAndLocationsMatch(saved, mapped)
        }
    }

    static func isDuplicate(_ candidate: Program, in programs: [Program]) -> Bool {
        programs.contains { isSameProgram($0, candidate) }
    }

    // MARK: - Private

    private enum AccreditationMatch {
        case match
        case mismatch
        case unknown
    }

    private static func resolvedAccreditationMatch(_ lhs: String?, _ rhs: String?) -> AccreditationMatch {
        guard let left = normalizedAccreditationID(lhs), let right = normalizedAccreditationID(rhs) else {
            return .unknown
        }
        return left == right ? .match : .mismatch
    }

    /// Same hospital in a different specialty is a different program.
    private static func specialtiesMatch(_ lhs: Program, _ rhs: Program) -> Bool {
        let left = normalizedSpecialty(lhs.specialty)
        let right = normalizedSpecialty(rhs.specialty)
        guard !left.isEmpty, !right.isEmpty else { return false }
        return left == right
    }

    private static func hospitalsAndLocationsMatch(_ lhs: Program, _ rhs: Program) -> Bool {
        normalizedHospital(lhs.hospital) == normalizedHospital(rhs.hospital)
            && normalizedLocation(lhs.city) == normalizedLocation(rhs.city)
            && normalizedLocation(lhs.state) == normalizedLocation(rhs.state)
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
