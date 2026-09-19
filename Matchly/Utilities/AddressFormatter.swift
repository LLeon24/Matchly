//
//  AddressFormatter.swift
//  Matchly
//
//  Parses clean mailing addresses from ACGME PDF blobs and resolves multi-campus sites.
//

import Foundation

enum AddressFormatter {
    struct ResolvedAddress {
        let street: String
        let city: String
        let state: String
        let siteName: String?
    }

    /// Street line only for program headers (no city/state duplication).
    static func displayStreet(for program: ResidencyProgramInfo) -> String {
        resolved(for: program).street
    }

    static func displayStreet(for program: Program) -> String {
        resolved(
            hospital: program.hospital,
            address: program.address,
            city: program.city,
            state: program.state,
            accreditationID: program.accreditationID
        ).street
    }

    /// Full string for Maps / geocoding.
    static func geocodingQuery(for program: Program) -> String {
        geocodingQuery(
            hospital: program.hospital,
            address: program.address,
            city: program.city,
            state: program.state,
            accreditationID: program.accreditationID
        )
    }

    static func geocodingQuery(for program: ResidencyProgramInfo) -> String {
        geocodingQuery(
            hospital: program.hospital,
            address: program.address,
            city: program.city,
            state: program.state,
            accreditationID: program.accreditationID
        )
    }

    static func geocodingQuery(
        hospital: String,
        address: String?,
        city: String,
        state: String,
        accreditationID: String? = nil
    ) -> String {
        let r = resolved(
            hospital: hospital,
            address: address,
            city: city,
            state: state,
            accreditationID: accreditationID
        )
        if !r.street.isEmpty {
            return "\(r.street), \(r.city), \(r.state)"
        }
        if let site = r.siteName, !site.isEmpty {
            return "\(site), \(r.city), \(r.state)"
        }
        let formattedHospital = HospitalNameFormatter.format(hospital)
        if !formattedHospital.isEmpty {
            return "\(formattedHospital), \(r.city), \(r.state)"
        }
        return "\(r.city), \(r.state)"
    }

    static func resolved(for program: ResidencyProgramInfo) -> ResolvedAddress {
        resolved(
            hospital: program.hospital,
            address: program.address,
            city: program.city,
            state: program.state,
            accreditationID: program.accreditationID
        )
    }

    static func resolved(
        hospital: String,
        address: String?,
        city: String,
        state: String,
        accreditationID: String? = nil
    ) -> ResolvedAddress {
        let raw = address ?? ""

        let normalizedState = USState.abbreviation(for: state)
        let normalizedCity = city.trimmingCharacters(in: .whitespacesAndNewlines)

        if let override = campusOverride(hospital: hospital, rawAddress: raw) {
            return override
        }

        if let parsed = parseStreetFromRaw(raw) {
            let parsedState = USState.abbreviation(for: parsed.state)
            if !parsed.state.isEmpty,
               !normalizedState.isEmpty,
               parsedState != normalizedState {
                // PDF blobs sometimes contain a different campus address; keep catalog city/state.
                return catalogOnlyAddress(
                    hospital: hospital,
                    city: normalizedCity,
                    state: normalizedState
                )
            }
            return ResolvedAddress(
                street: parsed.street,
                city: parsed.city.isEmpty ? normalizedCity : parsed.city,
                state: parsed.state.isEmpty ? normalizedState : parsedState,
                siteName: extractCareSiteName(from: hospital)
            )
        }

        if looksLikeGarbageAddress(raw) {
            return catalogOnlyAddress(
                hospital: hospital,
                city: normalizedCity,
                state: normalizedState
            )
        }

        let trimmedStreet = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedStreet.isEmpty {
            return catalogOnlyAddress(
                hospital: hospital,
                city: normalizedCity,
                state: normalizedState
            )
        }

        return ResolvedAddress(
            street: trimmedStreet,
            city: normalizedCity,
            state: normalizedState,
            siteName: extractCareSiteName(from: hospital)
        )
    }

    /// City/state from the catalog only — never inferred from map coordinates.
    private static func catalogOnlyAddress(
        hospital: String,
        city: String,
        state: String
    ) -> ResolvedAddress {
        ResolvedAddress(
            street: "",
            city: city,
            state: state,
            siteName: extractCareSiteName(from: hospital)
        )
    }

    // MARK: - Campus overrides (multi-site programs detected by hospital name)

