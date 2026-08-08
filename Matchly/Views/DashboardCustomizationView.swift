//
//  DashboardCustomizationView.swift
//  Matchly
//
//  Created on 11/23/25.
//

import SwiftUI
import Combine

private struct DashboardSectionInfo: Identifiable {
    let id: String
    let title: String
    let icon: String
    let tint: Color
    let description: String
}

struct DashboardCustomizationView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) private var dismiss

    @State private var draftPreferences = DashboardPreferences()
    @State private var dashboardOrder: [String] = []
    @State private var disabledSections: Set<String> = []

    private static let allSections: [DashboardSectionInfo] = [
        DashboardSectionInfo(
            id: "overviewHero",
            title: "Interview Season",
            icon: "sparkles",
            tint: AppColors.accentOrange,
            description: "Season progress, program count, and key stats"
        ),
        DashboardSectionInfo(
            id: "needsAttention",
            title: "Needs Attention",
            icon: "bell.badge.fill",
            tint: AppColors.accentPink,
            description: "Actionable to-dos and reminders"
        ),
        DashboardSectionInfo(
            id: "analytics",
            title: "Signals & Status",
            icon: "star.circle.fill",
            tint: AppColors.accentPink,
            description: "ERAS signal usage by specialty plus review and red-flag follow-up"
        ),
        DashboardSectionInfo(
            id: "quickActions",
            title: "Quick Actions",
            icon: "bolt.fill",
            tint: AppColors.accentYellow,
            description: "Add Program, My Programs, Rank List"
        ),
        DashboardSectionInfo(
            id: "programsCompare",
            title: "Compare Programs",
            icon: "square.grid.2x2",
            tint: AppColors.primaryBlue,
            description: "Side-by-side scores and details for 2–4 programs"
        )
    ]

    var body: some View {
        MatchlyNavigationView {
            List {
                Section {
                    Text("Choose what appears on your dashboard and reorder sections to match your workflow. The greeting bar at the top is always visible.")
                        .font(.arial(size: 13))
                        .foregroundColor(.secondary)
                        .padding(.vertical, 4)
                        .glassPanelStyle(cornerRadius: 14)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowBackground(Color.clear)
                } header: {
                    Text("Dashboard Layout")
                }

                Section {
                    ForEach(dashboardOrder, id: \.self) { sectionId in
                        if let section = Self.allSections.first(where: { $0.id == sectionId }) {
                            DashboardSectionRow(
                                section: section,
                                isEnabled: !disabledSections.contains(sectionId),
                                onToggle: {
                                    if disabledSections.contains(sectionId) {
                                        disabledSections.remove(sectionId)
                                    } else {
                                        disabledSections.insert(sectionId)
                                    }
                                }
                            )
                        }
                    }
                    .onMove { source, destination in
                        dashboardOrder.move(fromOffsets: source, toOffset: destination)
                    }
                } footer: {
                    Text("Interview Season includes the key metrics row. Needs Attention and Signals & Status stay near the top by default.")
                }

                Section {
                    Button("Reset to Defaults") {
                        resetToDefaults()
                    }
                    .foregroundColor(.red)
                }
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle("Customize Dashboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        saveCustomization()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .buttonStyle(.glassProminent)
                    .tint(AppColors.primaryBlue)
                }
            }
            .scrollContentBackground(.hidden)
            .appCanvasBackground()
            .onAppear {
                loadCurrentSettings()
            }
        }
    }

    private func loadCurrentSettings() {
        draftPreferences = dataManager.preferences.dashboardPreferences

        let layout = dataManager.preferences.dashboardLayout
        let normalizedOrder = DashboardLayout.normalizeSectionOrder(
            layout.sectionOrder.isEmpty ? DashboardLayout.defaultSectionOrder : layout.sectionOrder
        )

        dashboardOrder = normalizedOrder.filter { DashboardLayout.dashboardSectionIDs.contains($0) }
        ensureDashboardOrder(&dashboardOrder)

        disabledSections = DashboardLayout.normalizeSectionIDs(layout.disabledSections)
    }

    private func ensureDashboardOrder(_ order: inout [String]) {
        for id in DashboardLayout.dashboardSectionIDs where !order.contains(id) {
            order.append(id)
        }
        order.removeAll { !DashboardLayout.dashboardSectionIDs.contains($0) }
    }

    private func resetToDefaults() {
        draftPreferences = DashboardPreferences()
        dashboardOrder = DashboardLayout.defaultSectionOrder
        disabledSections = []
    }

    private func saveCustomization() {
        var updatedLayout = dataManager.preferences.dashboardLayout
        updatedLayout.sectionOrder = dashboardOrder
        updatedLayout.disabledSections = DashboardLayout.normalizeSectionIDs(disabledSections)

        var prefs = draftPreferences
        prefs.greetingStyle = .timeBased
        prefs.headerSubtitleMode = .motivational
        prefs.showMotivationalMessage = true
        prefs.showSpecialtyCount = false

        dataManager.updateDashboardCustomization(layout: updatedLayout, dashboardPreferences: prefs)
    }
}

private struct DashboardSectionRow: View {
    let section: DashboardSectionInfo
    let isEnabled: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(section.tint.opacity(isEnabled ? 0.16 : 0.08))
                    .frame(width: 34, height: 34)
                Image(systemName: section.icon)
                    .font(.arial(size: 16, weight: .semibold))
                    .foregroundStyle(isEnabled ? section.tint : Color.gray)
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text(section.title)
                    .font(.arial(size: 15, weight: .medium))
                    .foregroundColor(isEnabled ? .primary : .secondary)

                Text(section.description)
                    .font(.arial(size: 12))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { isEnabled },
                set: { _ in onToggle() }
            ))
            .labelsHidden()
        }
        .opacity(isEnabled ? 1.0 : 0.6)
        .contentShape(Rectangle())
    }
}

#Preview {
    DashboardCustomizationView()
        .environmentObject(DataManager.shared)
}
