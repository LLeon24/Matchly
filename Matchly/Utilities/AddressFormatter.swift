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
        let r = resolved(
            hospital: program.hospital,
            address: program.address,
            city: program.city,
            state: program.state,
            accreditationID: program.accreditationID
        )
        if !r.street.isEmpty {
            return "\(r.street), \(r.city), \(r.state)"
        }
        if let site = r.siteName, !site.isEmpty {
            return "\(site), \(r.city), \(r.state)"
        }
        return "\(program.hospital), \(r.city), \(r.state)"
    }

    static func geocodingQuery(for program: ResidencyProgramInfo) -> String {
        let r = resolved(for: program)
        if !r.street.isEmpty {
            return "\(r.street), \(r.city), \(r.state)"
        }
        if let site = r.siteName, !site.isEmpty {
            return "\(site), \(r.city), \(r.state)"
        }
        return "\(program.hospital), \(r.city), \(r.state)"
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
        accreditationID: String?
    ) -> ResolvedAddress {
        let hospitalLower = hospital.lowercased()
        let raw = address ?? ""

        if let override = campusOverride(hospital: hospital, rawAddress: raw, accreditationID: accreditationID) {
            return override
        }

        if let parsed = parseStreetFromRaw(raw) {
            return ResolvedAddress(
                street: parsed.street,
                city: parsed.city.isEmpty ? city : parsed.city,
                state: parsed.state.isEmpty ? state : parsed.state,
                siteName: nil
            )
        }

        if looksLikeGarbageAddress(raw) {
            return ResolvedAddress(street: "", city: city, state: state, siteName: nil)
        }

        return ResolvedAddress(street: raw.trimmingCharacters(in: .whitespacesAndNewlines), city: city, state: state, siteName: nil)
    }

    // MARK: - Campus overrides (multi-site programs)

    private static func campusOverride(
        hospital: String,
        rawAddress: String,
        accreditationID: String?
    ) -> ResolvedAddress? {
        let h = hospital.lowercased()
        let raw = rawAddress.lowercased()

        let isLakeNona = raw.contains("lake nona") || raw.contains("6850")

        if (h.contains("central florida") && h.contains("hca")) || (h.contains("ucf") && h.contains("hca")) {
            // Hospital campus label wins over a mismatched street line in the PDF blob.
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

        if let id = accreditationID, let byID = overridesByAccreditationID[id] {
            return byID
        }

        return nil
    }

    private static let overridesByAccreditationID: [String: ResolvedAddress] = [
        "1101100194": ResolvedAddress(
            street: "700 W Oak St",
            city: "Kissimmee",
            state: "FL",
            siteName: "HCA Florida Osceola Hospital"
        ),
    ]

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
