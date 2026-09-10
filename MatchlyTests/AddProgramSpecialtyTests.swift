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

    func testCrossSpecialtyProgramIsSavedWithoutUpdatingPreferences() {
        let manager = DataManager.shared
        let originalPrograms = manager.programs
        let originalSpecialties = manager.preferences.specialties
        defer {
            manager.programs = originalPrograms
            manager.preferences.specialties = originalSpecialties
            manager.saveProgramsImmediately()
            manager.savePreferences()
        }

        manager.programs = [
            Program(
                specialty: "Internal Medicine",
                hospital: "Brigham and Women's Hospital",
                city: "Boston",
                state: "MA",
                accreditationID: "1400121030"
            )
        ]
        manager.preferences.specialties = ["Internal Medicine"]

        let fmProgram = Program(
            specialty: "Family Medicine",
            hospital: "Abington Memorial Hospital",
            city: "Jenkintown",
            state: "PA",
            accreditationID: "1200121001"
        )

        XCTAssertEqual(manager.addProgram(fmProgram, allowSpecialtyMismatch: true), .added)
        XCTAssertEqual(manager.programs.count, 2)
        XCTAssertEqual(manager.preferences.specialties, ["Internal Medicine"])
        XCTAssertTrue(manager.programs.contains { $0.specialty == "Family Medicine" })
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
