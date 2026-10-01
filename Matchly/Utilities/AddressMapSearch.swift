//
//  AddressMapSearch.swift
//  Matchly
//
//  Apple MapKit address autocomplete and resolution for manual program entry.
//

import Combine
import Foundation
import MapKit

struct ResolvedManualAddress: Equatable {
    var street: String
    var city: String
    var state: String
    var postalCode: String
}

enum AddressMapSearch {
    enum SearchError: Error {
        case noResults
    }

    static func resolve(completion: MKLocalSearchCompletion) async throws -> ResolvedManualAddress {
        let request = MKLocalSearch.Request(completion: completion)
        request.resultTypes = [.address, .pointOfInterest]
        let response = try await MKLocalSearch(request: request).start()
        guard let mapItem = response.mapItems.first else {
            throw SearchError.noResults
        }

        var resolved = parsedAddress(
            from: mapItem,
            supplementalTexts: [completion.title, completion.subtitle]
        )

        if resolved.postalCode.isEmpty,
           let zip = await reverseGeocodedPostalCode(for: mapItem.location) {
            resolved.postalCode = normalizedPostalCode(zip)
        }

        return resolved
    }

    static func parsedAddress(
        from mapItem: MKMapItem,
        supplementalTexts: [String] = []
    ) -> ResolvedManualAddress {
        var texts = supplementalTexts
        if let short = mapItem.address?.shortAddress {
            texts.append(short)
        }
        if let full = mapItem.address?.fullAddress {
            texts.append(full)
        }
        if let reps = mapItem.addressRepresentations {
            if let cityName = reps.cityName {
                texts.append(cityName)
            }
            if let cityWithContext = reps.cityWithContext {
                texts.append(cityWithContext)
            }
            if let multiline = reps.fullAddress(includingRegion: false, singleLine: false) {
                texts.append(multiline)
            }
            if let singleLine = reps.fullAddress(includingRegion: false, singleLine: true) {
                texts.append(singleLine)
            }
            if let withRegion = reps.fullAddress(includingRegion: true, singleLine: false) {
                texts.append(withRegion)
            }
        }

        let preferredStreet = mapItem.address?.shortAddress?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return resolvedAddress(from: texts, preferredStreet: preferredStreet)
    }

    /// Parses street, city, state, and ZIP from MapKit address strings (used in tests).
    static func resolvedAddress(from texts: [String], preferredStreet: String = "") -> ResolvedManualAddress {
        var street = preferredStreet.trimmingCharacters(in: .whitespacesAndNewlines)
        var city = ""
        var state = ""
        var postalCode = ""

        for text in texts {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            applyFullAddressLines(trimmed, street: &street, city: &city, state: &state, postalCode: &postalCode)

            if postalCode.isEmpty, let zip = firstUSPostalCode(in: trimmed) {
                postalCode = zip
            }
        }

        if postalCode.isEmpty {
            for text in texts {
                if let zip = firstUSPostalCode(in: text) {
                    postalCode = zip
                    break
                }
            }
        }

        if state.isEmpty {
            for text in texts {
                if let parsed = parsedStateAbbreviation(nearPostalCodeIn: text) {
                    state = parsed
                    break
                }
            }
        }

        return ResolvedManualAddress(
            street: street,
            city: city,
            state: USState.abbreviation(for: state),
            postalCode: normalizedPostalCode(postalCode)
        )
    }

    private static func normalizedPostalCode(_ raw: String) -> String {
        String(raw.filter(\.isNumber).prefix(5))
    }

    private static func firstUSPostalCode(in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: #"(?<!\d)(\d{5})(?:-\d{4})?(?!\d)"#) else {
            return nil
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              match.numberOfRanges > 1,
              let zipRange = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return String(text[zipRange])
    }

    private static func parsedStateAbbreviation(nearPostalCodeIn text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: #"\b([A-Z]{2})\s+\d{5}(?:-\d{4})?\b"#) else {
            return nil
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              match.numberOfRanges > 1,
              let stateRange = Range(match.range(at: 1), in: text) else {
            return nil
        }
        let abbrev = String(text[stateRange])
        return USState.selectableAbbreviations.contains(abbrev) ? abbrev : nil
    }

    private static func applyCityWithContext(
        _ cityWithContext: String,
        city: inout String,
        state: inout String,
        postalCode: inout String
    ) {
        let trimmed = cityWithContext.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if postalCode.isEmpty, let zip = firstUSPostalCode(in: trimmed) {
            postalCode = zip
        }
        if state.isEmpty, let parsedState = parsedStateAbbreviation(nearPostalCodeIn: trimmed) {
            state = parsedState
        }

        let parts = trimmed
            .split(separator: ",", maxSplits: 1)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard parts.count == 2 else { return }

        if city.isEmpty {
            city = parts[0]
        }

        let stateAndZip = parts[1]
        let tokens = stateAndZip.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        if let first = tokens.first, state.isEmpty, first.count == 2 {
            state = first
        }
        if tokens.count > 1, postalCode.isEmpty {
            postalCode = tokens[1]
        }
    }

    private static func applyFullAddressLines(
        _ fullAddress: String,
        street: inout String,
        city: inout String,
        state: inout String,
        postalCode: inout String
    ) {
        let lines = fullAddress
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !isCountryLine($0) }

        if lines.count <= 1 {
            if lines.count == 1, street.isEmpty, !lines[0].contains(",") {
                street = lines[0]
            }
            applyCityWithContext(fullAddress, city: &city, state: &state, postalCode: &postalCode)
            return
        }

        if street.isEmpty {
            street = lines[0]
        }

        for line in lines.dropFirst() {
            applyCityWithContext(line, city: &city, state: &state, postalCode: &postalCode)
        }
    }

    private static func isCountryLine(_ line: String) -> Bool {
        switch line.lowercased() {
        case "united states", "united states of america", "usa", "u.s.a.", "us":
            return true
        default:
            return false
        }
    }

    private static func reverseGeocodedPostalCode(for location: CLLocation) async -> String? {
        guard let request = MKReverseGeocodingRequest(location: location),
              let mapItems = try? await request.mapItems,
              let mapItem = mapItems.first else {
            return nil
        }
        let postal = parsedAddress(from: mapItem).postalCode
        return postal.isEmpty ? nil : postal
    }
}

@MainActor
final class AddressSearchCompleterModel: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published private(set) var completions: [MKLocalSearchCompletion] = []
    @Published private(set) var isResolving = false

    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
        completer.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 39.8283, longitude: -98.5795),
            span: MKCoordinateSpan(latitudeDelta: 45, longitudeDelta: 55)
        )
    }

    func updateQuery(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 3 else {
            completer.queryFragment = ""
            completions = []
            return
        }
        completer.queryFragment = trimmed
    }

    func clearResults() {
        completer.queryFragment = ""
        completions = []
    }

    func resolve(_ completion: MKLocalSearchCompletion) async -> ResolvedManualAddress? {
        isResolving = true
        defer { isResolving = false }
        return try? await AddressMapSearch.resolve(completion: completion)
    }

    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        Task { @MainActor in
            self.completions = Array(completer.results.prefix(6))
        }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor in
            self.completions = []
        }
    }
}
