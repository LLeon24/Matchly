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

        return parsedAddress(
            from: mapItem,
            supplementalTexts: [completion.subtitle]
        )
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
        }

        if state.isEmpty {
            for text in texts {
                if let parsed = parsedStateAbbreviation(nearPostalCodeIn: text) {
                    state = parsed
                    break
                }
            }
        }

        let normalizedState = USState.abbreviation(for: state)
        if postalCode.isEmpty {
            postalCode = bestPostalCode(from: texts, expectedState: normalizedState) ?? ""
        } else if !normalizedState.isEmpty,
                  !postalMatchesState(postalCode, state: normalizedState, in: texts) {
            if let corrected = bestPostalCode(from: texts, expectedState: normalizedState) {
                postalCode = corrected
            }
        }

        return ResolvedManualAddress(
            street: street,
            city: city,
            state: normalizedState,
            postalCode: normalizedPostalCode(postalCode)
        )
    }

    private static func normalizedPostalCode(_ raw: String) -> String {
        String(raw.filter(\.isNumber).prefix(5))
    }

    /// ZIP must appear with a state abbreviation (avoids treating street numbers like 10001 as ZIP codes).
    private static func bestPostalCode(from texts: [String], expectedState: String) -> String? {
        var matches: [(state: String, zip: String)] = []
        for text in texts {
            matches.append(contentsOf: statePostalMatches(in: text))
        }
        guard !matches.isEmpty else { return nil }

        if !expectedState.isEmpty,
           let match = matches.last(where: { $0.state == expectedState }) {
            return match.zip
        }
        return matches.last?.zip
    }

    private static func postalMatchesState(_ postal: String, state: String, in texts: [String]) -> Bool {
        guard !state.isEmpty else { return true }
        let normalized = normalizedPostalCode(postal)
        return statePostalMatches(in: texts.joined(separator: "\n"))
            .contains { $0.state == state && $0.zip == normalized }
    }

    private static func statePostalMatches(in text: String) -> [(state: String, zip: String)] {
        guard let regex = try? NSRegularExpression(pattern: #"\b([A-Z]{2})\s+(\d{5})(?:-\d{4})?(?!\d)"#) else {
            return []
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        let results = regex.matches(in: text, range: range)
        return results.compactMap { match in
            guard match.numberOfRanges > 2,
                  let stateRange = Range(match.range(at: 1), in: text),
                  let zipRange = Range(match.range(at: 2), in: text) else {
                return nil
            }
            let abbrev = String(text[stateRange])
            guard USState.selectableAbbreviations.contains(abbrev) else { return nil }
            return (abbrev, String(text[zipRange]))
        }
    }

    private static func parsedStateAbbreviation(nearPostalCodeIn text: String) -> String? {
        statePostalMatches(in: text).last?.state
    }

    private static func applyCityWithContext(
        _ cityWithContext: String,
        city: inout String,
        state: inout String,
        postalCode: inout String
    ) {
        let trimmed = cityWithContext.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if state.isEmpty, let parsedState = parsedStateAbbreviation(nearPostalCodeIn: trimmed) {
            state = parsedState
        }
        if postalCode.isEmpty, let parsedState = state.isEmpty ? parsedStateAbbreviation(nearPostalCodeIn: trimmed) : state,
           let match = statePostalMatches(in: trimmed).last(where: { $0.state == USState.abbreviation(for: parsedState) }) {
            postalCode = match.zip
        } else if postalCode.isEmpty, let match = statePostalMatches(in: trimmed).last {
            postalCode = match.zip
            if state.isEmpty { state = match.state }
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
