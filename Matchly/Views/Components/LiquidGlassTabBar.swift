//
//  LiquidGlassTabBar.swift
//  Matchly
//
//  Created on 11/14/25.
//

import SwiftUI

struct LiquidGlassTabBar: View {
    @Binding var selectedTab: Int
    @State private var pendingTab: Int? = nil
    
    var body: some View {
        HStack(spacing: 0) {
            TabBarButton(
                icon: "house.fill",
                title: "Dashboard",
                isSelected: selectedTab == 0,
                color: AppColors.primaryBlue
            ) {
                handleTabSelection(targetTab: 0)
            }
            
            TabBarButton(
                icon: "list.bullet",
                title: "My Programs",
                isSelected: selectedTab == 1,
                color: AppColors.accentGreen
            ) {
                handleTabSelection(targetTab: 1)
            }
            
            TabBarButton(
                icon: "chart.bar.fill",
                title: "Rank List",
                isSelected: selectedTab == 2,
                color: AppColors.accentPink
            ) {
                handleTabSelection(targetTab: 2)
            }
            
            TabBarButton(
                icon: "map.fill",
                title: "Map",
                isSelected: selectedTab == 3,
                color: AppColors.accentTeal
            ) {
                handleTabSelection(targetTab: 3)
            }
            
            TabBarButton(
                icon: "gearshape.fill",
                title: "Settings",
                isSelected: selectedTab == 4,
                color: AppColors.accentPurple
            ) {
                handleTabSelection(targetTab: 4)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
        .background(
            ZStack {
                // Glass effect background with blur
                RoundedRectangle(cornerRadius: 28)
                    .fill(.ultraThinMaterial)
                    .shadow(color: Color.black.opacity(0.15), radius: 20, x: 0, y: -5)
                    .shadow(color: Color.white.opacity(0.1), radius: 10, x: 0, y: 2)
                
                // Subtle gradient border
                RoundedRectangle(cornerRadius: 28)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.4),
                                Color.white.opacity(0.15),
                                Color.white.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            }
        )
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 0) // No bottom padding - at absolute bottom
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ProceedWithTabNavigation"))) { _ in
            // Proceed with pending tab navigation after save/discard
            if let tab = pendingTab {
                selectedTab = tab
                pendingTab = nil
            }
        }
    }
    
    private func handleTabSelection(targetTab: Int) {
        // Always check for unsaved changes by posting notification
        // If ProgramEntryView is active, it will intercept and show alert
        NotificationCenter.default.post(
            name: NSNotification.Name("TabBarNavigationRequested"),
            object: nil,
            userInfo: ["targetTab": targetTab]
        )
        
        // Set pending tab and proceed after a brief delay
        // If no alert is shown, navigation will proceed
        pendingTab = targetTab
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Only navigate if still pending (no alert was shown)
            if pendingTab == targetTab {
                // Always set the tab, even if it's the same, to force navigation
                selectedTab = targetTab
                pendingTab = nil
                
                // If already on this tab, scroll to top (for dashboard) or pop to root
                if targetTab == 0 {
                    NotificationCenter.default.post(name: NSNotification.Name("ScrollToTop"), object: nil)
                    // Also post a notification to pop to root if in a navigation stack
                    NotificationCenter.default.post(name: NSNotification.Name("PopToRoot"), object: nil)
                }
            }
        }
    }
}

struct TabBarButton: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack {
                    // Glass background for selected state
                    if isSelected {
                        RoundedRectangle(cornerRadius: 18)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        color.opacity(0.25),
                                        color.opacity(0.15),
                                        color.opacity(0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .background(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 18)
                                    .stroke(
                                        LinearGradient(
                                            colors: [
                                                color.opacity(0.5),
                                                color.opacity(0.3),
                                                color.opacity(0.2)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1.5
                                    )
                            )
                            .shadow(color: color.opacity(0.3), radius: 12, x: 0, y: 4)
                            .shadow(color: Color.white.opacity(0.2), radius: 6, x: 0, y: -2)
                    }
                    
                    Image(systemName: icon)
                        .font(.system(size: isSelected ? 22 : 20, weight: isSelected ? .semibold : .medium))
                        .foregroundColor(isSelected ? color : .secondary)
                        .scaleEffect(isSelected ? 1.1 : 1.0)
                }
                .frame(width: 52, height: 52)
                
                Text(title)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? color : .secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.2)
            .ignoresSafeArea()
        
        VStack {
            Spacer()
            LiquidGlassTabBar(selectedTab: .constant(0))
        }
    }
}

