//
//  MatchlyBuildInfo.swift
//  Matchly
//
//  Visible build identity so Xcode/iCloud sync issues are easy to spot in Settings.
//

import Foundation

enum MatchlyBuildInfo {
    /// User-facing app version (Settings → About).
    static let version = "1.0.1"

    /// Short recovery tag — changes when we reset the branch to a known-good baseline.
    static let recoveryTag = "recovery-1"

    static var displayLabel: String { "\(version) · \(recoveryTag)" }
}
