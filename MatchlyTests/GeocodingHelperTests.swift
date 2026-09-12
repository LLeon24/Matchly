//
//  GeocodingHelperTests.swift
//  MatchlyTests
//

import CoreLocation
import Testing
@testable import Matchly

struct GeocodingHelperTests {
    @Test func normalizesFullStateNamesForFallbackCoordinates() {
        let floridaCenter = GeocodingHelper.coordinate(for: "Aventura", state: "Florida")
        #expect(abs(floridaCenter.latitude - 25.9565) < 0.5)
        #expect(abs(floridaCenter.longitude - (-80.1392)) < 0.5)
    }

    @Test func doesNotSendUnknownStatesToKansasDefault() {
        let stateOnly = GeocodingHelper.coordinate(for: "California")
        #expect(abs(stateOnly.latitude - 36.116203) < 1.0)
        #expect(abs(stateOnly.longitude - (-119.681564)) < 1.0)
    }

    @Test func hcaAventuraOverrideUsesFloridaStreetAddress() {
        let resolved = AddressFormatter.resolved(
            hospital: "HCA FLORIDA HEALTHCARE/AVENTURA HOSPITAL",
            address: nil,
            city: "Aventura",
            state: "Florida",
            accreditationID: "1101100196"
        )

        #expect(resolved.state == "FL")
        #expect(resolved.city == "Aventura")
        #expect(resolved.street.contains("20900"))
    }
}
