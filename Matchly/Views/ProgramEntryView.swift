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
    @Environment(\.dismiss) var dismiss
    
    let program: Program?
    let scrollToFirstMissing: Bool
    let scrollToRedFlags: Bool
    
    @State private var specialty: String = ""
    @State private var name: String = ""
    @State private var hospital: String = ""
    @State private var city: String = ""
    @State private var state: String = ""
    @State private var address: String = ""
    @State private var accreditationID: String? = nil
    @State private var type: String = ""
    @State private var notes: String = ""
    @State private var interviewDate: Date = Date()
    @State private var hasInterviewDate: Bool = false
    @State private var showProgramSearch = false
    @State private var showContactInfo = false
    @State private var showEnableCalendarSyncAlert = false
    @State private var pendingInterviewDate: Date? = nil
    @State private var previousInterviewDate: Date? = nil
    @State private var isInitialLoad = true
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
    
    // New comprehensive questionnaire
    @State private var questionnaire: Questionnaire = Questionnaire()
    @State private var expandedSections: Set<String> = [] // Track which sections are expanded
    @State private var scrollProxy: ScrollViewProxy? = nil // Notes + questionnaire auto-scroll

    /// Positions the next question below mid-screen so the just-answered question stays visible above.
    private static let nextQuestionScrollAnchor = UnitPoint(x: 0.5, y: 0.42)
    private static let questionScrollAnimation = Animation.easeInOut(duration: 0.2)
    private static let questionScrollDelay: TimeInterval = 0.08
    
    init(program: Program?, scrollToFirstMissing: Bool = false, scrollToRedFlags: Bool = false) {
        self.program = program
        self.scrollToFirstMissing = scrollToFirstMissing
        self.scrollToRedFlags = scrollToRedFlags
    }
    
    // MARK: - Form Content (now using ScrollView for better scrolling)
    private var formContent: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Basic Information Section (only show if hospital not selected)
                if hospital.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Basic Information")
                            .font(.arial(size: 20, weight: .semibold))
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
                            
                            ClearableTextField("Program Name", text: $name)
                                .padding(.horizontal, 16)
                            
                            ClearableTextField("Hospital / University", text: $hospital)
                                .padding(.horizontal, 16)
                            
                            ClearableTextField("Street Address (e.g., 123 Main St)", text: $address)
                                .autocapitalization(.words)
                                .padding(.horizontal, 16)
                            
                            ClearableTextField("City", text: $city)
                                .padding(.horizontal, 16)
                            
                            ClearableTextField("State", text: $state)
                                .padding(.horizontal, 16)
                            
                            Toggle("Set Interview Date", isOn: $hasInterviewDate)
                                .padding(.horizontal, 16)
                                .onChange(of: hasInterviewDate) { oldValue, newValue in
                                    if newValue && !isInitialLoad {
                                        handleInterviewDateChanged(newDate: interviewDate)
                                    }
                                }
                            
                            if hasInterviewDate {
                                DatePicker("Interview Date & Time", selection: $interviewDate, displayedComponents: [.date, .hourAndMinute])
                                    .padding(.horizontal, 16)
                                    .onChange(of: interviewDate) { oldValue, newValue in
                                        if hasInterviewDate && !isInitialLoad && oldValue != newValue {
                                            pendingInterviewDate = newValue
                                            handleInterviewDateChanged(newDate: newValue)
                                        }
                                    }
                            }
                        }
                    }
                    .padding(.bottom, 8)
                } else {
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
                }
                
                // EMR selection - white card design
                emrSelectionCard

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
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                        if let proxy = scrollProxy {
                                            withAnimation(Self.questionScrollAnimation) {
                                                proxy.scrollTo("notes-section", anchor: .center)
                                            }
                                        }
                                    }
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
                
                // Extra clearance when the keyboard is open
                Color.clear.frame(height: keyboardHeight > 0 ? 20 : 0)
            }
            .padding(.bottom, 8)
        }
        .matchlyScrollTabBarClearance()
        .scrollDismissesKeyboard(.interactively)
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
    }
    
    // MARK: - EMR Selection
    private var emrSelectionCard: some View {
        let preferred = dataManager.preferences.preferredEMR
        let selectedIsSpecific = emr.flatMap { EMRSystem(rawValue: $0)?.isSpecific } ?? false
        let preferredIsSpecific = preferred.flatMap { EMRSystem(rawValue: $0)?.isSpecific } ?? false
        let isOtherSelected = EMRSystem.isOtherOrCustom(emr)

        return whiteCardContainer {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "waveform.path.ecg.rectangle")
                        .font(.arial(size: 14))
                        .foregroundColor(.blue)
                    Text("Electronic Medical Record (EMR)")
                        .font(.arial(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    Spacer()
                }

                Text("Which EMR does this hospital use?")
                    .font(.arial(size: 13))
                    .foregroundColor(.secondary)

                Menu {
                    Button(action: {
                        emr = nil
                        emrOtherDetail = ""
                    }) {
                        if emr == nil {
                            Label("Not selected", systemImage: "checkmark")
                        } else {
                            Text("Not selected")
                        }
                    }
                    ForEach(EMRSystem.allCases) { system in
                        Button(action: { selectEMR(system) }) {
                            if EMRSystem.matchesSelection(emr, system: system) {
                                Label(system.displayName, systemImage: "checkmark")
                            } else {
                                Text(system.displayName)
                            }
                        }
                    }
                } label: {
                    HStack {
                        Text(emrMenuLabel)
                            .font(.arial(size: 15, weight: .medium))
                            .foregroundColor(emr == nil ? .secondary : .primary)
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.arial(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 10))
                }
                .buttonStyle(.plain)

                if isOtherSelected {
                    ClearableTextField("Type EMR name", text: $emrOtherDetail)
                        .font(.arial(size: 15))
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .padding(.horizontal, 14)
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
                            .font(.arial(size: 12, weight: .medium))
                            .foregroundColor(.green)
                    } else {
                        Label("Uses \(emrMenuLabel) — you prefer \(preferred)", systemImage: "info.circle")
                            .font(.arial(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .padding(.horizontal, 20)
    }

    private var emrMenuLabel: String {
        guard let emr else { return "Select EMR" }
        if EMRSystem.isOtherOrCustom(emr) {
            let trimmed = emrOtherDetail.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? EMRSystem.other.displayName : trimmed
        }
        return emr
    }

    private func selectEMR(_ system: EMRSystem) {
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
        questionnaire.questionnaireCompletionRatio(preferences: dataManager.preferences) >= 1.0
    }

    private var questionnaireCompletionPercent: Int {
        Int((questionnaire.questionnaireCompletionRatio(preferences: dataManager.preferences) * 100).rounded())
    }

    private var questionnaireUnansweredCount: Int {
        questionnaire.unansweredCount(preferences: dataManager.preferences)
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

                Button("Jump to next") {
                    scrollToFirstUnansweredQuestion()
                }
                .font(.arial(size: 14, weight: .semibold))
                .buttonStyle(.glassProminent)
                .tint(AppColors.primaryBlue)
            }

            ProgressView(value: questionnaire.questionnaireCompletionRatio(preferences: dataManager.preferences))
                .tint(AppColors.primaryBlue)
        }
        .padding(16)
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
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
        NavigationLink(destination: InterviewPrepView(program: currentProgramSnapshot())) {
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

    // MARK: - Questionnaire Sections
    private var questionnaireSections: some View {
        ForEach(questionnaire.enabledSections(preferences: dataManager.preferences)) { section in
            let enabledItems = questionnaire.enabledItems(for: section, preferences: dataManager.preferences)
            if !enabledItems.isEmpty {
                let sectionId = section.id
                let isExpanded = expandedSections.contains(sectionId) || (section.title.contains("Section A") && expandedSections.isEmpty)
                
                whiteCardQuestionnaireSection(
                    title: section.title,
                    unansweredCount: sectionUnansweredCount(section),
                    isExpanded: Binding(
                        get: { isExpanded },
                        set: { newValue in
                            if newValue {
                                expandedSections.insert(sectionId)
                            } else {
                                expandedSections.remove(sectionId)
                            }
                        }
                    )
                ) {
                    VStack(spacing: 10) {
                        ForEach(Array(enabledItems.enumerated()), id: \.element.id) { index, item in
                            // Find the item in the questionnaire (could be in standard sections or custom questions merged in)
                            if let sectionIndex = questionnaire.sections.firstIndex(where: { $0.id == section.id }),
                               let itemIndex = questionnaire.sections[sectionIndex].items.firstIndex(where: { $0.id == item.id }) {
                                DualRatingSlider(
                                    question: item.question,
                                    programRating: Binding(
                                        get: { questionnaire.sections[sectionIndex].items[itemIndex].programRating },
                                        set: { newValue in
                                            let oldValue = questionnaire.sections[sectionIndex].items[itemIndex].programRating
                                            var updated = questionnaire
                                            updated.sections[sectionIndex].items[itemIndex].programRating = newValue
                                            questionnaire = updated

                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                checkAndExpandNextSection(currentSectionIndex: sectionIndex, currentItemIndex: itemIndex)
                                            }

                                            if oldValue == 0 && newValue > 0 {
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                                    scrollToNextQuestion(currentSectionId: section.id, currentItemId: item.id)
                                                }
                                            }
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
                                .id("\(section.id)-\(item.id)") // For scrolling
                            }
                        }
                    }
                    .padding(.bottom, 4)
                }
                .padding(.horizontal, 20)
            }
        }
    }
                    
    // MARK: - Custom Questionnaire Sections
    private var customQuestionnaireSections: some View {
        ForEach(questionnaire.customSections) { customSection in
            let enabledItems = questionnaire.enabledItems(for: customSection, preferences: dataManager.preferences)
            if !enabledItems.isEmpty {
                let sectionId = customSection.id
                let isExpanded = expandedSections.contains(sectionId)
                
                whiteCardQuestionnaireSection(
                    title: customSection.title,
                    unansweredCount: sectionUnansweredCount(customSection),
                    isExpanded: Binding(
                        get: { isExpanded },
                        set: { newValue in
                            if newValue {
                                expandedSections.insert(sectionId)
                            } else {
                                expandedSections.remove(sectionId)
                            }
                        }
                    )
                ) {
                    VStack(spacing: 12) {
                        ForEach(enabledItems) { item in
                            if let sectionIndex = questionnaire.customSections.firstIndex(where: { $0.id == customSection.id }),
                               let itemIndex = questionnaire.customSections[sectionIndex].items.firstIndex(where: { $0.id == item.id }) {
                                DualRatingSlider(
                                    question: item.question,
                                    programRating: Binding(
                                        get: { questionnaire.customSections[sectionIndex].items[itemIndex].programRating },
                                        set: { newValue in
                                            let oldValue = questionnaire.customSections[sectionIndex].items[itemIndex].programRating
                                            var updated = questionnaire
                                            updated.customSections[sectionIndex].items[itemIndex].programRating = newValue
                                            questionnaire = updated

                                            if oldValue == 0 && newValue > 0 {
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                                    scrollToNextQuestion(currentSectionId: customSection.id, currentItemId: item.id)
                                                }
                                            }
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
                                .id("\(customSection.id)-\(item.id)") // For scrolling
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
    
    var body: some View {
        contentWithSheets
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("TabBarNavigationRequested"))) { notification in
                // Check if we should block navigation due to unsaved changes
                if hasUnsavedChanges, let userInfo = notification.userInfo, let _ = userInfo["targetTab"] as? Int {
                    showUnsavedChangesAlert = true
                    // Store the target tab to navigate after save/discard
                    pendingDismissal = true
                }
            }
    }
    
    private var contentWithSheets: some View {
        contentWithAlerts
        .sheet(isPresented: $showProgramSearch) {
            ProgramSearchView(onSelect: { programInfo in
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
        .sheet(isPresented: $showContactInfo) {
            MatchlyNavigationView {
                List {
                    if let addressText = programInfoAddressText {
                        Section("Address") {
                            Text(addressText)
                                .font(.arial(size: 15))
                                .foregroundColor(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    if let directorName = programDirectorDisplayName {
                        Section("Program Director") {
                            Text(directorName)
                                .font(.arial(size: 15))
                                .foregroundColor(.primary)
                        }
                    }
                }
                .navigationTitle("Program Information")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            showContactInfo = false
                        }
                    }
                }
            }
            .presentationDetents([.medium])
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
    }
    
    private var contentWithChangeTracking: some View {
        contentWithLifecycle
            .onChange(of: name) { _, _ in debouncedCheckForUnsavedChanges() }
            .onChange(of: hospital) { _, _ in debouncedCheckForUnsavedChanges() }
            .onChange(of: city) { _, _ in debouncedCheckForUnsavedChanges() }
            .onChange(of: state) { _, _ in debouncedCheckForUnsavedChanges() }
            .onChange(of: notes) { _, _ in debouncedCheckForUnsavedChanges() }
            .onChange(of: interviewDate) { _, _ in debouncedCheckForUnsavedChanges() }
            .onChange(of: hasInterviewDate) { _, _ in debouncedCheckForUnsavedChanges() }
            .onChange(of: signalType) { _, _ in debouncedCheckForUnsavedChanges() }
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
                if let program = program {
                    draftProgramId = program.id
                    loadProgram(program)
                } else {
                    draftProgramId = UUID().uuidString
                    isInitialLoad = false
                }
                if let sectionA = questionnaire.sections.first(where: { $0.title.contains("Section A") }) {
                    expandedSections.insert(sectionA.id)
                }

                if scrollToRedFlags {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                        scrollToFirstRedFlag()
                    }
                } else if scrollToFirstMissing {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                        scrollToFirstUnansweredQuestion()
                    }
                } else {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        scrollProxy?.scrollTo("program-entry-top", anchor: .top)
                    }
                }
            }
    }

    private var hasProgramInfoDetails: Bool {
        programInfoAddressText != nil || programDirectorDisplayName != nil
    }

    private var programInfoAddressText: String? {
        let resolved = AddressFormatter.resolved(
            hospital: hospital,
            address: address.isEmpty ? nil : address,
            city: city,
            state: state,
            accreditationID: accreditationID
        )
        let street = resolved.street
        if !street.isEmpty, !resolved.city.isEmpty, !resolved.state.isEmpty {
            return "\(street)\n\(resolved.city), \(resolved.state)"
        }
        if !street.isEmpty {
            return street
        }
        if !resolved.city.isEmpty, !resolved.state.isEmpty {
            return "\(resolved.city), \(resolved.state)"
        }
        return nil
    }

    private var programDirectorDisplayName: String? {
        DirectorNameFormatter.displayDirector(
            programDirector: programDirector.isEmpty ? nil : programDirector,
            contactEmail: contactEmail.isEmpty ? nil : contactEmail
        )
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

            if hasProgramInfoDetails {
                Button(action: {
                    showContactInfo = true
                }) {
                    Image(systemName: "info.circle")
                        .font(.arial(size: 16))
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
            }
        }
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
                    Text("\(resolved.city), \(resolved.state)")
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

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var mainContentView: some View {
        VStack(spacing: 0) {
                // Compact Header (if program is selected)
                if !hospital.isEmpty {
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
                
                ScrollViewReader { proxy in
                    formContent
                        .onAppear {
                            scrollProxy = proxy
                        }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle(program == nil ? (hospital.isEmpty ? "Add Program" : "") : "Edit Program")
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
                }
            }
            .background(NavigationPopGestureBlocker(isBlocked: hasUnsavedChanges))
    }
    
    private func loadProgram(_ program: Program) {
        name = program.name
        hospital = program.hospital
        city = program.city
        state = program.state
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

        originalVoiceMemoReference = VoiceMemoStorage.normalizedReference(
            from: program.voiceMemoURL,
            programId: program.id
        )
    }

    private var currentVoiceMemoReference: String? {
        VoiceMemoStorage.referenceIfMemoExists(forProgramId: draftProgramId)
    }
    
    private func saveProgram() {
        let programId = program?.id ?? draftProgramId
        let normalizedSpecialty = SpecialtyFormatter.normalizedUserSpecialty(
            !specialty.isEmpty ? specialty : (program?.specialty ?? dataManager.preferences.specialties.first ?? dataManager.preferences.specialty ?? "Unknown")
        )
        
        let newProgram = Program(
            id: programId,
            specialty: normalizedSpecialty,
            name: name,
            hospital: hospital,
            city: city,
            state: state,
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
        
        // Update or add program - this calculates score and updates immediately
        if program == nil {
            guard dataManager.addProgram(newProgram) == .added else { return }
        } else {
            dataManager.updateProgram(newProgram)
        }
        
        // Force immediate save (bypass debounce for critical updates)
        dataManager.saveProgramsImmediately()
        
        // Note: Calendar sync is handled through alerts when interview date is set/changed
        // No need to sync here as it's already handled in handleInterviewDateChanged
        
        // Mark as saved
        hasUnsavedChanges = false
        
        // Dismiss after ensuring data is saved
        dismiss()
    }
    
    // Check if there are unsaved changes - optimized to avoid expensive comparisons
    private func checkForUnsavedChanges() -> Bool {
        guard let program = program else {
            // For new programs, check if any fields are filled (quick checks)
            return !name.isEmpty || !hospital.isEmpty || !city.isEmpty || !state.isEmpty ||
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
           program.state != state || program.notes != notes || program.signalType != signalType ||
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
    
    /// Scrolls to the next enabled question while keeping the answered question visible above it.
    private func scrollToNextQuestion(currentSectionId: String, currentItemId: String) {
        let allSections = questionnaire.enabledSections(preferences: dataManager.preferences)
        var allQuestions: [(sectionId: String, itemId: String)] = []

        for section in allSections {
            let enabledItems = questionnaire.enabledItems(for: section, preferences: dataManager.preferences)
            for item in enabledItems {
                allQuestions.append((sectionId: section.id, itemId: item.id))
            }
        }

        guard let currentIndex = allQuestions.firstIndex(where: {
            $0.sectionId == currentSectionId && $0.itemId == currentItemId
        }) else {
            return
        }

        let nextIndex = currentIndex + 1
        guard nextIndex < allQuestions.count else { return }

        let nextQuestion = allQuestions[nextIndex]
        scrollToQuestion(sectionId: nextQuestion.sectionId, itemId: nextQuestion.itemId)
    }

    private func scrollToFirstUnansweredQuestion() {
        guard let target = questionnaire.firstUnansweredQuestion(preferences: dataManager.preferences) else { return }
        scrollToQuestion(sectionId: target.sectionId, itemId: target.itemId)
    }

    private func scrollToFirstRedFlag() {
        guard let target = questionnaire.firstFlaggedRedFlagQuestion() else { return }
        scrollToQuestion(sectionId: target.sectionId, itemId: target.itemId)
    }

    private func scrollToQuestion(sectionId: String, itemId: String) {
        if !expandedSections.contains(sectionId) {
            expandedSections.insert(sectionId)
        }

        let questionId = "\(sectionId)-\(itemId)"

        DispatchQueue.main.asyncAfter(deadline: .now() + Self.questionScrollDelay) {
            if let proxy = scrollProxy {
                withAnimation(Self.questionScrollAnimation) {
                    proxy.scrollTo(questionId, anchor: Self.nextQuestionScrollAnchor)
                }
            }
        }
    }

    private func sectionUnansweredCount(_ section: QuestionnaireSection) -> Int {
        questionnaire.enabledItems(for: section, preferences: dataManager.preferences)
            .filter { $0.programRating == 0 }
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
                    expandedSections.insert(nextSection.id)
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
                let calendarManager = CalendarManager.shared
                
                // Request access if not already granted
                if calendarManager.authorizationStatus == .notDetermined {
                    let granted = await calendarManager.requestAccess()
                    if !granted {
                        programEntryLogger.warning("Calendar access denied")
                        return
                    }
                } else {
                    calendarManager.checkAuthorizationStatus()
                }
                
                if calendarManager.calendarAccessGranted {
                    // Create program with current data for calendar event
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
                    
                    try await calendarManager.createEventsForInterviews([tempProgram])
                    programEntryLogger.info("Successfully created calendar event for interview")
                } else {
                    programEntryLogger.warning("Calendar access not granted")
                }
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
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: "calendar")
                .font(.arial(size: 15))
                .foregroundColor(.secondary)
                .frame(width: 18, height: 18)
                .accessibilityHidden(true)

            Text("Interview")
                .font(.arial(size: 16, weight: .semibold))
                .foregroundColor(.primary)
                .fixedSize(horizontal: true, vertical: false)
                .layoutPriority(2)

            Button {
                showDatePickerSheet = true
            } label: {
                Group {
                    if hasInterviewDate {
                        Text(formatInterviewDate(interviewDate))
                            .font(.arial(size: 15, weight: .medium))
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                            .minimumScaleFactor(0.85)
                    } else {
                        Text("Set Date")
                            .font(.arial(size: 15, weight: .medium))
                            .foregroundColor(.blue)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .layoutPriority(1)
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
    func whiteCardQuestionnaireSection<Content: View>(
        title: String,
        unansweredCount: Int = 0,
        isExpanded: Binding<Bool>,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: 0) {
            // Header - tappable to expand/collapse
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isExpanded.wrappedValue.toggle()
                }
            }) {
                HStack(spacing: 12) {
                    Text(title)
                        .font(.arial(size: 16, weight: .semibold))
                        .foregroundColor(.primary)

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
                    
                    Spacer()
                    
                    Image(systemName: isExpanded.wrappedValue ? "chevron.down" : "chevron.right")
                        .font(.arial(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(isExpanded.wrappedValue ? 0 : -90))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            // Content - expandable
            if isExpanded.wrappedValue {
                VStack(spacing: 0) {
                    Divider()
                        .padding(.horizontal, 16)
                    
                    content()
                        .padding(.horizontal, 16)
                        .padding(.top, 6)
                        .padding(.bottom, 10)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
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

