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
    @State private var iconScale: CGFloat = 1.0
    @State private var enableCalendarSync: Bool = false
    @State private var includeRedFlaggedInRankList: Bool = true
    @State private var preferredEMR: String = ""
    
    enum OnboardingStep: Int, CaseIterable {
        case welcome = 0
        case applyingTrack = 1
        case specialties = 2
        case name = 3
        case aamcID = 4
        case photo = 5
        case appGuide = 6
        case matchPreferences = 7
        case calendarSync = 8
        
        var title: String {
            switch self {
            case .welcome: return "Welcome to Matchly"
            case .applyingTrack: return "What Are You Applying To?"
            case .specialties: return "Select Your Specialties"
            case .name: return "What's your name?"
            case .aamcID: return "AAMC ID (Optional)"
            case .photo: return "Add Your Photo (Optional)"
            case .appGuide: return "Quick App Tour"
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
            case .photo: return "Make your profile more personal"
            case .appGuide: return "After setup, we'll walk you through the real app with arrows and highlights — not a slideshow."
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
                    case .appGuide:
                        appGuideStep
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
                guard let data = try? await newItem.loadTransferable(type: Data.self) else {
                    await MainActor.run { isLoadingPhoto = false }
                    return
                }
                let preparedImage = await PhotoPickerImageLoader.loadPreparedImage(from: data)
                await MainActor.run {
                    isLoadingPhoto = false
                    if let preparedImage {
                        cropImageItem = CropImageItem(image: preparedImage)
                    }
                }
            }
        }
        .fullScreenCover(item: $cropImageItem) { item in
            ImageCropView(image: item.image) { croppedImage in
                if let data = croppedImage.jpegData(compressionQuality: 0.9) {
                    profile.photoData = data
                }
            }
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
            
            VStack(spacing: 32) {
                // Matchly App Icon with animation
                ZStack {
                    // Glow effect
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.blue.opacity(0.3),
                                    Color.purple.opacity(0.2),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 20,
                                endRadius: 80
                            )
                        )
                        .frame(width: 160, height: 160)
                        .blur(radius: 20)
                    
                    // App Icon
                    Image("MatchlyIcon")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 140, height: 140)
                        .cornerRadius(30)
                        .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
                }
                .scaleEffect(iconScale)
                .onAppear {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.7).repeatForever(autoreverses: true)) {
                        iconScale = 1.05
                    }
                }
                
                // Welcome text with animation
                VStack(spacing: 16) {
                    Text("Welcome to Matchly")
                        .font(.arial(size: 36, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("Your Residency Match Companion")
                        .font(.arial(size: 18, weight: .medium))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                    
                    // Feature highlights
                    VStack(spacing: 12) {
                        FeatureRow(icon: "list.bullet.clipboard.fill", text: "Track & Score Programs")
                        FeatureRow(icon: "chart.bar.fill", text: "Build Your NRMP Rank List")
                        FeatureRow(icon: "star.fill", text: "Manage ERAS Signals")
                        FeatureRow(icon: "heart.fill", text: "Couples Match with Your Partner")
                    }
                    .padding(.top, 24)
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
                    TextField("Enter your name", text: $profile.name)
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
            canContinue: !profile.name.trimmingCharacters(in: .whitespaces).isEmpty,
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
                    TextField("AAMC ID (Optional)", text: Binding(
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
                            selectedPhoto = nil
                        }) {
                            Text("Remove Photo")
                                .font(.arial(size: 15))
                                .foregroundColor(.red)
                        }
                    }
                    
                    Spacer()
                }
            },
            onNext: {
                withAnimation {
                    currentStep = .appGuide
                }
            },
            canContinue: true,
            showSkip: true,
            onSkip: {
                withAnimation {
                    currentStep = .appGuide
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

    // MARK: - App Guide Step
    private var appGuideStep: some View {
        OnboardingStepView(
            title: OnboardingStep.appGuide.title,
            subtitle: OnboardingStep.appGuide.subtitle,
            content: {
                VStack(spacing: 24) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(AppColors.primaryBlue.opacity(0.08))
                            .frame(height: 180)

                        VStack(spacing: 16) {
                            Image(systemName: "hand.point.up.left.fill")
                                .font(.system(size: 42))
                                .foregroundStyle(AppColors.primaryBlue)
                                .rotationEffect(.degrees(-8))

                            Text("Interactive guided tour")
                                .font(.arial(size: 18, weight: .semibold))

                            Text("We'll dim the screen, spotlight each tab, and draw arrows with tips — like the in-app tours you see in other apps.")
                                .font(.arial(size: 14))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        tourPreviewRow(icon: "house.fill", title: "Dashboard", tint: AppColors.primaryBlue)
                        tourPreviewRow(icon: "list.bullet", title: "My Programs", tint: AppColors.accentGreen)
                        tourPreviewRow(icon: "chart.bar.fill", title: "Rank List", tint: AppColors.accentPink)
                        tourPreviewRow(icon: "map.fill", title: "Map", tint: AppColors.accentTeal)
                        tourPreviewRow(icon: "gearshape.fill", title: "Settings", tint: AppColors.accentPurple)
                    }
                    .padding(16)
                    .glassEffect(.regular, in: .rect(cornerRadius: 14))
                }
            },
            onNext: {
                withAnimation {
                    currentStep = .matchPreferences
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
    }

    private func tourPreviewRow(icon: String, title: String, tint: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.arial(size: 14, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 24)
            Text(title)
                .font(.arial(size: 15, weight: .medium))
            Spacer()
            Image(systemName: "arrow.turn.down.right")
                .font(.arial(size: 12))
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Match Preferences Step
    private var matchPreferencesStep: some View {
        OnboardingStepView(
            title: OnboardingStep.matchPreferences.title,
            subtitle: OnboardingStep.matchPreferences.subtitle,
            content: {
                ScrollView {
                    VStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Program Scoring", systemImage: "slider.horizontal.3")
                                .font(.arial(size: 16, weight: .semibold))
                            Text("Programs are scored using the questionnaire. Matchly starts with balanced weights — customize them anytime under Settings → Set Section Weights.")
                                .font(.arial(size: 14))
                                .foregroundColor(.secondary)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .glassEffect(.regular, in: .rect(cornerRadius: 14))

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Preferred EMR (Optional)")
                                .font(.arial(size: 16, weight: .semibold))
                            Picker("Preferred EMR", selection: $preferredEMR) {
                                Text("Not set").tag("")
                                ForEach(EMRSystem.allCases) { system in
                                    Text(system.displayName).tag(system.rawValue)
                                }
                            }
                            .pickerStyle(.menu)
                            Text("Programs using your preferred EMR score higher on the EMR factor.")
                                .font(.arial(size: 13))
                                .foregroundColor(.secondary)
                        }
                        .padding(16)
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
                    currentStep = .appGuide
                }
            }
        )
        .onAppear {
            includeRedFlaggedInRankList = dataManager.preferences.includeRedFlaggedProgramsInRankList
            preferredEMR = dataManager.preferences.preferredEMR ?? ""
        }
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
        dataManager.preferences.preferredEMR = preferredEMR.isEmpty ? nil : preferredEMR
        
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
                TextField("Search specialties...", text: $searchText)
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

