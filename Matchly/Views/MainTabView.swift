//
//  MainTabView.swift
//  Matchly
//
//  Created by Leoh N. Leon II on 11/14/25.
//

import SwiftUI
import UIKit

private enum FeatureTourMode {
    case full
    case coupleOnly
}

struct MainTabView: View {
    @ObservedObject private var dataManager = DataManager.shared
    @State private var selectedTab: Int = MainTabLayout.dashboardIndex
    @State private var dashboardRefreshKey: UUID = UUID()
    @State private var isKeyboardVisible: Bool = false
    @State private var showFeatureTour = false
    @State private var featureTourStepIndex = 0
    @State private var featureTourMode: FeatureTourMode = .full
    @State private var tourAnchorRects: [String: CGRect] = [:]

    private var isCoupleLinked: Bool {
        FeatureFlags.couplesMatchEnabled && dataManager.preferences.couple?.isLinked == true
    }

    private var featureTourSteps: [FeatureTourStep] {
        switch featureTourMode {
        case .full:
            return AppFeatureTourSteps.steps(isCoupleLinked: isCoupleLinked)
        case .coupleOnly:
            return AppFeatureTourSteps.coupleMatchSteps()
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            AppColors.dashboardCanvas
                .ignoresSafeArea()

            Group {
                switch selectedTab {
                case MainTabLayout.dashboardIndex:
                    MatchlyNavigationView {
                        DashboardView(selectedTab: $selectedTab)
                            .matchlyReadableWidth()
                    }
                    .id("dashboard-\(dashboardRefreshKey)")
                case MainTabLayout.programsIndex:
                    ProgramsListView()
                case MainTabLayout.interviewsIndex:
                    MatchlyNavigationView {
                        InterviewsView()
                            .matchlyReadableWidth()
                    }
                case MainTabLayout.rankListIndex(isCoupleLinked: isCoupleLinked):
                    RankListView()
                case let index where index == MainTabLayout.coupleHubIndex(isCoupleLinked: isCoupleLinked):
                    CouplesHubView()
                case let index where index == MainTabLayout.mapIndex(isCoupleLinked: isCoupleLinked):
                    ProgramsMapView()
                case MainTabLayout.settingsIndex(isCoupleLinked: isCoupleLinked):
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

            if showFeatureTour {
                AppFeatureTourOverlay(
                    steps: featureTourSteps,
                    anchorRects: tourAnchorRects,
                    stepIndex: $featureTourStepIndex,
                    selectedTab: $selectedTab,
                    onFinish: completeFeatureTour,
                    onSkip: completeFeatureTour
                )
                .transition(.opacity)
                .zIndex(10)
            }
        }
        .matchlyAdaptiveLayout()
        .matchlyKeyboardDismissToolbar()
        .environmentObject(dataManager)
        .onAppear {
            if FeatureFlags.couplesMatchEnabled {
                dataManager.startCoupleSyncIfNeeded()
            }
            if !dataManager.preferences.hasCompletedFeatureTour {
                featureTourMode = .full
                showFeatureTour = true
                featureTourStepIndex = 0
            }
        }
        .onPreferenceChange(FeatureTourAnchorPreferenceKey.self) { tourAnchorRects = $0 }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowFeatureTour"))) { _ in
            featureTourMode = .full
            featureTourStepIndex = 0
            selectedTab = MainTabLayout.dashboardIndex
            showFeatureTour = true
        }
        .onChange(of: selectedTab) { oldTab, newTab in
            guard oldTab != newTab else { return }
            VoiceMemoPlayback.stopActivePlayback()
        }
        .onChange(of: isCoupleLinked) { wasLinked, linked in
            if linked && !wasLinked {
                handleCoupleMatchActivated()
            }
            guard wasLinked, !linked else { return }
            if selectedTab == MainTabLayout.coupleHubIndex(isCoupleLinked: true) {
                selectedTab = MainTabLayout.dashboardIndex
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("PopToRoot"))) { _ in
            VoiceMemoPlayback.stopActivePlayback()
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

    private func handleCoupleMatchActivated() {
        guard FeatureFlags.couplesMatchEnabled else { return }

        if showFeatureTour && featureTourMode == .full {
            if let coupleIndex = AppFeatureTourSteps.steps(isCoupleLinked: true).firstIndex(where: { $0.id == "couple" }) {
                featureTourStepIndex = coupleIndex
            }
            return
        }

        guard dataManager.preferences.hasCompletedFeatureTour else { return }
        guard !dataManager.preferences.hasCompletedCoupleFeatureTour else { return }

        featureTourMode = .coupleOnly
        featureTourStepIndex = 0
        selectedTab = MainTabLayout.coupleHubIndex(isCoupleLinked: true) ?? MainTabLayout.dashboardIndex
        showFeatureTour = true
    }

    private func completeFeatureTour() {
        switch featureTourMode {
        case .coupleOnly:
            dataManager.preferences.hasCompletedCoupleFeatureTour = true
        case .full:
            dataManager.preferences.hasCompletedFeatureTour = true
            if isCoupleLinked {
                dataManager.preferences.hasCompletedCoupleFeatureTour = true
            }
        }
        dataManager.savePreferences()
        showFeatureTour = false
        featureTourMode = .full
    }
}

#Preview {
    MainTabView()
}
