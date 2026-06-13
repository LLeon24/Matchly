//
//  QuestionnaireWeightsView.swift
//  Matchly
//
//  Created on 11/18/25.
//

import SwiftUI

struct QuestionnaireWeightsView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var sectionWeights: [String: Double] = [:]
    @State private var tempWeights: [String: Double] = [:]
    
    // Get all enabled sections (excluding red flags)
    // Use a stable identifier based on section title since Questionnaire() generates new UUIDs
    private var enabledSections: [(section: QuestionnaireSection, stableId: String)] {
        let questionnaire = Questionnaire()
        
        // Get standard sections - use title as stable ID
        var allSections: [(section: QuestionnaireSection, stableId: String)] = questionnaire.sections.map { section in
            (section: section, stableId: section.title)
        }
        
        // Add custom sections from preferences (convert CustomQuestionnaireSection to QuestionnaireSection)
        let customSections = dataManager.preferences.customSections.map { customSection in
            (section: QuestionnaireSection(
                id: customSection.id,
                title: customSection.title,
                items: customSection.items.map { customItem in
                    QuestionnaireItem(id: customItem.id, question: customItem.question)
                }
            ), stableId: customSection.id) // Use the stored ID for custom sections
        }
        allSections.append(contentsOf: customSections)
        
        var filtered = allSections.filter { item in
            let section = item.section
            // Check if section is enabled (empty set = all enabled)
            // For standard sections, check by title; for custom, check by ID
            if !dataManager.preferences.enabledSectionIds.isEmpty {
                if section.title.contains("Section A") || section.title.contains("Section B") || 
                   section.title.contains("Section C") || section.title.contains("Section D") ||
                   section.title.contains("Section E") || section.title.contains("Section F") {
                    // Standard section - check by title
                    if !dataManager.preferences.enabledSectionIds.contains(section.title) &&
                       !dataManager.preferences.enabledSectionIds.contains(section.id) {
                        return false
                    }
                } else {
                    // Custom section - check by ID
                    if !dataManager.preferences.enabledSectionIds.contains(section.id) {
                        return false
                    }
                }
            }
            // Skip red flags section
            if section.title.contains("Red flags") {
                return false
            }
            return true
        }
        
        // EMR is a weighted factor too — surface it as a row so its importance is
        // set with the exact same slider/percentage UX and stored in sectionWeights.
        filtered.append((
            section: QuestionnaireSection(id: EMRScoring.weightKey, title: EMRScoring.weightKey, items: []),
            stableId: EMRScoring.weightKey
        ))
        
        return filtered
    }
    
    // Calculate total weight percentage
    private var totalWeight: Double {
        tempWeights.values.reduce(0, +)
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
            } header: {
                Text("Electronic Medical Record (EMR)")
            } footer: {
                Text("Pick the EMR you know best. Programs that use this EMR score higher on the EMR factor; programs that use a different EMR score lower. \"Other\" / \"Not sure\" on either side is treated as neutral and isn't scored. Set how much EMR matters with the \"\(EMRScoring.weightKey)\" weight below.")
            }
            
            Section {
                HStack {
                    Text("Total Weight")
                        .font(.arial(size: 15, weight: .medium))
                    Spacer()
                    Text("\(Int(totalWeight * 100))%")
                        .font(.arial(size: 15, weight: .semibold))
                        .foregroundColor(totalWeight == 1.0 ? .green : .orange)
                }
                
                if totalWeight != 1.0 {
                    Text("Weights must sum to 100%")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            } header: {
                Text("Weight Summary")
            } footer: {
                Text("Adjust the sliders to set the importance of each section. The total must equal 100%. Higher weights mean that section will have more influence on the final score.")
            }
            
            Section {
                ForEach(enabledSections, id: \.stableId) { item in
                    let section = item.section
                    let stableId = item.stableId
                    let sectionWeight = tempWeights[stableId] ?? 0.0
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(section.title)
                                .font(.arial(size: 15, weight: .medium))
                            Spacer()
                            
                            // Text field for direct percentage input
                            HStack(spacing: 4) {
                                TextField("", value: Binding(
                                    get: { Int(sectionWeight * 100) },
                                    set: { newPercentage in
                                        let clampedPercentage = max(0, min(100, newPercentage))
                                        adjustWeights(sectionId: stableId, newValue: Double(clampedPercentage) / 100.0)
                                    }
                                ), format: .number)
                                .keyboardType(.numberPad)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 50)
                                .multilineTextAlignment(.center)
                                
                                Text("%")
                                    .font(.arial(size: 15, weight: .semibold))
                                    .foregroundColor(.blue)
                            }
                        }
                        
                        // Improved slider with better step size
                        Slider(value: Binding(
                            get: { sectionWeight },
                            set: { newValue in
                                adjustWeights(sectionId: stableId, newValue: newValue)
                            }
                        ), in: 0...1, step: 0.05) // Larger step for easier sliding
                        .tint(.blue)
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                Text("Section Weights")
            }
            
            Section {
                Button(action: {
                    resetToEqualWeights()
                }) {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                        Text("Reset to Equal Weights")
                    }
                    .foregroundColor(.blue)
                }
            }
        }
        .padding(.bottom, 90) // Space for custom tab bar
        .navigationTitle("Section Weights")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    saveWeights()
                }
                .disabled(totalWeight != 1.0)
            }
        }
        .onAppear {
            loadWeights()
        }
        .onChange(of: enabledSections.count) { oldCount, newCount in
            // Reload weights if section count changes
            if oldCount != newCount {
                loadWeights()
            }
        }
    }
    
    private func loadWeights() {
        guard !enabledSections.isEmpty else {
            tempWeights = [:]
            return
        }
        
        // Get saved weights
        let savedWeights = dataManager.preferences.sectionWeights
        
        // Initialize with equal weights for all enabled sections
        let equalWeight = 1.0 / Double(enabledSections.count)
        tempWeights = Dictionary(uniqueKeysWithValues: enabledSections.map { ($0.stableId, equalWeight) })
        
        // If we have saved weights, try to apply them
        if !savedWeights.isEmpty {
            var appliedWeights: [String: Double] = [:]
            var totalApplied: Double = 0
            
            // Try to match saved weights to current sections
            for item in enabledSections {
                // Try stable ID first (title for standard sections, ID for custom)
                if let weight = savedWeights[item.stableId] {
                    appliedWeights[item.stableId] = weight
                    totalApplied += weight
                } else if let weight = savedWeights[item.section.title] {
                    // Try by title for backward compatibility
                    appliedWeights[item.stableId] = weight
                    totalApplied += weight
                }
            }
            
            // If we found matching weights, use them
            if !appliedWeights.isEmpty && totalApplied > 0 {
                // Apply matched weights
                for (stableId, weight) in appliedWeights {
                    tempWeights[stableId] = weight
                }
                
                // Distribute remaining weight equally among sections without saved weights
                let sectionsWithWeights = Set(appliedWeights.keys)
                let sectionsWithoutWeights = enabledSections.filter { !sectionsWithWeights.contains($0.stableId) }
                
                if !sectionsWithoutWeights.isEmpty {
                    let usedWeight = tempWeights.values.reduce(0, +)
                    let remainingWeight = max(0, 1.0 - usedWeight)
                    let equalWeightForMissing = remainingWeight / Double(sectionsWithoutWeights.count)
                    for item in sectionsWithoutWeights {
                        tempWeights[item.stableId] = equalWeightForMissing
                    }
                }
                
                // Normalize to ensure exact 1.0
                let total = tempWeights.values.reduce(0, +)
                if total > 0 {
                    tempWeights = tempWeights.mapValues { $0 / total }
                }
            }
        }
        
        // Final safety check: ensure total is exactly 1.0
        let finalTotal = tempWeights.values.reduce(0, +)
        if abs(finalTotal - 1.0) > 0.001 { // Allow small floating point errors
            if finalTotal > 0 {
                tempWeights = tempWeights.mapValues { $0 / finalTotal }
            } else {
                resetToEqualWeights()
            }
        }
    }
    
    private func resetToEqualWeights() {
        let equalWeight = 1.0 / Double(enabledSections.count)
        tempWeights = Dictionary(uniqueKeysWithValues: enabledSections.map { ($0.stableId, equalWeight) })
    }
    
    private func adjustWeights(sectionId: String, newValue: Double) {
        let oldValue = tempWeights[sectionId] ?? 0.0
        let difference = newValue - oldValue
        
        // Update the changed section
        tempWeights[sectionId] = newValue
        
        // Distribute the difference proportionally among other sections
        let otherSections = enabledSections.filter { $0.stableId != sectionId }
        let totalOtherWeight = otherSections.reduce(0.0) { sum, item in
            sum + (tempWeights[item.stableId] ?? 0.0)
        }
        
        if totalOtherWeight > 0 && !otherSections.isEmpty {
            // Proportionally adjust other sections
            for item in otherSections {
                let currentWeight = tempWeights[item.stableId] ?? 0.0
                let proportion = currentWeight / totalOtherWeight
                let adjustment = -difference * proportion
                tempWeights[item.stableId] = max(0, min(1, currentWeight + adjustment))
            }
        } else if !otherSections.isEmpty {
            // If other sections have no weight, distribute equally
            let equalAdjustment = -difference / Double(otherSections.count)
            for item in otherSections {
                tempWeights[item.stableId] = max(0, min(1, (tempWeights[item.stableId] ?? 0.0) + equalAdjustment))
            }
        }
        
        // Ensure the changed section stays within bounds
        tempWeights[sectionId] = max(0, min(1, newValue))
    }
    
    private func saveWeights() {
        guard totalWeight == 1.0 else { return }
        
        // Normalize to ensure exact 1.0
        let normalizedWeights = tempWeights.mapValues { weight in
            weight / totalWeight
        }
        
        dataManager.preferences.sectionWeights = normalizedWeights
        dataManager.savePreferences()
        
        // Recalculate all program scores with new weights
        dataManager.recalculateAllScores()
    }
}

#Preview {
    NavigationView {
        QuestionnaireWeightsView()
            .environmentObject(DataManager.shared)
    }
}

