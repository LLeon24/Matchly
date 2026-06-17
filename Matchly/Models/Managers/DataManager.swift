//
//  DataManager.swift
//  Matchly
//
//  Created by Leoh N. Leon II on 11/14/25.
//

import Foundation
import Combine
import OSLog

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
    private let cloudSync = CloudSyncManager.shared
    private static let logger = Logger(subsystem: "com.matchly", category: "DataManager")
    private var cancellables = Set<AnyCancellable>()
    
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
        loadFromCloudIfAvailable()
        observeCatalogReadiness()
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
                
                // Auto-sync to iCloud if available (async to avoid blocking)
                if self.cloudSync.isCloudAvailable {
                    DispatchQueue.global(qos: .utility).async {
                        self.cloudSync.syncToCloud(programs: self.programs, preferences: self.preferences)
                    }
                }
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
            
            // Auto-sync to iCloud if available (async to avoid blocking)
            if cloudSync.isCloudAvailable {
                DispatchQueue.global(qos: .utility).async { [weak self] in
                    guard let self = self else { return }
                    self.cloudSync.syncToCloud(programs: self.programs, preferences: self.preferences)
                }
            }
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
                // Try to load from iCloud as backup
                if let cloudData = cloudSync.loadFromCloud().programs {
                    programs = cloudData
                    Self.logger.info("Loaded programs from iCloud backup")
                }
            }
        }
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
                
                // Auto-sync to iCloud if available (async to avoid blocking)
                if self.cloudSync.isCloudAvailable {
                    DispatchQueue.global(qos: .utility).async {
                        self.cloudSync.syncToCloud(programs: self.programs, preferences: self.preferences)
                    }
                }
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
                // Try to load from iCloud as backup
                if let cloudData = cloudSync.loadFromCloud().preferences {
                    preferences = cloudData
                    Self.logger.info("Loaded preferences from iCloud backup")
                }
            }
        }
    }
    
    func loadData() {
        loadPrograms()
        deduplicateSavedPrograms()
        loadPreferences()
        recalculateAllScores()
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
    
    private func loadFromCloudIfAvailable() {
        guard cloudSync.isCloudAvailable else { return }
        
        let cloudData = cloudSync.loadFromCloud()
        
        // Only use cloud data if local data is empty or older
        if programs.isEmpty, let cloudPrograms = cloudData.programs {
            programs = cloudPrograms
            savePrograms()
        }
        
        if preferences.specialties.isEmpty && preferences.profile.name.isEmpty,
           let cloudPreferences = cloudData.preferences {
            preferences = cloudPreferences
            savePreferences()
        }
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
        return programs.sorted { $0.finalScore > $1.finalScore }
    }
    
    // MARK: - Couples Matching
    
    func generateCouplesRankList() -> [CouplesRankPair] {
        // Generate couples rank list based on individual scores and couples preferences
        let user1Programs = getRankedPrograms()
        _ = preferences.couplesPreferences
        
        // This is a simplified algorithm - in reality, this would be more complex
        // and would consider partner's programs, geographic proximity, etc.
        var pairs: [CouplesRankPair] = []
        
        // For now, create pairs based on user1's ranked programs
        // In a real implementation, this would sync with partner's data
        for (index, program) in user1Programs.enumerated() {
            let pair = CouplesRankPair(
                rank: index + 1,
                user1ProgramID: program.id,
                user2ProgramID: nil, // Would be filled from partner's data
                user1NoMatch: false,
                user2NoMatch: false
            )
            pairs.append(pair)
        }
        
        return pairs
    }
    
    func validateCouplesRankList() -> (isValid: Bool, errors: [String]) {
        var errors: [String] = []
        let pairs = preferences.couplesRankPairs.sorted { $0.rank < $1.rank }
        
        // Check that all ranks are sequential
        for (index, pair) in pairs.enumerated() {
            if pair.rank != index + 1 {
                errors.append("Rank #\(index + 1) is missing or out of order")
            }
        }
        
        // Check that each pair has at least one program or "No Match"
        for pair in pairs {
            if !pair.user1NoMatch && pair.user1ProgramID == nil {
                errors.append("Rank #\(pair.rank): Your program is not set")
            }
            if !pair.user2NoMatch && pair.user2ProgramID == nil {
                errors.append("Rank #\(pair.rank): Partner's program is not set")
            }
        }
        
        // Check for duplicate programs
        let user1ProgramIDs = pairs.compactMap { $0.user1ProgramID }
        let user2ProgramIDs = pairs.compactMap { $0.user2ProgramID }
        
        if Set(user1ProgramIDs).count != user1ProgramIDs.count {
            errors.append("You have duplicate programs in your rank list")
        }
        if Set(user2ProgramIDs).count != user2ProgramIDs.count {
            errors.append("Partner has duplicate programs in their rank list")
        }
        
        return (errors.isEmpty, errors)
    }
    
    // MARK: - Signal Tracking
    
    func getSignalCounts(for specialty: String) -> (gold: Int, silver: Int) {
        let specialtyPrograms = programs.filter { $0.specialty == specialty }
        let goldCount = specialtyPrograms.filter { $0.signalType == .gold }.count
        let silverCount = specialtyPrograms.filter { $0.signalType == .silver }.count
        return (gold: goldCount, silver: silverCount)
    }
    
    func canAssignSignal(type: SignalType, specialty: String, excludingProgramId: String? = nil) -> (canAssign: Bool, reason: String?) {
        let isTiered = SignalLimits.isTiered(for: specialty)
        let limits = SignalLimits.limits(for: specialty)
        
        // Get counts excluding the current program (if editing)
        var specialtyPrograms = programs.filter { $0.specialty == specialty }
        if let excludingId = excludingProgramId {
            specialtyPrograms = specialtyPrograms.filter { $0.id != excludingId }
        }
        
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
    
    func getSignalUsage(for specialty: String) -> (goldUsed: Int, goldLimit: Int, silverUsed: Int, silverLimit: Int) {
        let isTiered = SignalLimits.isTiered(for: specialty)
        let limits = SignalLimits.limits(for: specialty)
        let counts = getSignalCounts(for: specialty)
        
        if isTiered {
            return (goldUsed: counts.gold, goldLimit: limits.gold, silverUsed: counts.silver, silverLimit: limits.silver)
        } else {
            // Single-level: gold represents total signals
            let totalUsed = counts.gold + counts.silver // For single-level, only gold should be used
            return (goldUsed: totalUsed, goldLimit: limits.gold, silverUsed: 0, silverLimit: 0)
        }
    }
}

