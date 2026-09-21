//
//  WidgetInstallationCheckerTests.swift
//  MatchlyTests
//

import XCTest
@testable import Matchly

final class WidgetInstallationCheckerTests: XCTestCase {
    func testWidgetInstallationCheckCompletes() async {
        _ = await WidgetInstallationChecker.isMatchlyWidgetInstalled()
    }
}
