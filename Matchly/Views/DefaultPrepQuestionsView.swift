//
//  DefaultPrepQuestionsView.swift
//  Matchly
//
//  Settings editor for the default Interview Prep question list.
//  New interview prep lists start from these questions; programs that
//  already have a prep list keep their own copy.
//

import SwiftUI

struct DefaultPrepQuestionsView: View {
    @EnvironmentObject var dataManager: DataManager

    @State private var newCustomQuestionText = ""
    @State private var showQuestionnairePicker = false
    @State private var showClearConfirmation = false
    @FocusState private var focusedField: FocusField?

    private enum FocusField: Hashable {
        case customQuestion
    }

    private static let addQuestionFieldID = "addQuestionField"

    private static let maxPriorityCount = 5

    private struct QuestionRow: Identifiable {
        let id: String
        let sectionTitle: String
        let question: String
        let isCustom: Bool
    }

    private var availablePrompts: [(id: String, sectionTitle: String, question: String)] {
        Questionnaire().allPrepPrompts(preferences: dataManager.preferences)
    }

    private var defaults: InterviewPrepDefaultQuestions {
        dataManager.preferences.interviewPrepDefaultQuestions ?? InterviewPrepDefaultQuestions()
    }

    private var rows: [QuestionRow] {
        let promptsById = Dictionary(
            availablePrompts.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let current = defaults
        return current.questionListOrder.compactMap { id in
            if let custom = current.customQuestions.first(where: { $0.id == id }) {
                return QuestionRow(id: id, sectionTitle: "Custom", question: custom.question, isCustom: true)
            }
            if let prompt = promptsById[id] {
                return QuestionRow(id: id, sectionTitle: prompt.sectionTitle, question: prompt.question, isCustom: false)
            }
            return nil
        }
    }

    var body: some View {
        ScrollViewReader { proxy in
            Form {
                questionsSection
                addSection
                if !rows.isEmpty {
                    Section {
                        Button("Clear All", role: .destructive) {
                            showClearConfirmation = true
                        }
                        .buttonStyle(.glass)
                    }
                }
            }
            .onChange(of: focusedField) { _, focused in
                guard focused == .customQuestion else { return }
                // Wait for the keyboard animation before scrolling the field above it.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    withAnimation {
                        proxy.scrollTo(Self.addQuestionFieldID, anchor: .bottom)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .appCanvasBackground()
        .navigationTitle("Prep Questions")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !rows.isEmpty {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
            }
        }
        .sheet(isPresented: $showQuestionnairePicker) {
            InterviewPrepQuestionnairePickerSheet(
                accentColor: AppColors.primaryBlue,
                availablePrompts: availablePrompts,
                alreadyAddedIds: Set(defaults.questionListOrder),
                onAdd: { ids in
                    updateDefaults { current in
                        for id in ids where !current.questionListOrder.contains(id) {
                            current.selectedQuestionIds.insert(id)
                            current.questionListOrder.append(id)
                        }
                    }
                }
            )
        }
        .alert("Clear all default questions?", isPresented: $showClearConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Clear All", role: .destructive) {
                updateDefaults { $0 = InterviewPrepDefaultQuestions() }
            }
        } message: {
            Text("New interviews will start with an empty prep list. Programs you've already prepped keep their questions.")
        }
    }

    private var questionsSection: some View {
        Section {
            if rows.isEmpty {
                Text("No default questions yet. Add your own below or pick from the questionnaire.")
                    .font(.arial(size: 13))
                    .foregroundColor(.secondary)
            } else {
                ForEach(rows) { row in
                    rowView(row)
                }
                .onMove(perform: moveRows)
                .onDelete(perform: deleteRows)
            }
        } header: {
            MatchlyFormSectionHeader(title: "Your Default Questions")
        } footer: {
            Text("Every new interview prep list starts with these questions. Star up to \(Self.maxPriorityCount) must-ask questions. Programs you've already prepped keep their own list.")
        }
    }

    private var addSection: some View {
        Section {
            Button {
                showQuestionnairePicker = true
            } label: {
                Label("Browse Questionnaire Questions", systemImage: "list.bullet.rectangle")
            }
            .buttonStyle(.glass)

            HStack(alignment: .top, spacing: 8) {
                ClearableTextFieldRow(
                    "Type your own question…",
                    text: $newCustomQuestionText,
                    axis: .vertical,
                    focus: $focusedField,
                    equals: .customQuestion
                )
                .font(.arial(size: 14))

                Button {
                    addCustomQuestion()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.arial(size: 24))
                        .foregroundColor(AppColors.primaryBlue)
                }
                .buttonStyle(.plain)
                .disabled(newCustomQuestionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .id(Self.addQuestionFieldID)
        } header: {
            MatchlyFormSectionHeader(title: "Add a Question")
        }
    }

    private func rowView(_ row: QuestionRow) -> some View {
        let isStarred = defaults.priorityQuestionIds.contains(row.id)
        let starsFull = defaults.priorityQuestionIds.count >= Self.maxPriorityCount

        return HStack(alignment: .top, spacing: 10) {
            Button {
                togglePriority(row.id)
            } label: {
                Image(systemName: isStarred ? "star.fill" : "star")
                    .font(.arial(size: 16))
                    .foregroundColor(isStarred ? .yellow : Color.primary.opacity(starsFull ? 0.15 : 0.35))
            }
            .buttonStyle(.plain)
            .disabled(!isStarred && starsFull)
            .accessibilityLabel(isStarred ? "Remove from must-ask questions" : "Mark as must-ask question")

            VStack(alignment: .leading, spacing: 2) {
                Text(row.question)
                    .font(.arial(size: 14))
                    .fixedSize(horizontal: false, vertical: true)
                Text(row.sectionTitle)
                    .font(.arial(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Mutations

    private func updateDefaults(_ mutate: (inout InterviewPrepDefaultQuestions) -> Void) {
        var current = dataManager.preferences.interviewPrepDefaultQuestions ?? InterviewPrepDefaultQuestions()
        mutate(&current)
        dataManager.preferences.interviewPrepDefaultQuestions = current
        dataManager.savePreferences()
    }

    private func addCustomQuestion() {
        let trimmed = newCustomQuestionText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let question = InterviewPrepCustomQuestion(question: trimmed)
        updateDefaults { current in
            current.customQuestions.append(question)
            current.questionListOrder.append(question.id)
        }
        newCustomQuestionText = ""
    }

    private func togglePriority(_ id: String) {
        updateDefaults { current in
            if current.priorityQuestionIds.contains(id) {
                current.priorityQuestionIds.removeAll { $0 == id }
            } else if current.priorityQuestionIds.count < Self.maxPriorityCount {
                current.priorityQuestionIds.append(id)
            }
        }
    }

    private func moveRows(from source: IndexSet, to destination: Int) {
        var ids = rows.map(\.id)
        ids.move(fromOffsets: source, toOffset: destination)
        updateDefaults { current in
            current.questionListOrder = ids
        }
    }

    private func deleteRows(at offsets: IndexSet) {
        let ids = offsets.map { rows[$0].id }
        updateDefaults { current in
            for id in ids {
                current.selectedQuestionIds.remove(id)
                current.customQuestions.removeAll { $0.id == id }
                current.questionListOrder.removeAll { $0 == id }
                current.priorityQuestionIds.removeAll { $0 == id }
            }
        }
    }
}

#Preview {
    MatchlyNavigationView {
        DefaultPrepQuestionsView()
            .environmentObject(DataManager.shared)
    }
}
