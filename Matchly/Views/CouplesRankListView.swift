//
//  CouplesRankListView.swift
//  Matchly
//
//  Created on 11/16/25.
//

import SwiftUI

struct CouplesRankListView: View {
    @EnvironmentObject var dataManager: DataManager
    @ObservedObject private var coupleSync = CoupleSyncCoordinator.shared
    @ObservedObject private var authManager = AuthManager.shared
    var embeddedInHub: Bool = false
    @State private var showAddPair = false
    @State private var selectedUser1Program: Program?
    @State private var selectedUser2Program: Program?
    @State private var editingPair: CouplesRankPair?
    @State private var showValidationAlert = false
    @State private var validationErrors: [String] = []
    @State private var showGenerateAlert = false
    @State private var isGenerating = false
    @State private var generateError: String?
    @State private var didAutoGenerateForEmptyList = false
    @State private var showRegenerateConfirm = false
    @Environment(\.editMode) private var editMode
    
    private var sortedPairs: [CouplesRankPair] {
        dataManager.preferences.couplesRankPairs.sorted { $0.rank < $1.rank }
    }
    
    private var myPrograms: [Program] {
        dataManager.getRankedPrograms()
    }

    private var partnerPrograms: [Program] {
        coupleSync.partnerPrograms.map { $0.asProgram() }
    }

    private var myScoredPrograms: [Program] {
        myPrograms.filter { $0.isReviewed || $0.finalScore > 0 }
    }

    private var partnerScoredPrograms: [Program] {
        partnerPrograms.filter { $0.finalScore > 0 }
    }

    private var canGenerateSuggestedList: Bool {
        !myScoredPrograms.isEmpty && !partnerScoredPrograms.isEmpty
    }
    
    private func myProgram(for pair: CouplesRankPair, couple: Couple) -> Program? {
        guard let myRecord = authManager.cloudKitUserRecordName else { return nil }
        guard let programID = CouplesRankPairPerspective.programID(forRecordName: myRecord, in: pair, couple: couple) else {
            return nil
        }
        return myPrograms.first { $0.id == programID }
    }

    private func partnerProgram(for pair: CouplesRankPair, couple: Couple) -> Program? {
        guard let myRecord = authManager.cloudKitUserRecordName else { return nil }
        let partnerRecord = myRecord == couple.user1ID ? couple.user2ID : couple.user1ID
        guard let partnerRecord,
              let programID = CouplesRankPairPerspective.programID(forRecordName: partnerRecord, in: pair, couple: couple) else {
            return nil
        }
        return partnerPrograms.first { $0.id == programID }
    }

    private func myNoMatch(for pair: CouplesRankPair, couple: Couple) -> Bool {
        guard let myRecord = authManager.cloudKitUserRecordName else { return false }
        return CouplesRankPairPerspective.isNoMatch(forRecordName: myRecord, in: pair, couple: couple)
    }

    private func partnerNoMatch(for pair: CouplesRankPair, couple: Couple) -> Bool {
        guard let myRecord = authManager.cloudKitUserRecordName else { return false }
        let partnerRecord = myRecord == couple.user1ID ? couple.user2ID : couple.user1ID
        guard let partnerRecord else { return false }
        return CouplesRankPairPerspective.isNoMatch(forRecordName: partnerRecord, in: pair, couple: couple)
    }

    private func partnerDisplayName(couple: Couple) -> String {
        guard let myRecord = authManager.cloudKitUserRecordName else {
            return couple.user2Name ?? couple.user1Name
        }
        if myRecord == couple.user1ID {
            return couple.user2Name ?? "your partner"
        }
        return couple.user1Name
    }
    
