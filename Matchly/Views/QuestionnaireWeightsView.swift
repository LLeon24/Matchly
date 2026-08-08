//
//  QuestionnaireWeightsView.swift
//  Matchly
//
//  Created on 11/18/25.
//

import SwiftUI

struct QuestionnaireWeightsView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var importances: [String: Int] = [:]

    private var questionnaireSections: [(section: QuestionnaireSection, stableId: String)] {
        enabledSections.filter { $0.stableId != EMRScoring.weightKey }
    }

    // Get all enabled sections (excluding red flags), including EMR as a weighted factor.
    private var enabledSections: [(section: QuestionnaireSection, stableId: String)] {
        let questionnaire = Questionnaire()

        var allSections: [(section: QuestionnaireSection, stableId: String)] = questionnaire.sections.map { section in
            (section: section, stableId: section.title)
        }

        let customSections = dataManager.preferences.customSections.map { customSection in
            (section: QuestionnaireSection(
                id: customSection.id,
                title: customSection.title,
                items: customSection.items.map { customItem in
                    QuestionnaireItem(id: customItem.id, question: customItem.question)
                }
            ), stableId: customSection.id)
        }
        allSections.append(contentsOf: customSections)

        var filtered = allSections.filter { item in
            let section = item.section
            if !dataManager.preferences.enabledSectionIds.isEmpty {
                if section.title.contains("Section A") || section.title.contains("Section B") ||
                   section.title.contains("Section C") || section.title.contains("Section D") ||
                   section.title.contains("Section E") || section.title.contains("Section F") {
                    if !dataManager.preferences.enabledSectionIds.contains(section.title) &&
                       !dataManager.preferences.enabledSectionIds.contains(section.id) {
                        return false
                    }
                } else {
                    if !dataManager.preferences.enabledSectionIds.contains(section.id) {
                        return false
                    }
                }
            }
            if section.title.contains("Red flags") {
                return false
            }
            return true
        }

        filtered.append((
            section: QuestionnaireSection(id: EMRScoring.weightKey, title: EMRScoring.weightKey, items: []),
            stableId: EMRScoring.weightKey
        ))

        return filtered
    }

    var body: some View {
        Form {
            Section {
                Picker("Your preferred EMR", selection: Binding(
                    get: { dataManager.preferences.preferredEMR ?? "" },
                    set: { newValue in
                        dataManager.preferences.preferredEMR = newValue.isEmpty ? nil : newValue
                        dataManager.savePreferences()
                        dataManager.recalculateAllScores()
                    }
                )) {
                    Text("Not set").tag("")
                    ForEach(EMRSystem.allCases) { system in
                        Text(system.displayName).tag(system.rawValue)
                    }
                }
                .pickerStyle(.menu)

                ImportanceSliderRow(
                    title: "How much does EMR matter?",
                    importance: importanceBinding(for: EMRScoring.weightKey)
                )
            } header: {
                Text("Electronic Medical Record (EMR)")
            } footer: {
                Text("Programs using your preferred EMR score higher on this factor. \"Other\" or \"Not sure\" is treated as neutral.")
            }

            Section {
                ForEach(questionnaireSections, id: \.stableId) { item in
                    ImportanceSliderRow(
                        title: item.section.title,
                        importance: importanceBinding(for: item.stableId)
                    )
                }
            } header: {
                Text("Section Priorities")
            } footer: {
                Text("Slide to show what matters most to you. Everything balances automatically—no percentages needed.")
            }

            Section {
                Button(action: resetToEqualImportance) {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                        Text("Reset to Equal Priority")
                    }
                    .foregroundColor(.blue)
                }
            }
        }
        .padding(.bottom, 90)
        .navigationTitle("Section Weights")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .appCanvasBackground()
        .onAppear {
            loadImportances()
        }
        .onChange(of: enabledSections.count) { oldCount, newCount in
            if oldCount != newCount {
                loadImportances()
            }
        }
    }

    private func importanceBinding(for stableId: String) -> Binding<Int> {
        Binding(
            get: { importances[stableId] ?? 3 },
            set: { newValue in
                importances[stableId] = newValue
                persistWeights()
            }
        )
    }

    private func loadImportances() {
        guard !enabledSections.isEmpty else {
            importances = [:]
            return
        }

        let savedWeights = dataManager.preferences.sectionWeights
        let sectionIds = enabledSections.map(\.stableId)

        if savedWeights.isEmpty {
            importances = Dictionary(uniqueKeysWithValues: sectionIds.map { ($0, 3) })
            return
        }

        var resolvedWeights: [String: Double] = [:]
        for item in enabledSections {
            if let weight = savedWeights[item.stableId] {
                resolvedWeights[item.stableId] = weight
            } else if let weight = savedWeights[item.section.title] {
                resolvedWeights[item.stableId] = weight
            }
        }

        if resolvedWeights.isEmpty {
            importances = Dictionary(uniqueKeysWithValues: sectionIds.map { ($0, 3) })
            return
        }

        for item in enabledSections where resolvedWeights[item.stableId] == nil {
            resolvedWeights[item.stableId] = 0
        }

        let minWeight = resolvedWeights.values.min() ?? 0
        let maxWeight = resolvedWeights.values.max() ?? 1

        importances = Dictionary(uniqueKeysWithValues: enabledSections.map { item in
            let weight = resolvedWeights[item.stableId] ?? 0
            let importance: Int
            if maxWeight - minWeight < 0.0001 {
                importance = 3
            } else {
                let normalized = (weight - minWeight) / (maxWeight - minWeight)
                importance = max(1, min(5, Int(round(1 + normalized * 4))))
            }
            return (item.stableId, importance)
        })
    }

    private func resetToEqualImportance() {
        importances = Dictionary(uniqueKeysWithValues: enabledSections.map { ($0.stableId, 3) })
        persistWeights()
    }

    private func weightsFromImportances() -> [String: Double] {
        let total = enabledSections.reduce(0) { sum, item in
            sum + Double(importances[item.stableId] ?? 3)
        }
        guard total > 0 else {
            let equal = 1.0 / Double(max(enabledSections.count, 1))
            return Dictionary(uniqueKeysWithValues: enabledSections.map { ($0.stableId, equal) })
        }
        return Dictionary(uniqueKeysWithValues: enabledSections.map { item in
            (item.stableId, Double(importances[item.stableId] ?? 3) / total)
        })
    }

    private func persistWeights() {
        dataManager.preferences.sectionWeights = weightsFromImportances()
        dataManager.savePreferences()
        dataManager.recalculateAllScores()
    }
}

// MARK: - Importance Slider

private struct ImportanceSliderRow: View {
    let title: String
    @Binding var importance: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.arial(size: 15, weight: .medium))

            HStack {
                Text("Not important")
                    .font(.arial(size: 11))
                    .foregroundColor(.secondary)

                Spacer()

                Text(Self.label(for: importance))
                    .font(.arial(size: 12, weight: .semibold))
                    .foregroundColor(AppColors.primaryBlue)

                Spacer()

                Text("Most important")
                    .font(.arial(size: 11))
                    .foregroundColor(.secondary)
            }

            Slider(
                value: Binding(
                    get: { Double(importance) },
                    set: { importance = Int($0.rounded()) }
                ),
                in: 1...5,
                step: 1
            )
            .tint(AppColors.primaryBlue)
        }
        .padding(.vertical, 4)
    }

    static func label(for value: Int) -> String {
        switch value {
        case 1: return "Not important"
        case 2: return "Low"
        case 3: return "Medium"
        case 4: return "High"
        default: return "Most important"
        }
    }
}

#Preview {
    MatchlyNavigationView {
        QuestionnaireWeightsView()
            .environmentObject(DataManager.shared)
    }
}
