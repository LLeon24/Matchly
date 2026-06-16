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
    @ObservedObject private var cloudSync = CloudSyncManager.shared
    @State private var showExportSheet = false
    @State private var showImportPicker = false
    @State private var showImportSuccess = false
    @State private var showImportError = false
    @State private var importErrorMessage = ""
    @State private var showCloudSyncAlert = false
    
    var body: some View {
        Form {
            Section {
                // iCloud Sync Status
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: cloudSync.isCloudAvailable ? "icloud.fill" : "icloud.slash")
                                .foregroundColor(cloudSync.isCloudAvailable ? .blue : .gray)
                            Text("iCloud Sync")
                                .font(.arial(size: 17, weight: .medium))
                        }
                        
                        if cloudSync.isCloudAvailable {
                            if let lastSync = cloudSync.lastSyncDate {
                                Text("Last synced: \(lastSync, style: .relative)")
                                    .font(.arial(size: 13))
                                    .foregroundColor(.secondary)
                            } else {
                                Text("Not yet synced")
                                    .font(.arial(size: 13))
                                    .foregroundColor(.secondary)
                            }
                            
                            if let error = cloudSync.syncError {
                                Text(error)
                                    .font(.arial(size: 12))
                                    .foregroundColor(.red)
                                    .lineLimit(3)
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("iCloud not available")
                                    .font(.arial(size: 13))
                                    .foregroundColor(.secondary)
                                Text("Sign in to iCloud in Settings")
                                    .font(.arial(size: 12))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    if cloudSync.isCloudAvailable {
                        Button(action: {
                            syncToCloud()
                        }) {
                            if cloudSync.isSyncing {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Text("Sync Now")
                                    .font(.arial(size: 15, weight: .medium))
                                    .foregroundColor(.blue)
                            }
                        }
                        .disabled(cloudSync.isSyncing)
                    }
                }
                .padding(.vertical, 4)
                .glassPanelStyle(cornerRadius: 14)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowBackground(Color.clear)
            } header: {
                Text("Cloud Backup")
            } footer: {
                if cloudSync.isCloudAvailable {
                    Text("Your data will be automatically synced across all your devices signed in to the same iCloud account.")
                } else {
                    Text("Enable iCloud in Settings > [Your Name] > iCloud to sync your data across devices.")
                }
            }
            
            Section {
                Button(action: {
                    exportData()
                }) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(.blue)
                        Text("Export All Data")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Button(action: {
                    showImportPicker = true
                }) {
                    HStack {
                        Image(systemName: "square.and.arrow.down")
                            .foregroundColor(.blue)
                        Text("Import Data")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text("Local Backup")
            } footer: {
                Text("Export your data as a JSON file to save a backup or transfer to another device.")
            }
            
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Programs")
                        Spacer()
                        Text("\(dataManager.programs.count)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Profile")
                        Spacer()
                        Text(dataManager.preferences.profile.name.isEmpty ? "Not set" : "Set")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Specialties")
                        Spacer()
                        Text("\(dataManager.preferences.specialties.count)")
                            .foregroundColor(.secondary)
                    }
                }
                .font(.arial(size: 15))
                .glassPanelStyle(cornerRadius: 14)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowBackground(Color.clear)
            } header: {
                Text("Data Summary")
            }
            
            Section {
                Button(action: {
                    // Show diagnostic info
                    let status = cloudSync.checkCloudStatus()
                    showCloudSyncAlert = true
                    importErrorMessage = status
                }) {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                        Text("iCloud Status & Diagnostics")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text("Troubleshooting")
            } footer: {
                Text("If sync isn't working, check the diagnostics above. Common issues: not signed into iCloud, data too large (>1MB), or iCloud Drive disabled.")
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
        ) { result in
            handleExportResult(result)
        }
        .fileImporter(
            isPresented: $showImportPicker,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            handleImportResult(result)
        }
        .alert("Import Successful", isPresented: $showImportSuccess) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("Your data has been imported successfully. The app will reload.")
        }
        .alert("Import Error", isPresented: $showImportError) {
            Button("OK") { }
        } message: {
            Text(importErrorMessage)
        }
        .alert("Cloud Sync", isPresented: $showCloudSyncAlert) {
            Button("OK") { }
        } message: {
            Text(importErrorMessage.isEmpty ? (cloudSync.syncError ?? "Data synced successfully to iCloud") : importErrorMessage)
        }
    }
    
    private func syncToCloud() {
        cloudSync.syncToCloud(programs: dataManager.programs, preferences: dataManager.preferences)
        if cloudSync.syncError != nil {
            showCloudSyncAlert = true
        }
    }
    
    private func exportData() {
        showExportSheet = true
    }
    
    private func exportDataJSON() -> Data {
        let exportData = MatchlyExportData(
            programs: dataManager.programs,
            preferences: dataManager.preferences,
            exportDate: Date(),
            version: "1.0.0"
        )
        
        if let jsonData = try? JSONEncoder().encode(exportData) {
            return jsonData
        }
        return Data()
    }
    
    private func handleExportResult(_ result: Result<URL, Error>) {
        // Export completed (success or failure handled by system)
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
                
                // Validate data
                guard !importData.programs.isEmpty || !importData.preferences.specialties.isEmpty else {
                    importErrorMessage = "The imported file appears to be empty or invalid."
                    showImportError = true
                    return
                }
                
                // Import data
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
        return FileWrapper(regularFileWithContents: data)
    }
}

#Preview {
    MatchlyNavigationView {
        DataBackupView()
            .environmentObject(DataManager.shared)
    }
}

