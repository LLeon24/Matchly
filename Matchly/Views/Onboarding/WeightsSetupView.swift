//
//  WeightsSetupView.swift
//  Matchly
//
//  Created by Leoh N. Leon II on 11/14/25.
//

import SwiftUI

struct WeightsSetupView: View {
    @StateObject private var dataManager = DataManager.shared
    @State private var showMainApp = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Spacer()
                
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.green)
                    
                    Text("You're All Set!")
                        .font(.system(size: 28, weight: .bold))
                    
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
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 50)
            }
            .navigationBarHidden(true)
            .fullScreenCover(isPresented: $showMainApp) {
                MainTabView()
            }
        }
    }
}


#Preview {
    WeightsSetupView()
}

