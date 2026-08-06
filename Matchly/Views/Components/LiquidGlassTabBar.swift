//
//  LiquidGlassTabBar.swift
//  Matchly
//
//  Created on 11/14/25.
//

import SwiftUI

struct LiquidGlassTabBar: View {
    @Binding var selectedTab: Int
    var isCoupleLinked: Bool = false
    @State private var pendingTab: Int? = nil
    @Environment(\.matchlyLayout) private var layout

    var body: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 0) {
                TabBarButton(
                    icon: "house.fill",
                    title: "Dashboard",
                    isSelected: selectedTab == 0,
                    color: AppColors.primaryBlue,
                    tourAnchorID: FeatureTourAnchorID.dashboardTab
                ) {
                    handleTabSelection(targetTab: 0)
                }

                TabBarButton(
                    icon: "list.bullet",
                    title: "My Programs",
                    isSelected: selectedTab == 1,
                    color: AppColors.accentGreen,
                    tourAnchorID: FeatureTourAnchorID.programsTab
                ) {
                    handleTabSelection(targetTab: 1)
                }

                TabBarButton(
                    icon: "chart.bar.fill",
                    title: "Rank List",
                    isSelected: selectedTab == 2,
                    color: AppColors.accentPink,
                    tourAnchorID: FeatureTourAnchorID.rankListTab
                ) {
                    handleTabSelection(targetTab: 2)
                }

                if isCoupleLinked {
                    TabBarButton(
                        icon: "heart.fill",
                        title: "Couple",
                        isSelected: selectedTab == 3,
                        color: .pink,
                        tourAnchorID: FeatureTourAnchorID.coupleTab
                    ) {
                        handleTabSelection(targetTab: 3)
                    }
                }

                TabBarButton(
                    icon: "map.fill",
                    title: "Map",
                    isSelected: selectedTab == (isCoupleLinked ? 4 : 3),
                    color: AppColors.accentTeal,
                    tourAnchorID: FeatureTourAnchorID.mapTab
                ) {
                    handleTabSelection(targetTab: isCoupleLinked ? 4 : 3)
                }

                TabBarButton(
                    icon: "gearshape.fill",
                    title: "Settings",
                    isSelected: selectedTab == (isCoupleLinked ? 5 : 4),
                    color: AppColors.accentPurple,
                    tourAnchorID: FeatureTourAnchorID.settingsTab
                ) {
                    handleTabSelection(targetTab: isCoupleLinked ? 5 : 4)
                }
            }
            .padding(.horizontal, layout == .compactVertical ? 8 : 10)
            .padding(.vertical, layout.tabBarVerticalPadding)
            .glassEffect(.regular.interactive(), in: .capsule)
        }
        .padding(.horizontal, layout == .compactVertical ? 12 : 16)
        .padding(.bottom, layout == .compactVertical ? 2 : 4)
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ProceedWithTabNavigation"))) { _ in
            if let tab = pendingTab {
                selectedTab = tab
                pendingTab = nil
            }
        }
    }

    private func handleTabSelection(targetTab: Int) {
        NotificationCenter.default.post(
            name: NSNotification.Name("TabBarNavigationRequested"),
            object: nil,
            userInfo: ["targetTab": targetTab]
        )

        pendingTab = targetTab
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if pendingTab == targetTab {
                selectedTab = targetTab
                pendingTab = nil

                if targetTab == 0 {
                    NotificationCenter.default.post(name: NSNotification.Name("ScrollToTop"), object: nil)
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
    var tourAnchorID: String? = nil
    let action: () -> Void
    @Environment(\.matchlyLayout) private var layout

    var body: some View {
        Button(action: action) {
            VStack(spacing: layout == .compactVertical ? 2 : 4) {
                Image(systemName: icon)
                    .font(.arial(size: layout.tabBarIconFont, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? color : .secondary)
                    .frame(height: layout == .compactVertical ? 22 : 28)

                Text(title)
                    .font(.arial(size: layout.tabBarTitleFont, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? color : .secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, layout == .compactVertical ? 4 : 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .background {
            GeometryReader { proxy in
                Color.clear.preference(
                    key: FeatureTourAnchorPreferenceKey.self,
                    value: tourAnchorID.map { [$0: proxy.frame(in: .global)] } ?? [:]
                )
            }
        }
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.2)
            .ignoresSafeArea()

        VStack {
            Spacer()
            LiquidGlassTabBar(selectedTab: .constant(0), isCoupleLinked: true)
        }
    }
}
