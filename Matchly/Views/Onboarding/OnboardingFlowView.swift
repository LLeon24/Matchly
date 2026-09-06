//
//  OnboardingFlowView.swift
//  Matchly
//
//  Created on 11/14/25.
//

import SwiftUI
import UIKit

struct OnboardingFlowView: View {
    @EnvironmentObject private var deepLinkHandler: CoupleDeepLinkHandler
    @ObservedObject private var dataManager = DataManager.shared
    @ObservedObject private var authManager = AuthManager.shared
    @State private var currentStep: OnboardingStep = .welcome
    @State private var profile = UserProfile()
    @State private var selectedSpecialties: Set<String> = []
    @State private var selectedApplyingTrack: ProgramTrainingLevelFilter = .residency
    @State private var fellowshipSpecialtyPhase: FellowshipSpecialtyPhase = .primarySpecialty
    @State private var selectedPrimarySpecialties: Set<String> = []
    @State private var selectedFellowshipCodes: Set<String> = []
    @State private var showMainApp = false
    @State private var enableCalendarSync: Bool = false
    @State private var includeRedFlaggedInRankList: Bool = true
    @State private var preferredEMR: String = ""
    @State private var preferredEMROtherDetail: String = ""
    @State private var appearanceMode: AppearanceMode = DataManager.shared.preferences.appearanceMode
    @State private var showQuestionnaireCustomization = false

    private enum FellowshipSpecialtyPhase {
        case primarySpecialty
        case fellowshipTypes
    }
    
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
            case .photo: return "Tap the circle to add a photo — you can move, zoom, and crop to center your face"
            case .matchPreferences: return "A few defaults to get your rank list and scoring right from the start."
            case .calendarSync: return "Would you like to sync your interviews to your device calendar? After you add programs, Interview Prep helps you build question lists for each visit."
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
        .preferredColorScheme(appearanceMode.preferredColorScheme)
        .onAppear {
            appearanceMode = dataManager.preferences.appearanceMode
            loadProfileFromAuthAndPreferences()
        }
        .onChange(of: dataManager.preferences.profile) { _, updatedProfile in
            mergeStoredProfileIntoLocalState(updatedProfile)
        }
        .onChange(of: authManager.currentUser?.displayName) { _, _ in
            loadProfileFromAuthAndPreferences()
        }
        .fullScreenCover(isPresented: $showMainApp) {
            MainTabView()
                .environmentObject(deepLinkHandler)
        }
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
                        FeatureRow(
                            icon: "star.fill",
                            text: "Manage ERAS Signals",
                            detail: "For planning only — not linked to ERAS"
                        )
                        FeatureRow(icon: "calendar", text: "Plan Interview Dates")
                        FeatureRow(icon: "calendar.badge.clock", text: "Prep Questions for Each Interview")
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
        var detail: String? = nil
        
