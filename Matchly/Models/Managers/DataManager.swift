//
//  DataManager.swift
//  Matchly
//
//  Created by Leoh N. Leon II on 11/14/25.
//

import Foundation
import Combine
import OSLog
import WidgetKit
#if canImport(UIKit)
import UIKit
#endif

class DataManager: ObservableObject {
    static let shared = DataManager()

    enum AddProgramResult {
        case added
        case duplicate
    }
    
    @Published var programs: [Program] = []
    @Published var preferences: UserPreferences = UserPreferences()
    @Published var lastAddProgramNotice: String?
    
    private let programsKey = "saved_programs"
    private let preferencesKey = "user_preferences"
    private let localProgramsUpdatedAtKey = "local_programs_updated_at"
    private let localPreferencesUpdatedAtKey = "local_preferences_updated_at"
    private let cloudSync = CloudSyncManager.shared
    private let accountCloudSync = AccountCloudSyncManager.shared
    private static let logger = Logger(subsystem: "com.matchly", category: "DataManager")
    private var cancellables = Set<AnyCancellable>()
    private var isApplyingRemoteCloudSnapshot = false
    private var isApplyingAccountCloudSnapshot = false
    private var accountCloudPushWorkItem: DispatchWorkItem?
    private var cloudMergeWorkItem: DispatchWorkItem?
    private var lastCloudMergeAt: Date?
    private var lastAccountCloudMergeAt: Date?
    private let manualRankOrderKey = "manual_rank_order"
    private static let cloudMergeDebounce: TimeInterval = 45
    
    // Performance optimization: Debounce save operations
    private var saveProgramsWorkItem: DispatchWorkItem?
    private var savePreferencesWorkItem: DispatchWorkItem?
    private let saveQueue = DispatchQueue(label: "com.matchly.save", qos: .utility)
    
    // Cache for score calculations.
    // Accessed from the main thread and background queues, so all reads/writes
    // must go through `cacheLock` to avoid a data race.
    private var scoreCache: [String: Double] = [:]
    private var lastPreferencesHash: Int = 0
    private let cacheLock = NSLock()
    
    // MARK: - Thread-safe score cache helpers
    private func cachedScore(forKey key: String) -> Double? {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        return scoreCache[key]
    }
    
    private func setCachedScore(_ value: Double, forKey key: String) {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        scoreCache[key] = value
    }
    
    private func clearScoreCache() {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        scoreCache.removeAll()
    }
    
    /// Clears the cache if the preferences hash changed. Returns the current hash.
    @discardableResult
    private func invalidateCacheIfPreferencesChanged() -> Int {
        let currentHash = preferences.hashValue
        cacheLock.lock()
        defer { cacheLock.unlock() }
        if currentHash != lastPreferencesHash {
            scoreCache.removeAll()
            lastPreferencesHash = currentHash
        }
        return currentHash
    }

    /// Cache key must include questionnaire ratings — otherwise an early save (e.g. interview
    /// date with no survey answers) caches 0 and blocks recalculation after the survey is done.
    private func scoreCacheKey(for program: Program, preferencesHash: Int) -> String {
        var ratingsHasher = Hasher()
        for section in program.questionnaire.sections + program.questionnaire.customSections {
            for item in section.items {
                ratingsHasher.combine(item.id)
                ratingsHasher.combine(item.programRating)
            }
        }
        return "\(program.id)-\(program.emr ?? "")-\(preferencesHash)-\(ratingsHasher.finalize())"
    }
    
    init() {
        loadData()
        publishWidgetSnapshot()
        bootstrapLocalSyncTimestampsIfNeeded()
        observeCatalogReadiness()
        observeCloudSyncTriggers()
        validateAndSanitizeSignals()
        // Defer cloud sync so the first frame can render from local storage.
        scheduleCloudMerge(trigger: "launch", delay: 1.25)
        scheduleAccountCloudMerge(trigger: "launch", delay: 1.75)
    }

    private func observeCloudSyncTriggers() {
        NotificationCenter.default.publisher(for: .matchlyCloudDataDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.scheduleCloudMerge(trigger: "icloud-external", delay: 0.5)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.scheduleCloudMerge(trigger: "foreground", delay: 0.75)
                self?.scheduleAccountCloudMerge(trigger: "foreground", delay: 1.0)
            }
            .store(in: &cancellables)
    }

