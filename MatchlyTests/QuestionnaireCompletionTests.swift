//
//  QuestionnaireCompletionTests.swift
//  MatchlyTests
//

import XCTest
@testable import Matchly

final class QuestionnaireCompletionTests: XCTestCase {
    func testNACountsAsComplete() {
        var questionnaire = Questionnaire()
        let prefs = UserPreferences()

        for sectionIndex in questionnaire.sections.indices {
            let title = questionnaire.sections[sectionIndex].title
            if title.lowercased().contains("red flag") { continue }
            for itemIndex in questionnaire.sections[sectionIndex].items.indices {
                questionnaire.sections[sectionIndex].items[itemIndex].programRating = 6
            }
        }

        XCTAssertEqual(questionnaire.questionnaireCompletionRatio(preferences: prefs), 1.0, accuracy: 0.001)
        XCTAssertFalse(questionnaire.needsScoring(preferences: prefs))
    }

    func testUnansweredEnabledItemsNeedScoring() {
        var questionnaire = Questionnaire()
        let prefs = UserPreferences()

        for sectionIndex in questionnaire.sections.indices {
            let title = questionnaire.sections[sectionIndex].title
            if title.lowercased().contains("red flag") { continue }
            for itemIndex in questionnaire.sections[sectionIndex].items.indices {
                questionnaire.sections[sectionIndex].items[itemIndex].programRating = 4
            }
        }

        // Leave one non–red-flag item unanswered.
        if let sectionIndex = questionnaire.sections.firstIndex(where: {
            !$0.title.lowercased().contains("red flag") && !$0.items.isEmpty
        }) {
            questionnaire.sections[sectionIndex].items[0].programRating = 0
        }

        XCTAssertTrue(questionnaire.needsScoring(preferences: prefs))
        XCTAssertLessThan(questionnaire.questionnaireCompletionRatio(preferences: prefs), 1.0)
    }

    func testDisabledSectionDoesNotBlockCompletion() {
        var questionnaire = Questionnaire()
        var prefs = UserPreferences()

        // Enable only the first non–red-flag section.
        guard let keepSection = questionnaire.sections.first(where: {
            !$0.title.lowercased().contains("red flag")
        }) else {
            return XCTFail("Expected a non–red-flag section")
        }
        prefs.enabledSectionIds = [keepSection.id]

        for itemIndex in questionnaire.sections[0].items.indices
            where questionnaire.sections[0].id == keepSection.id
                || questionnaire.sections.firstIndex(where: { $0.id == keepSection.id }) == 0 {
            // Score only the kept section via index lookup below.
            break
        }

        if let sectionIndex = questionnaire.sections.firstIndex(where: { $0.id == keepSection.id }) {
            for itemIndex in questionnaire.sections[sectionIndex].items.indices {
                questionnaire.sections[sectionIndex].items[itemIndex].programRating = 5
            }
        }

        // Other sections remain at 0, but are disabled — should still be complete.
        XCTAssertEqual(questionnaire.questionnaireCompletionRatio(preferences: prefs), 1.0, accuracy: 0.001)
        XCTAssertFalse(questionnaire.needsScoring(preferences: prefs))
    }
}
