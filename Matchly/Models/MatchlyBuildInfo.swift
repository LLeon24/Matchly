//
//  MatchlyBuildInfo.swift
//  Matchly
//
//  Visible build identity — reads Version and Build from the app bundle (Xcode target settings).
//

import Foundation

enum MatchlyBuildInfo {
    private static var bundle: Bundle { .main }

    /// User-facing version in Settings, e.g. "1.0.0 (22)" — matches Xcode Archives.
    static var version: String {
        let short = bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let build = bundle.infoDictionary?["CFBundleVersion"] as? String ?? "0"
        return "\(short) (\(build))"
    }

    /// Short baseline tag — visible in Settings → About to confirm Mac sync.
    static let recoveryTag = "auth-baseline-23"

    static var displayLabel: String { "\(version) · \(recoveryTag)" }
}