    private func scheduleCloudMerge(trigger: String, delay: TimeInterval) {
        cloudMergeWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            Task { await self?.mergeWithCloudIfNeeded(trigger: trigger) }
        }
        cloudMergeWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func scheduleAccountCloudMerge(trigger: String, delay: TimeInterval) {
        let work = DispatchWorkItem { [weak self] in
            Task { await self?.mergeWithAccountCloudIfNeeded(trigger: trigger) }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func shouldDebounceCloudMerge(trigger: String) -> Bool {
        guard trigger != "launch" else { return false }
        guard let lastCloudMergeAt else { return false }
        return Date().timeIntervalSince(lastCloudMergeAt) < Self.cloudMergeDebounce
    }

    private func shouldDebounceAccountCloudMerge(trigger: String) -> Bool {
        guard trigger != "launch" else { return false }
        guard let lastAccountCloudMergeAt else { return false }
        return Date().timeIntervalSince(lastAccountCloudMergeAt) < Self.cloudMergeDebounce
    }

    private func observeCatalogReadiness() {
        ResidencyProgramDatabase.shared.$isReady
            .filter { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshSavedProgramsFromCatalog()
            }
            .store(in: &cancellables)
    }
    
    func savePrograms() {
        // Cancel previous save operation
        saveProgramsWorkItem?.cancel()
        
        // Create new save operation with debounce (0.5 seconds)
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            do {
                let encoded = try JSONEncoder().encode(self.programs)
                UserDefaults.standard.set(encoded, forKey: self.programsKey)
                if !self.isApplyingRemoteCloudSnapshot {
                    self.touchLocalProgramsTimestamp()
                }

                // Auto-sync to iCloud if available (async to avoid blocking)
                if self.cloudSync.isCloudAvailable, !self.isApplyingRemoteCloudSnapshot {
                    let snapshot = self.programs
                    let prefs = self.preferences
                    let updatedAt = self.localProgramsUpdatedAt ?? Date()
                    DispatchQueue.global(qos: .utility).async {
                        self.cloudSync.syncProgramsToCloud(
                            programs: snapshot,
                            preferences: prefs,
                            programsUpdatedAt: updatedAt
                        )
                    }
                }
                if !self.isApplyingAccountCloudSnapshot {
                    self.scheduleAccountCloudPush()
                }
                self.scheduleCoupleCloudPublish()
            } catch {
                Self.logger.error("Error saving programs: \(error.localizedDescription, privacy: .public)")
            }
        }
        
        saveProgramsWorkItem = workItem
        saveQueue.asyncAfter(deadline: .now() + 0.5, execute: workItem)
    }
    
    // Immediate save without debounce - use for critical updates like saving questionnaire
    func saveProgramsImmediately() {
        // Cancel any pending debounced save
        saveProgramsWorkItem?.cancel()
        
        // Save immediately
        do {
            let encoded = try JSONEncoder().encode(programs)
            UserDefaults.standard.set(encoded, forKey: programsKey)
            if !isApplyingRemoteCloudSnapshot {
                touchLocalProgramsTimestamp()
            }

            // Auto-sync to iCloud if available (async to avoid blocking)
            if cloudSync.isCloudAvailable, !isApplyingRemoteCloudSnapshot {
                let snapshot = programs
                let prefs = preferences
                let updatedAt = localProgramsUpdatedAt ?? Date()
                DispatchQueue.global(qos: .utility).async { [weak self] in
                    self?.cloudSync.syncProgramsToCloud(
                        programs: snapshot,
                        preferences: prefs,
                        programsUpdatedAt: updatedAt
                    )
                }
            }
            if !isApplyingAccountCloudSnapshot {
                scheduleAccountCloudPush()
            }
            scheduleCoupleCloudPublish()
        } catch {
            Self.logger.error("Error saving programs immediately: \(error.localizedDescription, privacy: .public)")
        }
    }
    
    func loadPrograms() {
        if let data = UserDefaults.standard.data(forKey: programsKey) {
            do {
                let decoded = try JSONDecoder().decode([Program].self, from: data)
                programs = decoded
            } catch {
                Self.logger.error("Error loading programs: \(error.localizedDescription, privacy: .public)")
                // Keep local empty; deferred cloud merge may restore programs later.
            }
        }
    }
    
    func updateDashboardCustomization(layout: DashboardLayout, dashboardPreferences: DashboardPreferences) {
        var updated = preferences
        updated.dashboardLayout = layout
        updated.dashboardPreferences = dashboardPreferences
        preferences = updated
        savePreferences()
    }
    
    func savePreferences() {
        // Cancel previous save operation
        savePreferencesWorkItem?.cancel()
        
        // Create new save operation with debounce (0.5 seconds)
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            do {
                let encoded = try JSONEncoder().encode(self.preferences)
                UserDefaults.standard.set(encoded, forKey: self.preferencesKey)

                // Invalidate score cache when preferences change
                self.clearScoreCache()
                if !self.isApplyingRemoteCloudSnapshot {
                    self.touchLocalPreferencesTimestamp()
                }

                // Auto-sync to iCloud if available (async to avoid blocking)
                if self.cloudSync.isCloudAvailable, !self.isApplyingRemoteCloudSnapshot {
                    let snapshot = self.programs
                    let prefs = self.preferences
                    let updatedAt = self.localPreferencesUpdatedAt ?? Date()
                    DispatchQueue.global(qos: .utility).async {
                        self.cloudSync.syncPreferencesToCloud(
                            programs: snapshot,
                            preferences: prefs,
                            preferencesUpdatedAt: updatedAt
                        )
                    }
                }
                if !self.isApplyingAccountCloudSnapshot {
                    self.scheduleAccountCloudPush()
                }
                self.scheduleCoupleCloudPublish()
            } catch {
                Self.logger.error("Error saving preferences: \(error.localizedDescription, privacy: .public)")
            }
        }
        
        savePreferencesWorkItem = workItem
        saveQueue.asyncAfter(deadline: .now() + 0.5, execute: workItem)
    }
    
