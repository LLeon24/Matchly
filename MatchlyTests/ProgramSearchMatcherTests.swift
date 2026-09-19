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

    @Test func ucfMatchesUniversityOfCentralFloridaProgram() {
        let ucfProgram = ResidencyProgramInfo(
            id: "test_ucf",
            name: "Internal Medicine",
            hospital: "University of Central Florida/HCA Florida Healthcare (Greater Orlando/Lake Monroe)",
            city: "Orlando",
            state: "FL",
            specialty: "Internal Medicine",
            accreditationID: "1401100009"
        )
        #expect(ProgramSearchMatcher.matches(query: "ucf", program: ucfProgram, stateToAbbrev: emptyStateMap))
        #expect(ProgramSearchMatcher.matches(query: "lake monroe", program: ucfProgram, stateToAbbrev: emptyStateMap))
        #expect(ProgramSearchMatcher.matches(query: "central florida", program: ucfProgram, stateToAbbrev: emptyStateMap))
    }

    @Test func derivedAcronymMatchesWithoutHardcodedAliasEntry() {
        let program = ResidencyProgramInfo(
            id: "test_ohio_state",
            name: "Internal Medicine",
            hospital: "Ohio State University Medical Center",
            city: "Columbus",
            state: "OH",
            specialty: "Internal Medicine"
        )
        #expect(ProgramSearchMatcher.matches(query: "osu", program: program, stateToAbbrev: emptyStateMap))
    }

    @Test func aliasKeyAddedToHaystackForBidirectionalSearch() {
        let program = ResidencyProgramInfo(
            id: "test_fsu_haystack",
            name: "Internal Medicine",
            hospital: "Florida State University College of Medicine",
            city: "Tallahassee",
            state: "FL",
            specialty: "Internal Medicine"
        )
        let index = ProgramSearchMatcher.index(for: program)
        #expect(index.haystack.contains("fsu"))
    }

    @Test func shortAcronymQueryDoesNotMatchUnrelatedPrograms() {
        let universityOfFlorida = ResidencyProgramInfo(
            id: "test_uf",
            name: "Internal Medicine",
            hospital: "University of Florida College of Medicine",
            city: "Gainesville",
            state: "FL",
            specialty: "Internal Medicine"
        )
        #expect(!ProgramSearchMatcher.matches(query: "st", program: universityOfFlorida, stateToAbbrev: emptyStateMap))
    }

    @Test func acronymGenerationSkipsStopWords() {
        let acronym = ProgramSearchMatcher.acronym(from: "Florida State University College of Medicine")
        #expect(acronym.hasPrefix("fsu"))
    }
}
