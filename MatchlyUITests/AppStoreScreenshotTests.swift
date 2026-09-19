//
//  AppStoreScreenshotTests.swift
//  MatchlyUITests
//
//  Captures App Store screenshots after signing in on the simulator.
//  Run: xcodebuild test -scheme Matchly -destination 'platform=iOS Simulator,name=iPhone 16 Pro Max' -only-testing:MatchlyUITests/AppStoreScreenshotTests
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

        // Skip auth/onboarding overlays if they appear (demo data marks onboarding complete).
        dismissFeatureTourIfPresent(in: app)
        sleep(2)

        capture(app, name: "01-Dashboard")
        tapTab("My Programs", in: app)
        capture(app, name: "02-Programs")
        tapTab("Interviews", in: app)
        capture(app, name: "03-Interviews-List")
        tapTab("Rank List", in: app)
        capture(app, name: "04-Rank-List")
        tapTab("Settings", in: app)
        capture(app, name: "05-Settings")
    }

    @MainActor
    private func tapTab(_ title: String, in app: XCUIApplication) {
        let tab = app.buttons[title].firstMatch
        XCTAssertTrue(tab.waitForExistence(timeout: 8), "Missing tab: \(title)")
        tab.tap()
        sleep(1)
    }

    @MainActor
    private func dismissFeatureTourIfPresent(in app: XCUIApplication) {
        let skip = app.buttons["Skip"].firstMatch
        if skip.waitForExistence(timeout: 3) {
            skip.tap()
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
