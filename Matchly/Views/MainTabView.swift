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

    private var isCoupleLinked: Bool {
        dataManager.preferences.couple?.isLinked == true
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            AppColors.dashboardCanvas
                .ignoresSafeArea()

            Group {
                switch selectedTab {
                case 0:
                    MatchlyNavigationView {
                        DashboardView(selectedTab: $selectedTab)
                            .matchlyReadableWidth()
                    }
                    .id("dashboard-\(dashboardRefreshKey)")
                case 1:
                    ProgramsListView()
                case 2:
                    RankListView()
                case 3 where isCoupleLinked:
                    CouplesHubView()
                case 3:
                    ProgramsMapView()
                case 4 where isCoupleLinked:
                    ProgramsMapView()
                case 4:
                    SettingsView()
                case 5:
                    SettingsView()
                default:
                    MatchlyNavigationView {
                        DashboardView(selectedTab: $selectedTab)
                            .matchlyReadableWidth()
                    }
                }
            }
            .matchlyRootContentFrame()

            if !isKeyboardVisible {
                LiquidGlassTabBar(selectedTab: $selectedTab, isCoupleLinked: isCoupleLinked)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .matchlyAdaptiveLayout()
        .environmentObject(dataManager)
        .onAppear {
            dataManager.startCoupleSyncIfNeeded()
        }
        .onChange(of: isCoupleLinked) { _, linked in
            guard !linked else { return }
            switch selectedTab {
            case 3:
                selectedTab = 0
            case 4:
                selectedTab = 3
            case 5:
                selectedTab = 4
            default:
                break
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("PopToRoot"))) { _ in
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
