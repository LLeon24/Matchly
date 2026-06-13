//
//  OnboardingFlowView.swift
//  Matchly
//
//  Created on 11/14/25.
//

import SwiftUI
import PhotosUI

struct OnboardingFlowView: View {
    @ObservedObject private var dataManager = DataManager.shared
    @State private var currentStep: OnboardingStep = .welcome
    @State private var profile = UserProfile()
    @State private var selectedSpecialties: Set<String> = []
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showMainApp = false
    @State private var iconScale: CGFloat = 1.0
    @State private var enableCalendarSync: Bool = false
    
    enum OnboardingStep: Int, CaseIterable {
        case welcome = 0
        case specialties = 1  // Moved specialties to be second (right after welcome)
        case name = 2
        case aamcID = 3
        case photo = 4
        case calendarSync = 5
        
        var title: String {
            switch self {
            case .welcome: return "Welcome to Matchly"
            case .specialties: return "Select Your Specialties"
            case .name: return "What's your name?"
            case .aamcID: return "AAMC ID (Optional)"
            case .photo: return "Add Your Photo (Optional)"
            case .calendarSync: return "Calendar Sync"
            }
        }
        
        var subtitle: String {
            switch self {
            case .welcome: return "Let's get you set up"
            case .specialties: return "Choose the specialties you're applying to. You can select multiple if you're dual applying."
            case .name: return "We'll use this to personalize your experience"
            case .aamcID: return "Your AAMC ID helps us provide better program matching"
            case .photo: return "Make your profile more personal"
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
                    case .specialties:
                        specialtiesStep
                    case .name:
                        nameStep
                    case .aamcID:
                        aamcIDStep
                    case .photo:
                        photoStep
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
        .onChange(of: selectedPhoto) { oldValue, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self) {
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
                        FeatureRow(icon: "list.bullet.clipboard.fill", text: "Track & Rank Programs")
                        FeatureRow(icon: "map.fill", text: "Visualize on Interactive Maps")
                        FeatureRow(icon: "star.fill", text: "Manage ERAS Signals")
                        FeatureRow(icon: "chart.bar.fill", text: "Personalized Analytics")
                    }
                    .padding(.top, 24)
                }
            }
            
            Spacer()
            
            // Continue button with gradient
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    currentStep = .specialties  // Go to specialties first
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
            // Hero CTA → prominent Liquid Glass over the soft gradient backdrop.
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
                            
                            // Edit overlay
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
                    currentStep = .calendarSync
                }
            },
            canContinue: true,
            showSkip: true,
            onSkip: {
                withAnimation {
                    currentStep = .calendarSync
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
                    currentStep = .photo
                }
            }
        )
        .onAppear {
            // Initialize from existing preferences if available
            enableCalendarSync = dataManager.preferences.enableCalendarSync
        }
    }
    
    // MARK: - Specialties Step
    private var specialtiesStep: some View {
        OnboardingStepView(
            title: OnboardingStep.specialties.title,
            subtitle: OnboardingStep.specialties.subtitle,
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
                    currentStep = .welcome
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
        
        // Mark onboarding as complete
        dataManager.preferences.hasCompletedOnboarding = true
        dataManager.savePreferences()
        
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
                    // Back button (if available) → neutral Liquid Glass.
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

                    // Continue button → prominent Liquid Glass, brand-tinted.
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