    var body: some View {
        Form {
            if let couple = dataManager.preferences.couple, couple.isLinked {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 4) {
                            Text("Couples Rank List")
                                .font(.arial(size: 15, weight: .semibold))
                            SettingsInfoButton(
                                title: "Couples Rank List",
                                message: "Each rank pairs one of your programs with one of your partner's scored programs, or No Match. Matchly can suggest a starting list — tap any pair to edit, swipe to delete, or use Reorder to adjust before NRMP submission."
                            )
                        }
                        
                        Text("Each rank pairs one of your programs with one of your partner's scored programs (or 'No Match'). Matchly can suggest a starting list — then tap any pair to change it, reorder, add, or delete freely.")
                            .font(.arial(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Instructions")
                }

                if coupleSync.isSyncing && partnerPrograms.isEmpty {
                    Section {
                        HStack {
                            ProgressView()
                            Text("Syncing partner's programs…")
                                .font(.arial(size: 14))
                                .foregroundColor(.secondary)
                        }
                    }
                } else if partnerPrograms.isEmpty {
                    Section {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Your partner's programs haven't synced yet.")
                                .font(.arial(size: 14, weight: .medium))

                            Text("Ask \(partnerDisplayName(couple: couple)) to:")
                                .font(.arial(size: 13))
                                .foregroundColor(.secondary)

                            VStack(alignment: .leading, spacing: 6) {
                                Label("Open Matchly while signed in to iCloud", systemImage: "icloud.fill")
                                Label("Add at least one program under My Programs", systemImage: "list.bullet")
                                Label("Open the Couple tab (pull down to refresh)", systemImage: "arrow.triangle.2.circlepath")
                            }
                            .font(.arial(size: 13))
                            .foregroundColor(.secondary)

                            if let publishError = coupleSync.lastPublishError {
                                Text("Your upload: \(publishError)")
                                    .font(.arial(size: 12))
                                    .foregroundColor(.orange)
                            }
                            if let syncError = coupleSync.lastSyncError {
                                Text("Sync: \(syncError)")
                                    .font(.arial(size: 12))
                                    .foregroundColor(.orange)
                            }
                        }
                        .padding(.vertical, 4)
                    } header: {
                        Text("Partner Programs")
                    }
                } else if partnerScoredPrograms.isEmpty {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("\(partnerDisplayName(couple: couple)) has \(partnerPrograms.count) program\(partnerPrograms.count == 1 ? "" : "s") synced, but none are scored yet.")
                                .font(.arial(size: 14))

                            Text("Ask them to complete questionnaires for at least one program under My Programs.")
                                .font(.arial(size: 13))
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    } header: {
                        Text("Partner Programs")
                    }
                } else {
                    Section {
                        ForEach(Array(partnerScoredPrograms.prefix(5).enumerated()), id: \.element.id) { index, program in
                            HStack {
                                Text("#\(index + 1)")
                                    .font(.arial(size: 12, weight: .bold))
                                    .foregroundColor(.pink)
                                    .frame(width: 24)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(program.hospital.isEmpty ? program.name : program.hospital)
                                        .font(.arial(size: 14, weight: .medium))
                                    Text(program.displayCityState)
                                        .font(.arial(size: 12))
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Text(String(format: "%.1f", program.finalScore))
                                    .font(.arial(size: 13, weight: .semibold))
                                    .foregroundColor(.secondary)
                            }
                        }
                        if partnerScoredPrograms.count > 5 {
                            Text("+ \(partnerScoredPrograms.count - 5) more scored programs")
                                .font(.arial(size: 12))
                                .foregroundColor(.secondary)
                        }
                    } header: {
                        Text("Partner's Scored Programs (\(partnerScoredPrograms.count))")
                    }
                }

                if myScoredPrograms.isEmpty && !partnerPrograms.isEmpty {
                    Section {
                        Text("Score at least one program under My Programs to build your couples rank list.")
                            .font(.arial(size: 14))
                            .foregroundColor(.secondary)
                    } header: {
                        Text("Your Programs")
                    }
                }
                
                if sortedPairs.isEmpty {
                    Section {
                        VStack(spacing: 16) {
                            Image(systemName: canGenerateSuggestedList ? "sparkles" : "list.number")
                                .font(.arial(size: 40))
                                .foregroundColor(.secondary)
                            
                            Text("No Rank Pairs Yet")
                                .font(.arial(size: 17, weight: .semibold))
                            
                            Text(emptyPairsMessage)
                                .font(.arial(size: 14))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            
                            if canGenerateSuggestedList {
                                Button(action: {
                                    generateCouplesRankList()
                                }) {
                                    HStack {
                                        if isGenerating {
                                            ProgressView()
                                                .tint(.white)
                                        }
                                        Text("Generate Suggested List")
                                    }
                                    .font(.arial(size: 16, weight: .semibold))
                                    .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.glassProminent)
                                .tint(AppColors.primaryBlue)
                                .disabled(isGenerating)

                                Button("Add a pair manually") {
                                    showAddPair = true
                                }
                                .font(.arial(size: 14))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    }
                } else {
                    Section {
                        ForEach(sortedPairs) { pair in
                            CouplesRankPairRow(
                                pair: pair,
                                myProgram: myProgram(for: pair, couple: couple),
                                partnerProgram: partnerProgram(for: pair, couple: couple),
                                myNoMatch: myNoMatch(for: pair, couple: couple),
                                partnerNoMatch: partnerNoMatch(for: pair, couple: couple),
                                onTap: {
                                    editingPair = pair
                                    showAddPair = true
                                }
                            )
                        }
                        .onDelete(perform: deletePairs)
                        .onMove(perform: movePairs)
                    } header: {
                        HStack {
                            Text("Rank Pairs (\(sortedPairs.count))")
                            Spacer()
                            Button(action: {
                                validateRankList()
                            }) {
                                Text("Validate")
                                    .font(.arial(size: 12))
                            }
                            Button(editMode?.wrappedValue == .active ? "Done" : "Reorder") {
                                withAnimation {
                                    if editMode?.wrappedValue == .active {
                                        editMode?.wrappedValue = .inactive
                                    } else {
                                        editMode?.wrappedValue = .active
                                    }
                                }
                            }
                            .font(.arial(size: 12))
                        }
                    } footer: {
                        Text("Tap a pair to edit programs or No Match. Swipe left to delete. Use Reorder to drag pairs into NRMP rank order.")
                            .font(.arial(size: 12))
                    }
                }
                
                if !sortedPairs.isEmpty {
                    Section {
                        Button(action: {
                            showAddPair = true
                        }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(.blue)
                                Text("Add Rank Pair")
                            }
                        }

                        if canGenerateSuggestedList {
                            Button(action: {
                                showRegenerateConfirm = true
                            }) {
                                HStack {
                                    if isGenerating {
                                        ProgressView()
                                    } else {
                                        Image(systemName: "sparkles")
                                            .foregroundColor(.blue)
                                    }
                                    Text("Regenerate Suggested List")
                                }
                            }
                            .disabled(isGenerating)
                        }
                    } header: {
                        Text("Edit List")
                    } footer: {
                        Text("Regenerating replaces the whole list with a new suggestion. Manual edits are kept until you regenerate.")
                            .font(.arial(size: 12))
                    }
                }
            } else {
                Section {
                    Text("Please link with your partner first in Couples Matching settings.")
                        .font(.arial(size: 14))
                        .foregroundColor(.secondary)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .matchlyScrollTabBarClearance()
        .appCanvasBackground()
        .navigationTitle(embeddedInHub ? "" : "Couples Rank List")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !sortedPairs.isEmpty {
                EditButton()
            }
        }
        .sheet(isPresented: $showAddPair) {
            AddCouplesRankPairView(
                pair: editingPair,
                couple: dataManager.preferences.couple,
                myRecordName: authManager.cloudKitUserRecordName,
                myPrograms: myPrograms,
                partnerPrograms: partnerPrograms,
                onSave: { pair in
                    if let editing = editingPair {
                        updatePair(editing, with: pair)
                    } else {
                        addPair(pair)
                    }
                    editingPair = nil
                    showAddPair = false
                },
                onCancel: {
                    editingPair = nil
                    showAddPair = false
                }
            )
        }
        .alert("Validation Results", isPresented: $showValidationAlert) {
            Button("OK") { }
        } message: {
            if validationErrors.isEmpty {
                Text("✓ Your couples rank list is valid and ready for submission!")
            } else {
                Text("Please fix the following issues:\n\n" + validationErrors.joined(separator: "\n"))
            }
        }
        .alert("Rank List Generated", isPresented: $showGenerateAlert) {
            Button("Review & Edit") { }
        } message: {
            Text("A suggested list is ready. Tap any pair to change it, swipe to delete, or use Reorder to adjust rank order before submitting to NRMP.")
        }
        .confirmationDialog(
            "Replace your current rank list?",
            isPresented: $showRegenerateConfirm,
            titleVisibility: .visible
        ) {
            Button("Regenerate List", role: .destructive) {
                generateCouplesRankList()
            }
            Button("Keep Current List", role: .cancel) { }
        } message: {
            Text("This replaces all pairs with a new suggestion. Your manual edits will be lost.")
        }
        .alert("Could Not Generate", isPresented: Binding(
            get: { generateError != nil },
            set: { if !$0 { generateError = nil } }
        )) {
            Button("OK") { generateError = nil }
        } message: {
            Text(generateError ?? "")
        }
        .task {
            await coupleSync.refreshAll(dataManager: dataManager)
            tryAutoGenerateIfNeeded()
        }
        .refreshable {
            await coupleSync.refreshAll(dataManager: dataManager)
            tryAutoGenerateIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: .coupleDataDidChange)) { _ in
            tryAutoGenerateIfNeeded()
        }
        .onChange(of: sortedPairs.count) { _, newCount in
            if newCount == 0 {
                didAutoGenerateForEmptyList = false
            }
        }
    }

