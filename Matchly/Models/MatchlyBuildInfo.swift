//
//  MatchlyBuildInfo.swift
//  Matchly
//
//  Visible build identity — reads Version and Build from the app bundle (Xcode target settings).
//

import Foundation

enum MatchlyBuildInfo {
    private static var bundle: Bundle { .main }

    /// User-facing marketing version in Settings → About, e.g. "1.0.0".
    static var version: String {
        bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    /// Short baseline tag — visible in Settings → About to confirm Mac sync.
    static let recoveryTag = "auth-baseline-23"

    static var displayLabel: String { "\(version) · \(recoveryTag)" }
}
