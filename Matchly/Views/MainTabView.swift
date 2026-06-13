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
        ZStack(alignment: .bottom) {
            // Canvas behind all tabs so Liquid Glass chrome refracts content.
            AppColors.dashboardCanvas
                .ignoresSafeArea()
            
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
            
            // Custom liquid glass tab bar at bottom - hide when keyboard is visible
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

