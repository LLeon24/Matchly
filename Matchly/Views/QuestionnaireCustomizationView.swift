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
    @State private var showAddCustomSection = false
    @State private var newSectionTitle = ""
    @State private var editingSection: CustomQuestionnaireSection?
    
    // Get all standard sections from a sample questionnaire
    private var standardSections: [QuestionnaireSection] {
        Questionnaire().sections
    }
    
    var body: some View {
        Form {
            Section(header: Text("Standard Sections"), footer: Text("Toggle sections and questions to customize your questionnaire. All sections are enabled by default.")) {
                ForEach(standardSections) { section in
                    DisclosureGroup(isExpanded: Binding(
                        get: { true }, // Always expanded to show questions
                        set: { _ in }
                    )) {
                        ForEach(section.items) { item in
                            Toggle(isOn: Binding(
                                get: { !enabledQuestionIds.contains(item.id) },
                                set: { isEnabled in
                                    if isEnabled {
                                        enabledQuestionIds.remove(item.id)
                                    } else {
                                        enabledQuestionIds.insert(item.id)
                                    }
                                }
                            )) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.question)
                                        .font(.system(size: 13))
                                    if section.title.contains("Red flags") {
                                        Text("Yes/No question")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Toggle(isOn: Binding(
                                get: { !enabledSectionIds.contains(section.id) },
                                set: { isEnabled in
                                    if isEnabled {
                                        enabledSectionIds.remove(section.id)
                                    } else {
                                        enabledSectionIds.insert(section.id)
                                    }
                                }
                            )) {
                                Text(section.title)
                                    .font(.system(size: 15, weight: .medium))
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
                                .font(.system(size: 15, weight: .medium))
                            Text("\(section.items.count) question\(section.items.count == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
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
        .navigationTitle("Customize Questionnaire")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            enabledSectionIds = dataManager.preferences.enabledSectionIds
            enabledQuestionIds = dataManager.preferences.enabledQuestionIds
            customSections = dataManager.preferences.customSections
        }
        .onDisappear {
            // Save preferences
            dataManager.preferences.enabledSectionIds = enabledSectionIds
            dataManager.preferences.enabledQuestionIds = enabledQuestionIds
            dataManager.preferences.customSections = customSections
            dataManager.savePreferences()
            
            // Convert custom sections to QuestionnaireSection format and update all programs
            for program in dataManager.programs {
                var updatedProgram = program
                // Convert CustomQuestionnaireSection to QuestionnaireSection
                updatedProgram.questionnaire.customSections = customSections.map { customSection in
                    QuestionnaireSection(
                        id: customSection.id,
                        title: customSection.title,
                        items: customSection.items.map { customItem in
                            // Find existing item with same ID or create new one
                            if let existingItem = updatedProgram.questionnaire.sections.flatMap({ $0.items }).first(where: { $0.id == customItem.id }) {
                                return existingItem
                            } else if let customItemInCustomSection = updatedProgram.questionnaire.customSections.flatMap({ $0.items }).first(where: { $0.id == customItem.id }) {
                                return customItemInCustomSection
                            } else {
                                return QuestionnaireItem(id: customItem.id, question: customItem.question)
                            }
                        }
                    )
                }
                updatedProgram.finalScore = updatedProgram.questionnaire.totalWeightedScore(preferences: dataManager.preferences)
                dataManager.updateProgram(updatedProgram)
            }
        }
        .alert("Add Custom Section", isPresented: $showAddCustomSection) {
            TextField("Section Title", text: $newSectionTitle)
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
                TextField("Section Title", text: $sectionTitle)
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
            }
        }
        .alert("Add Question", isPresented: $showAddQuestion) {
            TextField("Question", text: $newQuestion)
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
                TextField("Question", text: $question, axis: .vertical)
                    .lineLimit(3...6)
            }
        }
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
            }
        }
    }
}

#Preview {
    NavigationView {
        QuestionnaireCustomizationView()
            .environmentObject(DataManager.shared)
    }
}

