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
        guard specialtiesMatch(saved.specialty, catalog.specialty) else { return false }

        let catalogAccreditationID = catalog.accreditationID ?? catalog.id
        switch resolvedAccreditationMatch(saved.accreditationID, catalogAccreditationID) {
        case .match:
            return true
        case .mismatch:
            return false
        case .unknown:
            return hospitalsAndLocationsMatch(
                saved,
                hospital: HospitalNameFormatter.format(catalog.hospital),
                city: catalog.city,
                state: catalog.state
            )
        }
    }

    static func isDuplicate(_ candidate: Program, in programs: [Program]) -> Bool {
        programs.contains { isSameProgram($0, candidate) }
    }

    /// Fast lookup keys for catalog rows (specialty + ACGME id, or specialty + hospital/location).
    static func catalogIdentityKey(for catalog: ResidencyProgramInfo) -> String {
        identityKey(
            specialty: catalog.specialty,
            accreditationID: catalog.accreditationID,
            fallbackCatalogID: catalog.id,
            hospital: HospitalNameFormatter.format(catalog.hospital),
            city: catalog.city,
            state: catalog.state
        )
    }

    static func addedCatalogIdentityKeys(from programs: [Program]) -> Set<String> {
        Set(programs.map { identityKey(for: $0) })
    }

    static func isCatalogProgramAlreadyAdded(
        _ catalog: ResidencyProgramInfo,
        existingKeys: Set<String>
    ) -> Bool {
        existingKeys.contains(catalogIdentityKey(for: catalog))
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
        specialtiesMatch(lhs.specialty, rhs.specialty)
    }

    private static func specialtiesMatch(_ lhsSpecialty: String, _ rhsSpecialty: String) -> Bool {
        let left = normalizedSpecialty(lhsSpecialty)
        let right = normalizedSpecialty(rhsSpecialty)
        guard !left.isEmpty, !right.isEmpty else { return false }
        return left == right
    }

    private static func hospitalsAndLocationsMatch(_ lhs: Program, _ rhs: Program) -> Bool {
        hospitalsAndLocationsMatch(lhs, hospital: rhs.hospital, city: rhs.city, state: rhs.state)
    }

    private static func hospitalsAndLocationsMatch(
        _ lhs: Program,
        hospital: String,
        city: String,
        state: String
    ) -> Bool {
        normalizedHospital(lhs.hospital) == normalizedHospital(hospital)
            && normalizedLocation(lhs.city) == normalizedLocation(city)
            && normalizedLocation(lhs.state) == normalizedLocation(USState.abbreviation(for: state))
    }

    private static func identityKey(for program: Program) -> String {
        identityKey(
            specialty: program.specialty,
            accreditationID: program.accreditationID,
            hospital: program.hospital,
            city: program.city,
            state: program.state
        )
    }

    private static func identityKey(
        specialty: String,
        accreditationID: String?,
        fallbackCatalogID: String? = nil,
        hospital: String,
        city: String,
        state: String
    ) -> String {
        let normalizedSpecialty = normalizedSpecialty(specialty)
        let resolvedAccreditationID = normalizedAccreditationID(accreditationID)
            ?? normalizedAccreditationID(fallbackCatalogID)
        if let resolvedAccreditationID {
            return "id|\(normalizedSpecialty)|\(resolvedAccreditationID)"
        }

        return [
            "loc",
            normalizedSpecialty,
            normalizedHospital(hospital),
            normalizedLocation(city),
            normalizedLocation(USState.abbreviation(for: state))
        ].joined(separator: "|")
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
