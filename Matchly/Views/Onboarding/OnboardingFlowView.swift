//
//  OnboardingFlowView.swift
//  Matchly
//
//  Created on 11/14/25.
//

import SwiftUI
import PhotosUI
import UIKit

struct OnboardingFlowView: View {
    @ObservedObject private var dataManager = DataManager.shared
    @State private var currentStep: OnboardingStep = .welcome
    @State private var profile = UserProfile()
    @State private var selectedSpecialties: Set<String> = []
    @State private var selectedApplyingTrack: ProgramTrainingLevelFilter = .residency
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var cropImageItem: CropImageItem?
    @State private var isLoadingPhoto = false
    @State private var showMainApp = false
    @State private var enableCalendarSync: Bool = false
    @State private var includeRedFlaggedInRankList: Bool = true
    @State private var preferredEMR: String = ""
    @State private var preferredEMROtherDetail: String = ""
    @State private var showQuestionnaireCustomization = false
    
    enum OnboardingStep: Int, CaseIterable {
        case welcome = 0
        case applyingTrack = 1
        case specialties = 2
        case name = 3
        case aamcID = 4
        case photo = 5
        case matchPreferences = 6
        case calendarSync = 7
        
        var title: String {
            switch self {
            case .welcome: return "Welcome to Matchly"
            case .applyingTrack: return "What Are You Applying To?"
            case .specialties: return "Select Your Specialties"
            case .name: return "What's your name?"
            case .aamcID: return "AAMC ID (Optional)"
            case .photo: return "Add Your Photo (Optional)"
            case .matchPreferences: return "Match Preferences"
            case .calendarSync: return "Calendar Sync"
            }
        }
        
        var subtitle: String {
            switch self {
            case .welcome: return "Let's get you set up"
            case .applyingTrack: return "Medical students apply to residency. After residency, physicians apply to fellowship. You can change this anytime in Settings."
            case .specialties: return "Choose the specialties you're applying to. You can select multiple if you're dual applying."
            case .name: return "We'll use this to personalize your experience"
            case .aamcID: return "Your AAMC ID helps us provide better program matching"
            case .photo: return "Upload a photo or pick an avatar"
            case .matchPreferences: return "A few defaults to get your rank list and scoring right from the start."
            case .calendarSync: return "Would you like to sync your interviews to your device calendar? You can change this anytime in Settings."
            }
        }
    }
    