    private var emptyGenerationMessage: String {
        let prefs = dataManager.preferences.couplesPreferences
        switch prefs.geographyStrictness {
        case .sameCity:
            return """
            No program pairs share the same city. In Couple → Settings, switch geography to \
            "Same State" or "Within Max Distance", or add programs in the same city.
            """
        case .sameState:
            return """
            No program pairs are in the same state. In Couple → Settings, switch geography to \
            "Within Max Distance", or add programs in overlapping states.
            """
        case .withinDistance:
            return """
            No program pairs are within your \(prefs.distanceTolerance)-mile limit. Increase max \
            distance in Couple → Settings, or add programs closer together.
            """
        }
    }

    private var emptyPairsMessage: String {
        if canGenerateSuggestedList {
            return "You and your partner both have scored programs. Generate a suggested list to get started, or add pairs manually."
        }
        if partnerPrograms.isEmpty {
            return "Rank pairs will appear here once your partner's programs sync."
        }
        if myScoredPrograms.isEmpty {
            return "Score your programs first, then Matchly can build your couples list automatically."
        }
        if partnerScoredPrograms.isEmpty {
            return "Waiting for your partner to score at least one program."
        }
        if canGenerateSuggestedList {
            return """
            You both have scored programs. Tap Generate Suggested List — if nothing appears, \
            check geography settings in Couple → Settings (default is Same State).
            """
        }
        return "Waiting for your partner to score at least one program."
    }

