//
//  SplashView.swift
//  Matchly
//
//  Created by Leoh N. Leon II on 11/14/25.
//

import SwiftUI

struct SplashView: View {
    @ObservedObject private var authManager = AuthManager.shared
    @ObservedObject private var dataManager = DataManager.shared
    @Environment(\.scenePhase) private var scenePhase
    @State private var showSplash = true
    @State private var revealProgress: Double = 0
    @State private var showBiometricSetupAlert = false
    
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
                    withAnimation(.easeOut(duration: 1.0)) {
                        revealProgress = 1
                    }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                        withAnimation(.easeInOut(duration: 0.55)) {
                            revealProgress = 0
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                            showSplash = false
                        }
                    }
                }
            } else {
                // Main content based on auth state
                contentView
            }
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
            if dataManager.preferences.hasCompletedOnboarding {
                MainTabView()
            } else {
                OnboardingFlowView()
            }
        }
    }

    /// Avoid flashing login or main UI while session restoration finishes.
    private var launchPlaceholder: some View {
        AppColors.dashboardCanvas
            .ignoresSafeArea()
    }
}

#Preview {
    SplashView()
}

