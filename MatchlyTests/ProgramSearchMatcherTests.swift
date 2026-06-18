//
//  ProgramSearchMatcherTests.swift
//  MatchlyTests
//

import Testing
@testable import Matchly

struct ProgramSearchMatcherTests {
    private let floridaState = ResidencyProgramInfo(
        id: "test_fsu",
        name: "Internal Medicine",
        hospital: "Florida State University College of Medicine",
        city: "Tallahassee",
        state: "FL",
        specialty: "Internal Medicine"
    )

    private let massGeneral = ResidencyProgramInfo(
        id: "test_mgh",
        name: "Internal Medicine",
        hospital: "Massachusetts General Hospital",
        city: "Boston",
        state: "MA",
        specialty: "Internal Medicine"
    )

    private let ucla = ResidencyProgramInfo(
        id: "test_ucla",
        name: "Internal Medicine",
        hospital: "UCLA David Geffen School of Medicine/UCLA Medical Center",
        city: "Los Angeles",
        state: "CA",
        specialty: "Internal Medicine"
    )

    private let emptyStateMap: [String: String] = [:]

    @Test func fsuMatchesFloridaStateUniversity() {
        #expect(ProgramSearchMatcher.matches(query: "fsu", program: floridaState, stateToAbbrev: emptyStateMap))
    }

    @Test func floridaStateSubstringStillMatches() {
        #expect(ProgramSearchMatcher.matches(query: "florida state", program: floridaState, stateToAbbrev: emptyStateMap))
    }

    @Test func mghMatchesMassachusettsGeneral() {
        #expect(ProgramSearchMatcher.matches(query: "mgh", program: massGeneral, stateToAbbrev: emptyStateMap))
    }

    @Test func hopkinsAliasMatchesJohnsHopkins() {
        let program = ResidencyProgramInfo(
            id: "test_hopkins",
            name: "Internal Medicine",
            hospital: "Johns Hopkins Hospital",
            city: "Baltimore",
            state: "MD",
            specialty: "Internal Medicine"
        )
        #expect(ProgramSearchMatcher.matches(query: "hopkins", program: program, stateToAbbrev: emptyStateMap))
    }

    @Test func uclaMatchesLiteralSubstring() {
        #expect(ProgramSearchMatcher.matches(query: "ucla", program: ucla, stateToAbbrev: emptyStateMap))
    }

    @Test func shortAcronymQueryDoesNotMatchUnrelatedPrograms() {
        #expect(!ProgramSearchMatcher.matches(query: "st", program: floridaState, stateToAbbrev: emptyStateMap))
    }

    @Test func acronymGenerationSkipsStopWords() {
        let acronym = ProgramSearchMatcher.acronym(from: "Florida State University College of Medicine")
        #expect(acronym.hasPrefix("fsu"))
    }
}
