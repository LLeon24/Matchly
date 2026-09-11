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
    @State private var newSectionSubtitle = "Custom priorities"
    @State private var proposedSectionLetter: Character = "G"
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
            Section(
                header: Text("Standard Sections"),
                footer: Text("Toggle sections and questions to customize your questionnaire. All sections are enabled by default. Custom questions you add can be removed with the trash icon or by swiping left.")
            ) {
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
                                deletableCustomQuestionRow(
                                    question: customItem.question,
                                    questionId: customItem.id,
                                    isEnabled: enabledQuestionIds.isEmpty || enabledQuestionIds.contains(customItem.id),
                                    onToggle: { isEnabled in
                                        updateQuestionEnabled(customItem.id, isEnabled: isEnabled)
                                    },
                                    onDelete: {
                                        deleteCustomQuestionFromStandardSection(
                                            sectionId: section.id,
                                            questionId: customItem.id
                                        )
                                    }
                                )
                            }
                            .onDelete { offsets in
                                guard var questions = customQuestionsInSections[section.id] else { return }
                                let removedIds = offsets.map { questions[$0].id }
                                questions.remove(atOffsets: offsets)
                                customQuestionsInSections[section.id] = questions.isEmpty ? nil : questions
                                for id in removedIds {
                                    enabledQuestionIds.remove(id)
                                    dataManager.preferences.weightExcludedQuestionIds.remove(id)
                                }
                                persistAndSyncCustomizations()
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
            
            Section(
                header: Text("Custom Sections"),
                footer: Text("Custom sections use the next available letter after Section F and appear in your program questionnaire and section weights. Remove custom sections or questions with the trash icon, or swipe left.")
            ) {
                ForEach(customSections.indices, id: \.self) { index in
                    let section = customSections[index]
                    DisclosureGroup(isExpanded: Binding(
                        get: { true },
                        set: { _ in }
                    )) {
                        ForEach(section.items) { item in
                            deletableCustomQuestionRow(
                                question: item.question,
                                questionId: item.id,
                                isEnabled: enabledQuestionIds.isEmpty || enabledQuestionIds.contains(item.id),
                                onToggle: { isEnabled in
                                    updateQuestionEnabled(item.id, isEnabled: isEnabled)
                                },
                                onDelete: {
                                    deleteCustomQuestionFromCustomSection(
                                        sectionIndex: index,
                                        questionId: item.id
                                    )
                                }
                            )
                        }
                        .onDelete { offsets in
                            let removedIds = offsets.map { customSections[index].items[$0].id }
                            customSections[index].items.remove(atOffsets: offsets)
                            for id in removedIds {
                                enabledQuestionIds.remove(id)
                                dataManager.preferences.weightExcludedQuestionIds.remove(id)
                            }
                            persistAndSyncCustomizations()
                        }

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
                        HStack(spacing: 10) {
                            Button {
                                deleteCustomSection(at: index)
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 16))
                                    .foregroundColor(.red.opacity(0.85))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Delete section")

                            Toggle(isOn: Binding(
                                get: {
                                    if enabledSectionIds.isEmpty {
                                        return true
                                    }
                                    return enabledSectionIds.contains(section.id)
                                },
                                set: { isEnabled in
                                    updateSectionEnabled(section.id, isEnabled: isEnabled)
                                }
                            )) {
                                Text(section.title)
                                    .font(.arial(size: 15, weight: .medium))
                            }
                        }
                    }
                }
                .onDelete { offsets in
                    var removedSectionIds: [String] = []
                    var removedQuestionIds = Set<String>()
                    for index in offsets {
                        removedSectionIds.append(customSections[index].id)
                        removedQuestionIds.formUnion(customSections[index].items.map(\.id))
                    }
                    customSections.remove(atOffsets: offsets)
                    removeDeletedSectionReferences(
                        removedSectionIds: removedSectionIds,
                        removedQuestionIds: removedQuestionIds
                    )
                    persistAndSyncCustomizations()
                }

                Button(action: {
                    proposedSectionLetter = QuestionnaireSectionNaming.nextAvailableLetter(
                        existingTitles: standardSections.map(\.title) + customSections.map(\.title)
                    )
                    newSectionSubtitle = "Custom priorities"
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
            persistAndSyncCustomizations()
        }
        .sheet(isPresented: $showAddCustomSection) {
            AddCustomSectionSheet(
                subtitle: $newSectionSubtitle,
                proposedLetter: proposedSectionLetter
            ) { title in
                let newSection = CustomQuestionnaireSection(title: title)
                customSections.append(newSection)
                if !enabledSectionIds.isEmpty {
                    enabledSectionIds.insert(newSection.id)
                }
                newSectionSubtitle = "Custom priorities"
            }
        }
        .sheet(isPresented: Binding(
            get: { showAddQuestionToSection != nil },
            set: { isPresented in
                if !isPresented {
                    showAddQuestionToSection = nil
                    newQuestionText = ""
                }
            }
        )) {
            AddCustomQuestionSheet(
                questionText: $newQuestionText,
                contextMessage: "Add a custom question to \(sectionTitle(for: showAddQuestionToSection))."
            ) {
                appendQuestion(newQuestionText, toSectionId: showAddQuestionToSection)
                newQuestionText = ""
                showAddQuestionToSection = nil
            }
        }
    }

    private func sectionTitle(for sectionId: String?) -> String {
        guard let sectionId else { return "this section" }
        if let standard = standardSections.first(where: { $0.id == sectionId }) {
            return standard.title
        }
        if let custom = customSections.first(where: { $0.id == sectionId }) {
            return custom.title
        }
        return "this section"
    }

    private func appendQuestion(_ questionText: String, toSectionId sectionId: String?) {
        guard let sectionId else { return }
        let trimmed = questionText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let newItem = CustomQuestionnaireItem(question: trimmed)
        if let customIndex = customSections.firstIndex(where: { $0.id == sectionId }) {
            customSections[customIndex].items.append(newItem)
            return
        }

        if customQuestionsInSections[sectionId] == nil {
            customQuestionsInSections[sectionId] = []
        }
        customQuestionsInSections[sectionId]?.append(newItem)
    }

    private func updateSectionEnabled(_ sectionId: String, isEnabled: Bool) {
        var newSet = enabledSectionIds
        if isEnabled {
            if !newSet.isEmpty {
                newSet.insert(sectionId)
            }
        } else {
            if newSet.isEmpty {
                var allSectionIds = Set(standardSections.map(\.id))
                allSectionIds.formUnion(customSections.map(\.id))
                newSet = allSectionIds
            }
            newSet.remove(sectionId)
        }
        enabledSectionIds = newSet
    }

    private func updateQuestionEnabled(_ questionId: String, isEnabled: Bool) {
        var newSet = enabledQuestionIds
        if isEnabled {
            if !newSet.isEmpty {
                newSet.insert(questionId)
            }
        } else {
            if newSet.isEmpty {
                newSet = allQuestionIds()
            }
            newSet.remove(questionId)
        }
        enabledQuestionIds = newSet
    }

    private func deduplicatedCustomSections(_ sections: [CustomQuestionnaireSection]) -> [CustomQuestionnaireSection] {
        var seen = Set<String>()
        return sections.filter { section in
            guard !seen.contains(section.id) else { return false }
            seen.insert(section.id)
            return true
        }
    }

    private func allQuestionIds() -> Set<String> {
        var allQuestionIds = Set<String>()
        for standardSection in standardSections {
            allQuestionIds.formUnion(standardSection.items.map(\.id))
        }
        for (_, customQuestions) in customQuestionsInSections {
            allQuestionIds.formUnion(customQuestions.map(\.id))
        }
        for customSection in customSections {
            allQuestionIds.formUnion(customSection.items.map(\.id))
        }
        return allQuestionIds
    }

    @ViewBuilder
    private func deletableCustomQuestionRow(
        question: String,
        questionId: String,
        isEnabled: Bool,
        onToggle: @escaping (Bool) -> Void,
        onDelete: @escaping () -> Void
    ) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 16))
                    .foregroundColor(.red.opacity(0.85))
                    .padding(.top, 2)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Delete question")

            Toggle(isOn: Binding(
                get: { isEnabled },
                set: { onToggle($0) }
            )) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(question)
                        .font(.arial(size: 13))
                        .italic()
                    Text("Custom question")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private func deleteCustomQuestionFromStandardSection(sectionId: String, questionId: String) {
        guard var questions = customQuestionsInSections[sectionId] else { return }
        questions.removeAll { $0.id == questionId }
        customQuestionsInSections[sectionId] = questions.isEmpty ? nil : questions
        enabledQuestionIds.remove(questionId)
        dataManager.preferences.weightExcludedQuestionIds.remove(questionId)
        persistAndSyncCustomizations()
    }

    private func deleteCustomQuestionFromCustomSection(sectionIndex: Int, questionId: String) {
        guard customSections.indices.contains(sectionIndex) else { return }
        customSections[sectionIndex].items.removeAll { $0.id == questionId }
        enabledQuestionIds.remove(questionId)
        dataManager.preferences.weightExcludedQuestionIds.remove(questionId)
        persistAndSyncCustomizations()
    }

    private func deleteCustomSection(at index: Int) {
        guard customSections.indices.contains(index) else { return }
        let section = customSections[index]
        removeDeletedSectionReferences(
            removedSectionIds: [section.id],
            removedQuestionIds: Set(section.items.map(\.id))
        )
        customSections.remove(at: index)
        persistAndSyncCustomizations()
    }

    private func removeDeletedSectionReferences(
        removedSectionIds: [String],
        removedQuestionIds: Set<String>
    ) {
        for removedId in removedSectionIds {
            enabledSectionIds.remove(removedId)
            customQuestionsInSections.removeValue(forKey: removedId)
            dataManager.preferences.sectionWeights.removeValue(forKey: removedId)
        }
        enabledQuestionIds.subtract(removedQuestionIds)
        dataManager.preferences.weightExcludedQuestionIds.subtract(removedQuestionIds)
    }

    private func persistAndSyncCustomizations() {
        customSections = deduplicatedCustomSections(customSections)
        dataManager.preferences.enabledSectionIds = enabledSectionIds
        dataManager.preferences.enabledQuestionIds = enabledQuestionIds
        dataManager.preferences.customSections = customSections
        dataManager.preferences.customQuestionsInSections = customQuestionsInSections
        pruneOrphanedPreferenceKeys()
        syncQuestionnaireCustomizationsToPrograms()
    }

    private func pruneOrphanedPreferenceKeys() {
        let weightableIds = Set(
            SectionWeighting.weightableSections(preferences: dataManager.preferences).map(\.id)
        )
        dataManager.preferences.sectionWeights = dataManager.preferences.sectionWeights.filter {
            weightableIds.contains($0.key)
        }
        dataManager.preferences.sectionWeights = SectionWeighting.redistributedWeights(
            stored: dataManager.preferences.sectionWeights,
            preferences: dataManager.preferences
        )

        let activeQuestionIds = allQuestionIds()
        if !enabledQuestionIds.isEmpty {
            enabledQuestionIds = enabledQuestionIds.intersection(activeQuestionIds)
        }
        dataManager.preferences.enabledQuestionIds = enabledQuestionIds
        dataManager.preferences.weightExcludedQuestionIds =
            dataManager.preferences.weightExcludedQuestionIds.intersection(activeQuestionIds)
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

            var removedQuestionIds = Set<String>()
            for existingSection in program.questionnaire.customSections where !prefCustomSectionIds.contains(existingSection.id) {
                removedQuestionIds.formUnion(existingSection.items.map(\.id))
            }

            for (sectionId, allowedIds) in prefCustomQuestionIdsBySection {
                guard let existingSection = program.questionnaire.customSections.first(where: { $0.id == sectionId }) else {
                    continue
                }
                removedQuestionIds.formUnion(Set(existingSection.items.map(\.id)).subtracting(allowedIds))
            }

            enabledQuestionIds.subtract(removedQuestionIds)
            dataManager.preferences.weightExcludedQuestionIds.subtract(removedQuestionIds)

            dataManager.updateProgram(updatedProgram)
        }

        dataManager.preferences.enabledQuestionIds = enabledQuestionIds
        dataManager.savePreferences()
        dataManager.recalculateAllScores()
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
        .sheet(isPresented: $showAddQuestion) {
            AddCustomQuestionSheet(
                questionText: $newQuestion,
                contextMessage: "Enter a question for \"\(sectionTitle)\"."
            ) {
                let trimmed = newQuestion.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                items.append(CustomQuestionnaireItem(question: trimmed))
                newQuestion = ""
                showAddQuestion = false
            }
        }
    }
}

