//
//  InterviewSeasonPipelineTests.swift
//  MatchlyTests
//

import XCTest
@testable import Matchly

final class InterviewSeasonPipelineTests: XCTestCase {
    func testIncompleteWithoutInterviewDateCountsAsToReview() {
        let program = Program(specialty: "Internal Medicine", hospital: "Test Hospital")

        let stage = InterviewSeasonStage.stage(for: program, preferences: UserPreferences())

        XCTAssertEqual(stage, .toReview)
    }

    func testCompletedQuestionnaireWithoutInterviewDateCountsAsNeedDate() {
        var program = Program(specialty: "Internal Medicine", hospital: "Test Hospital")
        fillQuestionnaire(&program.questionnaire)
        program.interviewDate = nil

        let stage = InterviewSeasonStage.stage(for: program, preferences: UserPreferences())

        XCTAssertEqual(stage, .needDate)
    }

    func testIncompleteWithUpcomingInterviewCountsAsUpcoming() {
        var program = Program(specialty: "Internal Medicine", hospital: "Test Hospital")
        program.interviewDate = Date().addingTimeInterval(86_400)

        let stage = InterviewSeasonStage.stage(for: program, preferences: UserPreferences())

        XCTAssertEqual(stage, .upcoming)
    }

    func testCompletedQuestionnaireWithUpcomingInterviewCountsAsUpcoming() {
        var program = Program(specialty: "Internal Medicine", hospital: "Test Hospital")
        fillQuestionnaire(&program.questionnaire)
        program.interviewDate = Date().addingTimeInterval(86_400)

        let stage = InterviewSeasonStage.stage(for: program, preferences: UserPreferences())

        XCTAssertEqual(stage, .upcoming)
    }

    func testIncompletePastInterviewCountsAsToReview() {
        var program = Program(specialty: "Internal Medicine", hospital: "Test Hospital")
        program.interviewDate = Date().addingTimeInterval(-86_400)

        let stage = InterviewSeasonStage.stage(for: program, preferences: UserPreferences())

        XCTAssertEqual(stage, .toReview)
    }

    func testCompletedPastInterviewCountsAsScored() {
        var program = Program(specialty: "Internal Medicine", hospital: "Test Hospital")
        fillQuestionnaire(&program.questionnaire)
        program.interviewDate = Date().addingTimeInterval(-86_400)

        let stage = InterviewSeasonStage.stage(for: program, preferences: UserPreferences())

        XCTAssertEqual(stage, .scored)
    }

    func testCountsAlignWithProgramsNeedingReviewList() {
        var scoredPast = Program(specialty: "Internal Medicine", hospital: "Scored Program")
        fillQuestionnaire(&scoredPast.questionnaire)
        scoredPast.finalScore = 82
        scoredPast.interviewDate = Date().addingTimeInterval(-86_400)

        var upcoming = Program(specialty: "Internal Medicine", hospital: "Upcoming Program")
        fillQuestionnaire(&upcoming.questionnaire)
        upcoming.interviewDate = Date().addingTimeInterval(86_400)

        var pendingPast = Program(specialty: "Family Medicine", hospital: "Pending Program")
        pendingPast.interviewDate = Date().addingTimeInterval(-86_400)

        let needsReviewNoDate = Program(specialty: "Pediatrics", hospital: "Emory-like Program")

        var scoredNoDate = Program(specialty: "Internal Medicine", hospital: "Scored No Date")
        fillQuestionnaire(&scoredNoDate.questionnaire)

        let counts = InterviewSeasonStage.counts(
            for: [scoredPast, upcoming, pendingPast, needsReviewNoDate, scoredNoDate],
            preferences: UserPreferences()
        )

        XCTAssertEqual(counts[.scored], 1)
        XCTAssertEqual(counts[.upcoming], 1)
        XCTAssertEqual(counts[.toReview], 2)
        XCTAssertEqual(counts[.needDate], 1)
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
