//
//  AddProgramSpecialtyTests.swift
//  MatchlyTests
//

import XCTest
@testable import Matchly

@MainActor
final class AddProgramSpecialtyTests: XCTestCase {
    func testSpecialtyMismatchCanBeBypassed() {
        let manager = DataManager.shared
        let originalPrograms = manager.programs
        let originalSpecialties = manager.preferences.specialties
        defer {
            manager.programs = originalPrograms
            manager.preferences.specialties = originalSpecialties
            manager.saveProgramsImmediately()
            manager.savePreferences()
        }

        manager.programs = []
        manager.preferences.specialties = ["Internal Medicine"]

        let emProgram = Program(
            specialty: "Emergency Medicine",
            hospital: "Test Hospital",
            city: "Orlando",
            state: "FL",
            accreditationID: "1101112190"
        )

        XCTAssertEqual(manager.addProgram(emProgram), .specialtyMismatch)
        XCTAssertEqual(manager.addProgram(emProgram, allowSpecialtyMismatch: true), .added)
    }

    func testAddSpecialtyToPreferencesAppendsCanonicalName() {
        let manager = DataManager.shared
        let originalSpecialties = manager.preferences.specialties
        defer {
            manager.preferences.specialties = originalSpecialties
            manager.savePreferences()
        }

        manager.preferences.specialties = ["Internal Medicine"]
        manager.appendSpecialtyToPreferences("Emergency Medicine")

        XCTAssertTrue(manager.preferences.specialties.contains("Emergency Medicine"))
        XCTAssertTrue(manager.preferences.specialties.contains("Internal Medicine"))
    }
}
