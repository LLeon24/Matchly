//
//  WeightsSetupView.swift
//  Matchly
//
//  Created by Leoh N. Leon II on 11/14/25.
//

import SwiftUI

struct WeightsSetupView: View {
    @ObservedObject private var dataManager = DataManager.shared
    @State private var showMainApp = false
    
    var body: some View {
        MatchlyNavigationView {
            VStack(spacing: 30) {
                Spacer()
                
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.arial(size: 60))
                        .foregroundColor(.green)
                    
                    Text("You're All Set!")
                        .font(.arial(size: 28, weight: .bold))
                    
                    Text("We'll use balanced weights for scoring. You can adjust them later in Settings if needed.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                
                Spacer()
                
                Button(action: {
                    // Use default weights - already set in UserPreferences
                    dataManager.preferences.hasCompletedOnboarding = true
                    dataManager.savePreferences()
                    showMainApp = true
                }) {
                    Text("Get Started")
                        .font(.arial(size: 18, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.glassProminent)
                .tint(AppColors.primaryBlue)
                .padding(.horizontal, 40)
                .padding(.bottom, 50)
            }
            .navigationBarHidden(true)
            .appCanvasBackground()
            .fullScreenCover(isPresented: $showMainApp) {
                MainTabView()
            }
        }
    }
}


#Preview {
    WeightsSetupView()
}