    private func tryAutoGenerateIfNeeded() {
        guard !didAutoGenerateForEmptyList,
              sortedPairs.isEmpty,
              canGenerateSuggestedList,
              !isGenerating else { return }

        didAutoGenerateForEmptyList = true
        generateCouplesRankList(showSuccessAlert: true)
    }
    
    private func markRankListEdited() {
        dataManager.preferences.couplesRankListUpdatedAt = Date()
        dataManager.savePreferences()
        dataManager.scheduleCoupleCloudPublish()
    }

    private func addPair(_ pair: CouplesRankPair) {
        var newPair = pair
        newPair.rank = dataManager.preferences.couplesRankPairs.count + 1
        dataManager.preferences.couplesRankPairs.append(newPair)
        markRankListEdited()
    }
    
    private func updatePair(_ oldPair: CouplesRankPair, with newPair: CouplesRankPair) {
        if let index = dataManager.preferences.couplesRankPairs.firstIndex(where: { $0.id == oldPair.id }) {
            var updated = newPair
            updated.rank = oldPair.rank
            dataManager.preferences.couplesRankPairs[index] = updated
            markRankListEdited()
        }
    }
    
    private func deletePairs(at offsets: IndexSet) {
        dataManager.preferences.couplesRankPairs.remove(atOffsets: offsets)
        for (index, _) in dataManager.preferences.couplesRankPairs.enumerated() {
            dataManager.preferences.couplesRankPairs[index].rank = index + 1
        }
        markRankListEdited()
    }
    
