//
//  QuestionnaireCustomizationView.swift
//  Matchly
//
//  Created on 11/14/25.
//

import SwiftUI

struct QuestionnaireCustomizationView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var enabledSectionIds: Set<String> = []
    @State private var enabledQuestionIds: Set<String> = []
    @State private var customSections: [CustomQuestionnaireSection] = []
    @State private var customQuestionsInSections: [String: [CustomQuestionnaireItem]] = [:]
    @State private var showAddCustomSection = false
    @State private var newSectionTitle = ""
    @State private var editingSection: CustomQuestionnaireSection?
    @State private var showAddQuestionToSection: String? = nil
    @State private var newQuestionText = ""
    
    // Cache of standard sections with stable IDs from existing programs
    @State private var cachedStandardSections: [QuestionnaireSection] = []
    
    // Get all standard sections - always use cached sections to ensure stable IDs
    private var standardSections: [QuestionnaireSection] {
        // Always return cached sections if available (they have stable IDs from programs)
        // If not cached yet, return empty array (will be populated in onAppear)
        return cachedStandardSections.isEmpty ? Questionnaire.makeStandardSections() : cachedStandardSections
    }
    
    var body: some View {
        Form {
            Section(header: Text("Standard Sections"), footer: Text("Toggle sections and questions to customize your questionnaire. All sections are enabled by default.")) {
                ForEach(standardSections.indices, id: \.self) { index in
                    let section = standardSections[index]
                    DisclosureGroup(isExpanded: Binding(
                        get: { true }, // Always expanded to show questions
                        set: { _ in }
                    )) {
                        // Standard questions - use the actual item ID from the section
                        ForEach(section.items) { item in
                            // Use the item's ID directly (should be stable if from cached sections)
                            let itemId = item.id
                            
                            Toggle(isOn: Binding(
                                get: { 
                                    // Check if this question is enabled
                                    // Empty set = all enabled, non-empty set = only items in set are enabled
                                    if enabledQuestionIds.isEmpty {
                                        return true // All enabled by default
                                    }
                                    // Check if this item's ID is in the enabled set
                                    return enabledQuestionIds.contains(itemId)
                                },
                                set: { isEnabled in
                                    // Use the item's ID directly from the current section
                                    let actualIdToUse = itemId
                                    
                                    // Calculate the new set value
                                    var newSet = enabledQuestionIds
                                    
                                    if isEnabled {
                                        // Enabling: if set is empty (all enabled), no change needed
                                        // If set is not empty, add this question to enabled set
                                        if newSet.isEmpty {
                                            // Set is empty means all are enabled, so this question is already enabled
                                            // No change needed - but we should still update to ensure consistency
                                        } else {
                                            // Set is not empty, add this question to enabled set
                                            newSet.insert(actualIdToUse)
                                        }
                                    } else {
                                        // Disabling: if set is empty (all enabled), populate with all questions except this one
                                        if newSet.isEmpty {
                                            // Get all question IDs from current sections (standard + custom)
                                            var allQuestionIds = Set<String>()
                                            
                                            // Add all standard section question IDs
                                            for standardSection in standardSections {
                                                allQuestionIds.formUnion(standardSection.items.map { $0.id })
                                            }
                                            
                                            // Add all custom questions added to standard sections
                                            for (_, customQuestions) in customQuestionsInSections {
                                                allQuestionIds.formUnion(customQuestions.map { $0.id })
                                            }
                                            
                                            // Add all custom section question IDs
                                            for customSection in customSections {
                                                allQuestionIds.formUnion(customSection.items.map { $0.id })
                                            }
                                            
                                            newSet = allQuestionIds
                                        }
                                        // Remove this question from enabled set
                                        newSet.remove(actualIdToUse)
                                    }
                                    
                                    // Update state
                                    enabledQuestionIds = newSet
                                }
                            )) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.question)
                                        .font(.arial(size: 13))
                                    if section.title.contains("Red flags") {
                                        Text("Yes/No question")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                        
                        // Custom questions added to this section
                        if let customQuestions = customQuestionsInSections[section.id], !customQuestions.isEmpty {
                            ForEach(customQuestions) { customItem in
                                Toggle(isOn: Binding(
                                    get: {
                                        enabledQuestionIds.isEmpty || enabledQuestionIds.contains(customItem.id)
                                    },
                                    set: { isEnabled in
                                        var newSet = enabledQuestionIds
                                        if isEnabled {
                                            // Enabling: if set is empty (all enabled), no change needed
                                            // If set is not empty, add this question to enabled set
                                            if !newSet.isEmpty {
                                                newSet.insert(customItem.id)
                                            }
                                        } else {
                                            // Disabling: if set is empty (all enabled), populate with all questions except this one
                                            if newSet.isEmpty {
                                                // Get all question IDs from current sections (standard + custom)
                                                var allQuestionIds = Set<String>()
                                                
                                                // Add all standard section question IDs
                                                for standardSection in standardSections {
                                                    allQuestionIds.formUnion(standardSection.items.map { $0.id })
                                                }
                                                
                                                // Add all custom questions added to standard sections
                                                for (_, customQuestions) in customQuestionsInSections {
                                                    allQuestionIds.formUnion(customQuestions.map { $0.id })
                                                }
                                                
                                                // Add all custom section question IDs
                                                for customSection in customSections {
                                                    allQuestionIds.formUnion(customSection.items.map { $0.id })
                                                }
                                                
                                                newSet = allQuestionIds
                                            }
                                            // Remove this question from enabled set
                                            newSet.remove(customItem.id)
                                        }
                                        enabledQuestionIds = newSet
                                    }
                                )) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(customItem.question)
                                            .font(.arial(size: 13))
                                            .italic()
                                        Text("Custom question")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .onDelete { offsets in
                                var questions = customQuestionsInSections[section.id] ?? []
                                questions.remove(atOffsets: offsets)
                                customQuestionsInSections[section.id] = questions.isEmpty ? nil : questions
                            }
                        }
                        
                        // Add question button
                        Button(action: {
                            showAddQuestionToSection = section.id
                            newQuestionText = ""
                        }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(.blue)
                                Text("Add Question to \(section.title)")
                                    .foregroundColor(.blue)
                                    .font(.arial(size: 13))
                            }
                        }
                    } label: {
                        HStack {
                            Toggle(isOn: Binding(
                                get: { 
                                    // Empty set = all enabled, non-empty set = only sections in set are enabled
                                    if enabledSectionIds.isEmpty {
                                        return true // All enabled by default
                                    }
                                    return enabledSectionIds.contains(section.id)
                                },
                                set: { isEnabled in
                                    var newSet = enabledSectionIds
                                    
                                    if isEnabled {
                                        // Enabling: if set is empty (all enabled), no change needed
                                        // If set is not empty, add this section to enabled set
                                        if !newSet.isEmpty {
                                            newSet.insert(section.id)
                                        }
                                    } else {
                                        // Disabling: if set is empty (all enabled), populate with all sections except this one
                                        if newSet.isEmpty {
                                            // Get all section IDs from current sections (standard + custom)
                                            var allSectionIds = Set<String>()
                                            
                                            // Add all standard section IDs
                                            for standardSection in standardSections {
                                                allSectionIds.insert(standardSection.id)
                                            }
                                            
                                            // Add all custom section IDs
                                            for customSection in customSections {
                                                allSectionIds.insert(customSection.id)
                                            }
                                            
                                            newSet = allSectionIds
                                        }
                                        // Remove this section from enabled set
                                        newSet.remove(section.id)
                                    }
                                    
                                    enabledSectionIds = newSet
                                }
                            )) {
                                Text(section.title)
                                    .font(.arial(size: 15, weight: .medium))
                            }
                        }
                    }
                }
            }
            
            Section(header: Text("Custom Sections")) {
                ForEach(customSections) { section in
                    NavigationLink(destination: EditCustomSectionView(section: section, onSave: { updatedSection in
                        if let index = customSections.firstIndex(where: { $0.id == updatedSection.id }) {
                            customSections[index] = updatedSection
                        }
                    })) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(section.title)
                                .font(.arial(size: 15, weight: .medium))
                            Text("\(section.items.count) question\(section.items.count == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .onDelete { offsets in
                    let removedIds = offsets.map { customSections[$0].id }
                    customSections.remove(atOffsets: offsets)
                    for removedId in removedIds {
                        enabledSectionIds.remove(removedId)
                    }
                }
                
                Button(action: {
                    showAddCustomSection = true
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.blue)
                        Text("Add Custom Section")
                            .foregroundColor(.blue)
                    }
                }
            }
        }
        .padding(.bottom, 90) // Space for custom tab bar
        .scrollContentBackground(.hidden)
        .appCanvasBackground()
        .navigationTitle("Customize Questionnaire")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            enabledSectionIds = dataManager.preferences.enabledSectionIds
            enabledQuestionIds = dataManager.preferences.enabledQuestionIds
            customSections = dataManager.preferences.customSections
            customQuestionsInSections = dataManager.preferences.customQuestionsInSections
            
            // Cache standard sections with stable IDs (same template used for new programs)
            cachedStandardSections = Questionnaire.makeStandardSections()
        }
        .onDisappear {
            dataManager.preferences.enabledSectionIds = enabledSectionIds
            dataManager.preferences.enabledQuestionIds = enabledQuestionIds
            dataManager.preferences.customSections = customSections
            dataManager.preferences.customQuestionsInSections = customQuestionsInSections
            dataManager.savePreferences()
            syncQuestionnaireCustomizationsToPrograms()
        }
        .alert("Add Custom Section", isPresented: $showAddCustomSection) {
            ClearableTextField("Section Title", text: $newSectionTitle)
            Button("Cancel", role: .cancel) {
                newSectionTitle = ""
            }
            Button("Add") {
                if !newSectionTitle.isEmpty {
                    let newSection = CustomQuestionnaireSection(title: newSectionTitle)
                    customSections.append(newSection)
                    newSectionTitle = ""
                }
            }
        } message: {
            Text("Enter a title for your custom section")
        }
        .alert("Add Question", isPresented: Binding(
            get: { showAddQuestionToSection != nil },
            set: { if !$0 { showAddQuestionToSection = nil } }
        )) {
            ClearableTextField("Question", text: $newQuestionText, axis: .vertical)
            Button("Cancel", role: .cancel) {
                newQuestionText = ""
                showAddQuestionToSection = nil
            }
            Button("Add") {
                if let sectionId = showAddQuestionToSection, !newQuestionText.isEmpty {
                    let newItem = CustomQuestionnaireItem(question: newQuestionText)
                    if customQuestionsInSections[sectionId] == nil {
                        customQuestionsInSections[sectionId] = []
                    }
                    customQuestionsInSections[sectionId]?.append(newItem)
                    newQuestionText = ""
                    showAddQuestionToSection = nil
                }
            }
        } message: {
            if let sectionId = showAddQuestionToSection,
               let section = standardSections.first(where: { $0.id == sectionId }) {
                Text("Add a custom question to \(section.title)")
            } else {
                Text("Enter your custom question")
            }
        }
    }

    private func syncQuestionnaireCustomizationsToPrograms() {
        let standardSectionTemplates = cachedStandardSections.isEmpty
            ? Questionnaire.makeStandardSections()
            : cachedStandardSections
        let standardQuestionIdsBySection = Dictionary(
            uniqueKeysWithValues: standardSectionTemplates.map { ($0.id, Set($0.items.map(\.id))) }
        )
        let allowedCustomQuestionIdsBySection = customQuestionsInSections.mapValues { Set($0.map(\.id)) }
        let prefCustomSectionIds = Set(customSections.map(\.id))
        let prefCustomQuestionIdsBySection = Dictionary(
            uniqueKeysWithValues: customSections.map { ($0.id, Set($0.items.map(\.id))) }
        )

        for program in dataManager.programs {
            var updatedProgram = program

            for sectionIndex in updatedProgram.questionnaire.sections.indices {
                let sectionId = updatedProgram.questionnaire.sections[sectionIndex].id
                let standardIds = standardQuestionIdsBySection[sectionId] ?? []
                let allowedCustomIds = allowedCustomQuestionIdsBySection[sectionId] ?? []

                updatedProgram.questionnaire.sections[sectionIndex].items =
                    updatedProgram.questionnaire.sections[sectionIndex].items.filter { item in
                        if standardIds.contains(item.id) { return true }
                        return allowedCustomIds.contains(item.id)
                    }

                if let customQuestions = customQuestionsInSections[sectionId] {
                    for customQuestion in customQuestions {
                        let sectionItems = updatedProgram.questionnaire.sections[sectionIndex].items
                        let alreadyExists = sectionItems.contains {
                            $0.id == customQuestion.id || $0.question == customQuestion.question
                        }
                        if !alreadyExists {
                            updatedProgram.questionnaire.sections[sectionIndex].items.append(
                                QuestionnaireItem(id: customQuestion.id, question: customQuestion.question)
                            )
                        }
                    }
                }
            }

            updatedProgram.questionnaire.customSections = customSections.map { customSection in
                let existingSection = program.questionnaire.customSections.first { $0.id == customSection.id }
                return QuestionnaireSection(
                    id: customSection.id,
                    title: customSection.title,
                    items: customSection.items.map { customItem in
                        if let existingItem = existingSection?.items.first(where: { $0.id == customItem.id }) {
                            return existingItem
                        }
                        if let existingItem = program.questionnaire.sections
                            .flatMap(\.items)
                            .first(where: { $0.id == customItem.id }) {
                            return existingItem
                        }
                        return QuestionnaireItem(id: customItem.id, question: customItem.question)
                    }
                )
            }

            for existingSection in program.questionnaire.customSections where !prefCustomSectionIds.contains(existingSection.id) {
                let removedQuestionIds = Set(existingSection.items.map(\.id))
                enabledQuestionIds.subtract(removedQuestionIds)
            }

            for (sectionId, allowedIds) in prefCustomQuestionIdsBySection {
                guard let existingSection = program.questionnaire.customSections.first(where: { $0.id == sectionId }) else {
                    continue
                }
                let removedIds = Set(existingSection.items.map(\.id)).subtracting(allowedIds)
                enabledQuestionIds.subtract(removedIds)
            }

            updatedProgram.finalScore = updatedProgram.questionnaire.totalWeightedScore(
                preferences: dataManager.preferences,
                programEMR: updatedProgram.emr
            )
            dataManager.updateProgram(updatedProgram)
        }

        dataManager.preferences.enabledQuestionIds = enabledQuestionIds
        dataManager.preferences.sectionWeights = SectionWeighting.redistributedWeights(
            stored: dataManager.preferences.sectionWeights,
            preferences: dataManager.preferences
        )
        dataManager.savePreferences()
    }
}

