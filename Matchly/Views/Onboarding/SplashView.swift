//
//  SplashView.swift
//  Matchly
//
//  Created by Leoh N. Leon II on 11/14/25.
//

import SwiftUI
import Combine

struct SplashView: View {
    @ObservedObject private var authManager = AuthManager.shared
    @Environment(\.scenePhase) private var scenePhase
    @State private var showSplash = true
    @State private var revealProgress: Double = 0
    @State private var showBiometricSetupAlert = false
    @State private var appearanceMode: AppearanceMode = DataManager.shared.preferences.appearanceMode
    @State private var hasCompletedOnboarding = DataManager.shared.preferences.hasCompletedOnboarding
    
    var body: some View {
        Group {
            if showSplash {
                // Splash screen
                ZStack {
                    AppColors.dashboardCanvas
                        .ignoresSafeArea()
                    
                    VStack(spacing: 0) {
                        Spacer()

                        MatchlyBrandInlineLockup(glyphSize: .feature)
                            .frame(maxWidth: .infinity)
                            .scaleEffect(0.97 + (0.03 * revealProgress))
                            .opacity(revealProgress)

                        Spacer()
                    }
                }
                .onAppear {
                    if case .signedIn = authManager.authState {
                        showSplash = false
                        return
                    }
                    guard revealProgress == 0 else { return }
                    withAnimation(.easeOut(duration: 0.85)) {
                        revealProgress = 1
                    }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        withAnimation(.easeInOut(duration: 0.45)) {
                            revealProgress = 0
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                            showSplash = false
                        }
                    }
                }
            } else {
                // Main content based on auth state
                contentView
            }
        }
        .preferredColorScheme(appearanceMode.preferredColorScheme)
        .environmentObject(DataManager.shared)
        .onReceive(DataManager.shared.$preferences.map(\.appearanceMode).removeDuplicates()) { mode in
            appearanceMode = mode
        }
        .onReceive(DataManager.shared.$preferences.map(\.hasCompletedOnboarding).removeDuplicates()) { completed in
            hasCompletedOnboarding = completed
        }
        .onAppear {
            appearanceMode = DataManager.shared.preferences.appearanceMode
            hasCompletedOnboarding = DataManager.shared.preferences.hasCompletedOnboarding
        }
        .onChange(of: authManager.authState) { oldValue, newState in
            // React to auth state changes immediately
            if case .signedIn = newState {
                showSplash = false
            }
        }
        .onChange(of: authManager.shouldOfferBiometricSetup) { _, shouldOffer in
            showBiometricSetupAlert = shouldOffer
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                authManager.lockAppIfNeeded()
            } else if newPhase == .active, authManager.isAppLocked, !showSplash {
                authManager.attemptAutomaticBiometricUnlock()
            }
        }
        .onChange(of: showSplash) { _, showing in
            if !showing, authManager.isAppLocked {
                authManager.attemptAutomaticBiometricUnlock()
            }
        }
        .onChange(of: authManager.isAppLocked) { _, locked in
            if locked, !showSplash {
                authManager.attemptAutomaticBiometricUnlock()
            }
        }
        .overlay {
            if !showSplash && authManager.isAppLocked {
                BiometricLockView()
                    .transition(.opacity)
                    .zIndex(20)
            }
        }
        .alert(
            "Use \(authManager.biometricDisplayName)?",
            isPresented: $showBiometricSetupAlert
        ) {
            Button("Not Now", role: .cancel) {
                authManager.declineBiometricSetup()
            }
            Button("Enable \(authManager.biometricDisplayName)") {
                authManager.enableBiometricLogin()
            }
        } message: {
            Text("Quickly unlock Matchly with \(authManager.biometricDisplayName) when you return to the app.")
        }
    }
    
    @ViewBuilder
    private var contentView: some View {
        switch authManager.authState {
        case .loading:
            launchPlaceholder
        case .signedOut:
            AuthenticationView()
        case .signedIn:
            if hasCompletedOnboarding {
                MainTabView()
            } else {
                OnboardingFlowView()
            }
        }
    }

    /// Avoid flashing login or main UI while session restoration finishes.
    private var launchPlaceholder: some View {
        ZStack {
            AppColors.dashboardCanvas
                .ignoresSafeArea()

            VStack(spacing: 18) {
                MatchlyBrandInlineLockup(glyphSize: .feature)
                ProgressView()
                    .tint(AppColors.primaryBlue)
            }
        }
    }
}

#Preview {
    SplashView()
        .environmentObject(CoupleDeepLinkHandler())
        .environmentObject(CoupleSyncCoordinator.shared)
}