    func loadPreferences() {
        if let data = UserDefaults.standard.data(forKey: preferencesKey) {
            do {
                let decoded = try JSONDecoder().decode(UserPreferences.self, from: data)
                preferences = decoded
            } catch {
                Self.logger.error("Error loading preferences: \(error.localizedDescription, privacy: .public)")
                // Keep local defaults; deferred cloud merge may restore preferences later.
            }
        }
        applyInterviewPrepListMigrationIfNeeded(persist: true)
    }

    @discardableResult
    private func applyInterviewPrepListMigrationIfNeeded(persist: Bool) -> Bool {
        var prefs = preferences
        guard prefs.migrateInterviewPrepCuratedListsIfNeeded() else { return false }
        preferences = prefs
        if persist {
            persistPreferencesToDisk()
        }
        Self.logger.info("Migrated interview prep question lists to explicit add-only model")
        return true
    }

    /// Fills empty profile name fields from Apple/Google/email auth display names.
    /// Pass `authEmail` when called from auth flows so we never touch `AuthManager.shared` during singleton init.
    @MainActor
    func applyAuthDisplayNameToProfileIfNeeded(_ displayName: String?, authEmail: String? = nil) {
        guard let displayName = displayName?.trimmingCharacters(in: .whitespacesAndNewlines),
              !displayName.isEmpty else { return }
        guard !AuthManager.isEmailDerivedDisplayName(displayName, email: authEmail) else {
            return
        }

        let split = UserProfile.splitLegacyName(displayName)
        var profile = preferences.profile
        var changed = false

        if profile.firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !split.first.isEmpty {
            profile.firstName = split.first
            changed = true
        }
        if profile.lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !split.last.isEmpty {
            profile.lastName = split.last
            changed = true
        }

        guard changed else { return }
        preferences.profile = profile
        savePreferences()
        objectWillChange.send()
        Self.logger.info("Applied auth display name to profile")
    }

    /// Removes profile names that were incorrectly copied from an email prefix (e.g. "Lleon").
    @MainActor
    func clearEmailDerivedProfileNameIfNeeded(email: String?) {
        guard let email else { return }
        var profile = preferences.profile
        var changed = false

        let first = profile.firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let last = profile.lastName.trimmingCharacters(in: .whitespacesAndNewlines)

        if AuthManager.isEmailDerivedDisplayName(first, email: email) {
            profile.firstName = ""
            changed = true
        }
        if !last.isEmpty, AuthManager.isEmailDerivedDisplayName(profile.name, email: email) {
            profile.lastName = ""
            changed = true
        }

        guard changed else { return }
        preferences.profile = profile
        savePreferences()
        objectWillChange.send()
        Self.logger.info("Cleared email-derived profile name")
    }
    
    func loadData() {
        loadPrograms()
        deduplicateProgramsByID()
        deduplicateSavedPrograms()
        loadPreferences()
        DispatchQueue.main.async { [weak self] in
            self?.recalculateAllScores()
        }
    }

    /// Removes duplicate program IDs (keeps the first entry). Prevents SwiftUI `ForEach` and
    /// `Dictionary(uniqueKeysWithValues:)` crashes when cloud sync merges stale snapshots.
    private func deduplicateProgramsByID() {
        var seen = Set<String>()
        var unique: [Program] = []
        var removed = 0
        for program in programs {
            if seen.contains(program.id) {
                removed += 1
            } else {
                seen.insert(program.id)
                unique.append(program)
            }
        }
        guard removed > 0 else { return }
        programs = unique
        savePrograms()
        Self.logger.info("Removed \(removed, privacy: .public) duplicate program ID(s)")
    }

    /// Removes duplicate saved programs, keeping the earliest entry for each ACGME listing.
    private func deduplicateSavedPrograms() {
        var unique: [Program] = []
        var removed = 0
        for program in programs {
            if ProgramIdentity.isDuplicate(program, in: unique) {
                removed += 1
            } else {
                unique.append(program)
            }
        }
        guard removed > 0 else { return }
        programs = unique
        savePrograms()
        Self.logger.info("Removed \(removed, privacy: .public) duplicate saved program(s)")
    }
    
    private func bootstrapLocalSyncTimestampsIfNeeded() {
        if localProgramsUpdatedAt == nil, !programs.isEmpty {
            touchLocalProgramsTimestamp()
        }
        if localPreferencesUpdatedAt == nil, hasMeaningfulLocalPreferences {
            touchLocalPreferencesTimestamp()
        }
    }

    private var hasMeaningfulLocalPreferences: Bool {
        !preferences.specialties.isEmpty || !preferences.profile.name.isEmpty
    }

    private var localProgramsUpdatedAt: Date? {
        storedDate(forKey: localProgramsUpdatedAtKey)
    }

    private var localPreferencesUpdatedAt: Date? {
        storedDate(forKey: localPreferencesUpdatedAtKey)
    }

