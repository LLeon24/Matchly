//
//  MatchlyBuildInfo.swift
//  Matchly
//
//  Visible build identity so Xcode/iCloud sync issues are easy to spot in Settings.
//

import Foundation

enum MatchlyBuildInfo {
    /// User-facing app version (Settings → About).
    static let version = "1.0.0"

    /// Short baseline tag — visible in Settings → About to confirm Mac sync.
    static let recoveryTag = "auth-baseline-7"

    static var displayLabel: String { "\(version) · \(recoveryTag)" }
}