private struct AddCustomSectionSheet: View {
    @Binding var subtitle: String
    let proposedLetter: Character
    let onAdd: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    private var previewTitle: String {
        QuestionnaireSectionNaming.customSectionTitle(letter: proposedLetter, subtitle: subtitle)
    }

    var body: some View {
        MatchlyNavigationView {
            Form {
                Section {
                    HStack {
                        Text("Section letter")
                        Spacer()
                        Text("Section \(proposedLetter)")
                            .font(.arial(size: 16, weight: .semibold))
                            .foregroundColor(AppColors.primaryBlue)
                    }

                    ClearableTextField("Section focus", text: $subtitle)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .glassEffect(.regular, in: .capsule)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowBackground(Color.clear)
                } footer: {
                    Text("Your section will appear as \"\(previewTitle)\" in the questionnaire and section weights.")
                }
            }
            .scrollContentBackground(.hidden)
            .appCanvasBackground()
            .navigationTitle("Add Custom Section")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        subtitle = "Custom priorities"
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onAdd(previewTitle)
                        dismiss()
                    }
                }
            }
        }
        .matchlyExpandedSheet()
    }
}

private struct AddCustomQuestionSheet: View {
    @Binding var questionText: String
    let contextMessage: String
    let onAdd: () -> Void
    @Environment(\.dismiss) private var dismiss

    private var trimmedQuestion: String {
        questionText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        MatchlyNavigationView {
            Form {
                Section {
                    ClearableTextField("Question", text: $questionText, axis: .vertical)
                        .lineLimit(3...8)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .glassEffect(.regular, in: .capsule)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowBackground(Color.clear)
                } footer: {
                    Text(contextMessage)
                }
            }
            .scrollContentBackground(.hidden)
            .appCanvasBackground()
            .navigationTitle("Add Question")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        questionText = ""
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onAdd()
                        dismiss()
                    }
                    .disabled(trimmedQuestion.isEmpty)
                }
            }
        }
        .matchlyExpandedSheet()
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

