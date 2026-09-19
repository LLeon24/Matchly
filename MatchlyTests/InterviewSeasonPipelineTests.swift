//
//  InterviewSeasonPipelineTests.swift
//  MatchlyTests
//

import XCTest
@testable import Matchly

final class InterviewSeasonPipelineTests: XCTestCase {
    func testIncompleteWithoutInterviewDateCountsAsToReviewRingStage() {
        let program = Program(specialty: "Internal Medicine", hospital: "Test Hospital")

        let stage = InterviewSeasonStage.ringStage(for: program, preferences: UserPreferences())

        XCTAssertEqual(stage, .toReview)
    }

    func testCompletedQuestionnaireWithoutInterviewDateUsesNeedDateRingStage() {
        var program = Program(specialty: "Internal Medicine", hospital: "Test Hospital")
        fillQuestionnaire(&program.questionnaire)
        program.finalScore = 82
        program.interviewDate = nil

        let stage = InterviewSeasonStage.ringStage(for: program, preferences: UserPreferences())

        XCTAssertEqual(stage, .needDate)
    }

    func testRankReadyWithoutInterviewDateCountsTowardScoredStat() {
        var program = Program(specialty: "Internal Medicine", hospital: "Test Hospital")
        fillQuestionnaire(&program.questionnaire)
        program.finalScore = 82
        program.interviewDate = nil

        let count = InterviewSeasonStage.statCount(
            .scored,
            for: [program],
            preferences: UserPreferences()
        )

        XCTAssertEqual(count, 1)
    }

    func testMissingInterviewDateCountsTowardNeedDateStat() {
        var program = Program(specialty: "Internal Medicine", hospital: "Test Hospital")
        fillQuestionnaire(&program.questionnaire)
        program.finalScore = 82
        program.interviewDate = nil

        let count = InterviewSeasonStage.statCount(
            .needDate,
            for: [program],
            preferences: UserPreferences()
        )

        XCTAssertEqual(count, 1)
    }

    func testIncompleteWithUpcomingInterviewCountsAsToReviewRingStage() {
        var program = Program(specialty: "Internal Medicine", hospital: "Test Hospital")
        program.interviewDate = Date().addingTimeInterval(86_400)

        let stage = InterviewSeasonStage.ringStage(for: program, preferences: UserPreferences())

        XCTAssertEqual(stage, .toReview)
    }

    func testCompletedQuestionnaireWithUpcomingInterviewCountsAsUpcomingRingStage() {
        var program = Program(specialty: "Internal Medicine", hospital: "Test Hospital")
        fillQuestionnaire(&program.questionnaire)
        program.finalScore = 88
        program.interviewDate = Date().addingTimeInterval(86_400)

        let stage = InterviewSeasonStage.ringStage(for: program, preferences: UserPreferences())

        XCTAssertEqual(stage, .upcoming)
    }

    func testUpcomingInterviewCountsTowardUpcomingStatEvenWhenRankReady() {
        var program = Program(specialty: "Internal Medicine", hospital: "Test Hospital")
        fillQuestionnaire(&program.questionnaire)
        program.finalScore = 88
        program.interviewDate = Date().addingTimeInterval(86_400)

        let count = InterviewSeasonStage.statCount(
            .upcoming,
            for: [program],
            preferences: UserPreferences()
        )

        XCTAssertEqual(count, 1)
    }

    func testIncompletePastInterviewCountsAsToReviewRingStage() {
        var program = Program(specialty: "Internal Medicine", hospital: "Test Hospital")
        program.interviewDate = Date().addingTimeInterval(-86_400)

        let stage = InterviewSeasonStage.ringStage(for: program, preferences: UserPreferences())

        XCTAssertEqual(stage, .toReview)
    }

    func testCompletedPastInterviewCountsAsScoredRingStage() {
        var program = Program(specialty: "Internal Medicine", hospital: "Test Hospital")
        fillQuestionnaire(&program.questionnaire)
        program.finalScore = 82
        program.interviewDate = Date().addingTimeInterval(-86_400)

        let stage = InterviewSeasonStage.ringStage(for: program, preferences: UserPreferences())

        XCTAssertEqual(stage, .scored)
    }

    func testRingCountsAreMutuallyExclusive() {
        var scoredPast = Program(specialty: "Internal Medicine", hospital: "Scored Program")
        fillQuestionnaire(&scoredPast.questionnaire)
        scoredPast.finalScore = 82
        scoredPast.interviewDate = Date().addingTimeInterval(-86_400)

        var upcoming = Program(specialty: "Internal Medicine", hospital: "Upcoming Program")
        fillQuestionnaire(&upcoming.questionnaire)
        upcoming.finalScore = 90
        upcoming.interviewDate = Date().addingTimeInterval(86_400)

        var pendingPast = Program(specialty: "Family Medicine", hospital: "Pending Program")
        pendingPast.interviewDate = Date().addingTimeInterval(-86_400)

        let needsReviewNoDate = Program(specialty: "Pediatrics", hospital: "Emory-like Program")

        var scoredNoDate = Program(specialty: "Internal Medicine", hospital: "Scored No Date")
        fillQuestionnaire(&scoredNoDate.questionnaire)
        scoredNoDate.finalScore = 80

        let counts = InterviewSeasonStage.ringStageCounts(
            for: [scoredPast, upcoming, pendingPast, needsReviewNoDate, scoredNoDate],
            preferences: UserPreferences()
        )

        XCTAssertEqual(counts[.scored], 1)
        XCTAssertEqual(counts[.upcoming], 1)
        XCTAssertEqual(counts[.toReview], 2)
        XCTAssertEqual(counts[.needDate], 1)
        XCTAssertEqual(counts.values.reduce(0, +), 5)
    }

    func testStatCountsCanOverlapAcrossCategories() {
        var scoredPast = Program(specialty: "Internal Medicine", hospital: "Scored Program")
        fillQuestionnaire(&scoredPast.questionnaire)
        scoredPast.finalScore = 82
        scoredPast.interviewDate = Date().addingTimeInterval(-86_400)

        var upcoming = Program(specialty: "Internal Medicine", hospital: "Upcoming Program")
        fillQuestionnaire(&upcoming.questionnaire)
        upcoming.finalScore = 90
        upcoming.interviewDate = Date().addingTimeInterval(86_400)

        var pendingPast = Program(specialty: "Family Medicine", hospital: "Pending Program")
        pendingPast.interviewDate = Date().addingTimeInterval(-86_400)

        let needsReviewNoDate = Program(specialty: "Pediatrics", hospital: "Emory-like Program")

        var scoredNoDate = Program(specialty: "Internal Medicine", hospital: "Scored No Date")
        fillQuestionnaire(&scoredNoDate.questionnaire)
        scoredNoDate.finalScore = 80

        let programs = [scoredPast, upcoming, pendingPast, needsReviewNoDate, scoredNoDate]
        let preferences = UserPreferences()

        XCTAssertEqual(InterviewSeasonStage.statCount(.scored, for: programs, preferences: preferences), 3)
        XCTAssertEqual(InterviewSeasonStage.statCount(.upcoming, for: programs, preferences: preferences), 1)
        XCTAssertEqual(InterviewSeasonStage.statCount(.toReview, for: programs, preferences: preferences), 2)
        XCTAssertEqual(InterviewSeasonStage.statCount(.needDate, for: programs, preferences: preferences), 2)
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
