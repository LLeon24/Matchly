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
    @State private var voiceMemoURL: URL?
    @State private var showProgramSearch = false
    @State private var showContactInfo = false
    @State private var showCalendarSyncAlert = false
    @State private var showEnableCalendarSyncAlert = false
    @State private var showEnableAllFutureSyncAlert = false
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
    
    // ERAS Signaling
    @State private var signalType: SignalType = .none
    @State private var showSignalLimitAlert = false
    @State private var signalLimitMessage = ""
    
    // New comprehensive questionnaire
    @State private var questionnaire: Questionnaire = Questionnaire()
    @State private var expandedSections: Set<String> = [] // Track which sections are expanded
    @State private var scrollProxy: ScrollViewProxy? = nil // For auto-scrolling to next question
    
    let programTypes = ["Academic", "Community", "Hybrid"]
    
    init(program: Program?) {
        self.program = program
    }
    
    // MARK: - Form Content
    private var formContent: some View {
            Form {
                    // Basic Information Section (only show if hospital not selected)
                    if hospital.isEmpty {
                Section("Basic Information") {
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
                                }
                                
                    TextField("Program Name", text: $name)
                    TextField("Hospital / University", text: $hospital)
                                TextField("Street Address (e.g., 123 Main St)", text: $address)
                                    .autocapitalization(.words)
                    TextField("City", text: $city)
                    TextField("State", text: $state)
                    Picker("Type", selection: $type) {
                        ForEach(programTypes, id: \.self) { type in
                            Text(type).tag(type)
                        }
                    }
                    Toggle("Set Interview Date", isOn: $hasInterviewDate)
                        .onChange(of: hasInterviewDate) { oldValue, newValue in
                            if newValue && !isInitialLoad {
                                // Toggle was just turned on - prompt for calendar sync
                                handleInterviewDateChanged(newDate: interviewDate)
                            }
                        }
                    if hasInterviewDate {
                                    DatePicker("Interview Date & Time", selection: $interviewDate, displayedComponents: [.date, .hourAndMinute])
                            .onChange(of: interviewDate) { oldValue, newValue in
                                // When date is changed and it's not initial load, prompt for calendar sync
                                if hasInterviewDate && !isInitialLoad && oldValue != newValue {
                                    handleInterviewDateChanged(newDate: newValue)
                                }
                            }
                                }
                        }
                    } else {
                // Combined Interview & Signaling Section - liquid glass, full width
                        Section {
                    whiteCardContainer {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Interview & Signaling")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.primary)
                            
                            combinedInterviewAndSignalingSection
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                    }
                }
            }
            
            // Questionnaire Section with Rating Guide - liquid glass, full width
                    Section {
                whiteCardContainer {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Questionnaire")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        // Rating Guide - WITH COLOR and liquid glass
                        VStack(alignment: .leading, spacing: 10) {
                            Text("RATING SCALE")
                                .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.secondary)
                            
                            HStack(spacing: 8) {
                                    ForEach(1...5, id: \.self) { rating in
                                    ratingGuideButton(
                                        rating: rating,
                                        label: "\(rating)",
                                        color: ratingColor(for: rating)
                                    )
                                }
                                
                                ratingGuideButton(
                                    rating: 6,
                                    label: "N/A",
                                    color: Color.secondary
                                )
                            }
                            
                            Text("1=Poor, 2=Below Avg, 3=Avg, 4=Good, 5=Excellent, N/A=Not Applicable")
                                .font(.system(size: 11, weight: .regular))
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                                .padding(.top, 2)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
            }
            
            // Standard questionnaire sections - white card design
            questionnaireSections
            
            // Custom sections - white card design
            customQuestionnaireSections
            
            // Notes Section
            Section {
                whiteCardContainer {
                    VStack(alignment: .leading, spacing: 14) {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showNotes.toggle()
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: showNotes ? "chevron.down" : "chevron.right")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.secondary)
                                Text(notes.isEmpty ? "Add Notes" : "Notes (\(notes.count) chars)")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(notes.isEmpty ? .secondary : .blue)
                                if !notes.isEmpty {
                                    Spacer()
                                    Image(systemName: "text.bubble.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        
                        if showNotes {
                            HStack(alignment: .top, spacing: 8) {
                                TextField("Notes...", text: $notes, axis: .vertical)
                                    .textFieldStyle(.roundedBorder)
                                    .lineLimit(5...10)
                                    .focused($isNotesFocused)
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                                
                                if isNotesFocused {
                                    Button(action: {
                                        isNotesFocused = false
                                    }) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.blue)
                                            .font(.system(size: 20))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
            }
            
            // Voice Memo Section
            Section {
                whiteCardContainer {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Voice Memo")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        VoiceMemoRecorder(recordingURL: $voiceMemoURL)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .padding(.bottom, 20) // Extra padding to prevent keyboard overlap
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground).opacity(0.3))
        .safeAreaInset(edge: .bottom) {
            // Add safe area padding to prevent tab bar overlap
            // When keyboard is visible, reduce padding so keyboard appears above tab bar
            Color.clear.frame(height: keyboardHeight > 0 ? 0 : 90)
        }
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
    
    // MARK: - Questionnaire Sections
    private var questionnaireSections: some View {
                    ForEach(questionnaire.enabledSections(preferences: dataManager.preferences)) { section in
                        let enabledItems = questionnaire.enabledItems(for: section, preferences: dataManager.preferences)
                        if !enabledItems.isEmpty {
                            let sectionId = section.id
                            let isExpanded = expandedSections.contains(sectionId) || (section.title.contains("Section A") && expandedSections.isEmpty)
                            
                            Section {
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
                        VStack(spacing: 20) {
                                    ForEach(enabledItems) { item in
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
                                                            // Post notification to trigger scroll
                                                            NotificationCenter.default.post(name: NSNotification.Name("ScrollToNextQuestion"), object: nil, userInfo: ["currentSectionId": section.id, "currentItemId": item.id])
                                                        }
                                                    }
                                                ),
                                                notes: Binding(
                                                    get: { questionnaire.sections[sectionIndex].items[itemIndex].notes },
                                                    set: { questionnaire.sections[sectionIndex].items[itemIndex].notes = $0 }
                                                ),
                                                isYesNo: section.title.contains("Red flags"),
                                                isPositiveYesNo: item.question.contains("Do you feel you could see yourself living")
                                            )
                                            .id("\(section.id)-\(item.id)") // Force view refresh
                                            .accessibilityIdentifier("\(section.id)-\(item.id)") // For UIKit scrolling
                                        }
                                    }
                        }
                        .padding(.bottom, 8) // Extra padding to prevent cutting off
                    }
                                }
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
                            
                            Section {
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
                        VStack(spacing: 20) {
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
                                                        // Post notification to trigger scroll
                                                        NotificationCenter.default.post(name: NSNotification.Name("ScrollToNextQuestion"), object: nil, userInfo: ["currentSectionId": customSection.id, "currentItemId": item.id])
                                                    }
                                                    }
                                                ),
                                                notes: Binding(
                                                    get: { questionnaire.customSections[sectionIndex].items[itemIndex].notes },
                                                    set: { questionnaire.customSections[sectionIndex].items[itemIndex].notes = $0 }
                                                ),
                                                isYesNo: false
                                            )
                                            .id("\(customSection.id)-\(item.id)") // Force view refresh
                                            .accessibilityIdentifier("\(customSection.id)-\(item.id)") // For UIKit scrolling
                                        }
                                    }
                        }
                    }
                }
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
            .alert("Add to Calendar", isPresented: $showCalendarSyncAlert) {
                Button("Cancel", role: .cancel) {
                    pendingInterviewDate = nil
                }
                Button("Add Event") {
                    addCalendarEventForInterview()
                    pendingInterviewDate = nil
                }
            } message: {
                Text("Would you like to add this interview to your calendar?")
            }
            .alert("Add to Calendar", isPresented: $showEnableCalendarSyncAlert) {
                Button("Cancel", role: .cancel) {
                    pendingInterviewDate = nil
                }
                Button("Add Event") {
                    addCalendarEventForInterview()
                    showEnableAllFutureSyncAlert = true
                }
            } message: {
                Text("Would you like to add this interview to your calendar?")
            }
            .alert("Enable Calendar Sync", isPresented: $showEnableAllFutureSyncAlert) {
                Button("No") {
                    pendingInterviewDate = nil
                }
                Button("Yes") {
                    // Enable calendar sync for all future events
                    dataManager.preferences.enableCalendarSync = true
                    dataManager.savePreferences()
                    pendingInterviewDate = nil
                }
            } message: {
                Text("Would you like to automatically sync all future interview dates to your calendar? You can change this in Settings.")
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
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            // Hospital Name - formatted, smaller
                            Text(HospitalNameFormatter.format(hospital))
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.primary)
                                .lineLimit(2)
                            
                            // Address (below name)
                            if !address.isEmpty {
                                Text(address)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.primary)
                            }
                            
                            // Location, Accreditation ID, and Type
                            VStack(alignment: .leading, spacing: 4) {
                                // Location and Accreditation ID
                                HStack(spacing: 8) {
                                    if !city.isEmpty && !state.isEmpty {
                                        HStack(spacing: 4) {
                                            Image(systemName: "location.fill")
                                                .font(.system(size: 10))
                                            Text("\(city), \(state)")
                                                .font(.system(size: 13))
                                        }
                                        .foregroundColor(.secondary)
                                    }
                                    
                                    // Accreditation ID - subtle, no background
                                    if let acgmeID = accreditationID {
                                        HStack(spacing: 2) {
                                            Image(systemName: "number.circle.fill")
                                                .font(.system(size: 10))
                                            Text("ID:")
                                                .font(.system(size: 11, weight: .medium))
                                            Text(acgmeID)
                                                .font(.system(size: 12, weight: .medium))
                                        }
                                        .foregroundColor(.secondary)
                                    }
                                }
                                
                                if !type.isEmpty {
                                    Text(type)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(programTypeColor(type))
                                }
                            }
                        }
                        
                        Spacer()
                        
                        HStack(spacing: 8) {
                            // Map Button - show if we have location data
                            if !city.isEmpty && !state.isEmpty {
                                Button(action: {
                                    openInMaps()
                                }) {
                                    Image(systemName: "map.fill")
                                        .font(.system(size: 16))
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
                                        .font(.system(size: 16))
                                        .foregroundColor(.blue)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                    .background(Color(.systemGray6))
                }
                
                // Questionnaire Form with ScrollViewReader for auto-scrolling
                ScrollViewReader { proxy in
                    formContent
                        .scrollDismissesKeyboard(.interactively)
                        .onAppear {
                            // Set proxy immediately
                            scrollProxy = proxy
                        }
                        .background(
                            // Also set proxy when view appears using background modifier
                            GeometryReader { _ in
                                Color.clear
                                    .onAppear {
                                        scrollProxy = proxy
                                    }
                            }
                        )
                        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ScrollToNextQuestion"))) { notification in
                            if let userInfo = notification.userInfo,
                               let currentSectionId = userInfo["currentSectionId"] as? String,
                               let currentItemId = userInfo["currentItemId"] as? String {
                                // Delay to ensure view updates are complete
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
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
                ToolbarItemGroup(placement: .navigationBarTrailing) {
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
                    }
                    
                    Button("Save") {
                        saveProgram()
                    }
                    .fontWeight(.semibold)
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
        
        // Load signal type
        signalType = program.signalType
        
        if let voiceMemoString = program.voiceMemoURL {
            // Handle both file:// URLs and file paths
            if voiceMemoString.hasPrefix("file://") {
                voiceMemoURL = URL(string: voiceMemoString)
            } else {
                voiceMemoURL = URL(fileURLWithPath: voiceMemoString)
            }
        }
        
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
        let finalScore = questionnaire.totalWeightedScore(preferences: dataManager.preferences)
        
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
            voiceMemoURL: voiceMemoURL?.path,
            websiteURL: websiteURL.isEmpty ? nil : websiteURL,
            contactEmail: contactEmail.isEmpty ? nil : contactEmail,
            contactPhone: contactPhone.isEmpty ? nil : contactPhone,
            programCoordinator: programCoordinator.isEmpty ? nil : programCoordinator,
            isIMGFriendly: isIMGFriendly,
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
                   !notes.isEmpty || hasInterviewDate || signalType != .none || 
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
           program.state != state || program.notes != notes || program.signalType != signalType {
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
        
        if dataManager.preferences.enableCalendarSync {
            // Calendar sync is enabled - automatically ask to add event
            showCalendarSyncAlert = true
        } else {
            // Calendar sync is not enabled - ask if they want to add event
            showEnableCalendarSyncAlert = true
        }
    }
    
    // Add calendar event for interview
    private func addCalendarEventForInterview() {
        guard let date = pendingInterviewDate else { return }
        
        // Update the interview date in state
        interviewDate = date
        
        Task {
            do {
                let calendarManager = CalendarManager.shared
                calendarManager.checkAuthorizationStatus()
                
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
                        interviewDate: date
                    )
                    
                    try await calendarManager.createEventsForInterviews([tempProgram])
                }
            } catch {
                print("Failed to create calendar event: \(error)")
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
        
        // Try scrolling multiple times with increasing delays
        // Forms are difficult to scroll programmatically, so we need to be persistent
        for attempt in 0..<8 {
            let delay = 0.3 + Double(attempt) * 0.2
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                // Try ScrollViewReader first
                if let proxy = self.scrollProxy {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        proxy.scrollTo(nextQuestionId, anchor: .center)
                    }
                }
                
                // Also try UIKit approach
                self.scrollToViewWithId(nextQuestionId)
            }
        }
    }
    
    // Helper to scroll using UIKit - Forms use UITableView internally
    private func scrollToViewWithId(_ viewId: String) {
        // Try multiple times with increasing delays
        func attemptScroll(attempt: Int) {
            guard attempt < 10 else { return } // Max 10 attempts
            
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(attempt) * 0.15) {
                // Find the UITableView that Forms use internally
                func findTableView(in view: UIView) -> UITableView? {
                    if let tableView = view as? UITableView {
                        return tableView
                    }
                    for subview in view.subviews {
                        if let tableView = findTableView(in: subview) {
                            return tableView
                        }
                    }
                    return nil
                }
                
                func findViewWithAccessibilityId(in view: UIView, targetId: String) -> UIView? {
                    if let accessibilityId = view.accessibilityIdentifier, accessibilityId == targetId {
                        return view
                    }
                    for subview in view.subviews {
                        if let found = findViewWithAccessibilityId(in: subview, targetId: targetId) {
                            return found
                        }
                    }
                    return nil
                }
                
                guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                      let window = windowScene.windows.first,
                      let rootViewController = window.rootViewController else {
                    attemptScroll(attempt: attempt + 1)
                    return
                }
                
                // Find the UITableView
                guard let tableView = findTableView(in: rootViewController.view) else {
                    attemptScroll(attempt: attempt + 1)
                    return
                }
                
                // Find the target view
                guard let targetView = findViewWithAccessibilityId(in: rootViewController.view, targetId: viewId) else {
                    attemptScroll(attempt: attempt + 1)
                    return
                }
                
                // Find the cell containing the target view
                var parentCell: UITableViewCell? = nil
                var currentView: UIView? = targetView
                while let view = currentView {
                    if let cell = view as? UITableViewCell {
                        parentCell = cell
                        break
                    }
                    currentView = view.superview
                }
                
                if let cell = parentCell, let indexPath = tableView.indexPath(for: cell) {
                    // Scroll to the cell
                    tableView.scrollToRow(at: indexPath, at: .middle, animated: true)
                } else {
                    // Try ScrollViewReader as fallback
                    if let proxy = self.scrollProxy {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            proxy.scrollTo(viewId, anchor: .center)
                        }
                    }
                    attemptScroll(attempt: attempt + 1)
                }
            }
        }
        
        attemptScroll(attempt: 0)
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
    
    // MARK: - Combined Interview & Signaling Section
    
    private var combinedInterviewAndSignalingSection: some View {
            VStack(spacing: 8) {
            // Interview Date - compact
            VStack(spacing: 6) {
                HStack {
                    Image(systemName: "calendar")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .frame(width: 20)
                    
                    Text("Interview Date")
                        .font(.system(size: 15))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Toggle("", isOn: $hasInterviewDate)
                        .toggleStyle(SwitchToggleStyle(tint: .blue))
                        .labelsHidden()
                        .onChange(of: hasInterviewDate) { oldValue, newValue in
                            if newValue && !isInitialLoad {
                                // Toggle was just turned on - prompt for calendar sync
                                handleInterviewDateChanged(newDate: interviewDate)
                            }
                        }
                }
                
                if hasInterviewDate {
                    HStack(spacing: 12) {
                        DatePicker("Date", selection: $interviewDate, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .onChange(of: interviewDate) { oldValue, newValue in
                                if hasInterviewDate && !isInitialLoad && oldValue != newValue {
                                    handleInterviewDateChanged(newDate: newValue)
                                }
                            }
                        
                        DatePicker("Time", selection: $interviewDate, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .onChange(of: interviewDate) { oldValue, newValue in
                                if hasInterviewDate && !isInitialLoad && oldValue != newValue {
                                    handleInterviewDateChanged(newDate: newValue)
                    }
                }
            }
                    .padding(.leading, 24)
                }
            }
            
            Divider()
                .padding(.vertical, 1)
            
            // ERAS Signaling - conditionally show tiered or single-level
            VStack(spacing: 6) {
                let finalSpecialty = specialty.isEmpty ? (program?.specialty ?? dataManager.preferences.specialties.first ?? "Unknown") : specialty
                let isTiered = !finalSpecialty.isEmpty && finalSpecialty != "Unknown" ? SignalLimits.isTiered(for: finalSpecialty) : true
                
                HStack(spacing: 8) {
                    // Star icon that changes color when signal is selected
                    
                    Image(systemName: "star.fill")
                        .font(.system(size: 14))
                        .foregroundColor(
                            signalType == .gold ? (isTiered ? .yellow : .blue) : 
                            (signalType == .silver ? Color(white: 0.6) : .secondary)
                        )
                        .frame(width: 20)
                    
                    Text("ERAS Signal")
                        .font(.system(size: 15))
                        .foregroundColor(.primary)
                    
                    Spacer()
                
                    if isTiered {
                        // Tiered: Show Gold and Silver buttons on same line (prevent wrapping)
                        HStack(spacing: 4) {
                    // Gold Signal Button
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
                                HStack(spacing: 2) {
                            Image(systemName: signalType == .gold ? "star.fill" : "star")
                                        .font(.system(size: 10, weight: .medium))
                                .foregroundColor(signalType == .gold ? .yellow : .gray.opacity(0.4))
                            Text("Gold")
                                        .font(.system(size: 11, weight: .medium))
                                .foregroundColor(signalType == .gold ? .primary : .secondary)
                        }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(
                                    ZStack {
                                        // Liquid glass background
                            RoundedRectangle(cornerRadius: 8)
                                            .fill(.ultraThinMaterial)
                                            .shadow(color: signalType == .gold ? Color.yellow.opacity(0.2) : Color.black.opacity(0.05), radius: signalType == .gold ? 4 : 2, x: 0, y: 1)
                                        
                                        // Color overlay when selected
                                        if signalType == .gold {
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(
                                                    LinearGradient(
                                                        colors: [
                                                            Color.yellow.opacity(0.15),
                                                            Color.yellow.opacity(0.08)
                                                        ],
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    )
                                                )
                                        }
                                        
                                        // Border
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(
                                                LinearGradient(
                                                    colors: signalType == .gold ? [
                                                        Color.yellow.opacity(0.6),
                                                        Color.yellow.opacity(0.3)
                                                    ] : [
                                                        Color.white.opacity(0.3),
                                                        Color.white.opacity(0.1)
                                                    ],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                ),
                                                lineWidth: 1
                                            )
                                    }
                        )
                    }
                    .buttonStyle(.plain)
                    
                    // Silver Signal Button
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
                                HStack(spacing: 2) {
                            Image(systemName: signalType == .silver ? "star.fill" : "star")
                                        .font(.system(size: 10, weight: .medium))
                                .foregroundColor(signalType == .silver ? Color(white: 0.6) : .gray.opacity(0.4))
                            Text("Silver")
                                        .font(.system(size: 11, weight: .medium))
                                .foregroundColor(signalType == .silver ? .primary : .secondary)
                        }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(
                                    ZStack {
                                        // Liquid glass background
                            RoundedRectangle(cornerRadius: 8)
                                            .fill(.ultraThinMaterial)
                                            .shadow(color: signalType == .silver ? Color.gray.opacity(0.15) : Color.black.opacity(0.05), radius: signalType == .silver ? 4 : 2, x: 0, y: 1)
                                        
                                        // Color overlay when selected
                                        if signalType == .silver {
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(
                                                    LinearGradient(
                                                        colors: [
                                                            Color.gray.opacity(0.12),
                                                            Color.gray.opacity(0.06)
                                                        ],
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    )
                                                )
                                        }
                                        
                                        // Border
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(
                                                LinearGradient(
                                                    colors: signalType == .silver ? [
                                                        Color.gray.opacity(0.5),
                                                        Color.gray.opacity(0.25)
                                                    ] : [
                                                        Color.white.opacity(0.3),
                                                        Color.white.opacity(0.1)
                                                    ],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                ),
                                                lineWidth: 1
                                            )
                                    }
                        )
                    }
                    .buttonStyle(.plain)
                }
                        .fixedSize(horizontal: true, vertical: false) // Prevent wrapping
                    } else {
                        // Single-level: Show single "Signal" toggle/button
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
                            HStack(spacing: 3) {
                                Image(systemName: signalType == .gold ? "star.fill" : "star")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(signalType == .gold ? .blue : .gray.opacity(0.4))
                                Text("Signal")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(signalType == .gold ? .primary : .secondary)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                ZStack {
                                    // Liquid glass background
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(.ultraThinMaterial)
                                        .shadow(color: signalType == .gold ? Color.blue.opacity(0.2) : Color.black.opacity(0.05), radius: signalType == .gold ? 4 : 2, x: 0, y: 1)
                                    
                                    // Color overlay when selected
                                    if signalType == .gold {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(
                                                LinearGradient(
                                                    colors: [
                                                        Color.blue.opacity(0.15),
                                                        Color.blue.opacity(0.08)
                                                    ],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                    }
                                    
                                    // Border
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(
                                            LinearGradient(
                                                colors: signalType == .gold ? [
                                                    Color.blue.opacity(0.6),
                                                    Color.blue.opacity(0.3)
                                                ] : [
                                                    Color.white.opacity(0.3),
                                                    Color.white.opacity(0.1)
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 1
                                        )
                                }
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                // Compact usage display - conditional based on tiered vs single-level
                if !finalSpecialty.isEmpty && finalSpecialty != "Unknown" {
                    let usage = calculateSignalUsage(for: finalSpecialty)
                    
                    if isTiered {
                        // Tiered: Show Gold and Silver usage
                    HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            Text("Gold:")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                            Text("\(usage.goldUsed)/\(usage.goldLimit)")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(usage.goldUsed >= usage.goldLimit ? .red : .primary)
                        }
                        
                        HStack(spacing: 4) {
                            Text("Silver:")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                            Text("\(usage.silverUsed)/\(usage.silverLimit)")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(usage.silverUsed >= usage.silverLimit ? .red : .primary)
                        }
                        
                        Spacer()
                    }
                    .padding(.top, 2)
                    } else {
                        // Single-level: Show total usage
                        HStack(spacing: 4) {
                            Text("Signals:")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                            Text("\(usage.goldUsed)/\(usage.goldLimit)")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(usage.goldUsed >= usage.goldLimit ? .red : .primary)
                            
                            Spacer()
                        }
                        .padding(.top, 2)
                    }
                }
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
                print("Geocoding error: \(error.localizedDescription)")
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

struct RatingSlider: View {
    let title: String
    @Binding var value: Double
    var isRedFlag: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 15))
                Spacer()
                Text(value > 0 ? "\(Int(value))" : "—")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(value > 0 ? ratingColor(for: Int(value)) : .secondary)
                    .frame(width: 30)
            }
            
            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { rating in
                    Button(action: {
                        // Toggle: if clicking the same rating, set to 0; otherwise set to that rating
                        if value == Double(rating) {
                            value = 0
                        } else {
                        value = Double(rating)
                        }
                    }) {
                        Text("\(rating)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(value >= Double(rating) && value > 0 ? .white : ratingColor(for: rating).opacity(0.6))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                value >= Double(rating) && value > 0 
                                    ? ratingColor(for: rating)
                                    : Color(.systemGray5)
                            )
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    // Color coding: 1=red, 2=orange-red, 3=yellow, 4=yellow-green, 5=green
    // For red flags, colors are inverted (5=red, 1=green) since higher is worse
    // Colors are adjusted for dark mode visibility
    private func ratingColor(for rating: Int) -> Color {
        let actualRating = isRedFlag ? (6 - rating) : rating // Invert for red flags
        
        switch actualRating {
        case 1:
            return Color(
                light: Color(red: 0.9, green: 0.2, blue: 0.2),
                dark: Color(red: 1.0, green: 0.3, blue: 0.3)
            ) // Red
        case 2:
            return Color(
                light: Color(red: 1.0, green: 0.55, blue: 0.0),
                dark: Color(red: 1.0, green: 0.65, blue: 0.1)
            ) // Orange-red
        case 3:
            return Color(
                light: Color(red: 1.0, green: 0.8, blue: 0.0),
                dark: Color(red: 1.0, green: 0.9, blue: 0.2)
            ) // Yellow
        case 4:
            return Color(
                light: Color(red: 0.5, green: 0.85, blue: 0.3),
                dark: Color(red: 0.6, green: 0.95, blue: 0.4)
            ) // Yellow-green
        case 5:
            return Color(
                light: Color(red: 0.2, green: 0.7, blue: 0.3),
                dark: Color(red: 0.3, green: 0.8, blue: 0.4)
            ) // Green
        default:
            return .gray
        }
    }
}

// Helper extension to dismiss keyboard
extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// MARK: - Liquid Glass Card Components

extension ProgramEntryView {
    // Simple liquid glass card
    @ViewBuilder
    func liquidGlassCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .background(
                ZStack {
                    // Glass effect background
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                        .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
                        .shadow(color: Color.white.opacity(0.1), radius: 6, x: 0, y: -2)
                    
                    // Subtle gradient overlay
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.4),
                                    Color.white.opacity(0.2),
                                    Color.white.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    // Gradient border
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.5),
                                    Color.white.opacity(0.2),
                                    Color.white.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                }
            )
    }
    
    // Liquid glass card container - full width, beautiful design
    @ViewBuilder
    func whiteCardContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .background(
                ZStack {
                    // Solid white background with refined shadow
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white)
                        .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 4)
                        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 1)
                    
                    // Subtle border
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            Color.gray.opacity(0.12),
                            lineWidth: 0.5
                        )
                }
            )
            .listRowInsets(EdgeInsets(top: -8, leading: 0, bottom: -8, trailing: 0))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
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
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded.wrappedValue ? "chevron.down" : "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(isExpanded.wrappedValue ? 0 : -90))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            // Content - expandable
            if isExpanded.wrappedValue {
                VStack(spacing: 0) {
                    Divider()
                        .padding(.horizontal, 20)
                    
                    content()
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 20)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            ZStack {
                // Solid white background with refined shadow
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 4)
                    .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 1)
                
                // Subtle border
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        Color.gray.opacity(0.12),
                        lineWidth: 0.5
                    )
            }
        )
        .listRowInsets(EdgeInsets(top: -8, leading: 0, bottom: -8, trailing: 0))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }
    
    // Rating guide button - EXACT same size as "Overall fit" buttons (selected state styling)
    @ViewBuilder
    func ratingGuideButton(rating: Int, label: String, color: Color) -> some View {
        // Use selected state styling for visual prominence (matching "Overall fit" buttons)
        let textColor: Color = .white // Always white for selected state
        
        // EXACT same ZStack structure as DualRatingSlider selected buttons
        ZStack {
            // Background with FULL color and liquid glass effect - matching selected state
            RoundedRectangle(cornerRadius: 8)
                .fill(color)
                .shadow(color: color.opacity(0.4), radius: 4, x: 0, y: 1)
                .shadow(color: Color.white.opacity(0.25), radius: 2, x: 0, y: -0.5)
            
            // Glass overlay - selected state
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.35),
                            Color.white.opacity(0.15),
                            Color.white.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
        // Text - white for selected state
        Text(label)
            .font(.system(size: rating == 6 ? 12 : 13, weight: .semibold))
            .foregroundColor(textColor)
            .shadow(color: Color.black.opacity(0.3), radius: 1, x: 0, y: 0.5)
    }
    .frame(width: 50, height: 40) // More square shape
    .overlay(
        RoundedRectangle(cornerRadius: 8)
            .stroke(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.5),
                        Color.white.opacity(0.2)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 0.8
            )
    )
    }
    
    // Liquid glass rating button - matching actual scoring button size with improved visibility
    @ViewBuilder
    func liquidGlassRatingButton(rating: Int, label: String, color: Color) -> some View {
        // Determine text color based on rating for better contrast
        let textColor: Color = {
            switch rating {
            case 1, 5, 6: // Red, Green, Grey - use white
                return .white
            case 2, 3, 4: // Orange, Yellow, Light Green - use dark text
                return Color(white: 0.15) // Dark gray for better contrast
            default:
                return .white
            }
        }()
        
        // Enhanced color for better visibility (darker/more saturated)
        let enhancedColor: Color = {
            switch rating {
            case 1: // Red
                return Color(red: 0.85, green: 0.15, blue: 0.15)
            case 2: // Orange - darker
                return Color(red: 0.95, green: 0.45, blue: 0.0)
            case 3: // Yellow - darker
                return Color(red: 0.95, green: 0.7, blue: 0.0)
            case 4: // Light Green - darker
                return Color(red: 0.4, green: 0.75, blue: 0.25)
            case 5: // Green
                return Color(red: 0.15, green: 0.6, blue: 0.25)
            case 6: // Grey
                return Color.secondary
            default:
                return color
            }
        }()
        
        ZStack {
            // Background with liquid glass effect
            RoundedRectangle(cornerRadius: 6)
                .fill(enhancedColor)
                .shadow(color: enhancedColor.opacity(0.4), radius: 5, x: 0, y: 2)
                .shadow(color: Color.white.opacity(0.25), radius: 3, x: 0, y: -1)
            
            // Glass overlay gradient
            RoundedRectangle(cornerRadius: 6)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.35),
                            Color.white.opacity(0.15),
                            Color.white.opacity(0.05),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            // Subtle inner highlight
            RoundedRectangle(cornerRadius: 6)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.2),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .center
                    )
                )
            
            // Text with shadow for visibility
            Text(label)
                .font(.system(size: rating == 6 ? 12 : 13, weight: .semibold))
                .foregroundColor(textColor)
                .shadow(color: rating <= 1 || rating >= 5 ? Color.black.opacity(0.3) : Color.white.opacity(0.8), radius: 1, x: 0, y: 0.5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 7)
        .overlay(
            // Subtle border
            RoundedRectangle(cornerRadius: 6)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.5),
                            Color.white.opacity(0.2),
                            Color.white.opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.8
                )
        )
    }
    
    // Liquid glass questionnaire section - cleaner design
    @ViewBuilder
    func liquidGlassQuestionnaireSection<Content: View>(
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
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded.wrappedValue ? "chevron.down" : "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(isExpanded.wrappedValue ? 0 : -90))
                }
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            // Content - expandable with liquid glass background
            if isExpanded.wrappedValue {
                VStack(spacing: 0) {
                    Divider()
                        .padding(.horizontal, -16) // Extend to edges
                    
                    content()
                        .padding(.top, 12)
                        .padding(.bottom, 8)
                }
                .background(
                    ZStack {
                        // Subtle liquid glass background for content area
                        RoundedRectangle(cornerRadius: 0)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(.systemGray6).opacity(0.3),
                                        Color(.systemGray6).opacity(0.1)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            ZStack {
                // Liquid glass card background
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
                    .shadow(color: Color.white.opacity(0.08), radius: 4, x: 0, y: -1)
                
                // Subtle gradient overlay
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.3),
                                Color.white.opacity(0.15),
                                Color.white.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                // Gradient border
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.4),
                                Color.white.opacity(0.2),
                                Color.white.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
        )
        .padding(.vertical, 4)
    }
    
    // Expandable liquid glass section card
    @ViewBuilder
    func liquidGlassSectionCard<Content: View>(
        title: String,
        isExpanded: Binding<Bool>,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: 0) {
            // Header - always visible
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isExpanded.wrappedValue.toggle()
                }
            }) {
                HStack(spacing: 12) {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded.wrappedValue ? "chevron.down" : "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(isExpanded.wrappedValue ? 0 : -90))
                }
                .padding(16)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            // Content - expandable
            if isExpanded.wrappedValue {
                VStack(spacing: 0) {
                    Divider()
                        .padding(.horizontal, 16)
                    
                    content()
                        .padding(16)
                        .padding(.top, 8)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            ZStack {
                // Glass effect background
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
                    .shadow(color: Color.white.opacity(0.1), radius: 6, x: 0, y: -2)
                
                // Subtle gradient overlay
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.4),
                                Color.white.opacity(0.2),
                                Color.white.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                // Gradient border
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.5),
                                Color.white.opacity(0.2),
                                Color.white.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            }
        )
    }
}

#Preview {
    ProgramEntryView(program: nil)
        .environmentObject(DataManager.shared)
}

