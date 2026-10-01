//
//  AppStoreScreenshotTests.swift
//  MatchlyUITests
//
//  Captures marketing / App Store screenshots with demo seed data.
//  Run: xcodebuild test -scheme Matchly -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -only-testing:MatchlyUITests/AppStoreScreenshotTests
//

import XCTest

final class AppStoreScreenshotTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testCaptureAppStoreScreenshots() throws {
        let app = XCUIApplication()
        app.launchArguments.append("-MatchlyScreenshotSeed")
        app.launch()

        dismissFeatureTourIfPresent(in: app)
        dismissSystemAlertsIfPresent(in: app)
        sleep(2)

        // 1 — Hero overview (scores, pipeline, quick actions)
        capture(app, name: "01-Dashboard")

        // 2 — Program library with scores, signals, interview metadata
        tapTab("My Programs", in: app)
        capture(app, name: "02-Programs-List")

        // 3 — Side-by-side program comparison
        tapButton(containing: "Compare", in: app)
        sleep(1)
        capture(app, name: "03-Program-Compare")
        popNavigation(in: app)

        // 4 — Match rank order + red-flag grouping
        tapTab("Rank List", in: app)
        capture(app, name: "04-Rank-List")

        // 5 — Interview season pipeline
        tapTab("Interviews", in: app)
        capture(app, name: "05-Interviews")

        // 6 — Rich program record (questionnaire + interview prep entry)
        tapTab("My Programs", in: app)
        tapProgram(named: "Johns Hopkins", in: app)
        sleep(1)
        capture(app, name: "06-Program-Detail")

        // 7 — Interview prep workflow
        if tapIfExists(app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Interview Prep'")).firstMatch, in: app) {
            sleep(1)
            capture(app, name: "07-Interview-Prep")
            popNavigation(in: app)
        } else {
            capture(app, name: "07-Interview-Prep-Skipped")
        }
        popNavigation(in: app)

        // 8 — Preferences (EMR, questionnaire, account)
        tapTab("Settings", in: app)
        capture(app, name: "08-Settings")

        // 9 — Dashboard return (widgets / season snapshot for mockup variety)
        tapTab("Dashboard", in: app)
        sleep(1)
        capture(app, name: "09-Dashboard-Season")
    }

    @MainActor
    private func tapTab(_ title: String, in app: XCUIApplication) {
        let tab = app.buttons.matching(NSPredicate(format: "label == %@", title)).firstMatch
        if !tab.waitForExistence(timeout: 12) {
            let fallback = app.staticTexts.matching(NSPredicate(format: "label == %@", title)).firstMatch
            XCTAssertTrue(fallback.waitForExistence(timeout: 4), "Missing tab: \(title)")
            fallback.tap()
        } else if tab.isHittable {
            tab.tap()
        } else {
            tab.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
        sleep(1)
    }

    @MainActor
    private func tapButton(containing labelFragment: String, in app: XCUIApplication) {
        let button = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", labelFragment)).firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 8), "Missing button containing: \(labelFragment)")
        button.tap()
    }

    @MainActor
    private func tapProgram(named fragment: String, in app: XCUIApplication) {
        let cell = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", fragment)).firstMatch
        XCTAssertTrue(cell.waitForExistence(timeout: 8), "Missing program: \(fragment)")
        cell.tap()
    }

    @MainActor
    @discardableResult
    private func tapIfExists(_ element: XCUIElement, in app: XCUIApplication) -> Bool {
        guard element.waitForExistence(timeout: 4) else { return false }
        element.tap()
        return true
    }

    @MainActor
    private func popNavigation(in app: XCUIApplication) {
        let back = app.navigationBars.buttons.firstMatch
        if back.waitForExistence(timeout: 2), back.isHittable {
            back.tap()
            sleep(1)
        }
    }

    @MainActor
    private func dismissFeatureTourIfPresent(in app: XCUIApplication) {
        let skip = app.buttons["Skip"].firstMatch
        if skip.waitForExistence(timeout: 3) {
            skip.tap()
        }
    }

    @MainActor
    private func dismissSystemAlertsIfPresent(in app: XCUIApplication) {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = springboard.buttons["Allow"].firstMatch
        if allow.waitForExistence(timeout: 2) {
            allow.tap()
        }
    }

    @MainActor
    private func capture(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
