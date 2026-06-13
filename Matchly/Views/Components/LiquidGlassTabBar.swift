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
        // Comfortable vertical breathing room above/below the row. The bottom
        // safe-area inset is handled by the host (MainTabView no longer forces
        // the bar into the safe area), so the row stays clear of the home
        // indicator while the material background still extends to the screen edge.
        .padding(.top, 12)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea(.container, edges: .bottom)
        )
        .overlay(alignment: .top) {
            Divider()
                .opacity(0.5)
        }
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
                // No background shape on selection — only tint/weight change.
                Image(systemName: icon)
                    .font(.arial(size: 22, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? color : .secondary)
                    .frame(height: 28)
                
                Text(title)
                    .font(.arial(size: 10, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? color : .secondary)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
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

