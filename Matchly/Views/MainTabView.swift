//
//  MainTabView.swift
//  Matchly
//
//  Created by Leoh N. Leon II on 11/14/25.
//

import SwiftUI
import UIKit

struct MainTabView: View {
    @ObservedObject private var dataManager = DataManager.shared
    @State private var selectedTab: Int = 0
    @State private var dashboardRefreshKey: UUID = UUID()
    @State private var isKeyboardVisible: Bool = false
    
    var body: some View {
        Group {
            if selectedTab == 0 {
                MatchlyNavigationView {
                    DashboardView(selectedTab: $selectedTab)
                        .matchlyReadableWidth()
                }
                .id("dashboard-\(dashboardRefreshKey)") // Force refresh when key changes
            } else if selectedTab == 1 {
                ProgramsListView()
            } else if selectedTab == 2 {
                RankListView()
            } else if selectedTab == 3 {
                ProgramsMapView()
            } else if selectedTab == 4 {
                SettingsView()
            }
        }
        .matchlyRootContentFrame()
        .matchlyAdaptiveLayout()
        .background(AppColors.dashboardCanvas.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !isKeyboardVisible {
                LiquidGlassTabBar(selectedTab: $selectedTab)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .environmentObject(dataManager)
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("PopToRoot"))) { _ in
            // Refresh Dashboard view to pop any navigation stacks
            dashboardRefreshKey = UUID()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            withAnimation(.easeInOut(duration: 0.25)) {
                isKeyboardVisible = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(.easeInOut(duration: 0.25)) {
                isKeyboardVisible = false
            }
        }
    }
}

#Preview {
    MainTabView()
}

