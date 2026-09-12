//
//  SectionWeightingTests.swift
//  MatchlyTests
//

import XCTest
@testable import Matchly

final class SectionWeightingTests: XCTestCase {
    func testRebalanceKeepsTotalAt100() {
        let sectionIDs = ["matchly.section.a", "matchly.section.b", "matchly.section.c"]
        let initial = SectionWeighting.equalWeights(for: sectionIDs)
        let rebalanced = SectionWeighting.rebalance(
            changedSectionID: "matchly.section.b",
            newValue: 50,
            current: initial,
            sectionIDs: sectionIDs
        )

        XCTAssertEqual(rebalanced["matchly.section.b"], 50)
        XCTAssertEqual(Int(rebalanced.values.reduce(0, +).rounded()), 100)
    }

    func testCustomSectionNamingUsesNextLetter() {
        let title = QuestionnaireSectionNaming.makeCustomSectionTitle(existingCustomSections: [])
        XCTAssertTrue(title.hasPrefix("Section G —"))
    }

    func testWeightableSectionsIncludesCustomSections() {
        var prefs = UserPreferences()
        prefs.customSections = [
            CustomQuestionnaireSection(title: "Section G — Testing", items: [
                CustomQuestionnaireItem(question: "Sample question")
            ])
        ]
        prefs.enabledSectionIds = []

        let ids = SectionWeighting.weightableSections(preferences: prefs).map(\.id)
        XCTAssertTrue(ids.contains(prefs.customSections[0].id))
    }

    func testRebalancePreservesZeroWeightSections() {
        let sectionIDs = [
            "matchly.section.a",
            "matchly.section.b",
            "matchly.section.c",
            "matchly.section.d",
            "matchly.section.e"
        ]
        var current = SectionWeighting.equalWeights(for: sectionIDs)
        current = SectionWeighting.rebalance(
            changedSectionID: "matchly.section.a",
            newValue: 0,
            current: current,
            sectionIDs: sectionIDs
        )
        XCTAssertEqual(current["matchly.section.a"], 0)

        let after = SectionWeighting.rebalance(
            changedSectionID: "matchly.section.b",
            newValue: 20,
            current: current,
            sectionIDs: sectionIDs
        )

        XCTAssertEqual(after["matchly.section.a"], 0)
        XCTAssertEqual(after["matchly.section.b"], 20)
        XCTAssertEqual(Int(after.values.reduce(0, +).rounded()), 100)
    }

    func testRebalanceSplitsOthersEqually() {
        let sectionIDs = [
            "matchly.section.a",
            "matchly.section.b",
            "matchly.section.c",
            "matchly.section.d",
            "matchly.section.e"
        ]
        let initial = SectionWeighting.equalWeights(for: sectionIDs)
        let rebalanced = SectionWeighting.rebalance(
            changedSectionID: "matchly.section.a",
            newValue: 34,
            current: initial,
            sectionIDs: sectionIDs
        )

        XCTAssertEqual(rebalanced["matchly.section.a"], 34)
        let others = sectionIDs.dropFirst().map { rebalanced[$0] ?? 0 }
        XCTAssertEqual(others.reduce(0, +), 66)
        XCTAssertLessThanOrEqual((others.max() ?? 0) - (others.min() ?? 0), 1)
    }

    func testStandardWeightQuestionsStillAffectTotalScore() {
        var prefs = UserPreferences()
        prefs.sectionWeights = [
            "matchly.section.e": 100
        ]
        prefs.enabledSectionIds = ["matchly.section.e"]
        prefs.weightExcludedQuestionIds = [
            "matchly.section.e.q1",
            "matchly.section.e.q2",
            "matchly.section.e.q3",
            "matchly.section.e.q4",
            "matchly.section.e.q5"
        ]

        var questionnaire = Questionnaire()
        questionnaire.mergeCustomization(from: prefs)

        guard let sectionEIndex = questionnaire.sections.firstIndex(where: { $0.id == "matchly.section.e" }) else {
            XCTFail("Missing section E")
            return
        }

        let items = questionnaire.sections[sectionEIndex].items
        for index in items.indices {
            questionnaire.sections[sectionEIndex].items[index].programRating = 1
        }
        let lastIndex = items.count - 1
        questionnaire.sections[sectionEIndex].items[lastIndex].programRating = 5

        let score = questionnaire.totalWeightedScore(preferences: prefs)
        XCTAssertGreaterThan(score, 0)
        guard let sectionAverage = questionnaire.standardSectionAverage("Section E", preferences: prefs) else {
            XCTFail("Expected section E average")
            return
        }
        XCTAssertEqual(sectionAverage, 10.0 / 6.0, accuracy: 0.001)
    }

