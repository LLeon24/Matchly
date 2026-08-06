//
//  DashboardCustomizationView.swift
//  Matchly
//
//  Created on 11/23/25.
//

import SwiftUI
import Combine

private enum DashboardCustomizationTab: String {
    case overview = "Overview"
    case programs = "Programs"
    case interviews = "Interviews"
}

private struct DashboardSectionInfo: Identifiable {
    let id: String
    let title: String
    let icon: String
    let tint: Color
    let description: String
    let tab: DashboardCustomizationTab
}

struct DashboardCustomizationView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) private var dismiss

    @State private var draftPreferences = DashboardPreferences()
    @State private var overviewOrder: [String] = []
    @State private var programsOrder: [String] = []
    @State private var interviewsOrder: [String] = []
    @State private var disabledSections: Set<String> = []

    private static let allSections: [DashboardSectionInfo] = [
DashboardSectionInfo(
            id: "overviewHero",
            title: "Interview Season",
            icon: "sparkles",
            tint: AppColors.accentOrange,
            description: "Snapshot hero with progress and key stats",
            tab: .overview
        ),
DashboardSectionInfo(
            id: "needsAttention",
            title: "Needs Attention",
            icon: "bell.badge.fill",
            tint: AppColors.accentPink,
            description: "Actionable to-dos and reminders",
            tab: .overview
        ),
DashboardSectionInfo(
            id: "interviewPipeline",
            title: "Interview Pipeline",
            icon: "line.3.horizontal.decrease",
            tint: AppColors.accentTeal,
            description: "Funnel from invites through ranking",
            tab: .overview
        ),
DashboardSectionInfo(
            id: "quickStats",
            title: "Key Metrics",
            icon: "chart.bar.fill",
            tint: AppColors.primaryBlue,
            description: "Programs, reviews, interviews, top program",
            tab: .overview
        ),
DashboardSectionInfo(
            id: "quickActions",
            title: "Quick Actions",
            icon: "bolt.fill",
            tint: AppColors.accentYellow,
            description: "Add Program, My Programs, Rank List",
            tab: .overview
        ),
DashboardSectionInfo(
            id: "recentActivity",
            title: "Recent Activity",
            icon: "clock.fill",
            tint: AppColors.accentPurple,
            description: "Recently added or updated programs",
            tab: .overview
        ),
DashboardSectionInfo(
            id: "programsScoreDist",
            title: "Score Distribution",
            icon: "chart.bar.fill",
            tint: AppColors.accentGreen,
            description: "How your program scores are spread",
            tab: .programs
        ),
        DashboardSectionInfo(
            id: "topPrograms",
            title: "Top Programs",
            icon: "trophy.fill",
            tint: AppColors.accentYellow,
            description: "Preview of your highest-ranked programs",
            tab: .programs
        ),
        DashboardSectionInfo(
            id: "analytics",
            title: "Signals & Status",
            icon: "star.circle.fill",
            tint: AppColors.accentPink,
            description: "ERAS signal usage plus programs needing review or red-flag follow-up",
            tab: .programs
        ),
DashboardSectionInfo(
            id: "upcomingInterviews",
            title: "Interview Timeline",
            icon: "calendar.badge.clock",
            tint: AppColors.accentTeal,
            description: "Chronological list of upcoming interviews",
            tab: .interviews
        )
    ]

    var body: some View {
        MatchlyNavigationView {
            List {
                Section {
                    Text("Choose what appears on each dashboard tab and reorder sections to match your workflow. The greeting bar at the top is always visible.")
                        .font(.arial(size: 13))
                        .foregroundColor(.secondary)
                        .padding(.vertical, 4)
                        .glassPanelStyle(cornerRadius: 14)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowBackground(Color.clear)
                } header: {
                    Text("Dashboard Layout")
                }

                sectionGroup(
                    title: "Overview Tab",
                    footer: "Sections on the Overview page. On smaller phones, Needs Attention and Interview Pipeline may appear side by side when adjacent.",
                    order: $overviewOrder
                )

                sectionGroup(
                    title: "Programs Tab",
                    footer: "Sections below the Programs Tracked hero.",
                    order: $programsOrder
                )

                sectionGroup(
                    title: "Interviews Tab",
                    footer: "Timeline below the Upcoming Interviews hero.",
                    order: $interviewsOrder
                )

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

    @ViewBuilder
    private func sectionGroup(
        title: String,
        footer: String,
        order: Binding<[String]>
    ) -> some View {
        Section {
            ForEach(order.wrappedValue, id: \.self) { sectionId in
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
                order.wrappedValue.move(fromOffsets: source, toOffset: destination)
            }
        } header: {
            Text(title)
        } footer: {
            Text(footer)
        }
    }

    private func loadCurrentSettings() {
        draftPreferences = dataManager.preferences.dashboardPreferences

        let layout = dataManager.preferences.dashboardLayout
        let normalizedOrder = DashboardLayout.normalizeSectionOrder(
            layout.sectionOrder.isEmpty ? DashboardLayout.defaultSectionOrder : layout.sectionOrder
        )

        overviewOrder = normalizedOrder.filter { DashboardLayout.overviewSectionIDs.contains($0) }
        programsOrder = normalizedOrder.filter {
            DashboardLayout.programsSectionIDs.contains($0) && $0 != "programsCompare"
        }
        interviewsOrder = normalizedOrder.filter { DashboardLayout.interviewsSectionIDs.contains($0) }

        ensureGroupOrder(&overviewOrder, ids: DashboardLayout.overviewSectionIDs)
        ensureGroupOrder(&programsOrder, ids: DashboardLayout.programsSectionIDs.subtracting(["programsCompare"]))
        ensureGroupOrder(&interviewsOrder, ids: DashboardLayout.interviewsSectionIDs)

        disabledSections = DashboardLayout.normalizeSectionIDs(layout.disabledSections)
        disabledSections.remove("programsCompare")
    }

    private func ensureGroupOrder(_ order: inout [String], ids: Set<String>) {
        for id in ids where !order.contains(id) {
            order.append(id)
        }
        order.removeAll { !ids.contains($0) }
    }

    private func resetToDefaults() {
        draftPreferences = DashboardPreferences()
        overviewOrder = DashboardLayout.defaultSectionOrder.filter { DashboardLayout.overviewSectionIDs.contains($0) }
        programsOrder = DashboardLayout.defaultSectionOrder.filter {
            DashboardLayout.programsSectionIDs.contains($0) && $0 != "programsCompare"
        }
        interviewsOrder = DashboardLayout.defaultSectionOrder.filter { DashboardLayout.interviewsSectionIDs.contains($0) }
        disabledSections = []
    }

    private func saveCustomization() {
        var updatedLayout = dataManager.preferences.dashboardLayout
        updatedLayout.sectionOrder = overviewOrder + ["programsCompare"] + programsOrder + interviewsOrder
        var normalizedDisabled = DashboardLayout.normalizeSectionIDs(disabledSections)
        normalizedDisabled.remove("programsCompare")
        updatedLayout.disabledSections = normalizedDisabled

        var prefs = draftPreferences
        // Header bar is fixed for V1: time-based greeting + motivational subtitle.
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
