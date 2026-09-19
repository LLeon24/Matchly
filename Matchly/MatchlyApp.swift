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
    @ObservedObject private var dataManager = DataManager.shared

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
        DispatchQueue.main.async {
            MatchlyScreenshotSeed.applyIfRequested()
        }
    }

    var body: some Scene {
        WindowGroup {
            SplashView()
                .preferredColorScheme(dataManager.preferences.appearanceMode.preferredColorScheme)
                .arialFont()
                .environmentObject(deepLinkHandler)
                .environmentObject(coupleSync)
                .environmentObject(dataManager)
                .onOpenURL { url in
                    if GIDSignIn.sharedInstance.handle(url) {
                        return
                    }
                    deepLinkHandler.handle(url: url)
                }
        }
    }
}

final class CoupleDeepLinkHandler: ObservableObject {
    @Published var pendingCoupleCode: String?
    @Published private(set) var shouldOpenInterviewsTab = false
    @Published private(set) var pendingInterviewsListFocus: InterviewsListFocus?
    @Published private(set) var pendingProgramsListFocus: ProgramsListFocus?

    enum InterviewsListFocus: Equatable {
        case needDate
        case upcoming
        case past
    }

    enum ProgramsListFocus: Equatable {
        case incomplete
    }

    func handle(url: URL) {
        if Self.isInterviewsURL(url) {
            shouldOpenInterviewsTab = true
            return
        }
        guard FeatureFlags.couplesMatchEnabled,
              let code = Couple.parseLinkPayload(url.absoluteString) else { return }
        pendingCoupleCode = code
    }

    func requestInterviewsListFocus(_ focus: InterviewsListFocus) {
        pendingInterviewsListFocus = focus
    }

    func consumeInterviewsListFocus() -> InterviewsListFocus? {
        defer { pendingInterviewsListFocus = nil }
        return pendingInterviewsListFocus
    }

    func requestProgramsListFocus(_ focus: ProgramsListFocus) {
        pendingProgramsListFocus = focus
    }

    func consumeProgramsListFocus() -> ProgramsListFocus? {
        defer { pendingProgramsListFocus = nil }
        return pendingProgramsListFocus
    }

    func consumeInterviewsNavigation() {
        shouldOpenInterviewsTab = false
    }

    func consumePendingCode() -> String? {
        defer { pendingCoupleCode = nil }
        return pendingCoupleCode
    }

    private static func isInterviewsURL(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == "matchly" else { return false }
        if url.host?.lowercased() == "interviews" { return true }
        let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return path.lowercased() == "interviews"
    }
}
