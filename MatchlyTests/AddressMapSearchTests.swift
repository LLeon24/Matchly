//
//  AddressMapSearchTests.swift
//  MatchlyTests
//

import XCTest
@testable import Matchly

final class AddressMapSearchTests: XCTestCase {
    func testMultilineFullAddressExtractsZIP() {
        let full = """
        1364 Clifton Road NE
        Atlanta, GA 30322
        United States
        """
        let resolved = AddressMapSearch.resolvedAddress(from: [full], preferredStreet: "1364 Clifton Road NE")

        XCTAssertEqual(resolved.city, "Atlanta")
        XCTAssertEqual(resolved.state, "GA")
        XCTAssertEqual(resolved.postalCode, "30322")
    }

    func testSingleLineAddressExtractsZIP() {
        let line = "1364 Clifton Road NE, Atlanta, GA 30322"
        let resolved = AddressMapSearch.resolvedAddress(from: [line])

        XCTAssertEqual(resolved.postalCode, "30322")
        XCTAssertEqual(resolved.state, "GA")
    }

    func testCompletionSubtitleCanSupplyZIP() {
        let subtitle = "Atlanta, GA 30322"
        let resolved = AddressMapSearch.resolvedAddress(from: [subtitle])

        XCTAssertEqual(resolved.postalCode, "30322")
        XCTAssertEqual(resolved.city, "Atlanta")
        XCTAssertEqual(resolved.state, "GA")
    }

    func testZIPPlusFourNormalizesToFiveDigits() {
        let line = "Cupertino, CA 95014-2083"
        let resolved = AddressMapSearch.resolvedAddress(from: [line])

        XCTAssertEqual(resolved.postalCode, "95014")
    }

    func testStreetNumberIsNotTreatedAsZIP() {
        let texts = [
            "10001 Broadway",
            "New York, NY 10001",
        ]
        let resolved = AddressMapSearch.resolvedAddress(from: texts)

        XCTAssertEqual(resolved.postalCode, "10001")
        XCTAssertEqual(resolved.state, "NY")
    }

    func testKissimmeeAddressUsesStateAnchoredZIP() {
        let texts = [
            """
            468 Acacia Tree Way
            Kissimmee, FL 34758
            United States
            """
        ]
        let resolved = AddressMapSearch.resolvedAddress(from: texts, preferredStreet: "468 Acacia Tree Way")

        XCTAssertEqual(resolved.city, "Kissimmee")
        XCTAssertEqual(resolved.state, "FL")
        XCTAssertEqual(resolved.postalCode, "34758")
    }
}
