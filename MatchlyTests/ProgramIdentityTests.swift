//
//  ProgramIdentityTests.swift
//  MatchlyTests
//

import XCTest
@testable import Matchly

final class ProgramIdentityTests: XCTestCase {
    func testDifferentSpecialtyAtSameHospitalIsNotDuplicate() {
        let internalMedicine = Program(
            specialty: "Internal Medicine",
            hospital: "AdventHealth Florida (Orlando)",
            city: "Orlando",
            state: "FL",
            accreditationID: "1401131539"
        )
        let anesthesiology = Program(
            specialty: "Anesthesiology",
            hospital: "AdventHealth Florida",
            city: "Orlando",
            state: "FL",
            accreditationID: "0401100003"
        )

        XCTAssertFalse(ProgramIdentity.isSameProgram(internalMedicine, anesthesiology))
        XCTAssertFalse(ProgramIdentity.isDuplicate(anesthesiology, in: [internalMedicine]))
    }

    func testSameAccreditationIDAndSpecialtyIsDuplicate() {
        let existing = Program(
            specialty: "Anesthesiology",
            hospital: "AdventHealth Florida",
            city: "Orlando",
            state: "FL",
            accreditationID: "0401100003"
        )
        let candidate = Program(
            specialty: "Anesthesiology",
            hospital: "AdventHealth Florida",
            city: "Orlando",
            state: "FL",
            accreditationID: "0401100003"
        )

        XCTAssertTrue(ProgramIdentity.isSameProgram(existing, candidate))
        XCTAssertTrue(ProgramIdentity.isDuplicate(candidate, in: [existing]))
    }

    func testCatalogComparisonUsesCatalogIDWhenAccreditationIDMissing() {
        let saved = Program(
            specialty: "Anesthesiology",
            hospital: "AdventHealth Florida",
            city: "Orlando",
            state: "FL",
            accreditationID: "0401100003"
        )
        let catalog = ResidencyProgramInfo(
            id: "0401100003",
            name: "Anesthesiology",
            hospital: "AdventHealth Florida",
            city: "Orlando",
            state: "FL",
            specialty: "Anesthesiology",
            accreditationID: nil
        )

        XCTAssertTrue(ProgramIdentity.isSameProgram(saved, catalog: catalog))
    }

    func testCatalogComparisonAllowsSameHospitalDifferentSpecialty() {
        let saved = Program(
            specialty: "Internal Medicine",
            hospital: "AdventHealth Florida (Orlando)",
            city: "Orlando",
            state: "FL",
            accreditationID: "1401131539"
        )
        let catalog = ResidencyProgramInfo(
            id: "0401100003",
            name: "Anesthesiology",
            hospital: "AdventHealth Florida",
            city: "Orlando",
            state: "FL",
            specialty: "Anesthesiology",
            accreditationID: "0401100003"
        )

        XCTAssertFalse(ProgramIdentity.isSameProgram(saved, catalog: catalog))
    }

    func testCatalogIdentityKeyMatchesDuplicateLookup() {
        let saved = Program(
            specialty: "Anesthesiology",
            hospital: "AdventHealth Florida",
            city: "Orlando",
            state: "FL",
            accreditationID: "0401100003"
        )
        let catalog = ResidencyProgramInfo(
            id: "0401100003",
            name: "Anesthesiology",
            hospital: "AdventHealth Florida",
            city: "Orlando",
            state: "FL",
            specialty: "Anesthesiology",
            accreditationID: "0401100003"
        )

        let keys = ProgramIdentity.addedCatalogIdentityKeys(from: [saved])
        XCTAssertTrue(ProgramIdentity.isCatalogProgramAlreadyAdded(catalog, existingKeys: keys))
    }
}
