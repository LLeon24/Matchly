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
    
    private var user1Programs: [Program] {
        dataManager.getRankedPrograms()
    }
    
    private var user2Programs: [Program] {
        coupleSync.partnerPrograms.map { $0.asProgram() }
    }
    
    var body: some View {
        Form {
            if let couple = dataManager.preferences.couple, couple.isLinked {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Couples Rank List")
                            .font(.arial(size: 15, weight: .semibold))
                        
                        Text("Each rank pairs one of your programs with one of your partner's programs (or 'No Match'). Matchly can suggest an optimized list from both rank lists and your shared preferences.")
                            .font(.arial(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Instructions")
                }

                if coupleSync.isSyncing && user2Programs.isEmpty {
                    Section {
                        HStack {
                            ProgressView()
                            Text("Syncing partner's programs…")
                                .font(.arial(size: 14))
                                .foregroundColor(.secondary)
                        }
                    }
                } else if user2Programs.isEmpty {
                    Section {
                        Text("Waiting for your partner to share their program list. Ask them to open Couples Matching while signed in to iCloud.")
                            .font(.arial(size: 13))
                            .foregroundColor(.secondary)
                    } header: {
                        Text("Partner Programs")
                    }
                } else {
                    Section {
                        ForEach(Array(user2Programs.prefix(5).enumerated()), id: \.element.id) { index, program in
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
                        if user2Programs.count > 5 {
                            Text("+ \(user2Programs.count - 5) more programs")
                                .font(.arial(size: 12))
                                .foregroundColor(.secondary)
                        }
                    } header: {
                        Text("Partner's Ranked Programs (\(user2Programs.count))")
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
                                user1Program: user1Programs.first { $0.id == pair.user1ProgramID },
                                user2Program: user2Programs.first { $0.id == pair.user2ProgramID },
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
                    
                    if !user1Programs.isEmpty && !user2Programs.isEmpty {
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
                                Text("Generate Optimized Couples List")
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
        .appCanvasBackground()
        .navigationTitle("Couples Rank List")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !sortedPairs.isEmpty {
                EditButton()
            }
        }
        .sheet(isPresented: $showAddPair) {
            AddCouplesRankPairView(
                pair: editingPair,
                user1Programs: user1Programs,
                user2Programs: user2Programs,
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
            Text("An optimized couples rank list was created from both partners' scores, geography, and your shared preferences. Review and adjust before submitting.")
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
    let user1Program: Program?
    let user2Program: Program?
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
                            Text(user1Program?.hospital ?? (pair.user1NoMatch ? "No Match" : "Not Set"))
                                .font(.arial(size: 14, weight: .medium))
                        }
                        
                        HStack {
                            Text("Partner:")
                                .font(.arial(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                            Text(user2Program?.hospital ?? (pair.user2NoMatch ? "No Match" : "Not Set"))
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
    let user1Programs: [Program]
    let user2Programs: [Program]
    let onSave: (CouplesRankPair) -> Void
    let onCancel: () -> Void
    
    @State private var selectedUser1ProgramID: String?
    @State private var selectedUser2ProgramID: String?
    @State private var user1NoMatch = false
    @State private var user2NoMatch = false
    @State private var notes = ""
    
    var body: some View {
        MatchlyNavigationView {
            Form {
                Section("Your Program") {
                    Toggle("No Match", isOn: $user1NoMatch)
                    
                    if !user1NoMatch {
                        Picker("Select Program", selection: $selectedUser1ProgramID) {
                            Text("None").tag(nil as String?)
                            ForEach(user1Programs) { program in
                                Text(program.hospital.isEmpty ? program.name : program.hospital)
                                    .tag(program.id as String?)
                            }
                        }
                    }
                }
                
                Section("Partner's Program") {
                    Toggle("No Match", isOn: $user2NoMatch)
                    
                    if !user2NoMatch {
                        Picker("Select Program", selection: $selectedUser2ProgramID) {
                            Text("None").tag(nil as String?)
                            ForEach(user2Programs) { program in
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
                        let newPair = CouplesRankPair(
                            id: pair?.id ?? UUID().uuidString,
                            rank: pair?.rank ?? 0,
                            user1ProgramID: user1NoMatch ? nil : selectedUser1ProgramID,
                            user2ProgramID: user2NoMatch ? nil : selectedUser2ProgramID,
                            user1NoMatch: user1NoMatch,
                            user2NoMatch: user2NoMatch,
                            notes: notes
                        )
                        onSave(newPair)
                    }
                    .fontWeight(.semibold)
                    .disabled(!isValid)
                }
            }
            .onAppear {
                if let pair = pair {
                    selectedUser1ProgramID = pair.user1ProgramID
                    selectedUser2ProgramID = pair.user2ProgramID
                    user1NoMatch = pair.user1NoMatch
                    user2NoMatch = pair.user2NoMatch
                    notes = pair.notes
                }
            }
        }
    }
    
    private var isValid: Bool {
        (user1NoMatch || selectedUser1ProgramID != nil) &&
        (user2NoMatch || selectedUser2ProgramID != nil)
    }
}

struct CouplesPreferencesView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) var dismiss
    
    @State private var geographicPriority: CouplesPreferences.GeographicPriority
    @State private var programTypePriority: CouplesPreferences.ProgramTypePriority
    @State private var distanceTolerance: Double
    @State private var mustMatchTogether: Bool
    @State private var weightIndividualScores: Double
    @State private var weightGeography: Double
    @State private var weightSameHospital: Double
    @State private var weightEMR: Double
    @State private var weightProgramType: Double
    @State private var preferSameHospital: Bool
    
    init() {
        let prefs = DataManager.shared.preferences.couplesPreferences
        _geographicPriority = State(initialValue: prefs.geographicPriority)
        _programTypePriority = State(initialValue: prefs.programTypePriority)
        _distanceTolerance = State(initialValue: Double(prefs.distanceTolerance))
        _mustMatchTogether = State(initialValue: prefs.mustMatchTogether)
        _weightIndividualScores = State(initialValue: prefs.weightIndividualScores)
        _weightGeography = State(initialValue: prefs.weightGeography)
        _weightSameHospital = State(initialValue: prefs.weightSameHospital)
        _weightEMR = State(initialValue: prefs.weightEMR)
        _weightProgramType = State(initialValue: prefs.weightProgramType)
        _preferSameHospital = State(initialValue: prefs.preferSameHospital)
    }
    
    var body: some View {
        MatchlyNavigationView {
            Form {
                Section("Geographic Preferences") {
                    Picker("Priority", selection: $geographicPriority) {
                        ForEach(CouplesPreferences.GeographicPriority.allCases, id: \.self) { priority in
                            Text(priority.rawValue).tag(priority)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Maximum Distance: \(Int(distanceTolerance)) miles")
                            .font(.arial(size: 15, weight: .medium))
                        
                        Slider(value: $distanceTolerance, in: 0...500, step: 10)
                    }
                }
                
                Section("Program Type Preferences") {
                    Picker("Priority", selection: $programTypePriority) {
                        ForEach(CouplesPreferences.ProgramTypePriority.allCases, id: \.self) { priority in
                            Text(priority.rawValue).tag(priority)
                        }
                    }
                }
                
                Section {
                    Toggle("Must Match Together", isOn: $mustMatchTogether)
                    Toggle("Prefer Same Hospital", isOn: $preferSameHospital)
                } footer: {
                    Text("If enabled, you will only match if both partners match. Same-hospital preference boosts pairs at one institution.")
                }

                Section {
                    preferenceWeightRow("Program Scores", value: $weightIndividualScores)
                    preferenceWeightRow("Geography", value: $weightGeography)
                    preferenceWeightRow("Same Hospital", value: $weightSameHospital)
                    preferenceWeightRow("EMR Alignment", value: $weightEMR)
                    preferenceWeightRow("Program Type", value: $weightProgramType)
                } header: {
                    Text("Optimization Priorities")
                } footer: {
                    Text("These weights guide the Generate Optimized Couples List algorithm. Higher values make that factor more important when pairing programs.")
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
        }
    }
    
    private func preferenceWeightRow(_ title: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.arial(size: 15))
                Spacer()
                Text("\(Int(value.wrappedValue * 100))%")
                    .font(.arial(size: 13))
                    .foregroundColor(.secondary)
            }
            Slider(value: value, in: 0...1, step: 0.05)
        }
    }

    private func savePreferences() {
        dataManager.preferences.couplesPreferences.geographicPriority = geographicPriority
        dataManager.preferences.couplesPreferences.programTypePriority = programTypePriority
        dataManager.preferences.couplesPreferences.distanceTolerance = Int(distanceTolerance)
        dataManager.preferences.couplesPreferences.mustMatchTogether = mustMatchTogether
        dataManager.preferences.couplesPreferences.weightIndividualScores = weightIndividualScores
        dataManager.preferences.couplesPreferences.weightGeography = weightGeography
        dataManager.preferences.couplesPreferences.weightSameHospital = weightSameHospital
        dataManager.preferences.couplesPreferences.weightEMR = weightEMR
        dataManager.preferences.couplesPreferences.weightProgramType = weightProgramType
        dataManager.preferences.couplesPreferences.preferSameHospital = preferSameHospital
        dataManager.savePreferences()
        dataManager.scheduleCoupleCloudPublish()
        dismiss()
    }
}