        var body: some View {
            HStack(alignment: detail == nil ? .center : .top, spacing: 12) {
                Image(systemName: icon)
                    .font(.arial(size: 18))
                    .foregroundColor(AppColors.primaryBlue)
                    .frame(width: 28)
                    .padding(.top, detail == nil ? 0 : 1)
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(text)
                        .font(.arial(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                    
                    if let detail {
                        Text(detail)
                            .font(.arial(size: 12))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                
                Spacer(minLength: 0)
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
                    ClearableTextField("First Name", text: $profile.firstName, textContentType: .givenName)
                        .font(.arial(size: 18))
                        .padding()
                        .glassEffect(.regular, in: .rect(cornerRadius: 12))
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()

                    ClearableTextField("Last Name", text: $profile.lastName, textContentType: .familyName)
                        .font(.arial(size: 18))
                        .padding()
                        .glassEffect(.regular, in: .rect(cornerRadius: 12))
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                    
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
        .onAppear {
            loadProfileFromAuthAndPreferences()
        }
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

                    ProfilePhotoCirclePicker(
                        photoData: $profile.photoData,
                        avatarPresetID: $profile.avatarPresetID
                    )

                    ProfileAvatarPresetPicker(selectedPresetID: profile.avatarPresetID) { preset, data in
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
        .onAppear {
            loadProfileFromAuthAndPreferences()
        }
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

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Appearance")
                                .font(.arial(size: 15, weight: .medium))

                            Picker("Appearance", selection: $appearanceMode) {
                                ForEach(AppearanceMode.allCases) { mode in
                                    Text(mode.displayName).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()

                            Text("Auto follows your device. You can change this anytime in Settings.")
                                .font(.arial(size: 13))
                                .foregroundColor(.secondary)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .glassEffect(.regular, in: .rect(cornerRadius: 14))

                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 10) {
                                Image(systemName: "calendar.badge.clock")
                                    .font(.arial(size: 18))
                                    .foregroundColor(AppColors.primaryBlue)
                                Text("Home Screen Widget")
                                    .font(.arial(size: 15, weight: .medium))
                            }

                            Text("Add the Matchly widget to see your next interview at a glance on your Home Screen or Lock Screen.")
                                .font(.arial(size: 13))
                                .foregroundColor(.secondary)

                            VStack(alignment: .leading, spacing: 8) {
                                widgetSetupStep(number: 1, text: "Touch and hold your Home Screen")
                                widgetSetupStep(number: 2, text: "Tap Edit, then Add Widget")
                                widgetSetupStep(number: 3, text: "Search for Matchly and choose a size")
                            }
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
        appearanceMode = dataManager.preferences.appearanceMode
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
                            
                            Text("Automatically add your interview dates to your device calendar with reminders and all program details. Open Interview Prep on any program to build your must-ask question list.")
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
                if selectedApplyingTrack == .fellowship {
                    fellowshipSpecialtyPhase = .primarySpecialty
                    selectedPrimarySpecialties.removeAll()
                    selectedFellowshipCodes.removeAll()
                } else {
                    selectedPrimarySpecialties.removeAll()
                    selectedFellowshipCodes.removeAll()
                }
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
            title: specialtiesStepTitle,
            subtitle: specialtiesStepSubtitle,
            content: {
                specialtiesStepContent
            },
            onNext: specialtiesStepOnNext,
            canContinue: specialtiesStepCanContinue,
            buttonText: "Continue",
            onBack: specialtiesStepOnBack
        )
    }

    private var specialtiesStepTitle: String {
        guard selectedApplyingTrack == .fellowship else {
            return OnboardingStep.specialties.title
        }
        switch fellowshipSpecialtyPhase {
        case .primarySpecialty:
            return "What Are Your Primary Specialties?"
        case .fellowshipTypes:
            return "Select Fellowship Types"
        }
    }

    private var specialtiesStepSubtitle: String {
        guard selectedApplyingTrack == .fellowship else {
            return OnboardingStep.specialties.subtitle
        }
        switch fellowshipSpecialtyPhase {
        case .primarySpecialty:
            return "Select the residency specialty or specialties you completed (e.g. IM/Peds, IM/EM). This determines which fellowships you can apply to."
        case .fellowshipTypes:
            return "Choose the fellowship subspecialties you're applying to. You can select multiple."
        }
    }

    @ViewBuilder
    private var specialtiesStepContent: some View {
        if selectedApplyingTrack == .fellowship {
            switch fellowshipSpecialtyPhase {
            case .primarySpecialty:
                PrimarySpecialtySelectionContentView(
                    selectedPrimarySpecialties: $selectedPrimarySpecialties
                )
            case .fellowshipTypes:
                if !selectedPrimarySpecialties.isEmpty {
                    FellowshipSelectionContentView(
                        primarySpecialties: Array(selectedPrimarySpecialties).sorted(),
                        selectedFellowshipCodes: $selectedFellowshipCodes
                    )
                }
            }
        } else {
            SpecialtySelectionContentView(
                selectedSpecialties: $selectedSpecialties
            )
        }
    }

    private var specialtiesStepCanContinue: Bool {
        if selectedApplyingTrack == .fellowship {
            switch fellowshipSpecialtyPhase {
            case .primarySpecialty:
                return !selectedPrimarySpecialties.isEmpty
            case .fellowshipTypes:
                return !selectedFellowshipCodes.isEmpty
            }
        }
        return !selectedSpecialties.isEmpty
    }

    private func specialtiesStepOnNext() {
        if selectedApplyingTrack == .fellowship {
            switch fellowshipSpecialtyPhase {
            case .primarySpecialty:
                selectedFellowshipCodes.removeAll()
                withAnimation {
                    fellowshipSpecialtyPhase = .fellowshipTypes
                }
            case .fellowshipTypes:
                saveFellowshipSpecialtySelections()
                withAnimation {
                    currentStep = .name
                }
            }
            return
        }

        if !selectedSpecialties.isEmpty {
            dataManager.preferences.specialties = Array(selectedSpecialties).sorted()
            dataManager.preferences.fellowshipSpecialtyCodes = []
            if let first = selectedSpecialties.first {
                dataManager.preferences.specialty = first
            }
            dataManager.savePreferences()
        }
        withAnimation {
            currentStep = .name
        }
    }

    private func specialtiesStepOnBack() {
        if selectedApplyingTrack == .fellowship, fellowshipSpecialtyPhase == .fellowshipTypes {
            withAnimation {
                fellowshipSpecialtyPhase = .primarySpecialty
            }
            return
        }
        withAnimation {
            currentStep = .applyingTrack
        }
    }

    private func saveFellowshipSpecialtySelections() {
        guard !selectedPrimarySpecialties.isEmpty else { return }
        let sortedPrimaries = Array(selectedPrimarySpecialties).sorted()
        dataManager.preferences.specialties = sortedPrimaries
        dataManager.preferences.specialty = sortedPrimaries.first
        dataManager.preferences.fellowshipSpecialtyCodes = Array(selectedFellowshipCodes).sorted()
        dataManager.savePreferences()
    }
    
    private func completeOnboarding() {
        // Save profile
        dataManager.preferences.profile = profile
        
        // Save specialties (should already be saved, but ensure it's set)
        if selectedApplyingTrack == .fellowship {
            saveFellowshipSpecialtySelections()
        } else if !selectedSpecialties.isEmpty {
            dataManager.preferences.specialties = Array(selectedSpecialties).sorted()
            dataManager.preferences.fellowshipSpecialtyCodes = []
            if let first = selectedSpecialties.first {
                dataManager.preferences.specialty = first
            }
        }
        
        // Save calendar sync preference
        dataManager.preferences.enableCalendarSync = enableCalendarSync
        dataManager.preferences.applyingTrack = selectedApplyingTrack.rawValue
        dataManager.preferences.includeRedFlaggedProgramsInRankList = includeRedFlaggedInRankList
        dataManager.preferences.preferredEMR = resolvedPreferredEMRForSave()
        dataManager.preferences.appearanceMode = appearanceMode
        
        // Mark onboarding as complete
        dataManager.preferences.hasCompletedOnboarding = true
        dataManager.preferences.hasCompletedFeatureTour = false
        dataManager.preferences.shouldPromptFirstProgramAdd = true
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

    private func widgetSetupStep(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(number)")
                .font(.arial(size: 12, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 22, height: 22)
                .background(Circle().fill(AppColors.primaryBlue))
            Text(text)
                .font(.arial(size: 13))
                .foregroundColor(.primary)
        }
    }

    private func loadProfileFromAuthAndPreferences() {
        mergeStoredProfileIntoLocalState(dataManager.preferences.profile)

        if let user = authManager.currentUser {
            if let displayName = user.displayName?.trimmingCharacters(in: .whitespacesAndNewlines),
               !displayName.isEmpty,
               !AuthManager.isEmailDerivedDisplayName(displayName, email: user.email) {
                let split = UserProfile.splitLegacyName(displayName)
                if profile.firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                   !split.first.isEmpty {
                    profile.firstName = split.first
                }
                if profile.lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                   !split.last.isEmpty {
                    profile.lastName = split.last
                }
            }

            if profile.photoData == nil, user.photoURL != nil {
                Task {
                    await dataManager.applyAuthPhotoToProfileIfNeeded(from: user.photoURL)
                }
            }
        }
    }

    private func mergeStoredProfileIntoLocalState(_ stored: UserProfile) {
        if profile.firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           !stored.firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            profile.firstName = stored.firstName
        }
        if profile.lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           !stored.lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            profile.lastName = stored.lastName
        }
        if profile.photoData == nil, stored.photoData != nil {
            profile.photoData = stored.photoData
            profile.avatarPresetID = stored.avatarPresetID
        }
        if profile.aamcID == nil, stored.aamcID != nil {
            profile.aamcID = stored.aamcID
        }
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

// MARK: - Primary Specialty Selection (Fellowship Track)
struct PrimarySpecialtySelectionContentView: View {
    @Binding var selectedPrimarySpecialties: Set<String>
    @State private var searchText = ""

    private let specialties = SpecialtyFormatter.primarySpecialtiesForFellowship

    private var filteredSpecialties: [String] {
        if searchText.isEmpty {
            return specialties
        }
        return specialties.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                ClearableTextField("Search specialties...", text: $searchText)
            }
            .padding()
            .glassEffect(.regular, in: .rect(cornerRadius: 10))

            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(filteredSpecialties, id: \.self) { specialty in
                        SpecialtyRow(
                            specialty: specialty,
                            isSelected: selectedPrimarySpecialties.contains(specialty)
                        ) {
                            if selectedPrimarySpecialties.contains(specialty) {
                                selectedPrimarySpecialties.remove(specialty)
                            } else {
                                selectedPrimarySpecialties.insert(specialty)
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Fellowship Type Selection (Fellowship Track)
struct FellowshipSelectionContentView: View {
    let primarySpecialties: [String]
    @Binding var selectedFellowshipCodes: Set<String>
    @State private var searchText = ""

    private var options: [FellowshipFilterOption] {
        FellowshipFilterCatalog.options(forUserSpecialties: primarySpecialties)
    }

    private var filteredOptions: [FellowshipFilterOption] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return options }
        return options.filter {
            $0.displayName.localizedCaseInsensitiveContains(query)
                || $0.parentLabel.localizedCaseInsensitiveContains(query)
        }
    }

    private var primarySpecialtiesLabel: String {
        primarySpecialties.joined(separator: ", ")
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                ClearableTextField("Search fellowship types...", text: $searchText)
            }
            .padding()
            .glassEffect(.regular, in: .rect(cornerRadius: 10))

            if options.isEmpty {
                Text("No fellowship types found for \(primarySpecialtiesLabel).")
                    .font(.arial(size: 14))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredOptions) { option in
                            fellowshipRow(option)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func fellowshipRow(_ option: FellowshipFilterOption) -> some View {
        let isSelected = selectedFellowshipCodes.contains(option.code)
        Button(action: {
            if isSelected {
                selectedFellowshipCodes.remove(option.code)
            } else {
                selectedFellowshipCodes.insert(option.code)
            }
        }) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .purple : .gray)
                    .font(.arial(size: 22))

                Text(option.displayName)
                    .font(.arial(size: 16))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)

                Spacer(minLength: 0)
            }
            .padding()
            .glassEffect(
                isSelected ? .regular.tint(Color.purple.opacity(0.18)).interactive() : .regular,
                in: .rect(cornerRadius: 10)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.purple : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    OnboardingFlowView()
        .matchlyPreviewEnvironment()
}