    private func movePairs(from source: IndexSet, to destination: Int) {
        dataManager.preferences.couplesRankPairs.move(fromOffsets: source, toOffset: destination)
        for (index, _) in dataManager.preferences.couplesRankPairs.enumerated() {
            dataManager.preferences.couplesRankPairs[index].rank = index + 1
        }
        markRankListEdited()
    }
    
    private func validateRankList() {
        let result = dataManager.validateCouplesRankList()
        validationErrors = result.errors
        showValidationAlert = true
    }
    
    private func generateCouplesRankList(showSuccessAlert: Bool = true) {
        guard !coupleSync.partnerPrograms.isEmpty else {
            generateError = "Your partner's programs are not available yet. Ask them to open Matchly while signed in to iCloud."
            return
        }

        guard !myScoredPrograms.isEmpty else {
            generateError = "Score at least one program under My Programs before generating a couples list."
            return
        }

        guard !partnerScoredPrograms.isEmpty else {
            generateError = "Your partner hasn't scored any programs yet. Ask them to complete at least one program questionnaire."
            return
        }

        isGenerating = true
        let partnerScored = coupleSync.partnerPrograms.filter { $0.finalScore > 0 }
        let generatedPairs = dataManager.generateCouplesRankList(partnerPrograms: partnerScored)
        isGenerating = false

        guard !generatedPairs.isEmpty else {
            generateError = emptyGenerationMessage
            return
        }

        dataManager.preferences.couplesRankPairs = generatedPairs
        markRankListEdited()
        if showSuccessAlert {
            showGenerateAlert = true
        }
    }
}

