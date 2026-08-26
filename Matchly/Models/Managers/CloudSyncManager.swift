//
//  CloudSyncManager.swift
//  Matchly
//
//  Created on 11/14/25.
//

import Foundation
import Combine
import OSLog

extension Notification.Name {
    static let matchlyCloudDataDidChange = Notification.Name("matchlyCloudDataDidChange")
}

struct CloudSyncPayload {
    let programs: [Program]?
    let preferences: UserPreferences?
    let programsUpdatedAt: Date?
    let preferencesUpdatedAt: Date?
}

enum CloudSyncMergeOutcome: Equatable {
    case noChange
    case pulledPrograms
    case pulledPreferences
    case pulledBoth
    case pushedLocal
}

class CloudSyncManager: ObservableObject {
    static let shared = CloudSyncManager()
    
    @Published var isSyncing: Bool = false
    @Published var lastSyncDate: Date?
    @Published var syncError: String?
    
    private let store = NSUbiquitousKeyValueStore.default
    private let programsKey = "cloud_programs"
    private let preferencesKey = "cloud_preferences"
    private let programsUpdatedAtKey = "cloud_programs_updated_at"
    private let preferencesUpdatedAtKey = "cloud_preferences_updated_at"
    private static let logger = Logger(subsystem: "com.matchly", category: "CloudSyncManager")
    