    var body: some View {
        ZStack {
            AppColors.dashboardCanvas
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Progress indicator
                progressIndicator
                
                // Content - use conditional view instead of TabView
                Group {
                    switch currentStep {
                    case .welcome:
                        welcomeStep
                    case .applyingTrack:
                        applyingTrackStep
                    case .specialties:
                        specialtiesStep
                    case .name:
                        nameStep
                    case .aamcID:
                        aamcIDStep
                    case .photo:
                        photoStep
                    case .matchPreferences:
                        matchPreferencesStep
                    case .calendarSync:
                        calendarSyncStep
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .trailing)))
            }
        }
        .fullScreenCover(isPresented: $showMainApp) {
            MainTabView()
        }
        .onChange(of: selectedPhoto) { _, newItem in
            guard let newItem else { return }
            isLoadingPhoto = true
            Task {
                let preparedImage = await PhotoPickerImageLoader.loadPreparedImage(from: newItem)
                await MainActor.run {
                    isLoadingPhoto = false
                    if let preparedImage {
                        cropImageItem = CropImageItem(image: preparedImage)
                    } else {
                        selectedPhoto = nil
                    }
                }
            }
        }
        .fullScreenCover(item: $cropImageItem, onDismiss: {
            selectedPhoto = nil
        }) { item in
            ImageCropView(image: item.image) { croppedImage in
                if let data = croppedImage.jpegData(compressionQuality: 0.92) {
                    profile.photoData = data
                    profile.avatarPresetID = nil
                }
                selectedPhoto = nil
            }
        }
        .matchlyKeyboardDismissToolbar()
    }
    
    // MARK: - Progress Indicator
    private var progressIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<OnboardingStep.allCases.count, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(index <= currentStep.rawValue ? Color.blue : Color.gray.opacity(0.3))
                    .frame(height: 4)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }
    
    // MARK: - Welcome Step
    private var welcomeStep: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: 36) {
                MatchlyBrandLockup(style: .onboarding)

                VStack(spacing: 18) {
                    Text("YOUR MATCH COMPANION")
                        .font(.arial(size: 12, weight: .regular))
                        .foregroundColor(.secondary)
                        .kerning(2.2)

                    VStack(spacing: 12) {
                        FeatureRow(icon: "list.bullet.clipboard.fill", text: "Track & Score Programs")
                        FeatureRow(icon: "chart.bar.fill", text: "Build Your NRMP Rank List")
                        FeatureRow(icon: "star.fill", text: "Manage ERAS Signals")
                        FeatureRow(icon: "calendar", text: "Plan Interview Dates")
                        if FeatureFlags.couplesMatchEnabled {
                            FeatureRow(icon: "heart.fill", text: "Couples Match with Your Partner")
                        }
                    }
                    .padding(.top, 8)
                }
            }
            
            Spacer()
            
            // Continue button with gradient
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    currentStep = .applyingTrack
                }
            }) {
                HStack(spacing: 8) {
                    Text("Get Started")
                        .font(.arial(size: 18, weight: .semibold))
                    Image(systemName: "arrow.right")
                        .font(.arial(size: 16, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
            }
            // Hero CTA ? prominent Liquid Glass over the soft gradient backdrop.
            .buttonStyle(.glassProminent)
            .tint(AppColors.primaryBlue)
            .padding(.horizontal, 32)
            .padding(.bottom, 50)
        }
    }
    
    // Feature row component
    private struct FeatureRow: View {
        let icon: String
        let text: String
        
        var body: some View {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.arial(size: 18))
                    .foregroundColor(AppColors.primaryBlue)
                    .frame(width: 28)
                
                Text(text)
                    .font(.arial(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                
                Spacer()
            }
            .padding(.horizontal, 20)
        }
    }
    
    // MARK: - Name Step
    private var nameStep: some View {
        OnboardingStepView(
            title: OnboardingStep.name.title,
            subtitle: OnboardingStep.name.subtitle,
            content: {
                VStack(spacing: 24) {
                    ClearableTextField("First Name", text: $profile.firstName)
                        .font(.arial(size: 18))
                        .padding()
                        .glassEffect(.regular, in: .rect(cornerRadius: 12))
                        .autocapitalization(.words)
                        .disableAutocorrection(true)

                    ClearableTextField("Last Name", text: $profile.lastName)
                        .font(.arial(size: 18))
                        .padding()
                        .glassEffect(.regular, in: .rect(cornerRadius: 12))
                        .autocapitalization(.words)
                        .disableAutocorrection(true)
                    
                    Spacer()
                }
            },
            onNext: {
                withAnimation {
                    currentStep = .aamcID
                }
            },
            canContinue: !profile.firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            onBack: {
                withAnimation {
                    currentStep = .specialties
                }
            }
        )
    }
    
    // MARK: - AAMC ID Step
    private var aamcIDStep: some View {
        OnboardingStepView(
            title: OnboardingStep.aamcID.title,
            subtitle: OnboardingStep.aamcID.subtitle,
            content: {
                VStack(spacing: 24) {
                    ClearableTextField("AAMC ID (Optional)", text: Binding(
                        get: { profile.aamcID ?? "" },
                        set: { profile.aamcID = $0.isEmpty ? nil : $0 }
                    ))
                    .font(.arial(size: 18))
                    .padding()
                    .glassEffect(.regular, in: .rect(cornerRadius: 12))
                    .keyboardType(.default)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    
                    Text("You can skip this step if you don't have an AAMC ID")
                        .font(.arial(size: 14))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Spacer()
                }
            },
            onNext: {
                withAnimation {
                    currentStep = .photo
                }
            },
            canContinue: true,
            showSkip: true,
            onSkip: {
                withAnimation {
                    currentStep = .photo
                }
            },
            onBack: {
                withAnimation {
                    currentStep = .name
                }
            }
        )
    }
    
    // MARK: - Photo Step
    private var photoStep: some View {
        OnboardingStepView(
            title: OnboardingStep.photo.title,
            subtitle: OnboardingStep.photo.subtitle,
            content: {
                VStack(spacing: 32) {
                    Spacer()
                    
                    ZStack {
                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            ZStack {
                                Circle()
                                    .fill(.clear)
                                    .frame(width: 140, height: 140)
                                    .glassEffect(.regular.interactive(), in: .circle)
                                
                                if let photoData = profile.photoData,
                                   let uiImage = UIImage(data: photoData) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 140, height: 140)
                                        .clipShape(Circle())
                                } else {
                                    VStack(spacing: 12) {
                                        Image(systemName: "camera.fill")
                                            .font(.arial(size: 40))
                                            .foregroundColor(.blue)
                                        Text("Add Photo")
                                            .font(.arial(size: 16, weight: .medium))
                                            .foregroundColor(.blue)
                                    }
                                }
                                
                                if profile.hasPhoto {
                                    Circle()
                                        .fill(Color.black.opacity(0.3))
                                        .frame(width: 140, height: 140)
                                    
                                    Image(systemName: "pencil.circle.fill")
                                        .font(.arial(size: 32))
                                        .foregroundColor(.white)
                                }
                            }
                        }
                        .disabled(isLoadingPhoto)
                        
                        if isLoadingPhoto {
                            Circle()
                                .fill(Color.black.opacity(0.35))
                                .frame(width: 140, height: 140)
                            ProgressView()
                                .tint(.white)
                        }
                    }
                    
                    if profile.hasPhoto {
                        Button(action: {
                            profile.photoData = nil
                            profile.avatarPresetID = nil
                            selectedPhoto = nil
                        }) {
                            Text("Remove Photo")
                                .font(.arial(size: 15))
                                .foregroundColor(.red)
                        }
                    }

                    ProfileAvatarPresetPicker(selectedPresetID: profile.avatarPresetID) { preset, data in
                        selectedPhoto = nil
                        profile.photoData = data
                        profile.avatarPresetID = preset.id
                    }
                    .padding(.horizontal, 4)
                    
                    Spacer()
                }
            },
            onNext: {
                withAnimation {
                    currentStep = .matchPreferences
                }
            },
            canContinue: true,
            showSkip: true,
            onSkip: {
                withAnimation {
                    currentStep = .matchPreferences
                }
            },
            buttonText: "Continue",
            onBack: {
                withAnimation {
                    currentStep = .aamcID
                }
            }
        )
    }

    // MARK: - Match Preferences Step
    private var matchPreferencesStep: some View {
        OnboardingStepView(
            title: OnboardingStep.matchPreferences.title,
            subtitle: OnboardingStep.matchPreferences.subtitle,
            content: {
                ScrollView {
                    VStack(spacing: 16) {
                        Button {
                            showQuestionnaireCustomization = true
                        } label: {
                            HStack(alignment: .center, spacing: 12) {
                                VStack(alignment: .leading, spacing: 10) {
                                    Label("Program Scoring", systemImage: "slider.horizontal.3")
                                        .font(.arial(size: 16, weight: .semibold))
                                        .foregroundColor(.primary)
                                    Text("Programs are scored using the questionnaire. Every enabled section counts equally toward your score.")
                                        .font(.arial(size: 14))
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.leading)
                                    Text("Customize questionnaire")
                                        .font(.arial(size: 13, weight: .semibold))
                                        .foregroundColor(AppColors.primaryBlue)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.right")
                                    .font(.arial(size: 13, weight: .semibold))
                                    .foregroundColor(.secondary)
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .glassEffect(.regular, in: .rect(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Preferred EMR (Optional)")
                                .font(.arial(size: 16, weight: .semibold))

                            Menu {
                                Button {
                                    selectPreferredEMR(nil)
                                } label: {
                                    if preferredEMR.isEmpty {
                                        Label("Not set", systemImage: "checkmark")
                                    } else {
                                        Text("Not set")
                                    }
                                }
                                ForEach(EMRSystem.allCases) { system in
                                    Button {
                                        selectPreferredEMR(system)
                                    } label: {
                                        if EMRSystem.matchesSelection(preferredEMRForSelection, system: system) {
                                            Label(system.displayName, systemImage: "checkmark")
                                        } else {
                                            Text(system.displayName)
                                        }
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(preferredEMRMenuLabel)
                                        .font(.arial(size: 15, weight: .medium))
                                        .foregroundColor(preferredEMR.isEmpty ? .secondary : .primary)
                                    Spacer()
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.arial(size: 12))
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)

                            if isPreferredEMROtherSelected {
                                ClearableTextField("Type EMR name", text: $preferredEMROtherDetail)
                                    .font(.arial(size: 15))
                                    .textInputAutocapitalization(.words)
                                    .autocorrectionDisabled()
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 10))
                                    .onChange(of: preferredEMROtherDetail) { _, newValue in
                                        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                                        preferredEMR = trimmed.isEmpty ? EMRSystem.other.rawValue : trimmed
                                    }
                            }

                            Text("Optional — we'll note when a program uses the EMR you're most familiar with.")
                                .font(.arial(size: 13))
                                .foregroundColor(.secondary)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .glassEffect(.regular, in: .rect(cornerRadius: 14))

                        Toggle(isOn: $includeRedFlaggedInRankList) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Include Red-Flagged Programs in Rank List")
                                    .font(.arial(size: 15, weight: .medium))
                                Text("When off, programs you mark with red flags won't appear on your rank list.")
                                    .font(.arial(size: 13))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .glassEffect(.regular, in: .rect(cornerRadius: 14))
                    }
                }
            },
            onNext: {
                withAnimation {
                    currentStep = .calendarSync
                }
            },
            canContinue: true,
            buttonText: "Continue",
            onBack: {
                withAnimation {
                    currentStep = .photo
                }
            }
        )
        .onAppear {
            loadMatchPreferencesState()
        }
        .sheet(isPresented: $showQuestionnaireCustomization) {
            MatchlyNavigationView {
                QuestionnaireCustomizationView()
                    .environmentObject(dataManager)
                    .navigationTitle("Program Scoring")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                showQuestionnaireCustomization = false
                            }
                        }
                    }
            }
            .matchlyExpandedSheet()
        }
    }

    private var isPreferredEMROtherSelected: Bool {
        EMRSystem.isOtherOrCustom(preferredEMRForSelection)
    }

    private var preferredEMRForSelection: String? {
        preferredEMR.isEmpty ? nil : preferredEMR
    }

    private var preferredEMRMenuLabel: String {
        guard !preferredEMR.isEmpty else { return "Not set" }
        if EMRSystem.isOtherOrCustom(preferredEMR) {
            let trimmed = preferredEMROtherDetail.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? EMRSystem.other.displayName : trimmed
        }
        return preferredEMR
    }

    private func loadMatchPreferencesState() {
        includeRedFlaggedInRankList = dataManager.preferences.includeRedFlaggedProgramsInRankList
        if let stored = dataManager.preferences.preferredEMR, !stored.isEmpty {
            if let system = EMRSystem(rawValue: stored) {
                preferredEMR = system.rawValue
                preferredEMROtherDetail = ""
            } else {
                preferredEMR = EMRSystem.other.rawValue
                preferredEMROtherDetail = stored
            }
        } else {
            preferredEMR = ""
            preferredEMROtherDetail = ""
        }
    }

    private func selectPreferredEMR(_ system: EMRSystem?) {
        guard let system else {
            preferredEMR = ""
            preferredEMROtherDetail = ""
            return
        }
        if system == .other {
            let trimmed = preferredEMROtherDetail.trimmingCharacters(in: .whitespacesAndNewlines)
            preferredEMR = trimmed.isEmpty ? EMRSystem.other.rawValue : trimmed
        } else {
            preferredEMR = system.rawValue
            preferredEMROtherDetail = ""
        }
    }

    private func resolvedPreferredEMRForSave() -> String? {
        guard !preferredEMR.isEmpty else { return nil }
        if EMRSystem.isOtherOrCustom(preferredEMR) {
            let trimmed = preferredEMROtherDetail.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? EMRSystem.other.rawValue : trimmed
        }
        return preferredEMR
    }
    
    // MARK: - Calendar Sync Step
    private var calendarSyncStep: some View {
        OnboardingStepView(
            title: OnboardingStep.calendarSync.title,
            subtitle: OnboardingStep.calendarSync.subtitle,
            content: {
                VStack(spacing: 32) {
                    Spacer()
                    
                    VStack(spacing: 24) {
                        Image(systemName: "calendar.badge.plus")
                            .font(.arial(size: 80))
                            .foregroundColor(.blue)
                        
                        VStack(spacing: 12) {
                            Text("Sync Interviews to Calendar")
                                .font(.arial(size: 22, weight: .semibold))
                            
                            Text("Automatically add your interview dates to your device calendar with reminders and all program details.")
                                .font(.arial(size: 15))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                        }
                        
                        Toggle(isOn: $enableCalendarSync) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Enable Calendar Sync")
                                    .font(.arial(size: 17, weight: .medium))
                                Text("You can change this anytime in Settings")
                                    .font(.arial(size: 13))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .glassEffect(.regular, in: .rect(cornerRadius: 12))
                    }
                    
                    Spacer()
                }
            },
            onNext: {
                completeOnboarding()
            },
            canContinue: true,
            buttonText: "Complete Setup",
            onBack: {
                withAnimation {
                    currentStep = .matchPreferences
                }
            }
        )
        .onAppear {
            // Initialize from existing preferences if available
            enableCalendarSync = dataManager.preferences.enableCalendarSync
        }
    }
    
    // MARK: - Applying Track Step
    private var applyingTrackStep: some View {
        OnboardingStepView(
            title: OnboardingStep.applyingTrack.title,
            subtitle: OnboardingStep.applyingTrack.subtitle,
            content: {
                VStack(spacing: 16) {
                    ForEach([ProgramTrainingLevelFilter.residency, .fellowship], id: \.self) { track in
                        Button(action: {
                            selectedApplyingTrack = track
                        }) {
                            HStack(spacing: 14) {
                                Image(systemName: track == .residency ? "cross.case.fill" : "brain.head.profile")
                                    .font(.arial(size: 24))
                                    .foregroundColor(track == .residency ? .blue : .purple)
                                    .frame(width: 36)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(track.rawValue)
                                        .font(.arial(size: 18, weight: .semibold))
                                        .foregroundColor(.primary)
                                    Text(track == .residency
                                         ? "Categorical & integrated residency programs"
                                         : "Subspecialty fellowship programs")
                                        .font(.arial(size: 13))
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.leading)
                                }

                                Spacer()

                                Image(systemName: selectedApplyingTrack == track ? "checkmark.circle.fill" : "circle")
                                    .font(.arial(size: 22))
                                    .foregroundColor(selectedApplyingTrack == track ? .blue : .secondary.opacity(0.4))
                            }
                            .padding(16)
                            .glassEffect(
                                selectedApplyingTrack == track
                                    ? .regular.tint((track == .residency ? Color.blue : Color.purple).opacity(0.2)).interactive()
                                    : .regular.interactive(),
                                in: .rect(cornerRadius: 16)
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer()
                }
            },
            onNext: {
                dataManager.preferences.applyingTrack = selectedApplyingTrack.rawValue
                dataManager.savePreferences()
                withAnimation {
                    currentStep = .specialties
                }
            },
            canContinue: true,
            buttonText: "Continue",
            onBack: {
                withAnimation {
                    currentStep = .welcome
                }
            }
        )
    }

    // MARK: - Specialties Step
    private var specialtiesStep: some View {
        OnboardingStepView(
            title: OnboardingStep.specialties.title,
            subtitle: selectedApplyingTrack == .fellowship
                ? "Choose your specialty area. We'll show related fellowship programs in search."
                : OnboardingStep.specialties.subtitle,
            content: {
                SpecialtySelectionContentView(
                    selectedSpecialties: $selectedSpecialties
                )
            },
            onNext: {
                // Save specialties immediately when user continues
                if !selectedSpecialties.isEmpty {
                    dataManager.preferences.specialties = Array(selectedSpecialties).sorted()
                    if let first = selectedSpecialties.first {
                        dataManager.preferences.specialty = first
                    }
                    dataManager.savePreferences()
                }
                withAnimation {
                    currentStep = .name
                }
            },
            canContinue: !selectedSpecialties.isEmpty,
            buttonText: "Continue",
            onBack: {
                withAnimation {
                    currentStep = .applyingTrack
                }
            }
        )
    }
    
    private func completeOnboarding() {
        // Save profile
        dataManager.preferences.profile = profile
        
        // Save specialties (should already be saved, but ensure it's set)
        if !selectedSpecialties.isEmpty {
            dataManager.preferences.specialties = Array(selectedSpecialties).sorted()
            if let first = selectedSpecialties.first {
                dataManager.preferences.specialty = first
            }
        }
        
        // Save calendar sync preference
        dataManager.preferences.enableCalendarSync = enableCalendarSync
        dataManager.preferences.applyingTrack = selectedApplyingTrack.rawValue
        dataManager.preferences.includeRedFlaggedProgramsInRankList = includeRedFlaggedInRankList
        dataManager.preferences.preferredEMR = resolvedPreferredEMRForSave()
        
        // Mark onboarding as complete
        dataManager.preferences.hasCompletedOnboarding = true
        dataManager.preferences.hasCompletedFeatureTour = false
        dataManager.savePreferences()
        
        if dataManager.preferences.preferredEMR != nil {
            dataManager.recalculateAllScores()
        }
        
        // If the user opted into calendar sync, actually request permission now.
        // If access is denied, turn the preference back off so the stored state
        // matches reality.
        if enableCalendarSync {
            Task {
                let granted = await CalendarManager.shared.requestAccess()
                if !granted {
                    await MainActor.run {
                        dataManager.preferences.enableCalendarSync = false
                        dataManager.savePreferences()
                    }
                }
            }
        }
        
        showMainApp = true
    }
}

