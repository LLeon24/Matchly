//
//  SectionWeightsView.swift
//  Matchly
//

import SwiftUI

struct SectionWeightsView: View {
    @ObservedObject private var dataManager = DataManager.shared
    @State private var weights: [String: Double] = [:]
    @State private var expandedSectionIDs: Set<String> = []

    private var sections: [QuestionnaireSection] {
        SectionWeighting.weightableSections(preferences: dataManager.preferences)
    }

    private var totalWeight: Int {
        Int(sections.reduce(0.0) { $0 + (weights[$1.id] ?? 0) }.rounded())
    }

    var body: some View {
        MatchlyNavigationView {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Adjust how much each questionnaire section influences your program scores.")
                            .font(.arial(size: 14))
                            .foregroundColor(.secondary)

                        VStack(alignment: .leading, spacing: 6) {
                            instructionRow("Drag a slider to rebalance the other weighted sections. Sections at 0% stay excluded.")
                            instructionRow("Expand question weighting to choose which questions use that section's slider weight.")
                            instructionRow("Unchecked questions still affect your score using equal standard weighting.")
                            instructionRow("Section E includes program EMR fit when your preferred EMR is set.")
                        }

                        HStack {
                            Text("Total")
                                .font(.arial(size: 15, weight: .semibold))
                            Spacer()
                            Text("\(totalWeight)%")
                                .font(.arial(size: 15, weight: .bold))
                                .foregroundColor(totalWeight == 100 ? AppColors.accentGreen : AppColors.pipelineNeedDate)
                        }
                        .padding(.top, 2)
                    }
                    .padding(.vertical, 4)
                }

