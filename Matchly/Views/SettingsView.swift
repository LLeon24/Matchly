//
//  SettingsView.swift
//  Matchly
//
//  Created by Leoh N. Leon II on 11/14/25.
//

import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct SettingsView: View {
    @EnvironmentObject var dataManager: DataManager
    @ObservedObject private var authManager = AuthManager.shared
    @State private var showResetAlert = false
    @State private var showSignOutAlert = false
    @State private var showSpecialtyChange = false
    @State private var showWeights = false
    @State private var showLinkEmailPassword = false
    
    var body: some View {
        MatchlyNavigationView {
            Form {
                profileSection
                appInformationSection
                if FeatureFlags.couplesMatchEnabled {
                    couplesMatchingSection
                }
                questionnaireSection
                calendarSection
                dataManagementSection
                accountSection
                
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    Text("Matchly helps medical students organize residency interview information and generate personalized rank lists.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } header: {
                    MatchlyFormSectionHeader(title: "About")
                }
            }
            .scrollContentBackground(.hidden)
            .matchlyReadableWidth()
            .matchlyScrollTabBarClearance()
            .navigationTitle("Settings")
            .appCanvasBackground()
            .alert("Reset All Data", isPresented: $showResetAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    resetAllData()
                }
            } message: {
                Text("This will delete all programs and reset your preferences. This action cannot be undone.")
            }
            .alert("Sign Out", isPresented: $showSignOutAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) {
                    authManager.signOut()
                }
            } message: {
                Text(
                    authManager.isBiometricLoginEnabled
                        ? "You'll sign out of this session. Sign back in with \(authManager.biometricDisplayName) or Apple Sign In."
                        : "Are you sure you want to sign out? You'll need to sign in again to access your data."
                )
            }
            .sheet(isPresented: $showSpecialtyChange) {
                SpecialtySelectionView()
            }
            .sheet(isPresented: $showLinkEmailPassword) {
                LinkEmailPasswordView()
            }
        }
    }
    
    private var profileSection: some View {
        Section {
                    NavigationLink(destination: ProfileEditView()) {
                        HStack(spacing: 12) {
                            // Profile photo or icon
                            if let photoData = dataManager.preferences.profile.photoData,
                               let uiImage = UIImage(data: photoData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 50, height: 50)
                                    .clipShape(Circle())
                            } else {
                                ZStack {
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: [Color.blue.opacity(0.2), Color.purple.opacity(0.2)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 50, height: 50)
                                    
                                    Image(systemName: "person.fill")
                                        .font(.arial(size: 24))
                                        .foregroundStyle(
                                            LinearGradient(
                                                colors: [.blue, .purple],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                }
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(dataManager.preferences.profile.name.isEmpty ? "Add Profile" : dataManager.preferences.profile.name)
                                    .font(.arial(size: 17, weight: .medium))
                                    .foregroundColor(.primary)
                                
                                if let aamcID = dataManager.preferences.profile.aamcID, !aamcID.isEmpty {
                                    Text("AAMC ID: \(aamcID)")
                                        .font(.arial(size: 13))
                                        .foregroundColor(.secondary)
                                } else {
                                    Text("Tap to edit profile")
                                        .font(.arial(size: 13))
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(.clear)
                            .glassEffect(.regular, in: .rect(cornerRadius: 16))
                            .padding(.vertical, 4)
                    )
        } header: {
            MatchlyFormSectionHeader(title: "Profile")
        }
    }
    
    private var appInformationSection: some View {
        Section {
                    Button {
                        NotificationCenter.default.post(name: NSNotification.Name("ShowFeatureTour"), object: nil)
                    } label: {
                        Label("Replay Guided Tour", systemImage: "hand.point.up.left.fill")
                            .foregroundStyle(AppColors.primaryBlue)
                    }
                    .buttonStyle(.plain)

                    NavigationLink(destination: AppGuideView(showsNavigationChrome: true)) {
                        Label("Feature Overview", systemImage: "book.fill")
                    }

                    Picker("Applying To", selection: Binding(
                        get: {
                            ProgramTrainingLevelFilter(rawValue: dataManager.preferences.applyingTrack) ?? .residency
                        },
                        set: { newValue in
                            dataManager.preferences.applyingTrack = newValue.rawValue
                            dataManager.savePreferences()
                        }
                    )) {
                        ForEach(ProgramTrainingLevelFilter.allCases) { track in
                            Text(track.rawValue).tag(track)
                        }
                    }

                    if !dataManager.preferences.specialties.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Specialties")
                                .font(.headline)
                            ForEach(dataManager.preferences.specialties, id: \.self) { specialty in
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.blue)
                                    Text(specialty)
                                }
                                .font(.subheadline)
                            }
                        }
                    } else {
                        HStack {
                            Text("Specialty")
                            Spacer()
                            Text(dataManager.preferences.specialty ?? "Not set")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Button(action: {
                        showSpecialtyChange = true
                    }) {
                        Text(dataManager.preferences.specialties.isEmpty ? "Change Specialty" : "Edit Specialties")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(AppColors.primaryBlue)
                    .listRowBackground(Color.clear)
        } header: {
            MatchlyFormSectionHeader(title: "App Information")
        }
    }
    
    private var couplesMatchingSection: some View {
        Section {
                    if let couple = dataManager.preferences.couple {
                        if couple.isLinked {
                            NavigationLink(destination: CouplesMatchingView()) {
                                HStack {
                                    Image(systemName: "person.2.fill")
                                        .foregroundColor(.blue)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Linked with \(couple.user2Name ?? "Partner")")
                                            .font(.arial(size: 15, weight: .medium))
                                        Text("Active")
                                            .font(.arial(size: 12))
                                            .foregroundColor(.green)
                                    }
                                }
                            }
                        } else {
                            NavigationLink(destination: CouplesMatchingView()) {
                                HStack {
                                    Image(systemName: "person.2.fill")
                                        .foregroundColor(.orange)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Pending Link")
                                            .font(.arial(size: 15, weight: .medium))
                                        Text("Code: \(couple.coupleCode)")
                                            .font(.arial(size: 12))
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    } else {
                        NavigationLink(destination: CouplesMatchingView()) {
                            HStack {
                                Image(systemName: "person.2.fill")
                                    .foregroundColor(.blue)
                                Text("Set Up Couples Matching")
                            }
                        }
                    }
        } header: {
            MatchlyFormSectionHeader(title: "Couples Matching")
        }
    }
    
    private var questionnaireSection: some View {
        Section {
                    NavigationLink(destination: QuestionnaireCustomizationView()) {
                        Text("Customize Questionnaire")
                    }
                    
                    NavigationLink(destination: QuestionnaireWeightsView()) {
                        HStack {
                            Text("Set Section Weights")
                            Spacer()
                            if !dataManager.preferences.sectionWeights.isEmpty {
                                Text("Custom")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else {
                                Text("Equal")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    Toggle(isOn: Binding(
                        get: { dataManager.preferences.includeRedFlaggedProgramsInRankList },
                        set: { newValue in
                            dataManager.preferences.includeRedFlaggedProgramsInRankList = newValue
                            dataManager.savePreferences()
                        }
                    )) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                Text("Include Red Flagged Programs in Rank List")
                                    .font(.arial(size: 15, weight: .medium))
                            }
                            Text("When enabled, programs with red flags will appear at the bottom of your rank list")
                                .font(.arial(size: 13))
                                .foregroundColor(.secondary)
                        }
                    }
        } header: {
            MatchlyFormSectionHeader(title: "Questionnaire")
        }
    }
    
    private var calendarSection: some View {
        Section {
                    Toggle(isOn: Binding(
                        get: { dataManager.preferences.enableCalendarSync },
                        set: { newValue in
                            dataManager.preferences.enableCalendarSync = newValue
                            dataManager.savePreferences()
                        }
                    )) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Image(systemName: "calendar.badge.plus")
                                    .foregroundColor(.blue)
                                Text("Sync Interviews to Calendar")
                                    .font(.arial(size: 15, weight: .medium))
                            }
                            Text("Automatically add interview dates to your device calendar")
                                .font(.arial(size: 13))
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    MatchlyFormSectionHeader(title: "Calendar")
                } footer: {
                    Text("When enabled, your interview dates will be synced to a \"Matchly Interviews\" calendar in your device calendar app. You can sync interviews from the Interviews page.")
                }
    }
    
    private var dataManagementSection: some View {
        Section {
                    NavigationLink(destination: DataBackupView()) {
                        HStack {
                            Image(systemName: "icloud.fill")
                                .foregroundColor(.blue)
                            Text("Backup & Sync")
                        }
                    }
                    
                    
                    Button(role: .destructive, action: {
                        showResetAlert = true
                    }) {
                        Text("Reset All Data")
                    }
                    .buttonStyle(.glass)
        } header: {
            MatchlyFormSectionHeader(title: "Data Management")
        }
    }
    
    private var accountSection: some View {
        Section {
                    if BiometricAuthManager.shared.canAuthenticate {
                        Toggle(isOn: biometricLoginBinding) {
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Use \(authManager.biometricDisplayName)")
                                    Text("Unlock Matchly and sign in faster on this device.")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            } icon: {
                                Image(systemName: BiometricAuthManager.shared.kind.systemImageName)
                            }
                        }
                    }

                    if let user = authManager.currentUser {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Signed in as")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Text(authManager.preferredDisplayName(profileName: dataManager.preferences.profile.name))
                                .font(.arial(size: 15, weight: .medium))

                            if let email = user.email, !email.isEmpty,
                               authManager.preferredDisplayName(profileName: dataManager.preferences.profile.name) != email {
                                Text(email)
                                    .font(.arial(size: 13))
                                    .foregroundColor(.secondary)
                            } else if let phone = user.phoneNumber,
                                      authManager.preferredDisplayName(profileName: dataManager.preferences.profile.name) != phone {
                                Text(phone)
                                    .font(.arial(size: 13))
                                    .foregroundColor(.secondary)
                            }
                            
                            Text("via \(user.provider.rawValue.capitalized)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }

                    if authManager.currentUser != nil {
                        if authManager.hasPasswordProvider {
                            Label("Email login enabled", systemImage: "checkmark.seal.fill")
                                .foregroundColor(.secondary)
                        } else {
                            Button {
                                showLinkEmailPassword = true
                            } label: {
                                Text("Add Email & Password")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.glassProminent)
                            .tint(AppColors.primaryBlue)
                            .listRowBackground(Color.clear)
                        }
                    }
                    
                    Button(role: .destructive, action: {
                        showSignOutAlert = true
                    }) {
                        HStack {
                            Image(systemName: "arrow.right.square")
                            Text("Sign Out")
                        }
                    }
                    .buttonStyle(.glass)
        } header: {
            MatchlyFormSectionHeader(title: "Account")
        }
    }
    
    private var biometricLoginBinding: Binding<Bool> {
        Binding(
            get: { authManager.isBiometricLoginEnabled },
            set: { enabled in
                if enabled {
                    Task { @MainActor in
                        do {
                            let success = try await BiometricAuthManager.shared.authenticate(
                                reason: "Enable \(authManager.biometricDisplayName) for Matchly"
                            )
                            if success {
                                authManager.enableBiometricLogin()
                            }
                        } catch {
                            authManager.disableBiometricLogin()
                        }
                    }
                } else {
                    authManager.disableBiometricLogin()
                }
            }
        )
    }

    private func resetAllData() {
        dataManager.programs = []
        dataManager.preferences = UserPreferences()
        dataManager.savePrograms()
        dataManager.savePreferences()
    }
}

#Preview {
    SettingsView()
        .environmentObject(DataManager.shared)
}

