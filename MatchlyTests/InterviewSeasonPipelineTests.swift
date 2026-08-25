//
//  InterviewSeasonPipelineTests.swift
//  MatchlyTests
//

import XCTest
@testable import Matchly

final class InterviewSeasonPipelineTests: XCTestCase {
    func testCompletedQuestionnaireCountsAsScoredEvenWithoutInterviewDate() {
        var program = Program(specialty: "Internal Medicine", hospital: "Test Hospital")
        fillQuestionnaire(&program.questionnaire)
        program.interviewDate = nil

        let stage = InterviewSeasonStage.stage(for: program, preferences: UserPreferences())

        XCTAssertEqual(stage, .scored)
    }

    func testCompletedQuestionnaireCountsAsScoredWithUpcomingInterview() {
        var program = Program(specialty: "Internal Medicine", hospital: "Test Hospital")
        fillQuestionnaire(&program.questionnaire)
        program.interviewDate = Date().addingTimeInterval(86_400)

        let stage = InterviewSeasonStage.stage(for: program, preferences: UserPreferences())

        XCTAssertEqual(stage, .scored)
    }

    func testIncompletePastInterviewCountsAsToReview() {
        var program = Program(specialty: "Internal Medicine", hospital: "Test Hospital")
        program.interviewDate = Date().addingTimeInterval(-86_400)

        let stage = InterviewSeasonStage.stage(for: program, preferences: UserPreferences())

        XCTAssertEqual(stage, .toReview)
    }

    func testIncompleteWithoutInterviewDateCountsAsNeedDate() {
        let program = Program(specialty: "Internal Medicine", hospital: "Test Hospital")

        let stage = InterviewSeasonStage.stage(for: program, preferences: UserPreferences())

        XCTAssertEqual(stage, .needDate)
    }

    func testCountsIncludeScoredPrograms() {
        var scored = Program(specialty: "Internal Medicine", hospital: "Scored Program")
        fillQuestionnaire(&scored.questionnaire)
        scored.finalScore = 82

        var pending = Program(specialty: "Family Medicine", hospital: "Pending Program")
        pending.interviewDate = Date().addingTimeInterval(-86_400)

        let counts = InterviewSeasonStage.counts(
            for: [scored, pending],
            preferences: UserPreferences()
        )

        XCTAssertEqual(counts[.scored], 1)
        XCTAssertEqual(counts[.toReview], 1)
    }

    private func fillQuestionnaire(_ questionnaire: inout Questionnaire) {
        for sectionIndex in questionnaire.sections.indices {
            let title = questionnaire.sections[sectionIndex].title
            if title.lowercased().contains("red flag") { continue }
            for itemIndex in questionnaire.sections[sectionIndex].items.indices {
                questionnaire.sections[sectionIndex].items[itemIndex].programRating = 4
            }
        }
    }
}
