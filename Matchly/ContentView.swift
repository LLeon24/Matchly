//
//  ContentView.swift
//  Matchly
//
//  Created by Leoh Leon on 11/14/25.
//
//  Preview helper for development — use this to preview views while making changes.
//  The live app launches through SplashView in MatchlyApp.swift, not ContentView.

import SwiftUI

struct ContentView: View {
    @StateObject private var deepLinkHandler = CoupleDeepLinkHandler()
    @ObservedObject private var dataManager = DataManager.shared
    @ObservedObject private var authManager = AuthManager.shared

    var body: some View {
        #if DEBUG
        VStack(spacing: 0) {
            MatchlyDevScreenPicker()
            previewContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .preferredColorScheme(dataManager.preferences.appearanceMode.preferredColorScheme)
        .environmentObject(dataManager)
        .environmentObject(authManager)
        .environmentObject(deepLinkHandler)
        .environmentObject(CoupleSyncCoordinator.shared)
        #else
        MainTabView()
            .preferredColorScheme(dataManager.preferences.appearanceMode.preferredColorScheme)
            .environmentObject(dataManager)
            .environmentObject(authManager)
            .environmentObject(deepLinkHandler)
            .environmentObject(CoupleSyncCoordinator.shared)
        #endif
    }

    #if DEBUG
    @AppStorage(MatchlyDevLauncher.storageKey) private var devScreenRaw = MatchlyDevLauncher.Screen.automatic.rawValue

    private var devScreen: MatchlyDevLauncher.Screen {
        MatchlyDevLauncher.Screen(rawValue: devScreenRaw) ?? .automatic
    }

    @ViewBuilder
    private var previewContent: some View {
        switch devScreen {
        case .automatic, .mainApp:
            MainTabView()
        case .onboarding:
            OnboardingFlowView()
        case .auth:
            AuthenticationView()
        }
    }
    #endif
}

#Preview("Dev Launcher") {
    ContentView()
}

#Preview("Full App") {
    MainTabView()
        .matchlyPreviewEnvironment()
}

#Preview("Onboarding") {
    OnboardingFlowView()
        .matchlyPreviewEnvironment()
}