// MARK: - Onboarding Step View Template
struct OnboardingStepView<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: () -> Content
    let onNext: () -> Void
    let canContinue: Bool
    var showSkip: Bool = false
    var onSkip: (() -> Void)? = nil
    var buttonText: String = "Continue"
    var onBack: (() -> Void)? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                Text(title)
                    .font(.arial(size: 28, weight: .bold))
                    .multilineTextAlignment(.center)
                
                Text(subtitle)
                    .font(.arial(size: 16))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)
            .padding(.top, 40)
            .padding(.bottom, 32)
            
            // Content
            content()
                .padding(.horizontal, 24)
            
            Spacer()
            
            // Footer buttons
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    // Back button (if available) ? neutral Liquid Glass.
                    if let onBack = onBack {
                        Button(action: onBack) {
                            HStack(spacing: 6) {
                                Image(systemName: "chevron.left")
                                    .font(.arial(size: 14, weight: .semibold))
                                Text("Back")
                                    .font(.arial(size: 17, weight: .medium))
                            }
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                        }
                        .buttonStyle(.glass)
                    }

                    // Continue button ? prominent Liquid Glass, brand-tinted.
                    Button(action: onNext) {
                        Text(buttonText)
                            .font(.arial(size: 17, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(canContinue ? AppColors.primaryBlue : Color.gray)
                    .disabled(!canContinue)
                }
                .padding(.horizontal, 24)
                
                if showSkip, let onSkip = onSkip {
                    Button(action: onSkip) {
                        Text("Skip")
                            .font(.arial(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .padding(.bottom, 20)
                }
            }
        }
    }
}

// MARK: - Specialty Selection Content
struct SpecialtySelectionContentView: View {
    @Binding var selectedSpecialties: Set<String>
    @State private var searchText = ""
    
    let specialties = SpecialtyFormatter.commonSpecialties
    
    var filteredSpecialties: [String] {
        if searchText.isEmpty {
            return specialties
        }
        return specialties.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                ClearableTextField("Search specialties...", text: $searchText)
            }
            .padding()
            .glassEffect(.regular, in: .rect(cornerRadius: 10))
            
            // Specialty list
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(filteredSpecialties, id: \.self) { specialty in
                        SpecialtyRow(
                            specialty: specialty,
                            isSelected: selectedSpecialties.contains(specialty)
                        ) {
                            if selectedSpecialties.contains(specialty) {
                                selectedSpecialties.remove(specialty)
                            } else {
                                selectedSpecialties.insert(specialty)
                            }
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    OnboardingFlowView()
}