    private func storedDate(forKey key: String) -> Date? {
        let interval = UserDefaults.standard.double(forKey: key)
        guard interval > 0 else { return nil }
        return Date(timeIntervalSince1970: interval)
    }

    private func touchLocalProgramsTimestamp(_ date: Date = Date()) {
        UserDefaults.standard.set(date.timeIntervalSince1970, forKey: localProgramsUpdatedAtKey)
    }

    private func touchLocalPreferencesTimestamp(_ date: Date = Date()) {
        UserDefaults.standard.set(date.timeIntervalSince1970, forKey: localPreferencesUpdatedAtKey)
    }

    private func setLocalProgramsTimestamp(_ date: Date) {
        UserDefaults.standard.set(date.timeIntervalSince1970, forKey: localProgramsUpdatedAtKey)
    }

    private func setLocalPreferencesTimestamp(_ date: Date) {
        UserDefaults.standard.set(date.timeIntervalSince1970, forKey: localPreferencesUpdatedAtKey)
    }

    @MainActor
    @discardableResult
    func mergeWithCloudIfNeeded(trigger: String) async -> CloudSyncMergeOutcome {
        guard cloudSync.isCloudAvailable, !isApplyingRemoteCloudSnapshot else { return .noChange }
        guard !shouldDebounceCloudMerge(trigger: trigger) else { return .noChange }

        let cloud = await cloudSync.loadFromCloudAsync()
        lastCloudMergeAt = Date()

        let localProgramsAt = localProgramsUpdatedAt ?? .distantPast
        let localPreferencesAt = localPreferencesUpdatedAt ?? .distantPast
        let cloudProgramsAt = cloud.programsUpdatedAt ?? .distantPast
        let cloudPreferencesAt = cloud.preferencesUpdatedAt ?? .distantPast

        var pulledPrograms = false
        var pulledPreferences = false
        var pushedLocal = false

        if cloud.programs != nil {
            if programs.isEmpty || cloudProgramsAt > localProgramsAt {
                pulledPrograms = true
            } else if localProgramsAt > cloudProgramsAt {
                cloudSync.syncProgramsToCloud(
                    programs: programs,
                    preferences: preferences,
                    programsUpdatedAt: localProgramsAt
                )
                pushedLocal = true
            }
        } else if !programs.isEmpty, localProgramsAt > .distantPast {
            cloudSync.syncProgramsToCloud(
                programs: programs,
                preferences: preferences,
                programsUpdatedAt: localProgramsAt
            )
            pushedLocal = true
        }

        if cloud.preferences != nil {
            if !hasMeaningfulLocalPreferences || cloudPreferencesAt > localPreferencesAt {
                pulledPreferences = true
            } else if localPreferencesAt > cloudPreferencesAt {
                cloudSync.syncPreferencesToCloud(
                    programs: programs,
                    preferences: preferences,
                    preferencesUpdatedAt: localPreferencesAt
                )
                pushedLocal = true
            }
        } else if hasMeaningfulLocalPreferences {
            cloudSync.syncPreferencesToCloud(
                programs: programs,
                preferences: preferences,
                preferencesUpdatedAt: localPreferencesAt
            )
            pushedLocal = true
        }

        guard pulledPrograms || pulledPreferences else {
            if pushedLocal {
                Self.logger.info("Pushed newer local data to iCloud (\(trigger, privacy: .public))")
            }
            return pushedLocal ? .pushedLocal : .noChange
        }

        isApplyingRemoteCloudSnapshot = true
        defer { isApplyingRemoteCloudSnapshot = false }

        if pulledPrograms, let cloudPrograms = cloud.programs {
            programs = cloudPrograms
            persistProgramsToDisk()
            setLocalProgramsTimestamp(cloudProgramsAt == .distantPast ? Date() : cloudProgramsAt)
            deduplicateProgramsByID()
            deduplicateSavedPrograms()
        }

        if pulledPreferences, let cloudPreferences = cloud.preferences {
            preferences = cloudPreferences
            applyInterviewPrepListMigrationIfNeeded(persist: false)
            persistPreferencesToDisk()
            setLocalPreferencesTimestamp(cloudPreferencesAt == .distantPast ? Date() : cloudPreferencesAt)
        }

        recalculateAllScores()
        objectWillChange.send()
        Self.logger.info("Applied iCloud merge (\(trigger, privacy: .public)): programs=\(pulledPrograms, privacy: .public), preferences=\(pulledPreferences, privacy: .public)")

        switch (pulledPrograms, pulledPreferences) {
        case (true, true): return .pulledBoth
        case (true, false): return .pulledPrograms
        case (false, true): return .pulledPreferences
        case (false, false): return .noChange
        }
    }

    // MARK: - Account Cloud (Firestore) Sync