struct EditCustomSectionView: View {
    let section: CustomQuestionnaireSection
    let onSave: (CustomQuestionnaireSection) -> Void
    @Environment(\.dismiss) var dismiss
    
    @State private var sectionTitle: String
    @State private var items: [CustomQuestionnaireItem]
    @State private var showAddQuestion = false
    @State private var newQuestion = ""
    @State private var editingItem: CustomQuestionnaireItem?
    
    init(section: CustomQuestionnaireSection, onSave: @escaping (CustomQuestionnaireSection) -> Void) {
        self.section = section
        self.onSave = onSave
        _sectionTitle = State(initialValue: section.title)
        _items = State(initialValue: section.items)
    }
    
    var body: some View {
        Form {
            Section("Section Title") {
                ClearableTextField("Section Title", text: $sectionTitle)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .glassEffect(.regular, in: .capsule)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
            }
            
            Section("Questions") {
                ForEach(items) { item in
                    NavigationLink(destination: EditQuestionView(item: item, onSave: { updatedItem in
                        if let index = items.firstIndex(where: { $0.id == updatedItem.id }) {
                            items[index] = updatedItem
                        }
                    })) {
                        Text(item.question)
                    }
                }
                .onDelete { offsets in
                    items.remove(atOffsets: offsets)
                }
                
                Button(action: {
                    showAddQuestion = true
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.blue)
                        Text("Add Question")
                            .foregroundColor(.blue)
                    }
                }
            }
        }
        .navigationTitle("Edit Section")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    var updatedSection = section
                    updatedSection.title = sectionTitle
                    updatedSection.items = items
                    onSave(updatedSection)
                    dismiss()
                }
                .buttonStyle(.glassProminent)
                .tint(AppColors.primaryBlue)
            }
        }
        .scrollContentBackground(.hidden)
        .appCanvasBackground()
        .alert("Add Question", isPresented: $showAddQuestion) {
            ClearableTextField("Question", text: $newQuestion)
            Button("Cancel", role: .cancel) {
                newQuestion = ""
            }
            Button("Add") {
                if !newQuestion.isEmpty {
                    let newItem = CustomQuestionnaireItem(question: newQuestion)
                    items.append(newItem)
                    newQuestion = ""
                }
            }
        } message: {
            Text("Enter your custom question")
        }
    }
}

struct EditQuestionView: View {
    let item: CustomQuestionnaireItem
    let onSave: (CustomQuestionnaireItem) -> Void
    @Environment(\.dismiss) var dismiss
    
    @State private var question: String
    
    init(item: CustomQuestionnaireItem, onSave: @escaping (CustomQuestionnaireItem) -> Void) {
        self.item = item
        self.onSave = onSave
        _question = State(initialValue: item.question)
    }
    
    var body: some View {
        Form {
            Section("Question") {
                ClearableTextField("Question", text: $question, axis: .vertical)
                    .lineLimit(3...6)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .glassEffect(.regular, in: .capsule)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
            }
        }
        .scrollContentBackground(.hidden)
        .appCanvasBackground()
        .navigationTitle("Edit Question")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    var updatedItem = item
                    updatedItem.question = question
                    onSave(updatedItem)
                    dismiss()
                }
                .buttonStyle(.glassProminent)
                .tint(AppColors.primaryBlue)
            }
        }
    }
}

#Preview {
    MatchlyNavigationView {
        QuestionnaireCustomizationView()
            .environmentObject(DataManager.shared)
    }
}

