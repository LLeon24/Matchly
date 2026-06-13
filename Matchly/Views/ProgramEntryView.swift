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
    
    @State private var specialty: String = ""
    @State private var name: String = ""
    @State private var hospital: String = ""
    @State private var city: String = ""
    @State private var state: String = ""
    @State private var address: String = ""
    @State private var accreditationID: String? = nil
    @State private var type: String = "Academic"
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
    
    // Contact information
    @State private var websiteURL: String = ""
    @State private var contactEmail: String = ""
    @State private var contactPhone: String = ""
    @State private var programCoordinator: String = ""
    
    // IMG-friendly status
    @State private var isIMGFriendly: Bool? = nil
    
    // Electronic Medical Record (EMR) used by this hospital (EMRSystem.rawValue)
    @State private var emr: String? = nil
    
    // ERAS Signaling
    @State private var signalType: SignalType = .none
    @State private var showSignalLimitAlert = false
    @State private var signalLimitMessage = ""
    @State private var showDatePickerSheet = false
    
    // New comprehensive questionnaire
    @State private var questionnaire: Questionnaire = Questionnaire()
    @State private var expandedSections: Set<String> = [] // Track which sections are expanded
    @State private var scrollProxy: ScrollViewProxy? = nil // For auto-scrolling to next question
    
    let programTypes = ["Academic", "Community", "Hybrid"]
    
    init(program: Program?) {
        self.program = program
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
                                .background(Color(.systemGray6))
                                .cornerRadius(10)
                            }
                            
                            TextField("Program Name", text: $name)
                                .textFieldStyle(.roundedBorder)
                                .padding(.horizontal, 16)
                            
                            TextField("Hospital / University", text: $hospital)
                                .textFieldStyle(.roundedBorder)
                                .padding(.horizontal, 16)
                            
                            TextField("Street Address (e.g., 123 Main St)", text: $address)
                                .textFieldStyle(.roundedBorder)
                                .autocapitalization(.words)
                                .padding(.horizontal, 16)
                            
                            TextField("City", text: $city)
                                .textFieldStyle(.roundedBorder)
                                .padding(.horizontal, 16)
                            
                            TextField("State", text: $state)
                                .textFieldStyle(.roundedBorder)
                                .padding(.horizontal, 16)
                            
                            Picker("Type", selection: $type) {
                                ForEach(programTypes, id: \.self) { type in
                                    Text(type).tag(type)
                                }
                            }
                            .pickerStyle(.menu)
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
                            .padding(.vertical, 12)
                    }
                    .background(
                        ZStack {
                            // Adaptive background for light/dark mode
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(.systemBackground))
                                .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 4)
                                .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 1)
                            
                            // Subtle border - adaptive for dark mode
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(
                                    Color(.separator),
                                    lineWidth: 0.5
                                )
                        }
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                }
                
                // EMR selection - white card design
                emrSelectionCard

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
                                TextField("Notes...", text: $notes, axis: .vertical)
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
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                        if let proxy = scrollProxy {
                                            withAnimation(.easeInOut(duration: 0.3)) {
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
                
                // Bottom padding for tab bar
                Color.clear.frame(height: keyboardHeight > 0 ? 20 : 90)
            }
            .padding(.bottom, 8)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color(.systemGroupedBackground).opacity(0.3))
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

        return whiteCardContainer {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "waveform.path.ecg.rectangle")
                        .font(.arial(size: 14))
                        .foregroundColor(.blue)
                    Text("Electronic Medical Record (EMR)")
                        .font(.arial(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                    Spacer()
                }

                Text("Which EMR does this hospital use?")
                    .font(.arial(size: 13))
                    .foregroundColor(.secondary)

                Menu {
                    Button(action: { emr = nil }) {
                        if emr == nil {
                            Label("Not selected", systemImage: "checkmark")
                        } else {
                            Text("Not selected")
                        }
                    }
                    ForEach(EMRSystem.allCases) { system in
                        Button(action: { emr = system.rawValue }) {
                            if emr == system.rawValue {
                                Label(system.displayName, systemImage: "checkmark")
                            } else {
                                Text(system.displayName)
                            }
                        }
                    }
                } label: {
                    HStack {
                        Text(emr ?? "Select EMR")
                            .font(.arial(size: 15, weight: .medium))
                            .foregroundColor(emr == nil ? .secondary : .primary)
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.arial(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)

                // Surface the scoring impact relative to the applicant's preferred EMR.
                if preferredIsSpecific, selectedIsSpecific, let preferred = preferred {
                    if emr == preferred {
                        Label("Matches your preferred EMR", systemImage: "checkmark.circle.fill")
                            .font(.arial(size: 12, weight: .medium))
                            .foregroundColor(.green)
                    } else {
                        Label("Differs from your preferred EMR (\(preferred))", systemImage: "exclamationmark.circle")
                            .font(.arial(size: 12, weight: .medium))
                            .foregroundColor(.orange)
                    }
                } else if !preferredIsSpecific {
                    Text("Set your preferred EMR and its importance in Settings ▸ Section Weights to factor EMR into scoring.")
                        .font(.arial(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .padding(.horizontal, 20)
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
                                            questionnaire.sections[sectionIndex].items[itemIndex].programRating = newValue
                                            
                                            // Force layout refresh to prevent cutting off
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                checkAndExpandNextSection(currentSectionIndex: sectionIndex, currentItemIndex: itemIndex)
                                            }
                                            
                                            // Auto-scroll to next question if this question was just answered (changed from 0 to non-zero)
                                            if oldValue == 0 && newValue > 0 {
                                                // Post notification to trigger scroll with a slight delay
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                                    NotificationCenter.default.post(name: NSNotification.Name("ScrollToNextQuestion"), object: nil, userInfo: ["currentSectionId": section.id, "currentItemId": item.id])
                                                }
                                            }
                                        }
                                    ),
                                    notes: Binding(
                                        get: { questionnaire.sections[sectionIndex].items[itemIndex].notes },
                                        set: { questionnaire.sections[sectionIndex].items[itemIndex].notes = $0 }
                                    ),
                                    isYesNo: section.title.contains("Red flags"),
                                    isPositiveYesNo: item.question.contains("Do you feel you could see yourself living"),
                                    showLabels: index == 0 // Show labels only on first question
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
                                            questionnaire.customSections[sectionIndex].items[itemIndex].programRating = newValue
                                            
                                            // Auto-scroll to next question if this question was just answered (changed from 0 to non-zero)
                                            if oldValue == 0 && newValue > 0 {
                                                // Post notification to trigger scroll with a slight delay
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                                    NotificationCenter.default.post(name: NSNotification.Name("ScrollToNextQuestion"), object: nil, userInfo: ["currentSectionId": customSection.id, "currentItemId": item.id])
                                                }
                                            }
                                        }
                                    ),
                                    notes: Binding(
                                        get: { questionnaire.customSections[sectionIndex].items[itemIndex].notes },
                                        set: { questionnaire.customSections[sectionIndex].items[itemIndex].notes = $0 }
                                    ),
                                    isYesNo: false
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
                specialty = programInfo.specialty
                name = programInfo.name
                hospital = HospitalNameFormatter.format(programInfo.hospital)
                city = programInfo.city
                state = programInfo.state
                address = programInfo.address ?? ""
                accreditationID = programInfo.accreditationID
                type = programInfo.type
                // Auto-populate contact information from ERAS
                if let website = programInfo.websiteURL {
                    websiteURL = website
                }
                if let email = programInfo.contactEmail {
                    contactEmail = email
                }
                if let phone = programInfo.contactPhone {
                    contactPhone = phone
                }
                if let coordinator = programInfo.programCoordinator {
                    programCoordinator = coordinator
                }
                // Set IMG-friendly status from program info
                isIMGFriendly = programInfo.isIMGFriendly
                showProgramSearch = false
            })
        }
        .sheet(isPresented: $showDatePickerSheet) {
            NavigationView {
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
                                    id: program?.id ?? UUID().uuidString,
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
                                    voiceMemoURL: nil,
                                    websiteURL: websiteURL.isEmpty ? nil : websiteURL,
                                    contactEmail: contactEmail.isEmpty ? nil : contactEmail,
                                    contactPhone: contactPhone.isEmpty ? nil : contactPhone,
                                    programCoordinator: programCoordinator.isEmpty ? nil : programCoordinator,
                                    isIMGFriendly: isIMGFriendly,
                                    emr: emr,
                                    signalType: signalType,
                                    finalScore: finalScore
                                )
                                if program == nil {
                                    dataManager.addProgram(updatedProgram)
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
            NavigationView {
                Form {
                    Section("Address") {
                        TextField("Street Address", text: $address)
                            .autocapitalization(.words)
                    }
                    
                    Section("Contact Information") {
                        // Website URL with open button
                        HStack {
                            TextField("Website URL", text: $websiteURL)
                                .keyboardType(.URL)
                                .autocapitalization(.none)
                                if !websiteURL.isEmpty, let url = URL(string: websiteURL) {
                                Button(action: {
                                    UIApplication.shared.open(url)
                                }) {
                                    Image(systemName: "arrow.up.right.square")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        
                        TextField("Contact Email", text: $contactEmail)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                        
                        TextField("Contact Phone", text: $contactPhone)
                            .keyboardType(.phonePad)
                        
                        TextField("Program Coordinator", text: $programCoordinator)
                                .autocapitalization(.words)
                    }
                }
                .navigationTitle("Contact Information")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            showContactInfo = false
                        }
                    }
                    }
                }
            }
    }
    
    private var contentWithAlerts: some View {
        contentWithChangeTracking
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
            .alert("Add to Calendar", isPresented: $showEnableCalendarSyncAlert) {
                Button("Cancel", role: .cancel) {
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
            .onChange(of: questionnaire) { _, _ in debouncedCheckForUnsavedChanges() }
            .onChange(of: emr) { _, _ in debouncedCheckForUnsavedChanges() }
    }
    
    // Debounced version to avoid expensive checks on every keystroke
    private func debouncedCheckForUnsavedChanges() {
        // Cancel previous task
        changeCheckTask?.cancel()
        
        // Create new task with delay
        changeCheckTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
            guard !Task.isCancelled else { return }
            hasUnsavedChanges = checkForUnsavedChanges()
        }
    }
    
    private var contentWithLifecycle: some View {
        mainContentView
            .onAppear {
                if let program = program {
                    loadProgram(program)
                } else {
                    // For new programs, mark initial load complete immediately
                    isInitialLoad = false
                }
                // Expand Section A by default
                if let sectionA = questionnaire.sections.first(where: { $0.title.contains("Section A") }) {
                    expandedSections.insert(sectionA.id)
                }
            }
    }
    
    private var mainContentView: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Compact Header (if program is selected)
                if !hospital.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 6) {
                                // Hospital Name - formatted, allow more lines
                                Text(HospitalNameFormatter.format(hospital))
                                    .font(.arial(size: 18, weight: .semibold))
                                    .foregroundColor(.primary)
                                    .lineLimit(3)
                                    .fixedSize(horizontal: false, vertical: true)
                                
                                // Address (below name)
                                if !address.isEmpty {
                                    Text(address)
                                        .font(.arial(size: 13, weight: .medium))
                                        .foregroundColor(.primary)
                                }
                                
                                // Location and Accreditation ID
                                HStack(spacing: 8) {
                                    if !city.isEmpty && !state.isEmpty {
                                        HStack(spacing: 4) {
                                            Image(systemName: "location.fill")
                                                .font(.arial(size: 10))
                                            Text("\(city), \(state)")
                                                .font(.arial(size: 13))
                                        }
                                        .foregroundColor(.secondary)
                                    }
                                    
                                    // Accreditation ID - subtle, no background
                                    if let acgmeID = accreditationID {
                                        HStack(spacing: 2) {
                                            Image(systemName: "number.circle.fill")
                                                .font(.arial(size: 10))
                                            Text("ID:")
                                                .font(.arial(size: 11, weight: .medium))
                                            Text(acgmeID)
                                                .font(.arial(size: 12, weight: .medium))
                                        }
                                        .foregroundColor(.secondary)
                                    }
                                }
                            }
                            
                            Spacer()
                            
                            HStack(spacing: 8) {
                                // Website Link Button - show if we have a website URL
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
                                
                                // Map Button - show if we have location data
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
                                
                                // Contact Info Button - small "i" icon (always show if there's any contact info or address)
                                if !address.isEmpty || !websiteURL.isEmpty || !contactEmail.isEmpty || !contactPhone.isEmpty || !programCoordinator.isEmpty {
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
                        
                        // Program Type and IMG tags
                        HStack(spacing: 8) {
                            // Program Type
                            if !type.isEmpty {
                                HStack(spacing: 3) {
                                    Image(systemName: programTypeIcon(type))
                                        .font(.arial(size: 10))
                                    Text(type)
                                        .font(.arial(size: 12, weight: .medium))
                                }
                                .foregroundColor(programTypeColor(type))
                            }
                            
                            // IMG-Friendly
                            let imgStatus = isIMGFriendly ?? IMGFriendlyHelper.shared.assessIMGFriendlinessForProgram(
                                Program(
                                    specialty: specialty,
                                    name: name,
                                    hospital: hospital,
                                    city: city,
                                    state: state,
                                    address: address,
                                    type: type,
                                    accreditationID: accreditationID,
                                    isIMGFriendly: isIMGFriendly
                                )
                            )
                            if imgStatus == true {
                                HStack(spacing: 3) {
                                    Image(systemName: "globe.americas.fill")
                                        .font(.arial(size: 10))
                                    Text("IMG")
                                        .font(.arial(size: 12, weight: .medium))
                                }
                                .foregroundColor(.purple)
                            }
                        }
                        
                        // Signal and Red Flags tags
                        HStack(spacing: 8) {
                            // Signal indicator
                            if signalType != .none {
                                let isTiered = SignalLimits.isTiered(for: specialty.isEmpty ? "Unknown" : specialty)
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
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                    .background(Color(.systemGray6))
                }
                
                // Questionnaire with ScrollViewReader for auto-scrolling
                ScrollViewReader { proxy in
                    formContent
                        .onAppear {
                            scrollProxy = proxy
                        }
                        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ScrollToNextQuestion"))) { notification in
                            if let userInfo = notification.userInfo,
                               let currentSectionId = userInfo["currentSectionId"] as? String,
                               let currentItemId = userInfo["currentItemId"] as? String {
                                // Delay to ensure view updates are complete, then scroll
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    scrollToNextQuestion(currentSectionId: currentSectionId, currentItemId: currentItemId)
                                }
                            }
                        }
                }
            }
            .navigationTitle(program == nil ? (hospital.isEmpty ? "Add Program" : "") : "Edit Program")
                .navigationBarTitleDisplayMode(.inline)
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
                    HStack(spacing: 8) {
                        // Menu for additional actions (including delete) - only show when editing
                        if program != nil {
                            Menu {
                                Button(role: .destructive, action: {
                                    if let program = program {
                                        dataManager.deleteProgram(program)
                                        dismiss()
                                    }
                                }) {
                                    Label("Delete Program", systemImage: "trash")
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        
                        // Save button as blue pill
                        Button("Save") {
                            saveProgram()
                        }
                        .font(.arial(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue)
                        .cornerRadius(8)
                        .buttonStyle(.plain)
                    }
                    .background(Color.clear)
                }
            }
        }
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
        
        // Load IMG-friendly status
        isIMGFriendly = program.isIMGFriendly
        
        // Load EMR selection
        emr = program.emr
        
        // Load signal type
        signalType = program.signalType
        
        
        // Load questionnaire
        questionnaire = program.questionnaire
    }
    
    private func saveProgram() {
        // Use stored specialty, or program's specialty if editing, otherwise use first preference specialty, or "Unknown"
        let finalSpecialty: String
        if !specialty.isEmpty {
            finalSpecialty = specialty
        } else if let existingProgram = program {
            finalSpecialty = existingProgram.specialty
        } else if let firstSpecialty = dataManager.preferences.specialties.first {
            finalSpecialty = firstSpecialty
        } else {
            finalSpecialty = dataManager.preferences.specialty ?? "Unknown"
        }
        
        // Calculate final score from questionnaire using enabled sections/questions
        let finalScore = questionnaire.totalWeightedScore(preferences: dataManager.preferences, programEMR: emr)
        
        let newProgram = Program(
            id: program?.id ?? UUID().uuidString,
            specialty: finalSpecialty,
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
            voiceMemoURL: nil,
            websiteURL: websiteURL.isEmpty ? nil : websiteURL,
            contactEmail: contactEmail.isEmpty ? nil : contactEmail,
            contactPhone: contactPhone.isEmpty ? nil : contactPhone,
            programCoordinator: programCoordinator.isEmpty ? nil : programCoordinator,
            isIMGFriendly: isIMGFriendly,
            emr: emr,
            signalType: signalType,
            finalScore: finalScore
        )
        
        // Update or add program - this calculates score and updates immediately
        if program == nil {
            dataManager.addProgram(newProgram)
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
                   !notes.isEmpty || hasInterviewDate || signalType != .none || emr != nil ||
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
           program.emr != emr {
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
                        programCoordinator: programCoordinator.isEmpty ? nil : programCoordinator
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
    
    // Helper function to scroll to the next question after answering
    private func scrollToNextQuestion(currentSectionId: String, currentItemId: String) {
        // Get all enabled sections and items in order (enabledSections already includes both standard and custom sections)
        let allSections = questionnaire.enabledSections(preferences: dataManager.preferences)
        var allQuestions: [(sectionId: String, itemId: String)] = []
        
        for section in allSections {
            let enabledItems = questionnaire.enabledItems(for: section, preferences: dataManager.preferences)
            for item in enabledItems {
                allQuestions.append((sectionId: section.id, itemId: item.id))
            }
        }
        
        // Find current question index
        guard let currentIndex = allQuestions.firstIndex(where: { $0.sectionId == currentSectionId && $0.itemId == currentItemId }) else {
            return
        }
        
        // Get next question
        let nextIndex = currentIndex + 1
        guard nextIndex < allQuestions.count else {
            return // No more questions
        }
        
        let nextQuestion = allQuestions[nextIndex]
        let nextQuestionId = "\(nextQuestion.sectionId)-\(nextQuestion.itemId)"
        
        // Expand the section if it's collapsed
        if !expandedSections.contains(nextQuestion.sectionId) {
            expandedSections.insert(nextQuestion.sectionId)
        }
        
        // Use ScrollViewReader (now that we're using ScrollView instead of Form)
        // Scroll to top of next question for better visibility
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let proxy = self.scrollProxy {
                withAnimation(.easeInOut(duration: 0.3)) {
                    proxy.scrollTo(nextQuestionId, anchor: .top)
                }
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
    
    private func programTypeColor(_ type: String) -> Color {
        switch type {
        case "Academic":
            return .blue
        case "Community":
            return .green
        case "Hybrid":
            return .orange
        default:
            return .gray
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
    
    private var combinedInterviewAndSignalingSection: some View {
        let finalSpecialty = specialty.isEmpty ? (program?.specialty ?? dataManager.preferences.specialties.first ?? "Unknown") : specialty
        let isTiered = !finalSpecialty.isEmpty && finalSpecialty != "Unknown" ? SignalLimits.isTiered(for: finalSpecialty) : true
        
        return HStack(alignment: .center, spacing: 10) {
            // Interview Date - flexible width that can shrink
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: "calendar")
                    .font(.arial(size: 13))
                    .foregroundColor(.secondary)
                    .frame(width: 15, height: 15)
                
                Text("Interview")
                    .font(.arial(size: 13, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Button(action: {
                    showDatePickerSheet = true
                }) {
                    if hasInterviewDate {
                        Text(formatInterviewDate(interviewDate))
                            .font(.arial(size: 13, weight: .medium))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    } else {
                        Text("Set Date")
                            .font(.arial(size: 13, weight: .medium))
                            .foregroundColor(.blue)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
            }
            .layoutPriority(1)
            
            // Divider
            Rectangle()
                .fill(Color(.separator))
                .frame(width: 1, height: 18)
            
            // ERAS Signaling - compact single line with proper constraints
            HStack(alignment: .center, spacing: 5) {
                Image(systemName: "star.fill")
                    .font(.arial(size: 12))
                    .foregroundColor(
                        signalType == .gold ? (isTiered ? .yellow : .blue) : 
                        (signalType == .silver ? Color(white: 0.6) : .secondary)
                    )
                    .frame(width: 14, height: 14)
                
                if isTiered {
                    HStack(spacing: 3) {
                        Button(action: {
                            if signalType == .gold {
                                signalType = .none
                            } else {
                                let result = dataManager.canAssignSignal(type: .gold, specialty: finalSpecialty, excludingProgramId: program?.id)
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
                                .font(.arial(size: 10, weight: .semibold))
                                .foregroundColor(signalType == .gold ? .white : .secondary)
                                .fixedSize(horizontal: true, vertical: false)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(signalType == .gold ? Color.yellow : Color(.systemGray5))
                                .cornerRadius(5)
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: {
                            if signalType == .silver {
                                signalType = .none
                            } else {
                                let result = dataManager.canAssignSignal(type: .silver, specialty: finalSpecialty, excludingProgramId: program?.id)
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
                                .font(.arial(size: 10, weight: .semibold))
                                .foregroundColor(signalType == .silver ? .white : .secondary)
                                .fixedSize(horizontal: true, vertical: false)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(signalType == .silver ? Color.gray : Color(.systemGray5))
                                .cornerRadius(5)
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    Button(action: {
                        if signalType == .gold {
                            signalType = .none
                        } else {
                            let result = dataManager.canAssignSignal(type: .gold, specialty: finalSpecialty, excludingProgramId: program?.id)
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
                            .font(.arial(size: 10, weight: .semibold))
                            .foregroundColor(signalType == .gold ? .white : .secondary)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(signalType == .gold ? Color.blue : Color(.systemGray5))
                            .cornerRadius(5)
                    }
                    .buttonStyle(.plain)
                }
            }
            .layoutPriority(2)
            
            // Compact usage display - single line with proper spacing
            if !finalSpecialty.isEmpty && finalSpecialty != "Unknown" {
                let usage = calculateSignalUsage(for: finalSpecialty)
                Text(isTiered ? "\(usage.goldUsed)/\(usage.goldLimit)G \(usage.silverUsed)/\(usage.silverLimit)S" : "\(usage.goldUsed)/\(usage.goldLimit)")
                    .font(.arial(size: 8, weight: .medium))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.leading, 3)
            }
        }
    }
    
    // Helper function to calculate signal usage including current selection
    private func calculateSignalUsage(for specialty: String) -> (goldUsed: Int, goldLimit: Int, silverUsed: Int, silverLimit: Int) {
        let baseUsage = dataManager.getSignalUsage(for: specialty)
        
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
        // Use full address if available, otherwise use hospital + city + state
        let addressString: String
        if !address.isEmpty {
            addressString = "\(address), \(city), \(state)"
        } else if !hospital.isEmpty {
            addressString = "\(hospital), \(city), \(state)"
        } else if !name.isEmpty {
            addressString = "\(name), \(city), \(state)"
        } else {
            addressString = "\(city), \(state)"
        }
        
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
            .background(
                ZStack {
                    // Adaptive background for light/dark mode
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemBackground))
                        .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 4)
                        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 1)
                    
                    // Subtle border - adaptive for dark mode
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            Color(.separator),
                            lineWidth: 0.5
                        )
                }
            )
    }
    
    // Liquid glass questionnaire section - full width, beautiful design
    @ViewBuilder
    func whiteCardQuestionnaireSection<Content: View>(
        title: String,
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
        .background(
            ZStack {
                // Adaptive background for light/dark mode
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 4)
                    .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 1)
                
                // Subtle border - adaptive for dark mode
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        Color(.separator),
                        lineWidth: 0.5
                    )
            }
        )
    }
    
    private func programTypeIcon(_ type: String) -> String {
        switch type {
        case "Academic": return "graduationcap.fill"
        case "Community": return "house.fill"
        case "Hybrid": return "square.stack.3d.up.fill"
        default: return "building.2.fill"
        }
    }
}

#Preview {
    ProgramEntryView(program: nil)
        .environmentObject(DataManager.shared)
}