struct CouplesRankPairRow: View {
    let pair: CouplesRankPair
    let myProgram: Program?
    let partnerProgram: Program?
    let myNoMatch: Bool
    let partnerNoMatch: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("#\(pair.rank)")
                        .font(.arial(size: 14, weight: .bold))
                        .foregroundColor(.blue)
                        .frame(width: 30)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("You:")
                                .font(.arial(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                            Text(myProgram?.hospital ?? (myNoMatch ? "No Match" : "Not Set"))
                                .font(.arial(size: 14, weight: .medium))
                        }
                        
                        HStack {
                            Text("Partner:")
                                .font(.arial(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                            Text(partnerProgram?.hospital ?? (partnerNoMatch ? "No Match" : "Not Set"))
                                .font(.arial(size: 14, weight: .medium))
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Image(systemName: "chevron.right")
                            .font(.arial(size: 12))
                            .foregroundColor(.secondary)
                        Text("Edit")
                            .font(.arial(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}

struct AddCouplesRankPairView: View {
    let pair: CouplesRankPair?
    let couple: Couple?
    let myRecordName: String?
    let myPrograms: [Program]
    let partnerPrograms: [Program]
    let onSave: (CouplesRankPair) -> Void
    let onCancel: () -> Void
    
    @State private var selectedMyProgramID: String?
    @State private var selectedPartnerProgramID: String?
    @State private var myNoMatch = false
    @State private var partnerNoMatch = false
    @State private var notes = ""
    
    var body: some View {
        MatchlyNavigationView {
            Form {
                Section("Your Program") {
                    Toggle("No Match", isOn: $myNoMatch)
                    
                    if !myNoMatch {
                        Picker("Select Program", selection: $selectedMyProgramID) {
                            Text("None").tag(nil as String?)
                            ForEach(myPrograms) { program in
                                Text(program.hospital.isEmpty ? program.name : program.hospital)
                                    .tag(program.id as String?)
                            }
                        }
                    }
                }
                
                Section("Partner's Program") {
                    Toggle("No Match", isOn: $partnerNoMatch)
                    
                    if !partnerNoMatch {
                        Picker("Select Program", selection: $selectedPartnerProgramID) {
                            Text("None").tag(nil as String?)
                            ForEach(partnerPrograms) { program in
                                Text(program.hospital.isEmpty ? program.name : program.hospital)
                                    .tag(program.id as String?)
                            }
                        }
                    }
                }
                
                Section("Notes") {
                    ClearableTextField("Optional notes about this pair", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle(pair == nil ? "Add Rank Pair" : "Edit Rank Pair")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        savePair()
                    }
                    .fontWeight(.semibold)
                    .disabled(!isValid)
                }
            }
            .onAppear {
                loadExistingPair()
            }
        }
    }

    private func loadExistingPair() {
        guard let pair, let couple, let myRecordName else {
            if let pair {
                notes = pair.notes
            }
            return
        }

        selectedMyProgramID = CouplesRankPairPerspective.programID(forRecordName: myRecordName, in: pair, couple: couple)
        myNoMatch = CouplesRankPairPerspective.isNoMatch(forRecordName: myRecordName, in: pair, couple: couple)

        let partnerRecord = myRecordName == couple.user1ID ? couple.user2ID : couple.user1ID
        if let partnerRecord {
            selectedPartnerProgramID = CouplesRankPairPerspective.programID(forRecordName: partnerRecord, in: pair, couple: couple)
            partnerNoMatch = CouplesRankPairPerspective.isNoMatch(forRecordName: partnerRecord, in: pair, couple: couple)
        }
        notes = pair.notes
    }

    private func savePair() {
        guard let couple, let myRecordName else { return }

        let newPair = CouplesRankPairPerspective.makeCanonicalPair(
            couple: couple,
            myRecordName: myRecordName,
            myProgramID: selectedMyProgramID,
            partnerProgramID: selectedPartnerProgramID,
            myNoMatch: myNoMatch,
            partnerNoMatch: partnerNoMatch,
            id: pair?.id ?? UUID().uuidString,
            rank: pair?.rank ?? 0,
            notes: notes
        )
        onSave(newPair)
    }
    
    private var isValid: Bool {
        (myNoMatch || selectedMyProgramID != nil) &&
        (partnerNoMatch || selectedPartnerProgramID != nil)
    }
}

struct CouplesPreferencesView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) var dismiss
    
    @State private var mustMatchTogether: Bool = true
    @State private var preferSameHospital: Bool = false
    @State private var geographyStrictness: CouplesPreferences.GeographyStrictness = .sameState
    @State private var prioritizeIndividualRankLists: Bool = true
    @State private var distanceTolerance: Double = 100
    
    var body: some View {
        MatchlyNavigationView {
            Form {
                CouplesSharedPreferencesSections(
                    mustMatchTogether: $mustMatchTogether,
                    preferSameHospital: $preferSameHospital,
                    geographyStrictness: $geographyStrictness,
                    prioritizeIndividualRankLists: $prioritizeIndividualRankLists,
                    distanceTolerance: $distanceTolerance
                )
            }
            .navigationTitle("Couples Preferences")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        savePreferences()
                    }
                    .fontWeight(.semibold)
                    .buttonStyle(.glassProminent)
                    .tint(AppColors.primaryBlue)
                }
            }
            .onAppear {
                loadPreferences()
            }
        }
    }

    private func loadPreferences() {
        let prefs = dataManager.preferences.couplesPreferences
        mustMatchTogether = prefs.mustMatchTogether
        preferSameHospital = prefs.preferSameHospital
        geographyStrictness = prefs.geographyStrictness
        prioritizeIndividualRankLists = prefs.prioritizeIndividualRankLists
        distanceTolerance = Double(prefs.distanceTolerance)
    }

    private func savePreferences() {
        dataManager.preferences.couplesPreferences.mustMatchTogether = mustMatchTogether
        dataManager.preferences.couplesPreferences.preferSameHospital = preferSameHospital
        dataManager.preferences.couplesPreferences.geographyStrictness = geographyStrictness
        dataManager.preferences.couplesPreferences.normalizeGeography()
        dataManager.preferences.couplesPreferences.prioritizeIndividualRankLists = prioritizeIndividualRankLists
        dataManager.preferences.couplesPreferences.distanceTolerance = Int(distanceTolerance)
        dataManager.savePreferences()
        dataManager.scheduleCoupleCloudPublish()
        dismiss()
    }
}

