//
//  ProgramEntryView.swift
//  Matchly
//
//  Created by Leoh N. Leon II on 11/14/25.
//

import SwiftUI
import Combine
import MapKit
import CoreLocation
import UIKit
import EventKit
import OSLog

private let programEntryLogger = Logger(subsystem: "com.matchly", category: "ProgramEntryView")

struct ProgramEntryView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) var dismiss
    
    let program: Program?
    let scrollToFirstMissing: Bool
    let scrollToRedFlags: Bool
    /// When adding manually from program search, pre-select the specialty the user was filtering by.
    let preferredSpecialty: String?
    /// Called after saving a new manually entered program (closes search and returns to My Programs).
    var onNewManualProgramSaved: (() -> Void)? = nil
    
    @State private var specialty: String = ""
    @State private var name: String = ""
    @State private var hospital: String = ""
    @State private var city: String = ""
    @State private var state: String = ""
    @State private var postalCode: String = ""
    @State private var address: String = ""
    @State private var accreditationID: String? = nil
    @State private var type: String = ""
    @State private var notes: String = ""
    @State private var interviewDate: Date = Date()
    @State private var hasInterviewDate: Bool = false
    @State private var showProgramSearch = false
    @State private var showEnableCalendarSyncAlert = false
    @State private var pendingInterviewDate: Date? = nil
    @State private var previousInterviewDate: Date? = nil
    @State private var isInitialLoad = true
    /// True after picking a program from search; false while typing a manual program (avoids swapping the form when hospital is filled).
    @State private var didSelectProgramFromCatalog = false
    @State private var showManualSpecialtySheet = false
    @State private var showManualStateSheet = false
    @State private var manualStateSearchText = ""
    @State private var showMissingProgramNameAlert = false
    @State private var highlightMissingProgramName = false
    @State private var isEditingManualProgramDetails = false
    @State private var didPerformInitialProgramLoad = false
    @State private var hasUnsavedChanges = false
    @State private var showUnsavedChangesAlert = false
    @State private var pendingDismissal = false
    
    // Performance: Debounce expensive change checking
    @State private var changeCheckTask: Task<Void, Never>?
    
    // Focus state for notes
    @FocusState private var isNotesFocused: Bool
    @State private var showNotes: Bool = true
    @State private var keyboardHeight: CGFloat = 0
    @State private var draftProgramId: String = UUID().uuidString
    @State private var originalVoiceMemoReference: String?
    
    // Contact information
    @State private var websiteURL: String = ""
    @State private var contactEmail: String = ""
    @State private var contactPhone: String = ""
    @State private var programCoordinator: String = ""
    @State private var programDirector: String = ""
    
    // IMG-friendly status
    @State private var isIMGFriendly: Bool? = nil
    
    // Electronic Medical Record (EMR) used by this hospital (EMRSystem.rawValue,
    // or a free-typed name when the user picks Other and enters a custom system).
    @State private var emr: String? = nil
    @State private var emrOtherDetail: String = ""
    
    // ERAS Signaling
    @State private var signalType: SignalType = .none
    @State private var signalNote: String = ""
    @State private var showSignalLimitAlert = false
    @State private var showSignalClearedAlert = false
    @State private var signalLimitMessage = ""
    @State private var showDatePickerSheet = false
    @State private var showUnansweredQuestionsSheet = false
    
    // New comprehensive questionnaire
    @State private var questionnaire: Questionnaire = Questionnaire()
    @State private var expandedSections: Set<String> = [] // Track which sections are expanded
    /// Bumped to run `scrollTo` from inside `ScrollViewReader` (stored `ScrollViewProxy` is unreliable).
    @State private var programScrollToken = 0
    @State private var pendingProgramScrollID: String?
    @State private var pendingProgramScrollAnchor: UnitPoint = .top
    /// Faint highlight when EMR still needs a selection (not bright teal).
    private static let emrPromptFill = Color(red: 0.92, green: 0.95, blue: 0.99)
    private static let emrPromptStroke = Color(red: 0.78, green: 0.86, blue: 0.96)
    private static let emrPromptChevron = Color(red: 0.55, green: 0.68, blue: 0.88)

    private static func sectionHeaderScrollID(_ sectionId: String) -> String {
        "matchly-section-header-\(sectionId)"
    }

    /// First unanswered / jump targets: sit below pinned section headers.
    private static let questionnaireQuestionScrollAnchor = UnitPoint(x: 0.5, y: 0.34)
    /// After answering: bring the next question up without scrolling the previous one off-screen.
    private static let questionnaireRevealNextAnchor = UnitPoint(x: 0.5, y: 0.88)
    
    init(
        program: Program?,
        scrollToFirstMissing: Bool = false,
        scrollToRedFlags: Bool = false,
        preferredSpecialty: String? = nil,
        onNewManualProgramSaved: (() -> Void)? = nil
    ) {
        self.program = program
        self.scrollToFirstMissing = scrollToFirstMissing
        self.scrollToRedFlags = scrollToRedFlags
        self.preferredSpecialty = preferredSpecialty
        self.onNewManualProgramSaved = onNewManualProgramSaved

        if program == nil,
           let preferredSpecialty,
           !preferredSpecialty.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            _specialty = State(initialValue: preferredSpecialty)
        }
    }

    private var isManualDraftEntry: Bool {
        program == nil && !didSelectProgramFromCatalog
    }

    private var shouldShowManualBasicsSection: Bool {
        if program == nil {
            return !didSelectProgramFromCatalog
        }
        return program?.isManuallyAdded ?? false
    }

    private var isSavedManualProgram: Bool {
        program?.isManuallyAdded ?? false
    }

    private var showsCollapsedManualProgramSummary: Bool {
        isSavedManualProgram && !isEditingManualProgramDetails
    }

    private var showsProgramSummaryHeader: Bool {
        !isManualDraftEntry && !shouldShowManualBasicsSection && !hospital.isEmpty
    }

    private var manualEntryAllSpecialtyOptions: [String] {
        SpecialtyFormatter.commonSpecialties
    }

    private var manualEntryOtherSpecialtyOptions: [String] {
        let trimmed = specialty.trimmingCharacters(in: .whitespacesAndNewlines)
        return manualEntryAllSpecialtyOptions
            .filter { $0 != trimmed }
            .sorted()
    }

    private var trimmedProgramName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSaveProgram: Bool {
        !trimmedProgramName.isEmpty
    }

    private var manualEntrySpecialtyDisplayName: String {
        let trimmed = specialty.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return "Select specialty"
        }
        return SpecialtyFormatter.displayNameWithAbbreviation(trimmed)
    }
    
    // MARK: - Form Content (now using ScrollView for better scrolling)
    private var formContent: some View {
        ScrollViewReader { scrollProxy in
        ScrollView(.vertical) {
            LazyVStack(spacing: 16, pinnedViews: [.sectionHeaders]) {
                if showsCollapsedManualProgramSummary {
                    collapsedManualProgramSummary
                } else if shouldShowManualBasicsSection {
                    manualProgramBasicsSection
                }

                if !isManualDraftEntry {
                    // Combined Interview & Signaling Section - full width
                    VStack(spacing: 0) {
                        combinedInterviewAndSignalingSection
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 14)
                    }
                    .id("program-entry-top")
                    .glassEffect(.regular, in: .rect(cornerRadius: 16))
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                    if shouldShowSignalNoteSection {
                        signalNoteSection
                            .padding(.horizontal, 20)
                            .padding(.top, 8)
                    }

                if canOpenInterviewPrep {
                    interviewPrepReferenceCard
                }

                if !isQuestionnaireComplete {
                    questionnaireCompletionBanner
                        .padding(.horizontal, 20)
                }

                // Standard questionnaire sections - white card design
                questionnaireSections
                
                // Custom sections - white card design
                customQuestionnaireSections
                
                // Notes Section
                whiteCardContainer {
                    VStack(alignment: .leading, spacing: 14) {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showNotes.toggle()
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: showNotes ? "chevron.down" : "chevron.right")
                                    .font(.arial(size: 10, weight: .semibold))
                                    .foregroundColor(.secondary)
                                Text(notes.isEmpty ? "Add Notes" : "Notes")
                                    .font(.arial(size: 18, weight: .semibold))
                                    .foregroundColor(notes.isEmpty ? .secondary : .blue)
                                if !notes.isEmpty {
                                    Spacer()
                                    Image(systemName: "text.bubble.fill")
                                        .font(.arial(size: 12))
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .id("notes-section") // For scrolling
                        
                        if showNotes {
                            HStack(alignment: .top, spacing: 8) {
                                ClearableTextField("Notes...", text: $notes, axis: .vertical)
                                    .textFieldStyle(.roundedBorder)
                                    .lineLimit(5...10)
                                    .focused($isNotesFocused)
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                                
                                if isNotesFocused {
                                    VStack {
                                        Button(action: {
                                            isNotesFocused = false
                                        }) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.blue)
                                                .font(.arial(size: 20))
                                        }
                                        .buttonStyle(.plain)
                                        Spacer()
                                    }
                                    .frame(height: 44)
                                }
                            }
                            .onChange(of: isNotesFocused) { oldValue, newValue in
                                if newValue {
                                    requestProgramScroll(to: "notes-section", anchor: .center)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
                .padding(.horizontal, 20)

                whiteCardContainer {
                    ProgramVoiceMemoCard(programId: draftProgramId) {
                        hasUnsavedChanges = true
                    }
                }
                .padding(.horizontal, 20)
                }

                // Extra clearance when the keyboard is open
                Color.clear.frame(height: keyboardHeight > 0 ? 20 : 0)
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 8)
        }
        .scrollBounceBehavior(.basedOnSize, axes: .vertical)
        .matchlyScrollTabBarClearance()
        .scrollDismissesKeyboard(.interactively)
        .accessibilityIdentifier(MarketingAccessibilityID.programQuestionnaireRoot)
        .background(AppColors.dashboardCanvas)
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notification in
            if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                withAnimation {
                    keyboardHeight = keyboardFrame.height
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation {
                keyboardHeight = 0
            }
        }
        .onChange(of: programScrollToken) { _, _ in
            guard let scrollID = pendingProgramScrollID else { return }
            performProgramScroll(
                scrollID: scrollID,
                anchor: pendingProgramScrollAnchor,
                using: scrollProxy
            )
        }
        }
    }
    
    // MARK: - EMR Selection (Section E)
    private var sectionEEmrPicker: some View {
        let preferred = dataManager.preferences.preferredEMR
        let selectedIsSpecific = emr.flatMap { EMRSystem(rawValue: $0)?.isSpecific } ?? false
        let preferredIsSpecific = preferred.flatMap { EMRSystem(rawValue: $0)?.isSpecific } ?? false
        let isOtherSelected = EMRSystem.isOtherOrCustom(emr)
        let isEMRNotApplicable = EMRSystem.isNotApplicable(emr)
        let emrNeedsSelection = emr == nil || (emr?.isEmpty == true)

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "waveform.path.ecg.rectangle")
                    .font(.arial(size: 13))
                    .foregroundColor(.teal)
                Text("Electronic Medical Record (EMR)")
                    .font(.arial(size: 14, weight: .semibold))
                if preferredIsSpecific, emrNeedsSelection {
                    Text("Required")
                        .font(.arial(size: 10, weight: .bold))
                        .foregroundColor(AppColors.pipelineNeedDate)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(AppColors.pipelineNeedDate.opacity(0.12))
                        .clipShape(Capsule())
                }
            }

            Text("Which EMR does this hospital use?")
                .font(.arial(size: 12))
                .foregroundColor(.secondary)

            HStack(spacing: 8) {
                Menu {
                    Button(action: {
                        emr = nil
                        emrOtherDetail = ""
                    }) {
                        if emrNeedsSelection {
                            Label("Not selected", systemImage: "checkmark")
                        } else {
                            Text("Not selected")
                        }
                    }
                    ForEach(EMRSystem.menuChoices) { system in
                        Button(action: { selectEMR(system) }) {
                            if EMRSystem.matchesSelection(emr, system: system) {
                                Label(system.displayName, systemImage: "checkmark")
                            } else {
                                Text(system.displayName)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(emrMenuLabel)
                            .font(.arial(size: 13, weight: .medium))
                            .foregroundColor(emrPickerMenuLabelColor(needsSelection: emrNeedsSelection, isNotApplicable: isEMRNotApplicable))
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                        Spacer(minLength: 4)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.arial(size: 10))
                            .foregroundColor(emrPickerChevronColor(needsSelection: emrNeedsSelection, isNotApplicable: isEMRNotApplicable))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, minHeight: 36)
                    .background {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(emrNeedsSelection && !isEMRNotApplicable ? Self.emrPromptFill : Color.clear)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(
                                emrNeedsSelection && !isEMRNotApplicable ? Self.emrPromptStroke : Color.clear,
                                lineWidth: emrNeedsSelection && !isEMRNotApplicable ? 1 : 0
                            )
                    }
                    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 8))
                }
                .buttonStyle(.plain)

                Button(action: {
                    if isEMRNotApplicable {
                        emr = nil
                    } else {
                        emr = EMRSystem.notApplicable.rawValue
                        emrOtherDetail = ""
                    }
                }) {
                    Text("N/A")
                        .font(.arial(size: 11, weight: .semibold))
                        .foregroundColor(isEMRNotApplicable ? .white : .secondary)
                        .frame(width: 44, height: 36)
                        .background {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(isEMRNotApplicable ? Color.secondary : Color(.tertiarySystemFill))
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isEMRNotApplicable ? "EMR not applicable, selected" : "Mark EMR as not applicable")
            }

            if isEMRNotApplicable {
                Text("EMR won't affect this program's score (same as N/A on other questions).")
                    .font(.arial(size: 11))
                    .foregroundColor(.secondary)
            }

            if isOtherSelected {
                ClearableTextField("Type EMR name", text: $emrOtherDetail)
                    .font(.arial(size: 14))
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 10))
                    .onChange(of: emrOtherDetail) { _, newValue in
                        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                        emr = trimmed.isEmpty ? EMRSystem.other.rawValue : trimmed
                    }
            }

            if preferredIsSpecific, selectedIsSpecific, let preferred = preferred {
                if emr == preferred {
                    Label("Uses your preferred EMR", systemImage: "checkmark.circle.fill")
                        .font(.arial(size: 11, weight: .medium))
                        .foregroundColor(.green)
                } else {
                    Label("Uses \(emrMenuLabel) — you prefer \(preferred)", systemImage: "info.circle")
                        .font(.arial(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }
            } else if preferred == nil {
                Text("Set your preferred EMR in Settings to score EMR fit.")
                    .font(.arial(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.top, 4)
        .id("matchly.section.e-emr")
    }

    private func emrPickerMenuLabelColor(needsSelection: Bool, isNotApplicable: Bool) -> Color {
        if colorScheme == .dark {
            return .black
        }
        if needsSelection && !isNotApplicable {
            return .secondary
        }
        return .primary
    }

    private func emrPickerChevronColor(needsSelection: Bool, isNotApplicable: Bool) -> Color {
        if colorScheme == .dark {
            return Color.black.opacity(0.65)
        }
        if needsSelection && !isNotApplicable {
            return Self.emrPromptChevron
        }
        return .secondary
    }

    private var emrMenuLabel: String {
        if EMRSystem.isNotApplicable(emr) {
            return "N/A"
        }
        guard let emr else { return "Select EMR" }
        if EMRSystem.isOtherOrCustom(emr) {
            let trimmed = emrOtherDetail.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? EMRSystem.other.displayName : trimmed
        }
        return emr
    }

    private func selectEMR(_ system: EMRSystem) {
        if system == .notApplicable {
            emr = EMRSystem.notApplicable.rawValue
            emrOtherDetail = ""
            return
        }
        if system == .other {
            let trimmed = emrOtherDetail.trimmingCharacters(in: .whitespacesAndNewlines)
            emr = trimmed.isEmpty ? EMRSystem.other.rawValue : trimmed
        } else {
            emr = system.rawValue
            emrOtherDetail = ""
        }
    }

    // MARK: - Interview Prep

    private var canOpenInterviewPrep: Bool {
        hasInterviewDate && !hospital.isEmpty
    }

    private var isQuestionnaireComplete: Bool {
        questionnaire.questionnaireCompletionRatio(preferences: dataManager.preferences, programEMR: emr) >= 1.0
    }

    private var questionnaireCompletionPercent: Int {
        Int((questionnaire.questionnaireCompletionRatio(preferences: dataManager.preferences, programEMR: emr) * 100).rounded())
    }

    private var questionnaireUnansweredCount: Int {
        questionnaire.unansweredCount(preferences: dataManager.preferences, programEMR: emr)
    }

    private var questionnaireCompletionBanner: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Questionnaire \(questionnaireCompletionPercent)% complete")
                        .font(.arial(size: 15, weight: .semibold))
                    Text(questionnaireUnansweredCount == 1
                         ? "1 question still needs an answer"
                         : "\(questionnaireUnansweredCount) questions still need an answer")
                        .font(.arial(size: 13))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                Button("View unanswered") {
                    dismissProgramEntryKeyboard()
                    showUnansweredQuestionsSheet = true
                }
                .font(.arial(size: 14, weight: .semibold))
                .buttonStyle(.glassProminent)
                .tint(AppColors.primaryBlue)
            }

            ProgressView(value: questionnaire.questionnaireCompletionRatio(preferences: dataManager.preferences, programEMR: emr))
                .tint(AppColors.primaryBlue)
        }
        .padding(16)
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
        .id("program-questionnaire-start")
    }

    private var interviewPrepSummary: String {
        let prep = dataManager.preferences.interviewPrepByProgram[currentProgramId]
        if let prep, !prep.priorityQuestionIds.isEmpty {
            let count = prep.priorityQuestionIds.count
            return "\(count) must-ask question\(count == 1 ? "" : "s") saved"
        }
        if isQuestionnaireComplete {
            return "Review your questions and day-before checklist"
        }
        return "Pick questions, star your top 5, and run the checklist"
    }

    private var currentProgramId: String {
        program?.id ?? draftProgramId
    }

    private var interviewPrepReferenceCard: some View {
        NavigationLink(destination: InterviewPrepView(program: currentProgramSnapshot(), presentationContext: .fromProgramEntry)) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(AppColors.accentGreen.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: "calendar.badge.clock")
                        .font(.arial(size: 17, weight: .semibold))
                        .foregroundColor(AppColors.accentGreen)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(isQuestionnaireComplete ? "Interview Prep Reference" : "Interview Prep")
                        .font(.arial(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    Text(interviewPrepSummary)
                        .font(.arial(size: 12))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 8)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .glassEffect(.regular, in: .rect(cornerRadius: 16))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
    }

    private func currentProgramSnapshot() -> Program {
        let programId = currentProgramId
        let normalizedSpecialty = SpecialtyFormatter.normalizedUserSpecialty(
            !specialty.isEmpty
                ? specialty
                : (program?.specialty ?? dataManager.preferences.specialties.first ?? dataManager.preferences.specialty ?? "Unknown")
        )

        return Program(
            id: programId,
            specialty: normalizedSpecialty,
            name: name,
            hospital: hospital,
            city: city,
            state: state,
            address: address.isEmpty ? nil : address,
            type: type,
            accreditationID: accreditationID,
            programQuality: ProgramQuality(),
            cultureFit: CultureFit(),
            location: Location(),
            logistics: Logistics(),
            careerAlignment: CareerAlignment(),
            redFlags: RedFlags(),
            questionnaire: questionnaire,
            notes: notes,
            interviewDate: hasInterviewDate ? interviewDate : nil,
            voiceMemoURL: currentVoiceMemoReference,
            websiteURL: websiteURL.isEmpty ? nil : websiteURL,
            contactEmail: contactEmail.isEmpty ? nil : contactEmail,
            contactPhone: contactPhone.isEmpty ? nil : contactPhone,
            programCoordinator: programCoordinator.isEmpty ? nil : programCoordinator,
            programDirector: programDirector.isEmpty ? nil : programDirector,
            isIMGFriendly: isIMGFriendly,
            emr: emr,
            signalType: signalType,
            signalNote: trimmedSignalNote,
            finalScore: questionnaire.totalWeightedScore(preferences: dataManager.preferences, programEMR: emr)
        )
    }

    private var enabledStandardSections: [QuestionnaireSection] {
        let enabledIDs = Set(questionnaire.enabledSections(preferences: dataManager.preferences).map(\.id))
        return questionnaire.sections.filter { enabledIDs.contains($0.id) }
    }

    private var enabledCustomSections: [QuestionnaireSection] {
        let enabledIDs = Set(questionnaire.enabledSections(preferences: dataManager.preferences).map(\.id))
        var seen = Set<String>()
        return questionnaire.customSections.filter { section in
            guard enabledIDs.contains(section.id), !seen.contains(section.id) else { return false }
            seen.insert(section.id)
            return true
        }
    }

    // MARK: - Questionnaire Sections
    private var questionnaireSections: some View {
        ForEach(enabledStandardSections) { section in
            let enabledItems = questionnaire.enabledItems(for: section, preferences: dataManager.preferences)
            if !enabledItems.isEmpty {
                Section {
                    if expandedSections.contains(section.id) {
                        questionnaireSectionBody {
                            VStack(spacing: 10) {
                                ForEach(Array(enabledItems.enumerated()), id: \.element.id) { index, item in
                                    if let sectionIndex = questionnaire.sections.firstIndex(where: { $0.id == section.id }),
                                       let itemIndex = questionnaire.sections[sectionIndex].items.firstIndex(where: { $0.id == item.id }) {
                                        DualRatingSlider(
                                            question: item.question,
                                            programRating: Binding(
                                                get: { questionnaire.sections[sectionIndex].items[itemIndex].programRating },
                                                set: { newValue in
                                                    let previousRating = questionnaire.sections[sectionIndex].items[itemIndex].programRating
                                                    var transaction = Transaction()
                                                    transaction.disablesAnimations = true
                                                    withTransaction(transaction) {
                                                        var updated = questionnaire
                                                        updated.sections[sectionIndex].items[itemIndex].programRating = newValue
                                                        questionnaire = updated
                                                        checkAndExpandNextSection(currentSectionIndex: sectionIndex, currentItemIndex: itemIndex)
                                                    }
                                                    scrollToNextQuestionIfNeeded(
                                                        fromSectionId: section.id,
                                                        itemId: item.id,
                                                        previousRating: previousRating,
                                                        newRating: newValue
                                                    )
                                                }
                                            ),
                                            notes: Binding(
                                                get: { questionnaire.sections[sectionIndex].items[itemIndex].notes },
                                                set: { newValue in
                                                    var updated = questionnaire
                                                    updated.sections[sectionIndex].items[itemIndex].notes = newValue
                                                    questionnaire = updated
                                                }
                                            ),
                                            isYesNo: section.title.contains("Red flags"),
                                            isPositiveYesNo: item.question.contains("Do you feel you could see yourself living"),
                                            showLabels: index == 0,
                                            isUnanswered: item.programRating == 0
                                        )
                                        .id("\(section.id)-\(item.id)")
                                    }
                                }

                                if section.id == SectionWeighting.sectionEId {
                                    sectionEEmrPicker
                                }
                            }
                            .padding(.bottom, 4)
                        }
                    }
                } header: {
                    questionnaireSectionHeader(
                        title: section.title,
                        sectionId: section.id,
                        unansweredCount: sectionUnansweredCount(section),
                        accentColor: questionnaireSectionColor(title: section.title, sectionId: section.id),
                        isExpanded: sectionExpansionBinding(for: section.id)
                    )
                }
            }
        }
    }
                    
    // MARK: - Custom Questionnaire Sections
    private var customQuestionnaireSections: some View {
        ForEach(enabledCustomSections) { customSection in
            let enabledItems = questionnaire.enabledItems(for: customSection, preferences: dataManager.preferences)
            if !enabledItems.isEmpty {
                Section {
                    if expandedSections.contains(customSection.id) {
                        questionnaireSectionBody {
                            VStack(spacing: 12) {
                                ForEach(enabledItems) { item in
                                    if let sectionIndex = questionnaire.customSections.firstIndex(where: { $0.id == customSection.id }),
                                       let itemIndex = questionnaire.customSections[sectionIndex].items.firstIndex(where: { $0.id == item.id }) {
                                        DualRatingSlider(
                                            question: item.question,
                                            programRating: Binding(
                                                get: { questionnaire.customSections[sectionIndex].items[itemIndex].programRating },
                                                set: { newValue in
                                                    let previousRating = questionnaire.customSections[sectionIndex].items[itemIndex].programRating
                                                    var transaction = Transaction()
                                                    transaction.disablesAnimations = true
                                                    withTransaction(transaction) {
                                                        var updated = questionnaire
                                                        updated.customSections[sectionIndex].items[itemIndex].programRating = newValue
                                                        questionnaire = updated
                                                    }
                                                    scrollToNextQuestionIfNeeded(
                                                        fromSectionId: customSection.id,
                                                        itemId: item.id,
                                                        previousRating: previousRating,
                                                        newRating: newValue
                                                    )
                                                }
                                            ),
                                            notes: Binding(
                                                get: { questionnaire.customSections[sectionIndex].items[itemIndex].notes },
                                                set: { newValue in
                                                    var updated = questionnaire
                                                    updated.customSections[sectionIndex].items[itemIndex].notes = newValue
                                                    questionnaire = updated
                                                }
                                            ),
                                            isYesNo: false,
                                            isUnanswered: item.programRating == 0
                                        )
                                        .id("\(customSection.id)-\(item.id)")
                                    }
                                }
                            }
                        }
                    }
                } header: {
                    questionnaireSectionHeader(
                        title: customSection.title,
                        sectionId: customSection.id,
                        unansweredCount: sectionUnansweredCount(customSection),
                        accentColor: questionnaireSectionColor(title: customSection.title, sectionId: customSection.id),
                        isExpanded: sectionExpansionBinding(for: customSection.id)
                    )
                }
            }
        }
    }

    private func sectionExpansionBinding(for sectionId: String) -> Binding<Bool> {
        Binding(
            get: { expandedSections.contains(sectionId) },
            set: { isExpanded in
                if isExpanded {
                    expandedSections.insert(sectionId)
                } else {
                    expandedSections.remove(sectionId)
                }
            }
        )
    }
    
    var body: some View {
        contentWithSheets
    }
    
    private var contentWithSheets: some View {
        contentWithAlerts
        .sheet(isPresented: $showProgramSearch) {
            ProgramSearchView(onSelect: { programInfo in
                didSelectProgramFromCatalog = true
                let mapped = CatalogProgramMapper.toSavedProgram(programInfo)
                specialty = mapped.specialty
                name = mapped.name
                hospital = mapped.hospital
                city = mapped.city
                state = mapped.state
                address = mapped.address ?? ""
                accreditationID = mapped.accreditationID
                type = mapped.type
                websiteURL = mapped.websiteURL ?? ""
                contactEmail = mapped.contactEmail ?? ""
                contactPhone = mapped.contactPhone ?? ""
                programCoordinator = mapped.programCoordinator ?? ""
                programDirector = mapped.programDirector ?? ""
                isIMGFriendly = mapped.isIMGFriendly
                revalidateSignalAssignment()
                showProgramSearch = false
            })
            .matchlyExpandedSheet()
        }
        .sheet(isPresented: $showDatePickerSheet) {
            MatchlyNavigationView {
                VStack(spacing: 20) {
                    DatePicker("Interview Date & Time", selection: $interviewDate, displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .padding()
                        .onChange(of: interviewDate) { oldValue, newValue in
                            // Update pending date when picker changes
                            pendingInterviewDate = newValue
                        }
                    
                    Spacer()
                }
                .navigationTitle("Interview Date")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            showDatePickerSheet = false
                            pendingInterviewDate = nil
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            hasInterviewDate = true
                            // Set pending date before dismissing sheet
                            pendingInterviewDate = interviewDate
                            showDatePickerSheet = false
                            
                            if !isInitialLoad {
                                // Delay to ensure sheet is fully dismissed before showing alert
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    handleInterviewDateChanged(newDate: interviewDate)
                                }
                                
                                // Auto-save the program with the interview date without dismissing
                                let finalSpecialty = specialty.isEmpty ? (program?.specialty ?? dataManager.preferences.specialties.first ?? "Unknown") : specialty
                                let finalScore = questionnaire.totalWeightedScore(preferences: dataManager.preferences, programEMR: emr)
                                let updatedProgram = Program(
                                    id: program?.id ?? draftProgramId,
                                    specialty: finalSpecialty,
                                    name: name,
                                    hospital: hospital,
                                    city: city,
                                    state: state,
                                    address: address.isEmpty ? nil : address,
                                    type: type,
                                    accreditationID: accreditationID,
                                    programQuality: ProgramQuality(),
                                    cultureFit: CultureFit(),
                                    location: Location(),
                                    logistics: Logistics(),
                                    careerAlignment: CareerAlignment(),
                                    redFlags: RedFlags(),
                                    questionnaire: questionnaire,
                                    notes: notes,
                                    interviewDate: interviewDate,
                                    voiceMemoURL: currentVoiceMemoReference,
                                    websiteURL: websiteURL.isEmpty ? nil : websiteURL,
                                    contactEmail: contactEmail.isEmpty ? nil : contactEmail,
                                    contactPhone: contactPhone.isEmpty ? nil : contactPhone,
                                    programCoordinator: programCoordinator.isEmpty ? nil : programCoordinator,
                                    programDirector: programDirector.isEmpty ? nil : programDirector,
                                    isIMGFriendly: isIMGFriendly,
                                    emr: emr,
                                    signalType: signalType,
                                    signalNote: trimmedSignalNote,
                                    finalScore: finalScore
                                )
                                if program == nil {
                                    guard dataManager.addProgram(updatedProgram) == .added else { return }
                                } else {
                                    dataManager.updateProgram(updatedProgram)
                                }
                                dataManager.saveProgramsImmediately()
                            }
                        }
                    }
                }
            }
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showUnansweredQuestionsSheet) {
            UnansweredQuestionsSheet(
                questionnaire: $questionnaire,
                emr: $emr,
                preferences: dataManager.preferences,
                emrContent: { sectionEEmrPicker }
            )
        }
    }
    
    private var contentWithAlerts: some View {
        contentWithChangeTracking
            .interactiveDismissDisabled(hasUnsavedChanges)
            .alert("Unsaved Changes", isPresented: $showUnsavedChangesAlert) {
                Button("Discard", role: .destructive) {
                    hasUnsavedChanges = false
                    dismiss()
                    // Post notification to proceed with tab navigation after dismissal
                    if pendingDismissal {
                        NotificationCenter.default.post(name: NSNotification.Name("ProceedWithTabNavigation"), object: nil)
                        pendingDismissal = false
                    }
                }
                Button("Cancel", role: .cancel) {
                    pendingDismissal = false
                    NotificationCenter.default.post(name: NSNotification.Name("TabNavigationCancelled"), object: nil)
                }
                Button("Save") {
                    saveProgram()
                    // Post notification to proceed with tab navigation after save
                    if pendingDismissal {
                        NotificationCenter.default.post(name: NSNotification.Name("ProceedWithTabNavigation"), object: nil)
                        pendingDismissal = false
                    }
                }
            } message: {
                Text("You have unsaved changes. Would you like to save them before leaving?")
            }
            .alert("Signal Limit Reached", isPresented: $showSignalLimitAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(signalLimitMessage)
            }
            .alert("Signal Updated", isPresented: $showSignalClearedAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(signalLimitMessage)
            }
            .alert("Program Name Required", isPresented: $showMissingProgramNameAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Enter a program name before saving. Address search only fills location fields.")
            }
            .alert(
                "Already in List",
                isPresented: Binding(
                    get: { dataManager.lastAddProgramNotice != nil },
                    set: { if !$0 { dataManager.lastAddProgramNotice = nil } }
                )
            ) {
                Button("OK", role: .cancel) {
                    dataManager.lastAddProgramNotice = nil
                }
            } message: {
                Text(dataManager.lastAddProgramNotice ?? "")
            }
            .alert("Add to Calendar", isPresented: $showEnableCalendarSyncAlert) {
                Button("Not Now", role: .cancel) {
                    pendingInterviewDate = nil
                }
                Button("Add Event") {
                    addCalendarEventForInterview()
                    pendingInterviewDate = nil
                }
                Button("Always", role: .none) {
                    // Enable calendar sync and add event
                    dataManager.preferences.enableCalendarSync = true
                    dataManager.savePreferences()
                    addCalendarEventForInterview()
                    pendingInterviewDate = nil
                }
            } message: {
                Text("Would you like to add this interview to your calendar?")
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("TabBarNavigationRequested"))) { notification in
                guard hasUnsavedChanges,
                      let targetTab = notification.userInfo?["targetTab"] as? Int else { return }

                showUnsavedChangesAlert = true
                pendingDismissal = true
                NotificationCenter.default.post(
                    name: NSNotification.Name("TabNavigationBlocked"),
                    object: nil,
                    userInfo: ["targetTab": targetTab]
                )
            }
    }
    
    private var contentWithChangeTracking: some View {
        contentWithLifecycle
            .onChange(of: name) { _, _ in
                if !trimmedProgramName.isEmpty {
                    highlightMissingProgramName = false
                }
                debouncedCheckForUnsavedChanges()
            }
            .onChange(of: hospital) { _, _ in debouncedCheckForUnsavedChanges() }
            .onChange(of: city) { _, _ in debouncedCheckForUnsavedChanges() }
            .onChange(of: state) { _, _ in debouncedCheckForUnsavedChanges() }
            .onChange(of: postalCode) { _, newValue in
                let digits = newValue.filter(\.isNumber)
                let clipped = String(digits.prefix(5))
                if clipped != newValue {
                    postalCode = clipped
                }
                debouncedCheckForUnsavedChanges()
            }
            .onChange(of: notes) { _, _ in debouncedCheckForUnsavedChanges() }
            .onChange(of: interviewDate) { _, _ in debouncedCheckForUnsavedChanges() }
            .onChange(of: hasInterviewDate) { _, _ in debouncedCheckForUnsavedChanges() }
            .onChange(of: signalType) { _, _ in
                hasUnsavedChanges = checkForUnsavedChanges()
            }
            .onChange(of: signalNote) { _, _ in debouncedCheckForUnsavedChanges() }
            .onChange(of: specialty) { _, _ in
                revalidateSignalAssignment()
                debouncedCheckForUnsavedChanges()
            }
            .onChange(of: questionnaire) { _, _ in debouncedCheckForUnsavedChanges() }
            .onChange(of: emr) { _, _ in debouncedCheckForUnsavedChanges() }
    }
    
    // Debounced version to avoid expensive checks on every keystroke
    private func debouncedCheckForUnsavedChanges() {
        changeCheckTask?.cancel()

        changeCheckTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            hasUnsavedChanges = checkForUnsavedChanges()
        }
    }

    private var contentWithLifecycle: some View {
        mainContentView
            .onAppear {
                let isInitialAppearance = !didPerformInitialProgramLoad
                reloadProgramFromStoreIfNeeded(isInitialAppearance: isInitialAppearance)
                didPerformInitialProgramLoad = true

                if let sectionA = questionnaire.sections.first(where: { $0.title.contains("Section A") }) {
                    expandedSections.insert(sectionA.id)
                }

                if scrollToRedFlags {
                    revealFirstRedFlagSection()
                } else if scrollToFirstMissing {
                    revealFirstUnansweredQuestionSection()
                } else if isInitialAppearance {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        requestProgramScroll(to: "program-entry-top", anchor: .top)
                    }
                }
            }
            .onDisappear {
                autopPersistProgramChangesIfNeeded()
            }
            .onReceive(NotificationCenter.default.publisher(for: .matchlyFocusProgramQuestionnaire)) { notification in
                guard let programId = notification.userInfo?[MatchlyNotificationKey.programId] as? String,
                      programId == currentProgramId else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    focusQuestionnaireOnProgram()
                }
            }
    }

    @ViewBuilder
    private var programHeaderActionButtons: some View {
        HStack(spacing: 8) {
            if !websiteURL.isEmpty, let url = URL(string: websiteURL) {
                Button(action: {
                    UIApplication.shared.open(url)
                }) {
                    Image(systemName: "link")
                        .font(.arial(size: 16))
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
            }

            if !city.isEmpty && !state.isEmpty {
                Button(action: {
                    openInMaps()
                }) {
                    Image(systemName: "map.fill")
                        .font(.arial(size: 16))
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func locationSubtitle(city: String, state: String) -> String {
        let zip = postalCode.trimmingCharacters(in: .whitespacesAndNewlines)
        if zip.isEmpty {
            return "\(city), \(state)"
        }
        return "\(city), \(state) \(zip)"
    }

    private var programHeaderMetadataRow: some View {
        let resolved = AddressFormatter.resolved(
            hospital: hospital,
            address: address.isEmpty ? nil : address,
            city: city,
            state: state,
            accreditationID: accreditationID
        )

        return HStack(spacing: 8) {
            if !resolved.city.isEmpty && !resolved.state.isEmpty {
                HStack(spacing: 3) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.arial(size: 9))
                    Text(locationSubtitle(city: resolved.city, state: resolved.state))
                        .font(.arial(size: 11))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                .foregroundColor(.secondary)
            }

            if let acgmeID = accreditationID, !acgmeID.isEmpty {
                HStack(spacing: 2) {
                    Image(systemName: "number.circle.fill")
                        .font(.arial(size: 9))
                    Text("ID:")
                        .font(.arial(size: 10, weight: .medium))
                    Text(acgmeID)
                        .font(.arial(size: 11, weight: .medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                .foregroundColor(.secondary)
            }

            if !specialty.isEmpty {
                MatchlyProgramSpecialtyBadge(specialty: specialty)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var mainContentView: some View {
        VStack(spacing: 0) {
                if showsProgramSummaryHeader {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top, spacing: 10) {
                            Text(HospitalNameFormatter.format(hospital))
                                .font(.arial(size: 18, weight: .semibold))
                                .foregroundColor(.primary)
                                .lineLimit(3)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            programHeaderActionButtons
                        }

                        let streetLine = AddressFormatter.resolved(
                            hospital: hospital,
                            address: address.isEmpty ? nil : address,
                            city: city,
                            state: state,
                            accreditationID: accreditationID
                        ).street
                        if !streetLine.isEmpty {
                            Text(streetLine)
                                .font(.arial(size: 13, weight: .medium))
                                .foregroundColor(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        programHeaderMetadataRow
                        
                        // IMG tag
                        HStack(spacing: 8) {
                            let imgDisplay = IMGStatusDisplay.forSavedProgram(
                                Program(
                                    specialty: specialty,
                                    name: name,
                                    hospital: hospital,
                                    city: city,
                                    state: state,
                                    address: address.isEmpty ? nil : address,
                                    type: type,
                                    accreditationID: accreditationID,
                                    isIMGFriendly: isIMGFriendly
                                )
                            )
                            if imgDisplay != .none {
                                HStack(spacing: 3) {
                                    Image(systemName: "globe.americas.fill")
                                        .font(.arial(size: 10))
                                    Text(imgDisplay.label)
                                        .font(.arial(size: 12, weight: .medium))
                                }
                                .foregroundColor(imgDisplay.color)
                            }
                        }
                        
                        // Signal and Red Flags tags
                        HStack(spacing: 8) {
                            // Signal indicator
                            if signalType != .none {
                                let signalAccreditationID = currentSignalAccreditationID
                                let isTiered = SignalLimits.isTiered(
                                    for: specialty.isEmpty ? "Unknown" : specialty,
                                    accreditationID: signalAccreditationID
                                )
                                let signalText = isTiered 
                                    ? (signalType == .gold ? "Gold Signal" : "Silver Signal")
                                    : "Signal"
                                let signalColor = isTiered
                                    ? (signalType == .gold ? Color.yellow : Color(white: 0.6))
                                    : Color.blue
                                
                                HStack(spacing: 3) {
                                    Image(systemName: signalType == .gold ? "star.fill" : "star")
                                        .font(.arial(size: 10))
                                    Text(signalText)
                                        .font(.arial(size: 12, weight: .medium))
                                }
                                .foregroundColor(signalColor)
                            }
                            
                            // Red flag indicator - check if program has red flags
                            let tempProgram = Program(
                                specialty: specialty,
                                name: name,
                                hospital: hospital,
                                city: city,
                                state: state,
                                address: address,
                                type: type,
                                accreditationID: accreditationID,
                                questionnaire: questionnaire,
                                isIMGFriendly: isIMGFriendly
                            )
                            if tempProgram.hasRedFlags() {
                                HStack(spacing: 3) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.arial(size: 10))
                                    Text("Red Flag")
                                        .font(.arial(size: 12, weight: .medium))
                                }
                                .foregroundColor(.red)
                            }

                            if VoiceMemoStorage.programHasVoiceMemo(
                                id: draftProgramId,
                                reference: program?.voiceMemoURL ?? currentVoiceMemoReference
                            ) {
                                HStack(spacing: 3) {
                                    Image(systemName: "waveform")
                                        .font(.arial(size: 10))
                                    Text("Voice Memo")
                                        .font(.arial(size: 12, weight: .medium))
                                }
                                .foregroundColor(.purple)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 10))
                }
                
                formContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle(program == nil ? "Add Program" : "Edit Program")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(hasUnsavedChanges)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        if hasUnsavedChanges {
                            showUnsavedChangesAlert = true
                        } else {
                            dismiss()
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveProgram()
                    }
                    .font(.arial(size: 16, weight: .medium))
                    .buttonStyle(.glassProminent)
                    .tint(.blue)
                    .disabled(!canSaveProgram)
                }
            }
            .background(NavigationPopGestureBlocker(isBlocked: hasUnsavedChanges))
    }
    
    private var collapsedManualProgramSummary: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(trimmedProgramName.isEmpty ? "Program" : name)
                        .font(.arial(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    if !hospital.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(hospital)
                            .font(.arial(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    } else if !city.isEmpty && !state.isEmpty {
                        Text(locationSubtitle(city: city, state: USState.abbreviation(for: state)))
                            .font(.arial(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button("Edit") {
                    isEditingManualProgramDetails = true
                }
                .font(.arial(size: 15, weight: .semibold))
                .buttonStyle(.glassProminent)
                .tint(.blue)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .glassEffect(.regular, in: .rect(cornerRadius: 12))
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private var manualProgramBasicsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                Text("Basic Information")
                    .font(.arial(size: 20, weight: .semibold))
                Spacer(minLength: 8)
                if isSavedManualProgram {
                    Button("Done") {
                        isEditingManualProgramDetails = false
                    }
                    .font(.arial(size: 15, weight: .medium))
                }
            }
                .padding(.horizontal, 20)
                .padding(.top, 8)

            VStack(spacing: 12) {
                Button(action: {
                    showProgramSearch = true
                }) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.blue)
                        Text("Search Programs")
                            .foregroundColor(.blue)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 10))
                }
                .padding(.horizontal, 20)

                VStack(spacing: 0) {
                    manualFormRow {
                        VStack(alignment: .leading, spacing: 4) {
                            ClearableTextField("Program Name (required)", text: $name)
                                .font(.arial(size: 16))
                                .textContentType(.organizationName)
                                .autocorrectionDisabled()
                            if highlightMissingProgramName && trimmedProgramName.isEmpty {
                                Text("Enter a program name to save.")
                                    .font(.arial(size: 11, weight: .medium))
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    manualFormDivider
                    manualFormRow {
                        ClearableTextField("Hospital / University", text: $hospital)
                            .font(.arial(size: 16))
                            .textContentType(.organizationName)
                            .autocorrectionDisabled()
                    }
                    manualFormDivider
                    manualFormRow {
                        manualEntrySpecialtyPicker
                    }
                    manualFormDivider
                    manualFormRow {
                        ManualAddressSearchField(
                            address: $address,
                            city: $city,
                            state: $state,
                            postalCode: $postalCode
                        )
                    }
                    manualFormDivider
                    manualFormRow {
                        ClearableTextField("Street Address (e.g., 123 Main St)", text: $address)
                            .font(.arial(size: 16))
                            .autocapitalization(.words)
                    }
                    manualFormDivider
                    manualFormRow {
                        ClearableTextField("City", text: $city)
                            .font(.arial(size: 16))
                    }
                    manualFormDivider
                    manualFormRow {
                        manualEntryStatePicker
                    }
                    manualFormDivider
                    manualFormRow {
                        ClearableTextField("ZIP Code", text: $postalCode)
                            .font(.arial(size: 16))
                            .keyboardType(.numberPad)
                            .textContentType(.postalCode)
                    }
                }
                .glassEffect(.regular, in: .rect(cornerRadius: 12))
                .padding(.horizontal, 20)

                VStack(spacing: 0) {
                    manualFormRow {
                        Toggle("Set Interview Date", isOn: $hasInterviewDate)
                            .font(.arial(size: 16))
                            .onChange(of: hasInterviewDate) { oldValue, newValue in
                                if newValue && !isInitialLoad {
                                    handleInterviewDateChanged(newDate: interviewDate)
                                }
                            }
                    }

                    if hasInterviewDate {
                        manualFormDivider
                        manualFormRow {
                            DatePicker("Interview Date & Time", selection: $interviewDate, displayedComponents: [.date, .hourAndMinute])
                                .font(.arial(size: 16))
                                .onChange(of: interviewDate) { oldValue, newValue in
                                    if hasInterviewDate && !isInitialLoad && oldValue != newValue {
                                        pendingInterviewDate = newValue
                                        handleInterviewDateChanged(newDate: newValue)
                                    }
                                }
                        }
                    }
                }
                .glassEffect(.regular, in: .rect(cornerRadius: 12))
                .padding(.horizontal, 20)

                if !hospital.isEmpty {
                    combinedInterviewAndSignalingSection
                        .padding(.horizontal, 20)
                        .padding(.top, 4)
                }
            }
        }
        .padding(.bottom, 8)
        .sheet(isPresented: $showManualSpecialtySheet) {
            manualEntrySpecialtySheet
        }
        .sheet(isPresented: $showManualStateSheet) {
            manualEntryStateSheet
        }
    }

    private func manualFormRow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
    }

    private var manualFormDivider: some View {
        Divider()
            .padding(.leading, 14)
    }

    private var manualEntrySpecialtyPicker: some View {
        Button {
            showManualSpecialtySheet = true
        } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Specialty")
                        .font(.arial(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                    Text(manualEntrySpecialtyDisplayName)
                        .font(.arial(size: 16, weight: .medium))
                        .foregroundColor(specialty.isEmpty ? .secondary : .blue)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
            }
        }
        .buttonStyle(.plain)
    }

    private var manualEntrySpecialtySheet: some View {
        MatchlyNavigationView {
            List {
                if !specialty.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Section("Selected") {
                        manualEntrySpecialtySheetRow(specialty, isSelected: true)
                    }
                }

                Section(specialty.isEmpty ? "Specialty" : "Other specialties") {
                    ForEach(manualEntryOtherSpecialtyOptions, id: \.self) { option in
                        manualEntrySpecialtySheetRow(option, isSelected: false)
                    }
                }
            }
            .navigationTitle("Specialty")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showManualSpecialtySheet = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var manualEntryStateDisplayName: String {
        let trimmed = state.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return "Select state"
        }
        return USState.abbreviation(for: trimmed)
    }

    private var filteredManualEntryStates: [String] {
        let query = manualStateSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if query.isEmpty {
            return USState.selectableAbbreviations
        }
        let upper = query.uppercased()
        return USState.selectableAbbreviations.filter { abbrev in
            abbrev.contains(upper) || abbrev.localizedCaseInsensitiveContains(query)
        }
    }

    private var manualEntryStatePicker: some View {
        Button {
            manualStateSearchText = ""
            showManualStateSheet = true
        } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("State")
                        .font(.arial(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                    Text(manualEntryStateDisplayName)
                        .font(.arial(size: 16, weight: .medium))
                        .foregroundColor(state.isEmpty ? .secondary : .primary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
            }
        }
        .buttonStyle(.plain)
    }

    private var manualEntryStateSheet: some View {
        MatchlyNavigationView {
            List {
                if !state.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Section("Selected") {
                        manualEntryStateSheetRow(USState.abbreviation(for: state), isSelected: true)
                    }
                }

                Section(state.isEmpty ? "State" : "Other states") {
                    ForEach(filteredManualEntryStates.filter {
                        USState.abbreviation(for: state) != $0
                    }, id: \.self) { abbrev in
                        manualEntryStateSheetRow(abbrev, isSelected: false)
                    }
                }
            }
            .searchable(text: $manualStateSearchText, prompt: "Search states")
            .navigationTitle("State")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showManualStateSheet = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func manualEntryStateSheetRow(_ abbrev: String, isSelected: Bool) -> some View {
        Button {
            state = abbrev
            showManualStateSheet = false
        } label: {
            HStack {
                Text(abbrev)
                    .foregroundColor(.primary)
                Spacer()
                if isSelected || USState.abbreviation(for: state) == abbrev {
                    Image(systemName: "checkmark")
                        .foregroundColor(.blue)
                        .font(.body.weight(.semibold))
                }
            }
        }
    }

    private func manualEntrySpecialtySheetRow(_ option: String, isSelected: Bool) -> some View {
        Button {
            specialty = option
            revalidateSignalAssignment()
            showManualSpecialtySheet = false
        } label: {
            HStack {
                Text(SpecialtyFormatter.displayNameWithAbbreviation(option))
                    .foregroundColor(.primary)
                Spacer()
                if isSelected || specialty == option {
                    Image(systemName: "checkmark")
                        .foregroundColor(.blue)
                        .font(.body.weight(.semibold))
                }
            }
        }
    }

    private func loadProgram(_ program: Program) {
        didSelectProgramFromCatalog = !program.isManuallyAdded
        isEditingManualProgramDetails = false
        name = program.name
        hospital = program.hospital
        city = program.city
        state = program.state
        postalCode = program.postalCode ?? ""
        address = program.address ?? ""
        accreditationID = program.accreditationID
        type = program.type
        specialty = program.specialty
        notes = program.notes
        if let date = program.interviewDate {
            interviewDate = date
            hasInterviewDate = true
            previousInterviewDate = date
        }
        
        // Mark initial load as complete after a brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isInitialLoad = false
        }
        
        // Load contact information
        websiteURL = program.websiteURL ?? ""
        contactEmail = program.contactEmail ?? ""
        contactPhone = program.contactPhone ?? ""
        programCoordinator = program.programCoordinator ?? ""
        programDirector = program.programDirector ?? ""
        
        // Load IMG-friendly status
        isIMGFriendly = program.isIMGFriendly
        
        // Load EMR selection
        emr = program.emr
        if let stored = program.emr, EMRSystem.isOtherOrCustom(stored) {
            emrOtherDetail = stored == EMRSystem.other.rawValue ? "" : stored
        } else {
            emrOtherDetail = ""
        }
        
        // Load signal type
        signalType = program.signalType
        signalNote = program.signalNote ?? ""
        
        // Load questionnaire
        questionnaire = program.questionnaire
        questionnaire.mergeCustomization(from: dataManager.preferences)

        originalVoiceMemoReference = VoiceMemoStorage.normalizedReference(
            from: program.voiceMemoURL,
            programId: program.id
        )
    }

    private var currentVoiceMemoReference: String? {
        VoiceMemoStorage.referenceIfMemoExists(forProgramId: draftProgramId)
    }

    private func reloadProgramFromStoreIfNeeded(isInitialAppearance: Bool) {
        if let program {
            draftProgramId = program.id
            let latest = dataManager.programs.first(where: { $0.id == program.id }) ?? program
            if isInitialAppearance || !checkForUnsavedChanges() {
                loadProgram(latest)
                hasUnsavedChanges = false
            }
        } else if isInitialAppearance {
            draftProgramId = UUID().uuidString
            questionnaire.mergeCustomization(from: dataManager.preferences)
            if specialty.isEmpty {
                if let preferredSpecialty,
                   !preferredSpecialty.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    specialty = preferredSpecialty
                } else if let defaultSpecialty = dataManager.preferences.specialties.first {
                    specialty = defaultSpecialty
                }
            }
            isInitialLoad = false
        }
    }

    private func buildProgramDraft() -> Program {
        let programId = program?.id ?? draftProgramId
        let normalizedSpecialty = SpecialtyFormatter.normalizedUserSpecialty(
            !specialty.isEmpty ? specialty : (program?.specialty ?? dataManager.preferences.specialties.first ?? dataManager.preferences.specialty ?? "Unknown")
        )

        return Program(
            id: programId,
            specialty: normalizedSpecialty,
            name: trimmedProgramName,
            hospital: hospital.trimmingCharacters(in: .whitespacesAndNewlines),
            city: city,
            state: USState.abbreviation(for: state),
            postalCode: postalCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? nil
                : postalCode.trimmingCharacters(in: .whitespacesAndNewlines),
            address: address.isEmpty ? nil : address,
            type: type,
            accreditationID: accreditationID,
            programQuality: ProgramQuality(), // Keep for backward compatibility
            cultureFit: CultureFit(), // Keep for backward compatibility
            location: Location(), // Keep for backward compatibility
            logistics: Logistics(), // Keep for backward compatibility
            careerAlignment: CareerAlignment(), // Keep for backward compatibility
            redFlags: RedFlags(), // Keep for backward compatibility
            questionnaire: questionnaire,
            notes: notes,
            interviewDate: hasInterviewDate ? interviewDate : nil,
            voiceMemoURL: currentVoiceMemoReference,
            websiteURL: websiteURL.isEmpty ? nil : websiteURL,
            contactEmail: contactEmail.isEmpty ? nil : contactEmail,
            contactPhone: contactPhone.isEmpty ? nil : contactPhone,
            programCoordinator: programCoordinator.isEmpty ? nil : programCoordinator,
            programDirector: programDirector.isEmpty ? nil : programDirector,
            isIMGFriendly: isIMGFriendly,
            emr: emr,
            signalType: signalType,
            signalNote: trimmedSignalNote,
            finalScore: questionnaire.totalWeightedScore(preferences: dataManager.preferences, programEMR: emr)
        )
    }

    @discardableResult
    private func persistProgramChanges() -> Bool {
        guard validateProgramNameForSave() else { return false }
        let newProgram = buildProgramDraft()

        if program == nil {
            guard dataManager.addProgram(newProgram) == .added else { return false }
        } else {
            dataManager.updateProgram(newProgram)
        }

        dataManager.saveProgramsImmediately()
        return true
    }

    private func autopPersistProgramChangesIfNeeded() {
        changeCheckTask?.cancel()
        guard program != nil else { return }
        guard checkForUnsavedChanges() else { return }
        guard persistProgramChanges() else { return }
        hasUnsavedChanges = false
    }

    private func validateProgramNameForSave() -> Bool {
        guard !trimmedProgramName.isEmpty else {
            highlightMissingProgramName = true
            showMissingProgramNameAlert = true
            return false
        }
        highlightMissingProgramName = false
        return true
    }

    private func saveProgram() {
        let isNewManualProgram = program == nil && (accreditationID ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        guard persistProgramChanges() else { return }

        // Note: Calendar sync is handled through alerts when interview date is set/changed
        // No need to sync here as it's already handled in handleInterviewDateChanged

        hasUnsavedChanges = false
        if isSavedManualProgram {
            isEditingManualProgramDetails = false
        }
        if isNewManualProgram {
            onNewManualProgramSaved?()
        }
        dismiss()
    }
    
    /// Latest persisted copy used for dirty-state checks (not the snapshot passed at navigation time).
    private func persistedProgramBaseline() -> Program? {
        guard let id = program?.id else { return nil }
        return dataManager.programs.first(where: { $0.id == id })
    }

    // Check if there are unsaved changes - optimized to avoid expensive comparisons
    private func checkForUnsavedChanges() -> Bool {
        guard let program = persistedProgramBaseline() ?? program else {
            // For new programs, check if any fields are filled (quick checks)
            return !name.isEmpty || !hospital.isEmpty || !city.isEmpty || !state.isEmpty ||
                   !postalCode.isEmpty ||
                   !notes.isEmpty || hasInterviewDate || signalType != .none || !signalNote.isEmpty || emr != nil ||
                   currentVoiceMemoReference != nil ||
                   questionnaire.sections.contains { section in
                       section.items.contains { $0.programRating > 0 }
                   }
        }
        
        // For existing programs, compare current state with original (quick checks first)
        let originalDate = program.interviewDate
        let currentDate = hasInterviewDate ? interviewDate : nil
        
        if originalDate != currentDate {
            return true
        }
        
        // Quick string comparisons first
        if program.name != name || program.hospital != hospital || program.city != city ||
           program.state != USState.abbreviation(for: state) ||
           (program.postalCode ?? "") != postalCode.trimmingCharacters(in: .whitespacesAndNewlines) ||
           program.notes != notes || program.signalType != signalType ||
           program.signalNote != trimmedSignalNote || program.emr != emr ||
           program.voiceMemoURL != currentVoiceMemoReference {
            return true
        }
        
        // Only do expensive array comparisons if quick checks pass
        // Use count checks first to avoid full comparison
        if program.questionnaire.sections.count != questionnaire.sections.count {
            return true
        }
        
        if program.questionnaire.customSections.count != questionnaire.customSections.count {
            return true
        }
        
        // Only do full comparison if counts match (less frequent)
        if program.questionnaire.sections != questionnaire.sections {
            return true
        }
        
        if program.questionnaire.customSections != questionnaire.customSections {
            return true
        }
        
        return false
    }
    
    private func revealFirstUnansweredQuestionSection() {
        guard let target = questionnaire.firstUnansweredQuestion(
            preferences: dataManager.preferences,
            programEMR: emr
        ) else { return }
        dismissProgramEntryKeyboard()
        revealQuestionnaireSection(target.sectionId)
        requestProgramScroll(to: target.scrollID, anchor: Self.questionnaireQuestionScrollAnchor)
    }

    private func focusQuestionnaireOnProgram() {
        dismissProgramEntryKeyboard()
        if questionnaire.firstUnansweredQuestion(
            preferences: dataManager.preferences,
            programEMR: emr
        ) != nil {
            revealFirstUnansweredQuestionSection()
        } else {
            requestProgramScroll(to: "program-questionnaire-start", anchor: .top)
        }
    }

    private func dismissProgramEntryKeyboard() {
        isNotesFocused = false
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }

    private func revealFirstRedFlagSection() {
        guard let target = questionnaire.firstFlaggedRedFlagQuestion() else { return }
        revealQuestionnaireSection(target.sectionId)
    }

    private func revealQuestionnaireSection(_ sectionId: String) {
        var expandTransaction = Transaction()
        expandTransaction.disablesAnimations = true
        _ = withTransaction(expandTransaction) {
            expandedSections.insert(sectionId)
        }
    }

    private func requestProgramScroll(
        to scrollID: String,
        anchor: UnitPoint
    ) {
        pendingProgramScrollID = scrollID
        pendingProgramScrollAnchor = anchor
        programScrollToken += 1
    }

    private func scrollProgramContent(
        _ proxy: ScrollViewProxy,
        to scrollID: String,
        anchor: UnitPoint
    ) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            proxy.scrollTo(scrollID, anchor: anchor)
        }
    }

    private func performProgramScroll(
        scrollID: String,
        anchor: UnitPoint,
        using proxy: ScrollViewProxy
    ) {
        DispatchQueue.main.async {
            scrollProgramContent(proxy, to: scrollID, anchor: anchor)
        }
    }

    private func scrollToNextQuestionIfNeeded(
        fromSectionId: String,
        itemId: String,
        previousRating: Double,
        newRating: Double
    ) {
        guard previousRating == 0, newRating > 0 else { return }
        let current = QuestionnaireQuestionRef(sectionId: fromSectionId, itemId: itemId)
        guard let next = questionnaire.nextQuestion(
            after: current,
            preferences: dataManager.preferences
        ) else { return }
        if next.sectionId != fromSectionId {
            revealQuestionnaireSection(next.sectionId)
        }
        requestProgramScroll(to: next.scrollID, anchor: Self.questionnaireRevealNextAnchor)
    }

    private func sectionUnansweredCount(_ section: QuestionnaireSection) -> Int {
        questionnaire.unansweredQuestions(preferences: dataManager.preferences, programEMR: emr)
            .filter { $0.sectionId == section.id }
            .count
    }

    // Helper function to check if we should auto-expand next section
    private func checkAndExpandNextSection(currentSectionIndex: Int, currentItemIndex: Int) {
        guard currentSectionIndex < questionnaire.sections.count else { return }
        let currentSection = questionnaire.sections[currentSectionIndex]
        let enabledItems = questionnaire.enabledItems(for: currentSection, preferences: dataManager.preferences)
        
        // Check if this is the last enabled item in the current section
        if let lastEnabledItem = enabledItems.last,
           lastEnabledItem.id == currentSection.items[currentItemIndex].id {
            // Auto-expand next section if it exists
            let nextSectionIndex = currentSectionIndex + 1
            if nextSectionIndex < questionnaire.sections.count {
                let nextSection = questionnaire.sections[nextSectionIndex]
                let nextEnabledItems = questionnaire.enabledItems(for: nextSection, preferences: dataManager.preferences)
                if !nextEnabledItems.isEmpty {
                    var expandTransaction = Transaction()
                    expandTransaction.disablesAnimations = true
                    _ = withTransaction(expandTransaction) {
                        expandedSections.insert(nextSection.id)
                    }
                }
            }
        }
    }
    
    // Handle interview date change and prompt for calendar sync
    private func handleInterviewDateChanged(newDate: Date) {
        pendingInterviewDate = newDate
        interviewDate = newDate
        
        if dataManager.preferences.enableCalendarSync {
            // Calendar sync is enabled - automatically add to calendar
            addCalendarEventForInterview()
        } else {
            // Calendar sync is not enabled - ask if they want to add event
            showEnableCalendarSyncAlert = true
        }
    }
    
    // Add calendar event for interview
    private func addCalendarEventForInterview() {
        // Use pendingInterviewDate if available, otherwise use interviewDate
        let date = pendingInterviewDate ?? interviewDate
        
        // Update the interview date in state
        interviewDate = date
        pendingInterviewDate = date
        
        Task {
            do {
                let finalSpecialty = specialty.isEmpty ? (program?.specialty ?? dataManager.preferences.specialties.first ?? "Unknown") : specialty
                let tempProgram = Program(
                    id: program?.id ?? UUID().uuidString,
                    specialty: finalSpecialty,
                    name: name,
                    hospital: hospital,
                    city: city,
                    state: state,
                    address: address.isEmpty ? nil : address,
                    type: type,
                    accreditationID: accreditationID,
                    interviewDate: date,
                    websiteURL: websiteURL.isEmpty ? nil : websiteURL,
                    contactEmail: contactEmail.isEmpty ? nil : contactEmail,
                    contactPhone: contactPhone.isEmpty ? nil : contactPhone,
                    programCoordinator: programCoordinator.isEmpty ? nil : programCoordinator,
                    programDirector: programDirector.isEmpty ? nil : programDirector
                )

                try await CalendarManager.shared.createEventsForInterviews([tempProgram])
                programEntryLogger.info("Successfully created calendar event for interview")
            } catch {
                programEntryLogger.error("Failed to create calendar event: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
    
    // Helper function for rating colors (matching DualRatingSlider)
    private func ratingColor(for rating: Int) -> Color {
        switch rating {
        case 1: return Color(red: 0.9, green: 0.2, blue: 0.2)
        case 2: return Color(red: 1.0, green: 0.55, blue: 0.0)
        case 3: return Color(red: 1.0, green: 0.8, blue: 0.0)
        case 4: return Color(red: 0.5, green: 0.85, blue: 0.3)
        case 5: return Color(red: 0.2, green: 0.7, blue: 0.3)
        default: return .gray
        }
    }
    
    // Helper function to format interview date compactly
    private func formatInterviewDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.dateFormat = "MMM d, h:mm a"
        return formatter.string(from: date)
    }
    
    // MARK: - Combined Interview & Signaling Section

    private var interviewSchedulingRow: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "calendar")
                .font(.arial(size: 15))
                .foregroundColor(.secondary)
                .frame(width: 18, height: 18)
                .padding(.top, 2)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text("Interview")
                    .font(.arial(size: 16, weight: .semibold))
                    .foregroundColor(.primary)

                Button {
                    showDatePickerSheet = true
                } label: {
                    if hasInterviewDate {
                        Text(formatInterviewDate(interviewDate))
                            .font(.arial(size: 15, weight: .medium))
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text("Set Date")
                            .font(.arial(size: 15, weight: .medium))
                            .foregroundColor(.blue)
                    }
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var combinedInterviewAndSignalingSection: some View {
        let finalSpecialty = specialty.isEmpty ? (program?.specialty ?? dataManager.preferences.specialties.first ?? "Unknown") : specialty
        let signalAccreditationID = currentSignalAccreditationID
        let signalConfig = SignalLimits.configuration(for: finalSpecialty, accreditationID: signalAccreditationID)

        return VStack(alignment: .leading, spacing: 8) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 12) {
                    interviewSchedulingRow

                    if signalConfig.participates {
                        Rectangle()
                            .fill(Color(.separator))
                            .frame(width: 1, height: 22)

                        signalingControls(
                            finalSpecialty: finalSpecialty,
                            signalAccreditationID: signalAccreditationID,
                            signalConfig: signalConfig
                        )
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    interviewSchedulingRow

                    if signalConfig.participates {
                        signalingControls(
                            finalSpecialty: finalSpecialty,
                            signalAccreditationID: signalAccreditationID,
                            signalConfig: signalConfig
                        )
                    }
                }
            }

            if signalConfig.usesResidencyCAS {
                Text("Signals are tracked for planning. EM and OB/GYN apply through ResidencyCAS—verify limits in your portal.")
                    .font(.arial(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private func signalingControls(
        finalSpecialty: String,
        signalAccreditationID: String?,
        signalConfig: SignalConfiguration
    ) -> some View {
        let isTiered = signalConfig.isTiered

        HStack(alignment: .center, spacing: 5) {
            Image(systemName: "star.fill")
                .font(.arial(size: 14))
                .foregroundColor(
                    signalType == .gold ? (isTiered ? .yellow : .blue) :
                    (signalType == .silver ? Color(white: 0.6) : .secondary)
                )
                .frame(width: 16, height: 16)

            if isTiered {
                HStack(spacing: 3) {
                    Button(action: {
                        if signalType == .gold {
                            signalType = .none
                        } else {
                            let result = dataManager.canAssignSignal(
                                type: .gold,
                                specialty: finalSpecialty,
                                excludingProgramId: program?.id,
                                accreditationID: signalAccreditationID
                            )
                            if result.canAssign {
                                signalType = .gold
                                dataManager.objectWillChange.send()
                            } else {
                                signalLimitMessage = result.reason ?? "Signal limit reached"
                                showSignalLimitAlert = true
                            }
                        }
                    }) {
                        Text("Gold")
                            .font(.arial(size: 12, weight: .semibold))
                            .foregroundColor(signalType == .gold ? .yellow : .secondary)
                            .fixedSize(horizontal: true, vertical: false)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .glassChipStyle(
                                tint: signalType == .gold ? .yellow : nil,
                                interactive: true
                            )
                    }
                    .buttonStyle(.plain)

                    Button(action: {
                        if signalType == .silver {
                            signalType = .none
                        } else {
                            let result = dataManager.canAssignSignal(
                                type: .silver,
                                specialty: finalSpecialty,
                                excludingProgramId: program?.id,
                                accreditationID: signalAccreditationID
                            )
                            if result.canAssign {
                                signalType = .silver
                                dataManager.objectWillChange.send()
                            } else {
                                signalLimitMessage = result.reason ?? "Signal limit reached"
                                showSignalLimitAlert = true
                            }
                        }
                    }) {
                        Text("Silver")
                            .font(.arial(size: 12, weight: .semibold))
                            .foregroundColor(signalType == .silver ? .primary : .secondary)
                            .fixedSize(horizontal: true, vertical: false)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .glassChipStyle(
                                tint: signalType == .silver ? .gray : nil,
                                interactive: true
                            )
                    }
                    .buttonStyle(.plain)
                }
            } else {
                Button(action: {
                    if signalType == .gold {
                        signalType = .none
                    } else {
                        let result = dataManager.canAssignSignal(
                            type: .gold,
                            specialty: finalSpecialty,
                            excludingProgramId: program?.id,
                            accreditationID: signalAccreditationID
                        )
                        if result.canAssign {
                            signalType = .gold
                            dataManager.objectWillChange.send()
                        } else {
                            signalLimitMessage = result.reason ?? "Signal limit reached"
                            showSignalLimitAlert = true
                        }
                    }
                }) {
                    Text("Signal")
                        .font(.arial(size: 12, weight: .semibold))
                        .foregroundColor(signalType == .gold ? AppColors.primaryBlue : .secondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .glassChipStyle(
                            tint: signalType == .gold ? AppColors.primaryBlue : nil,
                            interactive: true
                        )
                }
                .buttonStyle(.plain)
            }

            if !finalSpecialty.isEmpty && finalSpecialty != "Unknown" {
                let usage = calculateSignalUsage(for: finalSpecialty, accreditationID: signalAccreditationID)
                Text(isTiered ? "\(usage.goldUsed)/\(usage.goldLimit)G \(usage.silverUsed)/\(usage.silverLimit)S" : "\(usage.goldUsed)/\(usage.goldLimit)")
                    .font(.arial(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.leading, 3)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var trimmedSignalNote: String? {
        let trimmed = signalNote.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private var currentSignalAccreditationID: String? {
        if let accreditationID, !accreditationID.isEmpty { return accreditationID }
        return program?.accreditationID
    }

    private var shouldShowSignalNoteSection: Bool {
        let finalSpecialty = specialty.isEmpty ? (program?.specialty ?? "") : specialty
        let config = SignalLimits.configuration(for: finalSpecialty, accreditationID: currentSignalAccreditationID)
        return config.participates && (config.requiresSignalStatement || signalType != .none)
    }

    private var signalNoteSection: some View {
        let finalSpecialty = specialty.isEmpty ? (program?.specialty ?? "") : specialty
        let config = SignalLimits.configuration(for: finalSpecialty, accreditationID: currentSignalAccreditationID)

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "text.quote")
                    .foregroundColor(.secondary)
                Text(config.requiresSignalStatement ? "Signal Statement" : "Signal Notes")
                    .font(.arial(size: 14, weight: .semibold))
                if config.requiresSignalStatement {
                    Text("Required")
                        .font(.arial(size: 10, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.15))
                        .foregroundColor(.orange)
                        .clipShape(Capsule())
                }
            }

            ClearableTextField(
                "Why this program? (for your ERAS / ResidencyCAS application)",
                text: $signalNote,
                axis: .vertical
            )
            .lineLimit(3...6)
            .font(.arial(size: 14))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
    }

    private func revalidateSignalAssignment() {
        let finalSpecialty = specialty.isEmpty ? (program?.specialty ?? dataManager.preferences.specialties.first ?? "Unknown") : specialty
        let sanitized = dataManager.sanitizedSignalType(
            signalType,
            specialty: finalSpecialty,
            accreditationID: currentSignalAccreditationID
        )
        guard sanitized != signalType else { return }
        signalType = sanitized
        if sanitized == .none {
            signalNote = ""
            signalLimitMessage = "The signal was cleared because this specialty uses different signaling rules."
            showSignalClearedAlert = true
        }
    }
    
    // Helper function to calculate signal usage including current selection
    private func calculateSignalUsage(
        for specialty: String,
        accreditationID: String? = nil
    ) -> (goldUsed: Int, goldLimit: Int, silverUsed: Int, silverLimit: Int) {
        let baseUsage = dataManager.getSignalUsage(for: specialty, accreditationID: accreditationID)
        
        // Adjust counts based on current selection vs saved state
        var goldUsed = baseUsage.goldUsed
        var silverUsed = baseUsage.silverUsed
        
        // If editing an existing program, remove its old signal from the count
        if let existingProgram = program {
            if existingProgram.signalType == .gold {
                goldUsed = max(0, goldUsed - 1)
            } else if existingProgram.signalType == .silver {
                silverUsed = max(0, silverUsed - 1)
            }
        }
        
        // Add current signal selection
        if signalType == .gold {
            goldUsed += 1
        } else if signalType == .silver {
            silverUsed += 1
        }
        
        return (goldUsed: goldUsed, goldLimit: baseUsage.goldLimit, silverUsed: silverUsed, silverLimit: baseUsage.silverLimit)
    }
    
    private func openInMaps() {
        let draft = Program(
            specialty: specialty,
            hospital: hospital,
            city: city,
            state: state,
            address: address.isEmpty ? nil : address,
            accreditationID: accreditationID
        )
        let addressString = AddressFormatter.geocodingQuery(for: draft)
        
        Task { @MainActor in
            do {
                let location = try await geocodeAddress(addressString)
                let mapItem = MKMapItem(location: location, address: nil)
                mapItem.name = hospital.isEmpty ? (name.isEmpty ? "Program Location" : name) : hospital
                mapItem.openInMaps(launchOptions: [
                    MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
                ])
            } catch {
                programEntryLogger.error("Geocoding error: \(error.localizedDescription, privacy: .public)")
                // Fallback: use city/state coordinates from GeocodingHelper
                let fallbackCoordinate = GeocodingHelper.coordinate(for: city, state: state)
                let fallbackLocation = CLLocation(latitude: fallbackCoordinate.latitude, longitude: fallbackCoordinate.longitude)
                let mapItem = MKMapItem(location: fallbackLocation, address: nil)
                mapItem.name = hospital.isEmpty ? (name.isEmpty ? "Program Location" : name) : hospital
                mapItem.openInMaps(launchOptions: [
                    MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
                ])
            }
        }
    }
    
    private func geocodeAddress(_ addressString: String) async throws -> CLLocation {
        // Use modern GeocodingHelper which uses MKLocalSearch (iOS 13+) or CLGeocoder fallback
        return try await GeocodingHelper.geocodeAddress(addressString)
    }
}

// MARK: - Liquid Glass Card Components

extension ProgramEntryView {
    // Liquid glass card container - full width, beautiful design
    @ViewBuilder
    func whiteCardContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(.vertical, 4)
            .glassEffect(.regular, in: .rect(cornerRadius: 16))
    }
    
    // Liquid glass questionnaire section - full width, beautiful design
    @ViewBuilder
    func questionnaireSectionColor(title: String, sectionId: String) -> Color {
        QuestionnaireSectionAccent.color(for: sectionId, title: title)
    }

    func questionnaireSectionHeader(
        title: String,
        sectionId: String,
        unansweredCount: Int = 0,
        accentColor: Color = AppColors.primaryBlue,
        isExpanded: Binding<Bool>
    ) -> some View {
        Button(action: {
            isExpanded.wrappedValue.toggle()
        }) {
            HStack(spacing: 12) {
                Text(title)
                    .font(.arial(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)

                if unansweredCount > 0 {
                    Text("\(unansweredCount) left")
                        .font(.arial(size: 11, weight: .semibold))
                        .foregroundStyle(AppColors.pipelineNeedDate)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(AppColors.pipelineNeedDate.opacity(0.14))
                        )
                }

                Spacer(minLength: 8)

                Image(systemName: isExpanded.wrappedValue ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(accentColor)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(AppColors.dashboardCanvas)
        .padding(.horizontal, 20)
        .id(Self.sectionHeaderScrollID(sectionId))
    }

    @ViewBuilder
    func questionnaireSectionBody<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            Divider()
                .padding(.horizontal, 16)

            content()
                .padding(.horizontal, 16)
                .padding(.top, 6)
                .padding(.bottom, 10)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
        .padding(.horizontal, 20)
    }
}

/// Disables swipe-back when there are unsaved changes so the alert can prompt first.
private struct NavigationPopGestureBlocker: UIViewControllerRepresentable {
    let isBlocked: Bool

    func makeUIViewController(context: Context) -> UIViewController {
        UIViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        DispatchQueue.main.async {
            uiViewController.navigationController?.interactivePopGestureRecognizer?.isEnabled = !isBlocked
        }
    }
}

#Preview {
    ProgramEntryView(program: nil)
        .environmentObject(DataManager.shared)
}

