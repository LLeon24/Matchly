//
//  MainTabView.swift
//  Matchly
//
//  Created by Leoh N. Leon II on 11/14/25.
//

import SwiftUI

struct MainTabView: View {
    @StateObject private var dataManager = DataManager.shared
    @State private var selectedTab: Int = 0
    @State private var dashboardRefreshKey: UUID = UUID()
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Content views
            Group {
                if selectedTab == 0 {
                    NavigationView {
                        DashboardView(selectedTab: $selectedTab)
                    }
                    .id("dashboard-\(dashboardRefreshKey)") // Force refresh when key changes
                } else if selectedTab == 1 {
                    ProgramsListView()
                } else if selectedTab == 2 {
                    RankListView()
                } else if selectedTab == 3 {
                    ProgramsMapView()
                } else if selectedTab == 4 {
                    NavigationView {
                        SettingsView()
                    }
                }
            }
            
            // Custom liquid glass tab bar at bottom - positioned at the absolute bottom
            LiquidGlassTabBar(selectedTab: $selectedTab)
                .ignoresSafeArea(.container, edges: .bottom)
        }
        .environmentObject(dataManager)
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("PopToRoot"))) { _ in
            // Refresh Dashboard view to pop any navigation stacks
            dashboardRefreshKey = UUID()
        }
    }
}

#Preview {
    MainTabView()
}