                Section {
                    if sections.isEmpty {
                        Text("Enable questionnaire sections in Customize Questionnaire to set weights.")
                            .font(.arial(size: 14))
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(sections) { section in
                            sectionWeightCard(for: section)
                                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                                .listRowBackground(Color.clear)
                        }
                    }
                } header: {
                    MatchlyFormSectionHeader(title: "Section Weights")
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .appCanvasBackground()
            .matchlyScrollTabBarClearance()
            .navigationTitle("Section Weights")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Reset") {
                        resetToEqual()
                    }
                    .disabled(sections.isEmpty)
                }
            }
            .onAppear {
                loadWeights()
            }
            .onChange(of: dataManager.preferences.enabledSectionIds) { _, _ in
                loadWeights()
            }
            .onChange(of: dataManager.preferences.customSections) { _, _ in
                loadWeights()
            }
        }
    }

    @ViewBuilder
    private func sectionWeightCard(for section: QuestionnaireSection) -> some View {
        let isExpanded = expandedSectionIDs.contains(section.id)
        let questions = SectionWeighting.scoreableQuestions(for: section, preferences: dataManager.preferences)
        let sectionTint = sectionColor(for: section.id)

        VStack(alignment: .leading, spacing: 12) {
            WeightSlider(
                title: SectionWeighting.displayTitle(for: section),
                value: binding(for: section.id),
                color: sectionTint
            )

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if isExpanded {
                        expandedSectionIDs.remove(section.id)
                    } else {
                        expandedSectionIDs.insert(section.id)
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Text("Question weighting")
                        .font(.arial(size: 13, weight: .semibold))
                        .foregroundColor(.primary)
                    Spacer()
                    Text("\(questions.count)")
                        .font(.arial(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(sectionTint)
                }
                .padding(.vertical, 2)
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Checked questions use this section's slider weight. Unchecked questions still count at standard equal weight.")
                        .font(.arial(size: 12))
                        .foregroundColor(.secondary)

                    if questions.isEmpty {
                        Text("No enabled questions in this section.")
                            .font(.arial(size: 13))
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(questions) { item in
                            questionWeightingRow(item: item, section: section, sectionTint: sectionTint)
                        }
                    }

                    if section.id == SectionWeighting.sectionEId, showsEMRScoring {
                        emrScoringRow
                    }
                }
                .padding(.top, 4)
            }
        }
    }

    private func questionWeightingRow(
        item: QuestionnaireItem,
        section: QuestionnaireSection,
        sectionTint: Color
    ) -> some View {
        let usesCustomWeight = SectionWeighting.itemUsesCustomSectionWeight(
            item,
            section: section,
            preferences: dataManager.preferences
        )

        return HStack(alignment: .top, spacing: 10) {
            Button {
                toggleQuestionWeighting(item: item, section: section, usesCustomWeight: usesCustomWeight)
            } label: {
                Image(systemName: usesCustomWeight ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(usesCustomWeight ? sectionTint : Color(.systemGray3))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(usesCustomWeight ? "Uses section weight" : "Uses standard weight")

            VStack(alignment: .leading, spacing: 2) {
                Text(item.question)
                    .font(.arial(size: 13))
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(usesCustomWeight ? "Uses section weight" : "Standard weight")
                    .font(.arial(size: 11))
                    .foregroundColor(usesCustomWeight ? sectionTint : .secondary)
            }
        }
    }

    private var emrScoringRow: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 22))
                .foregroundColor(.teal)
            VStack(alignment: .leading, spacing: 2) {
                Text("Program EMR fit")
                    .font(.arial(size: 13, weight: .medium))
                Text("Always uses Section E's slider weight when your preferred EMR is set.")
                    .font(.arial(size: 12))
                    .foregroundColor(.secondary)
            }
        }
    }

    private var showsEMRScoring: Bool {
        guard let preferredRaw = dataManager.preferences.preferredEMR,
              let preferred = EMRSystem(rawValue: preferredRaw) else {
            return false
        }
        return preferred.isSpecific
    }

    private func toggleQuestionWeighting(
        item: QuestionnaireItem,
        section: QuestionnaireSection,
        usesCustomWeight: Bool
    ) {
        var standardWeightIds = dataManager.preferences.weightExcludedQuestionIds
        if usesCustomWeight {
            standardWeightIds.insert(item.id)
            if let stableId = Questionnaire.stableItemId(forQuestion: item.question, sectionTitle: section.title) {
                standardWeightIds.insert(stableId)
            }
        } else {
            standardWeightIds.remove(item.id)
            if let stableId = Questionnaire.stableItemId(forQuestion: item.question, sectionTitle: section.title) {
                standardWeightIds.remove(stableId)
            }
        }
        dataManager.preferences.weightExcludedQuestionIds = standardWeightIds
        dataManager.savePreferences()
        dataManager.recalculateAllScores()
    }

    private func binding(for sectionID: String) -> Binding<Double> {
        Binding(
            get: { weights[sectionID] ?? 0 },
            set: { newValue in
                let sectionIDs = sections.map(\.id)
                weights = SectionWeighting.rebalance(
                    changedSectionID: sectionID,
                    newValue: newValue,
                    current: weights,
                    sectionIDs: sectionIDs
                )
                persistWeights()
            }
        )
    }

    private func loadWeights() {
        weights = SectionWeighting.effectiveWeights(for: dataManager.preferences)
    }

    private func resetToEqual() {
        let sectionIDs = sections.map(\.id)
        weights = SectionWeighting.equalWeights(for: sectionIDs)
        persistWeights()
    }

    private func persistWeights() {
        let sectionIDs = Set(sections.map(\.id))
        dataManager.preferences.sectionWeights = weights.filter { sectionIDs.contains($0.key) }
        dataManager.savePreferences()
        dataManager.recalculateAllScores()
    }

    private func sectionColor(for sectionID: String) -> Color {
        if let section = sections.first(where: { $0.id == sectionID }) {
            return QuestionnaireSectionAccent.color(for: sectionID, title: section.title)
        }
        return QuestionnaireSectionAccent.color(for: sectionID, title: "")
    }

    private func instructionRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .font(.arial(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
            Text(text)
                .font(.arial(size: 13))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    SectionWeightsView()
}
