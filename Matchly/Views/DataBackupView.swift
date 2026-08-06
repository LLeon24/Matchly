//
//  DataBackupView.swift
//  Matchly
//
//  Created on 11/14/25.
//

import SwiftUI
import UniformTypeIdentifiers

struct DataBackupView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var accountCloudSync = AccountCloudSyncManager.shared
    @ObservedObject private var authManager = AuthManager.shared
    @State private var showExportSheet = false
    @State private var showImportPicker = false
    @State private var showImportSuccess = false
    @State private var showImportError = false
    @State private var importErrorMessage = ""
    @State private var showSyncAlert = false
    @State private var syncAlertMessage = ""

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: accountCloudSync.isSignedIn ? "checkmark.icloud.fill" : "icloud.slash")
                            .foregroundColor(accountCloudSync.isSignedIn ? AppColors.primaryBlue : .secondary)
                        Text("Cloud Backup")
                            .font(.arial(size: 17, weight: .semibold))
                        Spacer()
                        if accountCloudSync.isSyncing {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }

                    Text(statusLine)
                        .font(.arial(size: 13))
                        .foregroundColor(.secondary)

                    if let error = accountCloudSync.syncError {
                        Text(error)
                            .font(.arial(size: 12))
                            .foregroundColor(.red)
                    }

                    if accountCloudSync.isSignedIn {
                        Button("Sync Now") {
                            Task { await syncAccountCloud() }
                        }
                        .buttonStyle(.glassProminent)
                        .tint(AppColors.primaryBlue)
                        .disabled(accountCloudSync.isSyncing)
                    }
                }
                .padding(.vertical, 6)
                .listRowBackground(Color.clear)
            } header: {
                MatchlyFormSectionHeader(title: "Cloud Backup")
            } footer: {
                Text("Backs up your programs and settings to your Matchly account. Works the same for Apple, Google, and email sign-in.")
            }

            Section {
                Button {
                    showExportSheet = true
                } label: {
                    Label("Export Backup File", systemImage: "square.and.arrow.up")
                }

                Button {
                    showImportPicker = true
                } label: {
                    Label("Import Backup File", systemImage: "square.and.arrow.down")
                }
            } header: {
                MatchlyFormSectionHeader(title: "File Backup")
            } footer: {
                Text("Optional. Save a JSON file on this device or share it elsewhere.")
            }

            Section {
                labeledRow("Programs", "\(dataManager.programs.count)")
                labeledRow("Profile", dataManager.preferences.profile.name.isEmpty ? "Not set" : "Set")
                labeledRow("Specialties", "\(dataManager.preferences.specialties.count)")
            } header: {
                MatchlyFormSectionHeader(title: "On This Device")
            }
        }
        .scrollContentBackground(.hidden)
        .appCanvasBackground()
        .navigationTitle("Backup & Sync")
        .navigationBarTitleDisplayMode(.inline)
        .fileExporter(
            isPresented: $showExportSheet,
            document: MatchlyDataDocument(data: exportDataJSON()),
            contentType: .json,
            defaultFilename: "Matchly_Backup_\(dateFormatter.string(from: Date())).json"
        ) { _ in }
        .fileImporter(
            isPresented: $showImportPicker,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            handleImportResult(result)
        }
        .alert("Import Successful", isPresented: $showImportSuccess) {
            Button("OK") { dismiss() }
        } message: {
            Text("Your data has been imported successfully.")
        }
        .alert("Import Error", isPresented: $showImportError) {
            Button("OK") { }
        } message: {
            Text(importErrorMessage)
        }
        .alert("Cloud Backup", isPresented: $showSyncAlert) {
            Button("OK") { }
        } message: {
            Text(syncAlertMessage)
        }
    }

    private var statusLine: String {
        if !accountCloudSync.isSignedIn {
            return "Sign in to enable automatic backup."
        }
        if let lastSync = accountCloudSync.lastSyncDate {
            return "Last synced \(lastSync.formatted(.relative(presentation: .named)))"
        }
        let method = authManager.currentUser?.provider.rawValue.capitalized ?? "your account"
        return "Signed in with \(method). Ready to sync."
    }

    private func labeledRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
        .font(.arial(size: 15))
    }

    private func syncAccountCloud() async {
        let changed = await dataManager.mergeWithAccountCloudIfNeeded(trigger: "manual")
        if let error = accountCloudSync.syncError {
            syncAlertMessage = error
        } else if changed {
            syncAlertMessage = "Synced with your Matchly account."
        } else if !accountCloudSync.isSignedIn {
            syncAlertMessage = "Sign in to enable cloud backup."
        } else {
            syncAlertMessage = "Already up to date."
        }
        showSyncAlert = true
    }

    private func exportDataJSON() -> Data {
        let exportData = MatchlyExportData(
            programs: dataManager.programs,
            preferences: dataManager.preferences,
            exportDate: Date(),
            version: "1.0.0"
        )
        return (try? JSONEncoder().encode(exportData)) ?? Data()
    }

    private func handleImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            _ = url.startAccessingSecurityScopedResource()
            defer { url.stopAccessingSecurityScopedResource() }

            do {
                let data = try Data(contentsOf: url)
                let importData = try JSONDecoder().decode(MatchlyExportData.self, from: data)
                guard !importData.programs.isEmpty || !importData.preferences.specialties.isEmpty else {
                    importErrorMessage = "The imported file appears to be empty or invalid."
                    showImportError = true
                    return
                }
                dataManager.programs = importData.programs
                dataManager.preferences = importData.preferences
                dataManager.savePrograms()
                dataManager.savePreferences()
                dataManager.recalculateAllScores()
                showImportSuccess = true
            } catch {
                importErrorMessage = "Failed to import data: \(error.localizedDescription)"
                showImportError = true
            }

        case .failure(let error):
            importErrorMessage = "Failed to access file: \(error.localizedDescription)"
            showImportError = true
        }
    }

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        return formatter
    }
}

// MARK: - Export Data Model
struct MatchlyExportData: Codable {
    let programs: [Program]
    let preferences: UserPreferences
    let exportDate: Date
    let version: String
}

// MARK: - Document for File Export
struct MatchlyDataDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

#Preview {
    MatchlyNavigationView {
        DataBackupView()
            .environmentObject(DataManager.shared)
    }
}
