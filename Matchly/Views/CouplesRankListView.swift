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
    
    private var sortedPairs: [CouplesRankPair] {
        dataManager.preferences.couplesRankPairs.sorted { $0.rank < $1.rank }
    }
    
    private var myPrograms: [Program] {
        dataManager.getRankedPrograms()
    }

    private var partnerPrograms: [Program] {
        coupleSync.partnerPrograms.map { $0.asProgram() }
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
    
    var body: some View {
        Form {
            if let couple = dataManager.preferences.couple, couple.isLinked {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Couples Rank List")
                            .font(.arial(size: 15, weight: .semibold))
                        
                        Text("Each rank pairs one of your programs with one of your partner's programs (or 'No Match'). Tap **Generate Suggested List** to build a starting list from both rank orders and your shared criteria — then edit freely.")
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
                        Text("Waiting for your partner to share their program list. Ask them to open Matchly while signed in to iCloud.")
                            .font(.arial(size: 13))
                            .foregroundColor(.secondary)
                    } header: {
                        Text("Partner Programs")
                    }
                } else {
                    Section {
                        ForEach(Array(partnerPrograms.prefix(5).enumerated()), id: \.element.id) { index, program in
                            HStack {
                                Text("#\(index + 1)")
                                    .font(.arial(size: 12, weight: .bold))
                                    .foregroundColor(.pink)
                                    .frame(width: 24)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(program.hospital.isEmpty ? program.name : program.hospital)
                                        .font(.arial(size: 14, weight: .medium))
                                    Text("\(program.city), \(program.state)")
                                        .font(.arial(size: 12))
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Text(String(format: "%.1f", program.finalScore))
                                    .font(.arial(size: 13, weight: .semibold))
                                    .foregroundColor(.secondary)
                            }
                        }
                        if partnerPrograms.count > 5 {
                            Text("+ \(partnerPrograms.count - 5) more programs")
                                .font(.arial(size: 12))
                                .foregroundColor(.secondary)
                        }
                    } header: {
                        Text("Partner's Ranked Programs (\(partnerPrograms.count))")
                    }
                }
                
                if sortedPairs.isEmpty {
                    Section {
                        VStack(spacing: 16) {
                            Image(systemName: "list.number")
                                .font(.arial(size: 40))
                                .foregroundColor(.secondary)
                            
                            Text("No Rank Pairs Yet")
                                .font(.arial(size: 17, weight: .semibold))
                            
                            Text("Create your first rank pair to get started")
                                .font(.arial(size: 14))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            
                            Button(action: {
                                showAddPair = true
                            }) {
                                Text("Add First Pair")
                                    .font(.arial(size: 16, weight: .semibold))
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.glassProminent)
                            .tint(AppColors.primaryBlue)
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
                            if sortedPairs.count > 0 {
                                Button(action: {
                                    validateRankList()
                                }) {
                                    Text("Validate")
                                        .font(.arial(size: 12))
                                }
                            }
                        }
                    }
                }
                
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
                    
                    if !myPrograms.isEmpty && !partnerPrograms.isEmpty {
                        Button(action: {
                            generateCouplesRankList()
                        }) {
                            HStack {
                                if isGenerating {
                                    ProgressView()
                                } else {
                                    Image(systemName: "sparkles")
                                        .foregroundColor(.blue)
                                }
                                Text("Generate Suggested List")
                            }
                        }
                        .disabled(isGenerating)
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
            if !sortedPairs.isEmpty && !embeddedInHub {
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
            Button("OK") { }
        } message: {
            Text("A suggested couples rank list was created from both partners' rank orders and your matching criteria. Review and adjust before submitting to NRMP.")
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
        }
        .refreshable {
            await coupleSync.refreshAll(dataManager: dataManager)
        }
        .onReceive(NotificationCenter.default.publisher(for: .coupleDataDidChange)) { _ in
            // Partner data updated via CloudKit.
        }
    }
    
    private func addPair(_ pair: CouplesRankPair) {
        var newPair = pair
        newPair.rank = dataManager.preferences.couplesRankPairs.count + 1
        dataManager.preferences.couplesRankPairs.append(newPair)
        dataManager.savePreferences()
        dataManager.scheduleCoupleCloudPublish()
    }
    
    private func updatePair(_ oldPair: CouplesRankPair, with newPair: CouplesRankPair) {
        if let index = dataManager.preferences.couplesRankPairs.firstIndex(where: { $0.id == oldPair.id }) {
            var updated = newPair
            updated.rank = oldPair.rank
            dataManager.preferences.couplesRankPairs[index] = updated
            dataManager.savePreferences()
            dataManager.scheduleCoupleCloudPublish()
        }
    }
    
    private func deletePairs(at offsets: IndexSet) {
        dataManager.preferences.couplesRankPairs.remove(atOffsets: offsets)
        for (index, _) in dataManager.preferences.couplesRankPairs.enumerated() {
            dataManager.preferences.couplesRankPairs[index].rank = index + 1
        }
        dataManager.savePreferences()
        dataManager.scheduleCoupleCloudPublish()
    }
    
    private func movePairs(from source: IndexSet, to destination: Int) {
        dataManager.preferences.couplesRankPairs.move(fromOffsets: source, toOffset: destination)
        for (index, _) in dataManager.preferences.couplesRankPairs.enumerated() {
            dataManager.preferences.couplesRankPairs[index].rank = index + 1
        }
        dataManager.savePreferences()
        dataManager.scheduleCoupleCloudPublish()
    }
    
    private func validateRankList() {
        let result = dataManager.validateCouplesRankList()
        validationErrors = result.errors
        showValidationAlert = true
    }
    
    private func generateCouplesRankList() {
        guard !coupleSync.partnerPrograms.isEmpty else {
            generateError = "Your partner's programs are not available yet. Ask them to open Matchly while signed in to iCloud."
            return
        }

        isGenerating = true
        let generatedPairs = dataManager.generateCouplesRankList(partnerPrograms: coupleSync.partnerPrograms)
        isGenerating = false

        guard !generatedPairs.isEmpty else {
            generateError = "Could not generate a list. Make sure both partners have ranked programs."
            return
        }

        dataManager.preferences.couplesRankPairs = generatedPairs
        dataManager.savePreferences()
        dataManager.scheduleCoupleCloudPublish()
        showGenerateAlert = true
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
                    
                    Image(systemName: "chevron.right")
                        .font(.arial(size: 12))
                        .foregroundColor(.secondary)
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
                    TextField("Optional notes about this pair", text: $notes, axis: .vertical)
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
    @State private var preferSameCity: Bool = false
    @State private var preferSameState: Bool = true
    @State private var prioritizeIndividualRankLists: Bool = true
    @State private var distanceTolerance: Double = 100
    
    var body: some View {
        MatchlyNavigationView {
            Form {
                Section {
                    Toggle("Must Match Together", isOn: $mustMatchTogether)
                    Toggle("Prefer Same Hospital", isOn: $preferSameHospital)
                    Toggle("Prefer Same City", isOn: $preferSameCity)
                    Toggle("Prefer Same State", isOn: $preferSameState)
                    Toggle("Prioritize Individual Rank Lists", isOn: $prioritizeIndividualRankLists)
                } header: {
                    Text("Matching Criteria")
                } footer: {
                    Text("These criteria guide Generate Suggested List on the couples rank list. Adjust pairs manually anytime.")
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Maximum Distance: \(Int(distanceTolerance)) miles")
                            .font(.arial(size: 15, weight: .medium))
                        Slider(value: $distanceTolerance, in: 0...500, step: 25)
                    }
                } header: {
                    Text("Geography")
                }
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
        preferSameCity = prefs.preferSameCity
        preferSameState = prefs.preferSameState
        prioritizeIndividualRankLists = prefs.prioritizeIndividualRankLists
        distanceTolerance = Double(prefs.distanceTolerance)
    }

    private func savePreferences() {
        dataManager.preferences.couplesPreferences.mustMatchTogether = mustMatchTogether
        dataManager.preferences.couplesPreferences.preferSameHospital = preferSameHospital
        dataManager.preferences.couplesPreferences.preferSameCity = preferSameCity
        dataManager.preferences.couplesPreferences.preferSameState = preferSameState
        dataManager.preferences.couplesPreferences.prioritizeIndividualRankLists = prioritizeIndividualRankLists
        dataManager.preferences.couplesPreferences.distanceTolerance = Int(distanceTolerance)
        dataManager.savePreferences()
        dataManager.scheduleCoupleCloudPublish()
        dismiss()
    }
}

