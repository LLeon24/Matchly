//
//  UnansweredQuestionsSheet.swift
//  Matchly
//

import SwiftUI

struct UnansweredQuestionsSheet<EMRContent: View>: View {
    @Binding var questionnaire: Questionnaire
    @Binding var emr: String?
    var preferences: UserPreferences
    @ViewBuilder var emrContent: () -> EMRContent

    @Environment(\.dismiss) private var dismiss

    private var unanswered: [QuestionnaireQuestionRef] {
        questionnaire.unansweredQuestions(preferences: preferences, programEMR: emr)
    }

    private var groupedSections: [(sectionId: String, title: String, refs: [QuestionnaireQuestionRef])] {
        var order: [String] = []
        var buckets: [String: [QuestionnaireQuestionRef]] = [:]
        for ref in unanswered {
            if buckets[ref.sectionId] == nil {
                order.append(ref.sectionId)
                buckets[ref.sectionId] = []
            }
            buckets[ref.sectionId]?.append(ref)
        }
        return order.compactMap { sectionId in
            guard let refs = buckets[sectionId], !refs.isEmpty else { return nil }
            return (sectionId, sectionTitle(sectionId), refs)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if unanswered.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.green)
                        Text("All caught up")
                            .font(.arial(size: 20, weight: .semibold))
                        Text("Every enabled question has an answer.")
                            .font(.arial(size: 15))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(32)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 20) {
                            Text("Only questions that still need an answer are shown here.")
                                .font(.arial(size: 13))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 20)

                            ForEach(groupedSections, id: \.sectionId) { group in
                                VStack(alignment: .leading, spacing: 12) {
                                    Text(group.title)
                                        .font(.arial(size: 15, weight: .semibold))
                                        .foregroundStyle(AppColors.primaryBlue)
                                        .padding(.horizontal, 20)

                                    VStack(spacing: 10) {
                                        ForEach(group.refs, id: \.self) { ref in
                                            unansweredRow(for: ref)
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .glassEffect(.regular, in: .rect(cornerRadius: 16))
                                    .padding(.horizontal, 20)
                                }
                            }
                        }
                        .padding(.vertical, 16)
                        .padding(.bottom, 24)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .appCanvasBackground()
            .navigationTitle("Unanswered Questions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .matchlyExpandedSheet()
    }

    @ViewBuilder
    private func unansweredRow(for ref: QuestionnaireQuestionRef) -> some View {
        if ref.itemId == QuestionnaireQuestionRef.emrPickerItemId {
            emrContent()
        } else if let question = questionText(for: ref),
                  let ratingBinding = programRatingBinding(for: ref) {
            DualRatingSlider(
                question: question,
                programRating: ratingBinding,
                notes: notesBinding(for: ref),
                isYesNo: isRedFlagSection(ref.sectionId),
                isPositiveYesNo: question.contains("Do you feel you could see yourself living"),
                showLabels: true,
                isUnanswered: true
            )
        }
    }

    private func sectionTitle(_ sectionId: String) -> String {
        if let section = questionnaire.sections.first(where: { $0.id == sectionId }) {
            return section.title
        }
        if let section = questionnaire.customSections.first(where: { $0.id == sectionId }) {
            return section.title
        }
        return "Questionnaire"
    }

    private func questionText(for ref: QuestionnaireQuestionRef) -> String? {
        if let section = questionnaire.sections.first(where: { $0.id == ref.sectionId }),
           let item = section.items.first(where: { $0.id == ref.itemId }) {
            return item.question
        }
        if let section = questionnaire.customSections.first(where: { $0.id == ref.sectionId }),
           let item = section.items.first(where: { $0.id == ref.itemId }) {
            return item.question
        }
        return nil
    }

    private func isRedFlagSection(_ sectionId: String) -> Bool {
        sectionTitle(sectionId).lowercased().contains("red flag")
    }

    private func programRatingBinding(for ref: QuestionnaireQuestionRef) -> Binding<Double>? {
        if let sectionIndex = questionnaire.sections.firstIndex(where: { $0.id == ref.sectionId }),
           let itemIndex = questionnaire.sections[sectionIndex].items.firstIndex(where: { $0.id == ref.itemId }) {
            return Binding(
                get: { questionnaire.sections[sectionIndex].items[itemIndex].programRating },
                set: { newValue in
                    var updated = questionnaire
                    updated.sections[sectionIndex].items[itemIndex].programRating = newValue
                    questionnaire = updated
                }
            )
        }
        if let sectionIndex = questionnaire.customSections.firstIndex(where: { $0.id == ref.sectionId }),
           let itemIndex = questionnaire.customSections[sectionIndex].items.firstIndex(where: { $0.id == ref.itemId }) {
            return Binding(
                get: { questionnaire.customSections[sectionIndex].items[itemIndex].programRating },
                set: { newValue in
                    var updated = questionnaire
                    updated.customSections[sectionIndex].items[itemIndex].programRating = newValue
                    questionnaire = updated
                }
            )
        }
        return nil
    }

    private func notesBinding(for ref: QuestionnaireQuestionRef) -> Binding<String> {
        if let sectionIndex = questionnaire.sections.firstIndex(where: { $0.id == ref.sectionId }),
           let itemIndex = questionnaire.sections[sectionIndex].items.firstIndex(where: { $0.id == ref.itemId }) {
            return Binding(
                get: { questionnaire.sections[sectionIndex].items[itemIndex].notes },
                set: { newValue in
                    var updated = questionnaire
                    updated.sections[sectionIndex].items[itemIndex].notes = newValue
                    questionnaire = updated
                }
            )
        }
        if let sectionIndex = questionnaire.customSections.firstIndex(where: { $0.id == ref.sectionId }),
           let itemIndex = questionnaire.customSections[sectionIndex].items.firstIndex(where: { $0.id == ref.itemId }) {
            return Binding(
                get: { questionnaire.customSections[sectionIndex].items[itemIndex].notes },
                set: { newValue in
                    var updated = questionnaire
                    updated.customSections[sectionIndex].items[itemIndex].notes = newValue
                    questionnaire = updated
                }
            )
        }
        return .constant("")
    }
}
