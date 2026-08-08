//
//  FeatureFlags.swift
//  Matchly
//
//  Launch switches for unfinished or deferred product surfaces.
//

import Foundation

enum FeatureFlags {
    /// Couples Match (linking, chat, shared rank list) is deferred to V2.
    /// Keep related code compiled; flip to `true` when ready to ship.
    ///
    /// Set to `true` temporarily in a local DEBUG build if you need to polish Couples.
    static let couplesMatchEnabled = false

    /// Programs map tab is deferred for V2.
    /// Keep map code compiled; flip to `true` when ready to ship.
    static let programsMapEnabled = false
}

/// Tab indices for the floating tab bar — accounts for optional Couple and Map tabs.
enum MainTabLayout {
    static let dashboardIndex = 0
    static let programsIndex = 1
    static let interviewsIndex = 2

    static func rankListIndex(isCoupleLinked: Bool) -> Int { 3 }

    static func coupleHubIndex(isCoupleLinked: Bool) -> Int? {
        guard FeatureFlags.couplesMatchEnabled && isCoupleLinked else { return nil }
        return 4
    }

    static func mapIndex(isCoupleLinked: Bool) -> Int? {
        guard FeatureFlags.programsMapEnabled else { return nil }
        var index = 4
        if FeatureFlags.couplesMatchEnabled && isCoupleLinked { index += 1 }
        return index
    }

    static func settingsIndex(isCoupleLinked: Bool) -> Int {
        var index = 4
        if FeatureFlags.couplesMatchEnabled && isCoupleLinked { index += 1 }
        if FeatureFlags.programsMapEnabled { index += 1 }
        return index
    }
}
