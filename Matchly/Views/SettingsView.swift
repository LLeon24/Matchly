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
    @StateObject private var authManager = AuthManager.shared
    @State private var showResetAlert = false
    @State private var showSignOutAlert = false
    @State private var showSpecialtyChange = false
    @State private var showWeights = false
    @State private var showERASImport = false
    @State private var showImportSuccess = false
    @State private var showImportError = false
    @State private var importErrorMessage = ""
    
    var body: some View {
        NavigationView {
            Form {
                profileSection
                appInformationSection
                couplesMatchingSection
                questionnaireSection
                calendarSection
                dataManagementSection
                accountSection
                
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    Text("Matchly helps medical students organize residency interview information and generate personalized rank lists.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.bottom, 90) // Space for custom tab bar
            .navigationTitle("Settings")
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
                Text("Are you sure you want to sign out? You'll need to sign in again to access your data.")
            }
            .sheet(isPresented: $showSpecialtyChange) {
                SpecialtySelectionView()
            }
            .fileImporter(
                isPresented: $showERASImport,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                handleERASImport(result: result)
            }
            .alert("Import Successful", isPresented: $showImportSuccess) {
                Button("OK") { }
            } message: {
                Text("ERAS 2026 data has been imported successfully. The app will restart to load the new data.")
            }
            .alert("Import Error", isPresented: $showImportError) {
                Button("OK") { }
            } message: {
                Text(importErrorMessage)
            }
        }
    }
    
    private var profileSection: some View {
        Section("Profile") {
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
                                        .font(.system(size: 24))
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
                                    .font(.system(size: 17, weight: .medium))
                                    .foregroundColor(.primary)
                                
                                if let aamcID = dataManager.preferences.profile.aamcID, !aamcID.isEmpty {
                                    Text("AAMC ID: \(aamcID)")
                                        .font(.system(size: 13))
                                        .foregroundColor(.secondary)
                                } else {
                                    Text("Tap to edit profile")
                                        .font(.system(size: 13))
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                }
    }
    
    private var appInformationSection: some View {
        Section("App Information") {
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
                    }
                }
    }
    
    private var couplesMatchingSection: some View {
        Section("Couples Matching") {
                    if let couple = dataManager.preferences.couple {
                        if couple.isLinked {
                            NavigationLink(destination: CouplesMatchingView()) {
                                HStack {
                                    Image(systemName: "person.2.fill")
                                        .foregroundColor(.blue)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Linked with \(couple.user2Name ?? "Partner")")
                                            .font(.system(size: 15, weight: .medium))
                                        Text("Active")
                                            .font(.system(size: 12))
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
                                            .font(.system(size: 15, weight: .medium))
                                        Text("Code: \(couple.coupleCode)")
                                            .font(.system(size: 12))
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
                }
    }
    
    private var questionnaireSection: some View {
        Section("Questionnaire") {
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
                                    .font(.system(size: 17, weight: .medium))
                            }
                            Text("When enabled, programs with red flags will appear at the bottom of your rank list")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                    }
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
                                    .font(.system(size: 17, weight: .medium))
                            }
                            Text("Automatically add interview dates to your device calendar")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Calendar")
                } footer: {
                    Text("When enabled, your interview dates will be synced to a \"Matchly Interviews\" calendar in your device calendar app. You can sync interviews from the Interviews page.")
                }
    }
    
    private var dataManagementSection: some View {
        Section("Data Management") {
                    NavigationLink(destination: DataBackupView()) {
                        HStack {
                            Image(systemName: "icloud.fill")
                                .foregroundColor(.blue)
                            Text("Backup & Sync")
                        }
                    }
                    
                    Button(action: {
                        showERASImport = true
                    }) {
                        HStack {
                            Text("Import ERAS 2026 Data")
                            Spacer()
                            Image(systemName: "square.and.arrow.down")
                                .foregroundColor(.blue)
                        }
                    }
                    
                    Button(role: .destructive, action: {
                        showResetAlert = true
                    }) {
                        Text("Reset All Data")
                    }
                }
    }
    
    private var accountSection: some View {
        Section("Account") {
                    if let user = authManager.currentUser {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Signed in as")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            // Prioritize displayName if available, then email, then phone
                            if let displayName = user.displayName, !displayName.isEmpty {
                                Text(displayName)
                                    .font(.system(size: 15, weight: .medium))
                                if let email = user.email, !email.isEmpty {
                                    Text(email)
                                        .font(.system(size: 13))
                                        .foregroundColor(.secondary)
                                } else if let phone = user.phoneNumber {
                                    Text(phone)
                                        .font(.system(size: 13))
                                        .foregroundColor(.secondary)
                                }
                            } else if let email = user.email, !email.isEmpty {
                                Text(email)
                                    .font(.system(size: 15, weight: .medium))
                            } else if let phone = user.phoneNumber {
                                Text(phone)
                                    .font(.system(size: 15, weight: .medium))
                            } else {
                                Text("User")
                                    .font(.system(size: 15, weight: .medium))
                            }
                            
                            Text("via \(user.provider.rawValue.capitalized)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                    
                    Button(role: .destructive, action: {
                        showSignOutAlert = true
                    }) {
                        HStack {
                            Image(systemName: "arrow.right.square")
                            Text("Sign Out")
                        }
                    }
                }
    }
    
    private func handleERASImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            
            // Access the file
            _ = url.startAccessingSecurityScopedResource()
            defer { url.stopAccessingSecurityScopedResource() }
            
            do {
                let data = try Data(contentsOf: url)
                try ResidencyProgramDatabase.shared.replaceWithERASData(data: data)
                showImportSuccess = true
            } catch {
                importErrorMessage = "Failed to import ERAS data: \(error.localizedDescription)"
                showImportError = true
            }
            
        case .failure(let error):
            importErrorMessage = "Failed to access file: \(error.localizedDescription)"
            showImportError = true
        }
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