    func scheduleAccountCloudPush() {
        guard accountCloudSync.isSignedIn, !isApplyingAccountCloudSnapshot else { return }

        accountCloudPushWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                await self.pushAccountCloudBackup()
            }
        }
        accountCloudPushWorkItem = workItem
        saveQueue.asyncAfter(deadline: .now() + 0.75, execute: workItem)
    }

    @MainActor
    private func pushAccountCloudBackup() async {
        guard accountCloudSync.isSignedIn, !isApplyingAccountCloudSnapshot else { return }

        let programsJSON = try? JSONEncoder().encode(programs)
        let preferencesJSON = try? JSONEncoder().encode(preferences)
        let manualRankOrder = UserDefaults.standard.array(forKey: manualRankOrderKey) as? [String]

        await accountCloudSync.push(
            programsJSON: programsJSON,
            preferencesJSON: preferencesJSON,
            manualRankOrder: manualRankOrder,
            programsUpdatedAt: localProgramsUpdatedAt,
            preferencesUpdatedAt: localPreferencesUpdatedAt
        )
    }

    @discardableResult
    func mergeWithAccountCloudIfNeeded(trigger: String) async -> Bool {
        guard accountCloudSync.isSignedIn, !isApplyingAccountCloudSnapshot else { return false }
        guard !shouldDebounceAccountCloudMerge(trigger: trigger) else { return false }

        guard let backup = await accountCloudSync.pull() else { return false }
        lastAccountCloudMergeAt = Date()

        let localProgramsAt = localProgramsUpdatedAt ?? .distantPast
        let localPreferencesAt = localPreferencesUpdatedAt ?? .distantPast
        let remoteProgramsAt = backup.programsUpdatedAt ?? .distantPast
        let remotePreferencesAt = backup.preferencesUpdatedAt ?? .distantPast

        var pulledSomething = false
        var shouldPush = false

        await MainActor.run {
            self.isApplyingAccountCloudSnapshot = true
        }

        if let programsJSON = backup.programsJSON,
           let remotePrograms = try? JSONDecoder().decode([Program].self, from: programsJSON) {
            if await MainActor.run(body: { self.programs.isEmpty }) || remoteProgramsAt > localProgramsAt {
                await MainActor.run {
                    self.programs = remotePrograms
                    self.persistProgramsToDisk()
                    self.setLocalProgramsTimestamp(remoteProgramsAt == .distantPast ? Date() : remoteProgramsAt)
                    self.deduplicateProgramsByID()
                    self.deduplicateSavedPrograms()
                }
                pulledSomething = true
            } else if localProgramsAt > remoteProgramsAt {
                shouldPush = true
            }
        } else if !(await MainActor.run(body: { self.programs.isEmpty })) {
            shouldPush = true
        }

        if let preferencesJSON = backup.preferencesJSON,
           let remotePreferences = try? JSONDecoder().decode(UserPreferences.self, from: preferencesJSON) {
            let meaningful = await MainActor.run(body: { self.hasMeaningfulLocalPreferences })
            if !meaningful || remotePreferencesAt > localPreferencesAt {
                await MainActor.run {
                    self.preferences = remotePreferences
                    self.applyInterviewPrepListMigrationIfNeeded(persist: false)
                    self.persistPreferencesToDisk()
                    self.setLocalPreferencesTimestamp(remotePreferencesAt == .distantPast ? Date() : remotePreferencesAt)
                }
                pulledSomething = true
            } else if localPreferencesAt > remotePreferencesAt {
                shouldPush = true
            }
        } else if await MainActor.run(body: { self.hasMeaningfulLocalPreferences }) {
            shouldPush = true
        }

        if let remoteOrder = backup.manualRankOrder, !remoteOrder.isEmpty {
            let localOrder = UserDefaults.standard.array(forKey: manualRankOrderKey) as? [String] ?? []
            if localOrder.isEmpty || remoteProgramsAt >= localProgramsAt {
                UserDefaults.standard.set(remoteOrder, forKey: manualRankOrderKey)
            } else {
                shouldPush = true
            }
        } else if UserDefaults.standard.array(forKey: manualRankOrderKey) != nil {
            shouldPush = true
        }

        if pulledSomething {
            await MainActor.run {
                self.recalculateAllScores()
                self.objectWillChange.send()
            }
            Self.logger.info("Applied account cloud merge (\(trigger, privacy: .public))")
        }

        await MainActor.run {
            self.isApplyingAccountCloudSnapshot = false
        }

        let emptyRemote = backup.programsJSON == nil && backup.preferencesJSON == nil
        if shouldPush || (!pulledSomething && emptyRemote) {
            await pushAccountCloudBackup()
        }

        return pulledSomething || shouldPush
    }

    private func persistProgramsToDisk() {
        guard let encoded = try? JSONEncoder().encode(programs) else { return }
        UserDefaults.standard.set(encoded, forKey: programsKey)
        publishWidgetSnapshot()
    }

    // MARK: - Widget Snapshot

    /// Shared with MatchlyWidgetExtension via the App Group container.
    static let widgetAppGroupID = "group.com.lleonmd.Matchly"
    static let widgetInterviewsKey = "widget_upcoming_interviews"

    /// Publishes upcoming interviews (today onward) as plain plist values so the
    /// widget can render without sharing any model code with the app.
    func publishWidgetSnapshot() {
        guard let shared = UserDefaults(suiteName: Self.widgetAppGroupID) else { return }

        let today = Calendar.current.startOfDay(for: Date())
        let upcoming: [[String: Any]] = programs
            .compactMap { program -> (Date, [String: Any])? in
                guard let date = program.interviewDate, date >= today else { return nil }
                let title = HospitalNameFormatter.format(
                    program.hospital.isEmpty ? (program.name.isEmpty ? "Program" : program.name) : program.hospital
                )
                var subtitleParts: [String] = []
                if !program.specialty.isEmpty {
                    subtitleParts.append(SpecialtyFormatter.abbreviation(for: program.specialty))
                }
                if program.hasDisplayLocation {
                    subtitleParts.append(program.displayCityState)
                }
                let entry: [String: Any] = [
                    "id": program.id,
                    "title": title,
                    "subtitle": subtitleParts.joined(separator: " • "),
                    "date": date.timeIntervalSince1970
                ]
                return (date, entry)
            }
            .sorted { $0.0 < $1.0 }
            .prefix(10)
            .map(\.1)

        shared.set(upcoming, forKey: Self.widgetInterviewsKey)
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func persistPreferencesToDisk() {
        guard let encoded = try? JSONEncoder().encode(preferences) else { return }
        UserDefaults.standard.set(encoded, forKey: preferencesKey)
        clearScoreCache()
    }
    
    @discardableResult
    func addProgram(_ program: Program) -> AddProgramResult {
        if ProgramIdentity.isDuplicate(program, in: programs) {
            lastAddProgramNotice = "This program is already in your list."
            return .duplicate
        }

        var newProgram = program
        newProgram.finalScore = newProgram.questionnaire.totalWeightedScore(preferences: preferences, programEMR: newProgram.emr)
        
        programs.append(newProgram)
        savePrograms()
        objectWillChange.send()
        return .added
    }

    /// Updates mailing address and catalog metadata for saved programs when the bundled catalog improves.
    func refreshSavedProgramsFromCatalog() {
        let database = ResidencyProgramDatabase.shared
        guard database.isReady else { return }

        var changed = false
        for index in programs.indices {
            guard let accreditationID = programs[index].accreditationID?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !accreditationID.isEmpty,
                  let catalogProgram = database.program(withAccreditationID: accreditationID)
            else { continue }

            var updated = programs[index]
            let before = catalogSnapshot(updated)
            CatalogProgramMapper.applyCatalogInfo(catalogProgram, to: &updated)
            let after = catalogSnapshot(updated)
            if before != after {
                updated.finalScore = updated.questionnaire.totalWeightedScore(
                    preferences: preferences,
                    programEMR: updated.emr
                )
                programs[index] = updated
                changed = true
            }
        }

        if changed {
            savePrograms()
            objectWillChange.send()
        }
    }

    private func catalogSnapshot(_ program: Program) -> (String?, String, String, String, String) {
        (
            program.address,
            program.city,
            program.state,
            program.hospital,
            program.specialty
        )
    }
    
    func updateProgram(_ program: Program) {
        guard let index = programs.firstIndex(where: { $0.id == program.id }) else { return }
        
        var updatedProgram = program
        updatedProgram.finalScore = updatedProgram.questionnaire.totalWeightedScore(
            preferences: preferences,
            programEMR: updatedProgram.emr
        )

        let cacheKey = scoreCacheKey(for: updatedProgram, preferencesHash: preferences.hashValue)
        setCachedScore(updatedProgram.finalScore, forKey: cacheKey)
        
        // Ensure we're on main thread for UI updates
        if Thread.isMainThread {
            programs[index] = updatedProgram
            savePrograms()
            // Explicitly trigger update to ensure all views refresh immediately
            objectWillChange.send()
        } else {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.programs[index] = updatedProgram
                self.savePrograms()
                self.objectWillChange.send()
            }
        }
    }
    
    func deleteProgram(_ program: Program) {
        VoiceMemoStorage.deleteMemo(reference: program.voiceMemoURL)
        programs.removeAll { $0.id == program.id }
        savePrograms()
    }
    
    func recalculateAllScores() {
        // Check if preferences changed (invalidate cache) - thread-safe
        let currentHash = invalidateCacheIfPreferencesChanged()
        
        // Perform score calculation on background thread for better performance
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            var updated = false
            var updatedPrograms = self.programs
            
            for index in updatedPrograms.indices {
                let program = updatedPrograms[index]
                
                let cacheKey = self.scoreCacheKey(for: program, preferencesHash: currentHash)
                let newScore: Double
                if let cachedScore = self.cachedScore(forKey: cacheKey) {
                    newScore = cachedScore
                } else {
                    newScore = program.questionnaire.totalWeightedScore(preferences: self.preferences, programEMR: program.emr)
                    self.setCachedScore(newScore, forKey: cacheKey)
                }
                
                if program.finalScore != newScore {
                    var updatedProgram = program
                    updatedProgram.finalScore = newScore
                    updatedPrograms[index] = updatedProgram
                    updated = true
                }
            }
            
            // Update on main thread
            DispatchQueue.main.async {
                if updated {
                    self.programs = updatedPrograms
                    self.savePrograms()
                }
            }
        }
    }
    
    func recalculateAllProgramScores() {
        recalculateAllScores()
    }
    
    func getRankedPrograms() -> [Program] {
        programs.filter { $0.finalScore > 0 }.sorted { $0.finalScore > $1.finalScore }
    }
    
    // MARK: - Couples Matching
    
    func generateCouplesRankList(partnerPrograms: [CoupleProgramSnapshot]) -> [CouplesRankPair] {
        let prefs = preferences.couplesPreferences
        guard let couple = preferences.couple,
              let myRecord = AuthManager.shared.cloudKitUserRecordName else { return [] }

        let myScored = getRankedPrograms().filter { $0.isReviewed || $0.finalScore > 0 }
        let partnerScored = partnerPrograms.filter { $0.finalScore > 0 }
        let mySnapshots = Program.rankedSnapshots(from: myScored)
        guard !mySnapshots.isEmpty, !partnerScored.isEmpty else { return [] }

        let user1Programs: [CoupleProgramSnapshot]
        let user2Programs: [CoupleProgramSnapshot]
        if myRecord == couple.user1ID {
            user1Programs = mySnapshots
            user2Programs = partnerScored
        } else {
            user1Programs = partnerScored
            user2Programs = mySnapshots
        }

        return CouplesRankEngine.generateRankList(
            user1Programs: user1Programs,
            user2Programs: user2Programs,
            preferences: prefs
        )
    }

    func scheduleCoupleCloudPublish() {
        guard FeatureFlags.couplesMatchEnabled else { return }
        guard preferences.couple?.isLinked == true else { return }
        Task { @MainActor in
            try? await CoupleSyncCoordinator.shared.publishOwnData(dataManager: self)
        }
    }

    func startCoupleSyncIfNeeded() {
        guard FeatureFlags.couplesMatchEnabled else {
            Task { @MainActor in
                CoupleSyncCoordinator.shared.stopMonitoring()
            }
            return
        }
        Task { @MainActor in
            await CoupleSyncCoordinator.shared.startMonitoringIfNeeded(dataManager: self)
        }
    }
    
    func validateCouplesRankList() -> (isValid: Bool, errors: [String]) {
        var errors: [String] = []
        let pairs = preferences.couplesRankPairs.sorted { $0.rank < $1.rank }
        guard let couple = preferences.couple else {
            return (false, ["Link with your partner before validating a couples rank list."])
        }
        
        for (index, pair) in pairs.enumerated() {
            if pair.rank != index + 1 {
                errors.append("Rank #\(index + 1) is missing or out of order")
            }
        }
        
        for pair in pairs {
            if !pair.user1NoMatch && pair.user1ProgramID == nil {
                errors.append("Rank #\(pair.rank): \(couple.user1Name)'s program is not set")
            }
            if !pair.user2NoMatch && pair.user2ProgramID == nil {
                let partnerLabel = couple.user2Name ?? "Partner"
                errors.append("Rank #\(pair.rank): \(partnerLabel)'s program is not set")
            }
        }
        
        let user1ProgramIDs = pairs.compactMap { $0.user1ProgramID }
        let user2ProgramIDs = pairs.compactMap { $0.user2ProgramID }
        
        if Set(user1ProgramIDs).count != user1ProgramIDs.count {
            errors.append("\(couple.user1Name) has duplicate programs in the rank list")
        }
        if Set(user2ProgramIDs).count != user2ProgramIDs.count {
            let partnerLabel = couple.user2Name ?? "Partner"
            errors.append("\(partnerLabel) has duplicate programs in the rank list")
        }
        
        return (errors.isEmpty, errors)
    }
    
    // MARK: - Signal Tracking

    struct SignalBudgetSummary: Identifiable {
        let id: String
        let displayName: String
        let isTiered: Bool
        let goldUsed: Int
        let goldLimit: Int
        let silverUsed: Int
        let silverLimit: Int
        let usesResidencyCAS: Bool
        let requiresSignalStatement: Bool

        var goldRemaining: Int { max(0, goldLimit - goldUsed) }
        var silverRemaining: Int { max(0, silverLimit - silverUsed) }
        var totalRemaining: Int {
            isTiered ? goldRemaining + silverRemaining : goldRemaining
        }
    }

    func relevantSignalBuckets() -> [String] {
        var buckets = Set(
            programs.map { SignalLimits.signalBucket(for: $0.specialty, accreditationID: $0.accreditationID) }
        )
        for specialty in preferences.specialties {
            let bucket = SignalLimits.signalBucket(for: specialty)
            if SignalLimits.participatesInSignaling(for: specialty) {
                buckets.insert(bucket)
            }
        }
        return buckets
            .filter { SignalLimits.participatesInSignaling(for: $0) }
            .sorted()
    }

    func signalBudgetSummaries() -> [SignalBudgetSummary] {
        relevantSignalBuckets().map { bucket in
            let usage = getSignalUsage(for: bucket)
            let config = SignalLimits.configuration(for: bucket)
            return SignalBudgetSummary(
                id: bucket,
                displayName: bucket,
                isTiered: config.isTiered,
                goldUsed: usage.goldUsed,
                goldLimit: usage.goldLimit,
                silverUsed: usage.silverUsed,
                silverLimit: usage.silverLimit,
                usesResidencyCAS: config.usesResidencyCAS,
                requiresSignalStatement: config.requiresSignalStatement
            )
        }
    }

    func sanitizedSignalType(
        _ type: SignalType,
        specialty: String,
        accreditationID: String? = nil
    ) -> SignalType {
        let config = SignalLimits.configuration(for: specialty, accreditationID: accreditationID)
        guard config.participates else { return .none }
        switch type {
        case .none:
            return .none
        case .silver:
            return config.isTiered ? .silver : .none
        case .gold:
            return .gold
        }
    }

    func validateAndSanitizeSignals() {
        var changed = false
        for index in programs.indices {
            let program = programs[index]
            guard program.signalType != .none else { continue }
            let sanitized = sanitizedSignalType(
                program.signalType,
                specialty: program.specialty,
                accreditationID: program.accreditationID
            )
            if sanitized != program.signalType || (sanitized == .none && program.signalNote != nil) {
                programs[index].signalType = sanitized
                if sanitized == .none {
                    programs[index].signalNote = nil
                }
                changed = true
            }
        }
        if changed {
            savePrograms()
            objectWillChange.send()
        }
    }

    private func programsInSignalBucket(
        for specialty: String,
        accreditationID: String? = nil,
        excludingProgramId: String? = nil
    ) -> [Program] {
        let bucket = SignalLimits.signalBucket(for: specialty, accreditationID: accreditationID)
        var matches = programs.filter {
            SignalLimits.signalBucket(for: $0.specialty, accreditationID: $0.accreditationID) == bucket
        }
        if let excludingProgramId {
            matches = matches.filter { $0.id != excludingProgramId }
        }
        return matches
    }
    
    func getSignalCounts(for specialty: String, accreditationID: String? = nil) -> (gold: Int, silver: Int) {
        let specialtyPrograms = programsInSignalBucket(for: specialty, accreditationID: accreditationID)
        let goldCount = specialtyPrograms.filter { $0.signalType == .gold }.count
        let silverCount = specialtyPrograms.filter { $0.signalType == .silver }.count
        return (gold: goldCount, silver: silverCount)
    }
    
    func canAssignSignal(
        type: SignalType,
        specialty: String,
        excludingProgramId: String? = nil,
        accreditationID: String? = nil
    ) -> (canAssign: Bool, reason: String?) {
        let config = SignalLimits.configuration(for: specialty, accreditationID: accreditationID)
        guard config.participates else {
            return (false, "Program signaling isn't tracked for \(specialty) in Matchly.")
        }

        let isTiered = config.isTiered
        let limits = (gold: config.goldLimit, silver: config.silverLimit)
        
        let specialtyPrograms = programsInSignalBucket(
            for: specialty,
            accreditationID: accreditationID,
            excludingProgramId: excludingProgramId
        )
        
        let goldCount = specialtyPrograms.filter { $0.signalType == .gold }.count
        let silverCount = specialtyPrograms.filter { $0.signalType == .silver }.count
        
        switch type {
        case .none:
            return (true, nil)
        case .gold:
            if isTiered {
                // Tiered: check gold limit
                if goldCount >= limits.gold {
                    return (false, "You've reached the limit of \(limits.gold) gold signals for \(specialty)")
                }
            } else {
                // Single-level: check total limit (stored in gold)
                let totalCount = goldCount + silverCount // For single-level, only gold is used, but check both
                if totalCount >= limits.gold {
                    return (false, "You've reached the limit of \(limits.gold) signals for \(specialty)")
                }
            }
            return (true, nil)
        case .silver:
            if isTiered {
                // Tiered: check silver limit
                if silverCount >= limits.silver {
                    return (false, "You've reached the limit of \(limits.silver) silver signals for \(specialty)")
                }
            } else {
                // Single-level: silver should not be used
                return (false, "This specialty uses single-level signals, not silver")
            }
            return (true, nil)
        }
    }
    
    func getSignalUsage(for specialty: String, accreditationID: String? = nil) -> (goldUsed: Int, goldLimit: Int, silverUsed: Int, silverLimit: Int) {
        let config = SignalLimits.configuration(for: specialty, accreditationID: accreditationID)
        guard config.participates else {
            return (goldUsed: 0, goldLimit: 0, silverUsed: 0, silverLimit: 0)
        }

        let isTiered = config.isTiered
        let limits = (gold: config.goldLimit, silver: config.silverLimit)
        let counts = getSignalCounts(for: specialty, accreditationID: accreditationID)
        
        if isTiered {
            return (goldUsed: counts.gold, goldLimit: limits.gold, silverUsed: counts.silver, silverLimit: limits.silver)
        } else {
            // Single-level: gold represents total signals
            let totalUsed = counts.gold + counts.silver // For single-level, only gold should be used
            return (goldUsed: totalUsed, goldLimit: limits.gold, silverUsed: 0, silverLimit: 0)
        }
    }
}