    private init() {
        // Listen for iCloud changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(cloudDataChanged),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: store
        )
    }
    
    // MARK: - iCloud Sync
    
    func syncToCloud(programs: [Program], preferences: UserPreferences) {
        syncToCloud(
            programs: programs,
            preferences: preferences,
            programsUpdatedAt: Date(),
            preferencesUpdatedAt: Date()
        )
    }

    func syncToCloud(
        programs: [Program],
        preferences: UserPreferences,
        programsUpdatedAt: Date,
        preferencesUpdatedAt: Date
    ) {
        uploadToCloud(
            programs: programs,
            preferences: preferences,
            programsUpdatedAt: programsUpdatedAt,
            preferencesUpdatedAt: preferencesUpdatedAt
        )
    }

    func syncProgramsToCloud(
        programs: [Program],
        preferences: UserPreferences,
        programsUpdatedAt: Date
    ) {
        let existingPreferencesUpdatedAt = date(forKey: preferencesUpdatedAtKey) ?? programsUpdatedAt
        uploadToCloud(
            programs: programs,
            preferences: preferences,
            programsUpdatedAt: programsUpdatedAt,
            preferencesUpdatedAt: existingPreferencesUpdatedAt
        )
    }

    func syncPreferencesToCloud(
        programs: [Program],
        preferences: UserPreferences,
        preferencesUpdatedAt: Date
    ) {
        let existingProgramsUpdatedAt = date(forKey: programsUpdatedAtKey) ?? preferencesUpdatedAt
        uploadToCloud(
            programs: programs,
            preferences: preferences,
            programsUpdatedAt: existingProgramsUpdatedAt,
            preferencesUpdatedAt: preferencesUpdatedAt
        )
    }

    private func uploadToCloud(
        programs: [Program],
        preferences: UserPreferences,
        programsUpdatedAt: Date,
        preferencesUpdatedAt: Date
    ) {
        DispatchQueue.main.async { [weak self] in
            self?.isSyncing = true
            self?.syncError = nil
        }
        
        // Check if iCloud is available
        guard isCloudAvailable else {
            DispatchQueue.main.async { [weak self] in
                self?.syncError = "iCloud is not available. Please sign in to iCloud in Settings."
                self?.isSyncing = false
            }
            Self.logger.warning("iCloud sync failed: iCloud not available")
            return
        }
        
        do {
            let programsData = try JSONEncoder().encode(programs)
            let preferencesData = try JSONEncoder().encode(preferences)
            
            // Check data sizes (NSUbiquitousKeyValueStore has 1MB limit per key)
            let programsSizeMB = Double(programsData.count) / 1_000_000.0
            let preferencesSizeMB = Double(preferencesData.count) / 1_000_000.0
            
            Self.logger.debug("iCloud sync data sizes: programs=\(String(format: "%.2f", programsSizeMB), privacy: .public) MB (\(programs.count, privacy: .public) programs), preferences=\(String(format: "%.2f", preferencesSizeMB), privacy: .public) MB")
            
            if programsSizeMB > 1.0 {
                DispatchQueue.main.async { [weak self] in
                    self?.syncError = "Programs data is too large (\(String(format: "%.2f", programsSizeMB)) MB). Maximum is 1 MB per key. Consider removing some programs or using export/import instead."
                    self?.isSyncing = false
                }
                Self.logger.warning("iCloud sync failed: Programs data exceeds 1MB limit")
                return
            }
            
            if preferencesSizeMB > 1.0 {
                DispatchQueue.main.async { [weak self] in
                    self?.syncError = "Preferences data is too large (\(String(format: "%.2f", preferencesSizeMB)) MB). Maximum is 1 MB per key."
                    self?.isSyncing = false
                }
                Self.logger.warning("iCloud sync failed: Preferences data exceeds 1MB limit")
                return
            }
            
            // Store data
            store.set(programsData, forKey: programsKey)
            store.set(preferencesData, forKey: preferencesKey)
            store.set(programsUpdatedAt.timeIntervalSince1970, forKey: programsUpdatedAtKey)
            store.set(preferencesUpdatedAt.timeIntervalSince1970, forKey: preferencesUpdatedAtKey)
            
            // Synchronize (this is synchronous but should be quick)
            let syncResult = store.synchronize()
            
            if syncResult {
                DispatchQueue.main.async { [weak self] in
                    self?.lastSyncDate = Date()
                }
                Self.logger.info("Successfully synced to iCloud: \(programs.count, privacy: .public) programs, \(String(format: "%.2f", programsSizeMB + preferencesSizeMB), privacy: .public) MB total")
            } else {
                DispatchQueue.main.async { [weak self] in
                    self?.syncError = "Failed to synchronize with iCloud. The data may be too large or iCloud may be unavailable."
                }
                Self.logger.warning("iCloud sync failed: synchronize() returned false")
            }
        } catch {
            DispatchQueue.main.async { [weak self] in
                self?.syncError = "Failed to encode data: \(error.localizedDescription)"
                self?.isSyncing = false
            }
            Self.logger.error("iCloud sync error: \(error.localizedDescription, privacy: .public)")
            return
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.isSyncing = false
        }
    }
    
    /// Loads the latest iCloud snapshot without blocking the main thread.
    /// `NSUbiquitousKeyValueStore.synchronize()` can take several seconds on a cold launch.
    func loadFromCloudAsync() async -> CloudSyncPayload {
        guard isCloudAvailable else {
            Self.logger.warning("Cannot load from iCloud: iCloud not available")
            return emptyCloudPayload
        }

        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async { [weak self] in
                guard let self else {
                    continuation.resume(returning: CloudSyncPayload(
                        programs: nil,
                        preferences: nil,
                        programsUpdatedAt: nil,
                        preferencesUpdatedAt: nil
                    ))
                    return
                }
                self.store.synchronize()
                continuation.resume(returning: self.readCloudPayloadFromStore())
            }
        }
    }

    func loadFromCloud() -> CloudSyncPayload {
        guard isCloudAvailable else {
            Self.logger.warning("Cannot load from iCloud: iCloud not available")
            return emptyCloudPayload
        }
        store.synchronize()
        return readCloudPayloadFromStore()
    }

    private var emptyCloudPayload: CloudSyncPayload {
        CloudSyncPayload(programs: nil, preferences: nil, programsUpdatedAt: nil, preferencesUpdatedAt: nil)
    }

    private func readCloudPayloadFromStore() -> CloudSyncPayload {
        let programs = decodePrograms(from: store.data(forKey: programsKey))
        let preferences = decodePreferences(from: store.data(forKey: preferencesKey))
        let programsUpdatedAt = date(forKey: programsUpdatedAtKey)
        let preferencesUpdatedAt = date(forKey: preferencesUpdatedAtKey)

        if programs == nil && preferences == nil {
            Self.logger.info("No iCloud data found (this is normal for first-time users)")
        } else {
            Self.logger.info("Loaded cloud snapshot: programs=\(programs?.count ?? 0, privacy: .public)")
        }

        return CloudSyncPayload(
            programs: programs,
            preferences: preferences,
            programsUpdatedAt: programsUpdatedAt,
            preferencesUpdatedAt: preferencesUpdatedAt
        )
    }

    private func decodePrograms(from data: Data?) -> [Program]? {
        guard let data else { return nil }
        return try? JSONDecoder().decode([Program].self, from: data)
    }

    private func decodePreferences(from data: Data?) -> UserPreferences? {
        guard let data else { return nil }
        return try? JSONDecoder().decode(UserPreferences.self, from: data)
    }

    private func date(forKey key: String) -> Date? {
        let interval = store.double(forKey: key)
        guard interval > 0 else { return nil }
        return Date(timeIntervalSince1970: interval)
    }
    
    @objc private func cloudDataChanged(_ notification: Notification) {
        // Handle external iCloud changes
        // Get change reason (using raw integer values since enum is not available in Swift)
        if let userInfo = notification.userInfo,
           let reason = userInfo[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int {
            Self.logger.info("Cloud data changed externally. Reason: \(self.reasonDescription(for: reason), privacy: .public)")
        } else {
            Self.logger.info("Cloud data changed externally")
        }
        
        // Notify the app to merge newer cloud data into the local store.
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .matchlyCloudDataDidChange, object: nil)
        }
    }
    
    private func reasonDescription(for reason: Int) -> String {
        // NSUbiquitousKeyValueStoreChangeReason enum values:
        // 0 = NSUbiquitousKeyValueStoreServerChange
        // 1 = NSUbiquitousKeyValueStoreInitialSyncChange
        // 2 = NSUbiquitousKeyValueStoreQuotaViolationChange
        // 3 = NSUbiquitousKeyValueStoreAccountChange
        switch reason {
        case 0:
            return "Server change (data updated from another device)"
        case 1:
            return "Initial sync"
        case 2:
            return "Quota violation (data too large)"
        case 3:
            return "Account change"
        default:
            return "Unknown reason (\(reason))"
        }
    }
    
    var isCloudAvailable: Bool {
        let available = FileManager.default.ubiquityIdentityToken != nil
        if !available {
            Self.logger.warning("iCloud not available - user may not be signed in or iCloud Drive may be disabled")
        }
        return available
    }
    
    // Diagnostic function to check iCloud status
    func checkCloudStatus() -> String {
        if !isCloudAvailable {
            return "iCloud is not available. Please:\n1. Sign in to iCloud in Settings\n2. Enable iCloud Drive\n3. Make sure the app has iCloud capability enabled"
        }
        
        // Check if we can access the store
        store.synchronize()
        
        let hasPrograms = store.data(forKey: programsKey) != nil
        let hasPreferences = store.data(forKey: preferencesKey) != nil
        
        var status = "iCloud is available ✓\n\n"
        status += "Programs in cloud: \(hasPrograms ? "Yes" : "No")\n"
        status += "Preferences in cloud: \(hasPreferences ? "Yes" : "No")\n\n"
        
        if let lastSync = lastSyncDate {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .full
            status += "Last sync: \(formatter.localizedString(for: lastSync, relativeTo: Date()))"
        } else {
            status += "Last sync: Never"
        }
        
        if let programsUpdatedAt = date(forKey: programsUpdatedAtKey) {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .full
            status += "\nPrograms updated: \(formatter.localizedString(for: programsUpdatedAt, relativeTo: Date()))"
        }

        if let preferencesUpdatedAt = date(forKey: preferencesUpdatedAtKey) {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .full
            status += "\nPreferences updated: \(formatter.localizedString(for: preferencesUpdatedAt, relativeTo: Date()))"
        }

        // Check data sizes if available
        if let programsData = store.data(forKey: programsKey) {
            let sizeMB = Double(programsData.count) / 1_000_000.0
            status += "\n\nPrograms data size: \(String(format: "%.2f", sizeMB)) MB"
            if sizeMB > 1.0 {
                status += " ⚠️ (exceeds 1MB limit)"
            }
        }
        
        if let preferencesData = store.data(forKey: preferencesKey) {
            let sizeMB = Double(preferencesData.count) / 1_000_000.0
            status += "\nPreferences data size: \(String(format: "%.2f", sizeMB)) MB"
            if sizeMB > 1.0 {
                status += " ⚠️ (exceeds 1MB limit)"
            }
        }
        
        return status
    }
}

