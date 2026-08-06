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
}