    func testNewCustomSectionGetsEqualWeightWhenDefaults() {
        var prefs = UserPreferences()
        prefs.sectionWeights = [:]
        prefs.customSections = [
            CustomQuestionnaireSection(title: "Section G — Testing", items: [
                CustomQuestionnaireItem(question: "Sample question")
            ])
        ]

        let weights = SectionWeighting.redistributedWeights(stored: prefs.sectionWeights, preferences: prefs)
        let sectionIDs = SectionWeighting.weightableSections(preferences: prefs).map(\.id)
        let expected = SectionWeighting.equalWeights(for: sectionIDs)

        XCTAssertEqual(Int(weights.values.reduce(0, +).rounded()), 100)
        XCTAssertEqual(weights[prefs.customSections[0].id], expected[prefs.customSections[0].id])
    }

    func testNewCustomSectionRebalancesCustomizedWeights() {
        var prefs = UserPreferences()
        prefs.sectionWeights = [
            "matchly.section.a": 40,
            "matchly.section.b": 15,
            "matchly.section.c": 15,
            "matchly.section.d": 15,
            "matchly.section.e": 15
        ]
        prefs.customSections = [
            CustomQuestionnaireSection(title: "Section G — Testing", items: [
                CustomQuestionnaireItem(question: "Sample question")
            ])
        ]

        let weights = SectionWeighting.redistributedWeights(stored: prefs.sectionWeights, preferences: prefs)
        let newId = prefs.customSections[0].id

        XCTAssertEqual(Int(weights.values.reduce(0, +).rounded()), 100)
        XCTAssertGreaterThan(weights[newId] ?? 0, 0)
        XCTAssertLessThan(weights["matchly.section.a"] ?? 0, 40)
        XCTAssertLessThan(weights["matchly.section.e"] ?? 0, 15)
    }

    func testNewCustomSectionWithEqualStoredWeightsResplitsEvenly() {
        var prefs = UserPreferences()
        let standardIDs = [
            "matchly.section.a",
            "matchly.section.b",
            "matchly.section.c"
        ]
        prefs.sectionWeights = SectionWeighting.equalWeights(for: standardIDs)
        prefs.enabledSectionIds = Set(standardIDs)
        prefs.customSections = [
            CustomQuestionnaireSection(title: "Section G — Testing", items: [
                CustomQuestionnaireItem(question: "Sample question")
            ])
        ]

        let sectionIDs = SectionWeighting.weightableSections(preferences: prefs).map(\.id)
        let weights = SectionWeighting.redistributedWeights(stored: prefs.sectionWeights, preferences: prefs)
        let expected = SectionWeighting.equalWeights(for: sectionIDs)

        XCTAssertEqual(Int(weights.values.reduce(0, +).rounded()), 100)
        for id in sectionIDs {
            XCTAssertEqual(weights[id], expected[id])
        }
    }

    func testRedistributeAfterSectionDisabled() {
        var prefs = UserPreferences()
        prefs.sectionWeights = [
            "matchly.section.a": 40,
            "matchly.section.b": 30,
            "matchly.section.c": 30
        ]
        prefs.enabledSectionIds = ["matchly.section.a", "matchly.section.c"]

        let redistributed = SectionWeighting.redistributedWeights(stored: prefs.sectionWeights, preferences: prefs)
        XCTAssertEqual(Int(redistributed.values.reduce(0, +).rounded()), 100)
        XCTAssertNil(redistributed["matchly.section.b"])
        XCTAssertGreaterThan(redistributed["matchly.section.a"] ?? 0, redistributed["matchly.section.c"] ?? 0)
    }

    func testWeightedScoreUsesSectionEForEMR() {
        var prefs = UserPreferences()
        prefs.preferredEMR = EMRSystem.epic.rawValue
        prefs.sectionWeights = [
            "matchly.section.a": 10,
            "matchly.section.e": 90
        ]
        prefs.enabledSectionIds = ["matchly.section.a", "matchly.section.e"]

        var questionnaire = Questionnaire()
        questionnaire.mergeCustomization(from: prefs)

        if let sectionAIndex = questionnaire.sections.firstIndex(where: { $0.id == "matchly.section.a" }) {
            for index in questionnaire.sections[sectionAIndex].items.indices {
                questionnaire.sections[sectionAIndex].items[index].programRating = 3
            }
        }

        let matchingScore = questionnaire.totalWeightedScore(
            preferences: prefs,
            programEMR: EMRSystem.epic.rawValue
        )
        let mismatchScore = questionnaire.totalWeightedScore(
            preferences: prefs,
            programEMR: EMRSystem.meditech.rawValue
        )

        XCTAssertGreaterThan(matchingScore, mismatchScore)
    }
}
