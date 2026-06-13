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
    @State private var showSplash = true
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0
    
    var body: some View {
        Group {
            if showSplash {
                // Splash screen
                ZStack {
                    AppColors.dashboardCanvas
                        .ignoresSafeArea()
                    
                    VStack(spacing: 20) {
                        Spacer()
                        
                        // Matchly app icon
                        Image("MatchlyIcon")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 120, height: 120)
                            .cornerRadius(26) // iOS app icon corner radius
                            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                            .scaleEffect(scale)
                            .opacity(opacity)
                        
                        // App name - clean, professional typography
                        Text("Matchly")
                            .font(.arial(size: 36, weight: .semibold, design: .default))
                            .foregroundColor(.primary)
                            .opacity(opacity)
                        
                        // Tagline - subtle and professional
                        Text("Residency Match Management")
                            .font(.arial(size: 15, weight: .regular))
                            .foregroundColor(.secondary)
                            .opacity(opacity)
                        
                        Spacer()
                    }
                }
                .onAppear {
                    // Smooth fade-in animation
                    withAnimation(.easeOut(duration: 0.6)) {
                        scale = 1.0
                        opacity = 1.0
                    }
                    
                    // Navigate after brief display
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        withAnimation(.easeIn(duration: 0.3)) {
                            opacity = 0
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
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
    }
    
    @ViewBuilder
    private var contentView: some View {
        // Check authentication first
        if authManager.authState == .signedOut {
            AuthenticationView()
        } else if dataManager.preferences.hasCompletedOnboarding {
            MainTabView()
        } else {
            OnboardingFlowView()
        }
    }
}

#Preview {
    SplashView()
}