    private static func campusOverride(
        hospital: String,
        rawAddress: String
    ) -> ResolvedAddress? {
        let h = hospital.lowercased()
        let raw = rawAddress.lowercased()

        let isLakeNona = raw.contains("lake nona") || raw.contains("6850")

        if h.contains("aventura") && h.contains("hca") {
            return ResolvedAddress(
                street: "20900 Biscayne Blvd",
                city: "Aventura",
                state: "FL",
                siteName: "HCA Florida Aventura Hospital"
            )
        }

        if (h.contains("central florida") && h.contains("hca")) || (h.contains("ucf") && h.contains("hca")) {
            if h.contains("osceola") && !h.contains("lake nona") {
                return ResolvedAddress(
                    street: "700 W Oak St",
                    city: "Kissimmee",
                    state: "FL",
                    siteName: "HCA Florida Osceola Hospital"
                )
            }
            if h.contains("lake nona") || isLakeNona {
                return ResolvedAddress(
                    street: "6850 Lake Nona Blvd",
                    city: "Orlando",
                    state: "FL",
                    siteName: "UCF Lake Nona Medical Center"
                )
            }
        }

        return nil
    }

    /// Pull a care-site name from a sponsoring-institution / hospital string for geocoding.
    /// Example: "Florida State University College of Medicine/Sarasota Memorial Hospital"
    /// → "Sarasota Memorial Hospital"
    static func extractCareSiteName(from hospital: String) -> String? {
        let formatted = HospitalNameFormatter.format(hospital.trimmingCharacters(in: .whitespacesAndNewlines))
        guard !formatted.isEmpty else { return nil }

        let slashParts = formatted.split(separator: "/").map {
            String($0).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if slashParts.count > 1 {
            for part in slashParts.reversed() where looksLikeCareSite(part) && !looksLikeAcademicShell(part) {
                return part
            }
        }

        if looksLikeCareSite(formatted), !looksLikeAcademicShell(formatted) {
            return formatted
        }

        return nil
    }

    private static func looksLikeCareSite(_ name: String) -> Bool {
        let lower = name.lowercased()
        let markers = [
            "hospital", "medical center", "medical centre", "health system",
            "healthcare", "health network", "memorial", "clinic", "medical group",
            "regional medical", "community hospital"
        ]
        return markers.contains { lower.contains($0) }
    }

    private static func looksLikeAcademicShell(_ name: String) -> Bool {
        let lower = name.lowercased()
        if lower.contains("college of medicine") && !looksLikeCareSite(name) {
            return true
        }
        if lower.contains("school of medicine") && !looksLikeCareSite(name) {
            return true
        }
        return false
    }

    // MARK: - Parsing

    private static func looksLikeGarbageAddress(_ raw: String) -> Bool {
        let lower = raw.lowercased()
        let junkMarkers = ["accreditation", "program director", "md accreditation", "healthcare (greater program"]
        return junkMarkers.contains { lower.contains($0) }
    }

    private static func parseStreetFromRaw(_ raw: String) -> (street: String, city: String, state: String)? {
        guard !raw.isEmpty else { return nil }

        let pattern = #"(\d{1,5}[^,]*?(?:Street|St|Boulevard|Blvd|Avenue|Ave|Road|Rd|Drive|Dr|Way|Lane|Ln|Circle|Cir|Court|Ct|Highway|Hwy|Parkway|Pkwy)(?:[^,]*?)?)\s*,\s*([A-Za-z][A-Za-z .'\-]+?)\s*,\s*([A-Z]{2})\s+\d{5}"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }

        let ns = raw as NSString
        let matches = regex.matches(in: raw, range: NSRange(location: 0, length: ns.length))
        guard let last = matches.last, last.numberOfRanges >= 4 else { return nil }

        let street = ns.substring(with: last.range(at: 1))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let city = ns.substring(with: last.range(at: 2))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let state = ns.substring(with: last.range(at: 3))
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard isPlausibleCity(city), !street.isEmpty else { return nil }
        return (normalizeStreet(street), city, state)
    }

    private static func isPlausibleCity(_ city: String) -> Bool {
        if city.isEmpty || city.count > 40 { return false }
        if city.contains(where: \.isNumber) { return false }
        let lower = city.lowercased()
        if lower.contains("program") || lower.contains("accreditation") || lower.contains("healthcare") {
            return false
        }
        return true
    }

    private static func normalizeStreet(_ street: String) -> String {
        street
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: CharacterSet(charactersIn: " ,;"))
    }
}

extension Program {
    var resolvedAddress: AddressFormatter.ResolvedAddress {
        AddressFormatter.resolved(
            hospital: hospital,
            address: address,
            city: city,
            state: state,
            accreditationID: accreditationID
        )
    }

    /// City, ST for display — from catalog-normalized resolution, never geocoding.
    var displayCityState: String {
        let resolved = resolvedAddress
        guard !resolved.city.isEmpty, !resolved.state.isEmpty else { return "" }
        return "\(resolved.city), \(resolved.state)"
    }

    var hasDisplayLocation: Bool {
        !displayCityState.isEmpty
    }
}

extension ResidencyProgramInfo {
    var resolvedAddress: AddressFormatter.ResolvedAddress {
        AddressFormatter.resolved(for: self)
    }

    var displayCityState: String {
        let resolved = resolvedAddress
        guard !resolved.city.isEmpty, !resolved.state.isEmpty else { return "" }
        return "\(resolved.city), \(resolved.state)"
    }
}
