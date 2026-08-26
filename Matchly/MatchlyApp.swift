//
//  MatchlyApp.swift
//  Matchly
//
//  Created by Leoh N. Leon II on 11/14/25.
//

import SwiftUI
import Combine
import GoogleSignIn
import FirebaseCore

@main
struct MatchlyApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var deepLinkHandler = CoupleDeepLinkHandler()
    @ObservedObject private var coupleSync = CoupleSyncCoordinator.shared

    init() {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        // Finish singleton construction before SplashView / AppDelegate tasks can re-enter them.
        _ = AuthManager.shared
        _ = DataManager.shared
        if FeatureFlags.couplesMatchEnabled {
            DataManager.shared.startCoupleSyncIfNeeded()
        }
    }

    var body: some Scene {
        WindowGroup {
            SplashView()
                .arialFont()
                .environmentObject(deepLinkHandler)
                .environmentObject(coupleSync)
                .onOpenURL { url in
                    if GIDSignIn.sharedInstance.handle(url) {
                        return
                    }
                    guard FeatureFlags.couplesMatchEnabled else { return }
                    deepLinkHandler.handle(url: url)
                }
        }
    }
}

final class CoupleDeepLinkHandler: ObservableObject {
    @Published var pendingCoupleCode: String?

    func handle(url: URL) {
        if let code = Couple.parseLinkPayload(url.absoluteString) {
            pendingCoupleCode = code
        }
    }

    func consumePendingCode() -> String? {
        defer { pendingCoupleCode = nil }
        return pendingCoupleCode
    }
}
