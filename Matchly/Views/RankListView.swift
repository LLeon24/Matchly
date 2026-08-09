//
//  RankListView.swift
//  Matchly
//
//  Created by Leoh N. Leon II on 11/14/25.
//

import SwiftUI
import UIKit

struct RankListView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var showExportSheet = false
    @State private var manualOrder: [String] = [] // Store program IDs in manual order
    @State private var isEditing = false
    @State private var sortOption: SortOption = .score
    @State private var filterInterviewed = false
    @State private var selectedSpecialties: Set<String> = []
    @State private var showAllSpecialties: Bool = true
    
    enum SortOption: String, CaseIterable {
        case score = "Score"
        case name = "Name"
        case location = "Location"
        case interviewDate = "Interview Date"
    }
    
    /// Sort programs by final score (highest first), then hospital name.
    private func sortedByScore(_ programs: [Program]) -> [Program] {
        programs.sorted {
            if $0.finalScore != $1.finalScore {
                return $0.finalScore > $1.finalScore
            }
            return HospitalNameFormatter.format($0.hospital) < HospitalNameFormatter.format($1.hospital)
        }
    }

    private func applySortOption(_ programs: [Program]) -> [Program] {
        switch sortOption {
        case .score:
            return sortedByScore(programs)
        case .name:
            return programs.sorted {
                HospitalNameFormatter.format($0.hospital) < HospitalNameFormatter.format($1.hospital)
            }
        case .location:
            return programs.sorted {
                if $0.state != $1.state {
                    return $0.state < $1.state
                }
                return $0.city < $1.city
            }
        case .interviewDate:
            return programs.sorted {
                guard let date1 = $0.interviewDate, let date2 = $1.interviewDate else {
                    if $0.interviewDate != nil { return true }
                    if $1.interviewDate != nil { return false }
                    return $0.finalScore > $1.finalScore
                }
                return date1 < date2
            }
        }
    }
    
    var rankedPrograms: [Program] {
        let includeRedFlags = dataManager.preferences.includeRedFlaggedProgramsInRankList
        var programs: [Program]
        
        if manualOrder.isEmpty {
            programs = applySortOption(dataManager.programs)
        } else {
            // Use manual order if available - optimize with dictionary lookup (O(1) instead of O(n))
            let programsById = Dictionary(uniqueKeysWithValues: dataManager.programs.map { ($0.id, $0) })
            var ordered: [Program] = []
            for id in manualOrder {
                if let program = programsById[id] {
                    ordered.append(program)
                }
            }
            // Add any programs not in manual order (newly added)
            let manualIds = Set(manualOrder)
            for program in applySortOption(dataManager.programs) where !manualIds.contains(program.id) {
                ordered.append(program)
            }
            programs = ordered
        }
        
        // Apply specialty filter (only if user has explicitly selected specialties)
        if !showAllSpecialties && !selectedSpecialties.isEmpty {
            programs = programs.filter { selectedSpecialties.contains($0.specialty) }
        }
        
        // Apply interview filter
        if filterInterviewed {
            programs = programs.filter { $0.interviewDate != nil }
        }
        
        // Red flagged programs are kept in the list when enabled (separated later for display),
        // and filtered out entirely when the setting is disabled.
        if !includeRedFlags {
            programs = programs.filter { !$0.hasRedFlags() }
        }
        
        // Apply sorting (only if not using manual order)
        if manualOrder.isEmpty {
            programs = applySortOption(programs)
        }
        
        return programs
    }

    /// Programs with a computed score — eligible for numbered rank positions.
    private var scoredRankedPrograms: [Program] {
        rankedPrograms.filter { $0.finalScore > 0 }
    }

    /// Tracked programs that are not scored yet — shown below the ranked list.
    private var unrankedPrograms: [Program] {
        rankedPrograms.filter { $0.finalScore <= 0 }
    }

    private func unrankedReason(for program: Program) -> String {
        let prefs = dataManager.preferences
        if program.interviewDate == nil {
            return "Add an interview date to start scoring"
        }
        if program.needsScoring(preferences: prefs) {
            return "Complete the questionnaire to rank this program"
        }
        return "Score this program to add it to your rank list"
    }
    
    private var allSpecialties: [String] {
        Array(Set(dataManager.programs.map { $0.specialty })).sorted()
    }
    
    // Computed properties to break up complex expressions
    /// Scored programs in display order — red-flag block stays at the bottom until manually reordered.
    private var orderedScoredPrograms: [Program] {
        let scored = scoredRankedPrograms
        if !manualOrder.isEmpty {
            return scored
        }
        guard dataManager.preferences.includeRedFlaggedProgramsInRankList else {
            return scored.filter { !$0.hasRedFlags() }
        }
        return scored.filter { !$0.hasRedFlags() } + scored.filter { $0.hasRedFlags() }
    }

    private func shouldShowSpecialtyHeader(at index: Int) -> Bool {
        let programs = orderedScoredPrograms
        guard index < programs.count else { return false }
        let program = programs[index]
        guard !program.hasRedFlags() else { return false }
        guard !program.specialty.isEmpty else { return false }
        if index == 0 { return true }
        let previous = programs[index - 1]
        if previous.hasRedFlags() { return true }
        return previous.specialty != program.specialty
    }

    private func shouldShowRedFlaggedBanner(at index: Int) -> Bool {
        let programs = orderedScoredPrograms
        guard index < programs.count else { return false }
        guard programs[index].hasRedFlags() else { return false }
        guard index > 0 else { return false }
        guard !programs[index - 1].hasRedFlags() else { return false }
        return programs[index...].allSatisfy { $0.hasRedFlags() }
    }

    private func elevatedRedFlag(at index: Int) -> Bool {
        let programs = orderedScoredPrograms
        guard index < programs.count else { return false }
        guard programs[index].hasRedFlags() else { return false }
        return programs[(index + 1)...].contains { !$0.hasRedFlags() }
    }
    
    var body: some View {
        MatchlyNavigationView {
            Group {
                if dataManager.programs.isEmpty {
                    EmptyRankListView()
                        .matchlyRootContentFrame()
                } else {
                    VStack(spacing: 0) {
                        MatchlyListPageTitleRow(title: "Rank List") {
                            if !scoredRankedPrograms.isEmpty {
                                MatchlyToolbarExportPDFButton {
                                    showExportSheet = true
                                }
                            }
                        }

                        filterToolbar
                        programListContent
                    }
                }
            }
            .matchlyRootContentFrame()
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                toolbarContent
            }
            .sheet(isPresented: $showExportSheet) {
                ExportView(orderedRankedPrograms: orderedScoredPrograms)
                    .environmentObject(dataManager)
            }
            .onAppear {
                loadManualOrder()
                showAllSpecialties = true
                selectedSpecialties = []
            }
            .appCanvasBackground()
        }
    }
    
    // MARK: - View Components
    
    private var filterToolbar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                specialtyFilterMenu
                sortMenu
                Spacer()
                Text("\(scoredRankedPrograms.count) ranked")
                    .font(.arial(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 4)
        }
        .padding()
    }
    
    private var specialtyFilterMenu: some View {
        Menu {
            if !allSpecialties.isEmpty {
                Section("Specialties") {
                    ForEach(allSpecialties, id: \.self) { specialty in
                        Button(action: {
                            showAllSpecialties = false
                            if selectedSpecialties.contains(specialty) {
                                selectedSpecialties.remove(specialty)
                            } else {
                                selectedSpecialties.insert(specialty)
                            }
                        }) {
                            HStack {
                                Text(SpecialtyFormatter.displayNameWithAbbreviation(specialty))
                                Spacer()
                                if selectedSpecialties.contains(specialty) {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }
                
                Divider()
                
                Button(action: {
                    selectedSpecialties.removeAll()
                    showAllSpecialties = true
                }) {
                    HStack {
                        Image(systemName: "square.grid.2x2")
                        Text("All Specialties")
                    }
                }
            }
        } label: {
            MatchlyFilterChipLabel(
                icon: "stethoscope",
                iconColor: AppColors.primaryBlue,
                text: showAllSpecialties ? "All" : "\(selectedSpecialties.count)",
                isActive: !showAllSpecialties && !selectedSpecialties.isEmpty
            )
        }
    }
    
    private var sortMenu: some View {
        Menu {
            ForEach(SortOption.allCases, id: \.self) { option in
                Button(action: {
                    sortOption = option
                    manualOrder = []
                    saveManualOrder()
                }) {
                    HStack {
                        Text(option.rawValue)
                        Spacer()
                        if sortOption == option {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
        } label: {
            MatchlyFilterChipLabel(
                icon: "arrow.up.arrow.down",
                text: "Sort: \(sortOption.rawValue)"
            )
        }
    }
    
    private var programListContent: some View {
        List {
            if scoredRankedPrograms.isEmpty && !unrankedPrograms.isEmpty {
                Section {
                    Text("Complete questionnaires and score your visits to build a ranked list.")
                        .font(.arial(size: 14))
                        .foregroundColor(.secondary)
                        .padding(.vertical, 4)
                }
            }

            rankedProgramsSection
            unrankedSection
        }
        .listStyle(.insetGrouped)
        .matchlyReadableWidth()
        .matchlyScrollTabBarClearance()
        .environment(\.editMode, isEditing ? .constant(.active) : .constant(.inactive))
    }
    
    private var rankedProgramsSection: some View {
        Section {
            ForEach(Array(orderedScoredPrograms.enumerated()), id: \.element.id) { index, program in
                if !isEditing && shouldShowSpecialtyHeader(at: index) {
                    MatchlySpecialtySectionHeader(specialty: program.specialty)
                        .padding(.top, index == 0 ? 0 : 6)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 0, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }

                if !isEditing && shouldShowRedFlaggedBanner(at: index) {
                    redFlaggedHeader
                        .padding(.top, 6)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 0, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }

                Group {
                    if isEditing {
                        RankListItemView(
                            rank: index + 1,
                            program: program,
                            showsElevatedRedFlag: elevatedRedFlag(at: index)
                        )
                    } else {
                        NavigationLink(destination: ProgramEntryView(program: program)) {
                            RankListItemView(
                                rank: index + 1,
                                program: program,
                                showsElevatedRedFlag: elevatedRedFlag(at: index)
                            )
                        }
                    }
                }
            }
            .onMove(perform: moveScoredPrograms)
        } header: {
            if isEditing {
                Text("Drag to set your match order")
                    .font(.arial(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                    .textCase(nil)
            }
        }
    }
    
    @ViewBuilder
    private var unrankedSection: some View {
        if !unrankedPrograms.isEmpty {
            Section(header: unrankedHeader) {
                ForEach(unrankedPrograms) { program in
                    NavigationLink(destination: ProgramEntryView(program: program)) {
                        UnrankedProgramRow(program: program, reason: unrankedReason(for: program))
                    }
                }
            }
        }
    }

    private var unrankedHeader: some View {
        HStack(spacing: 6) {
            Image(systemName: "list.bullet.clipboard")
                .font(.arial(size: 12))
                .foregroundColor(AppColors.pipelineToReview)
            Text("Not Ranked Yet (\(unrankedPrograms.count))")
                .font(.arial(size: 13, weight: .semibold))
                .foregroundColor(AppColors.pipelineToReview)
        }
    }
    
    private var redFlaggedHeader: some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.arial(size: 12))
                .foregroundColor(.red)
            Text("Red Flagged Programs")
                .font(.arial(size: 13, weight: .semibold))
                .foregroundColor(.red)
        }
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if MatchlyListPageToolbar.showsActions(hasContent: !scoredRankedPrograms.isEmpty) {
            ToolbarItem(placement: .navigationBarLeading) {
                HStack {
                    Button(action: {
                        isEditing.toggle()
                    }) {
                        Text(isEditing ? "Done" : "Edit")
                    }

                    if !manualOrder.isEmpty {
                        Button(action: {
                            manualOrder = []
                            saveManualOrder()
                        }) {
                            Text("Reset")
                                .font(.caption)
                        }
                    }
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                if dataManager.programs.count >= 2 {
                    NavigationLink(destination: ProgramComparisonView()) {
                        Image(systemName: "square.grid.2x2")
                            .font(.arial(size: 17, weight: .semibold))
                            .foregroundColor(AppColors.primaryBlue)
                    }
                    .accessibilityLabel("Compare programs")
                }
            }
        }
    }
    
    private func moveScoredPrograms(from source: IndexSet, to destination: Int) {
        var ordered = orderedScoredPrograms
        ordered.move(fromOffsets: source, toOffset: destination)

        let scoredIds = Set(ordered.map(\.id))
        var newManualOrder = ordered.map(\.id)
        for program in rankedPrograms where !scoredIds.contains(program.id) {
            newManualOrder.append(program.id)
        }

        manualOrder = newManualOrder
        saveManualOrder()
    }
    
    private func saveManualOrder() {
        UserDefaults.standard.set(manualOrder, forKey: "manual_rank_order")
    }
    
    private func loadManualOrder() {
        if let saved = UserDefaults.standard.array(forKey: "manual_rank_order") as? [String] {
            manualOrder = saved
        }
    }
}

struct UnrankedProgramRow: View {
    let program: Program
    let reason: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(HospitalNameFormatter.format(
                program.hospital.isEmpty
                    ? (program.name.isEmpty ? "Unnamed Program" : program.name)
                    : program.hospital
            ))
            .font(.arial(size: 15, weight: .semibold))
            .foregroundColor(.primary)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)

            if !program.specialty.isEmpty {
                MatchlyProgramSpecialtyBadge(specialty: program.specialty)
            }

            MatchlyProgramLocationAndIDRow(program: program)

            Text(reason)
                .font(.arial(size: 12, weight: .medium))
                .foregroundColor(AppColors.pipelineToReview)
        }
        .padding(.vertical, 4)
    }
}

struct RankListItemView: View {
    let rank: Int
    let program: Program
    var showsElevatedRedFlag: Bool = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Rank and Score combined on left
            VStack(spacing: 4) {
                // Rank badge
                ZStack {
                    Circle()
                        .fill(rankColor(rank).opacity(0.15))
                        .frame(width: 44, height: 44)
                    
                    VStack(spacing: 2) {
                        Image(systemName: rank <= 3 ? "trophy.fill" : "star.fill")
                            .font(.arial(size: 12))
                            .foregroundColor(rankColor(rank))
                        Text("\(rank)")
                            .font(.arial(size: 18, weight: .bold))
                            .foregroundColor(rankColor(rank))
                    }
                }
                
                // Score - prominent
                VStack(spacing: 1) {
                    Text(String(format: "%.1f", program.finalScore))
                        .font(.arial(size: 18, weight: .bold))
                        .foregroundColor(scoreColor(program.finalScore))
                    Text("pts")
                        .font(.arial(size: 9))
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 50)
            
            // Program info - cleaner, more spacious
            VStack(alignment: .leading, spacing: 6) {
                if showsElevatedRedFlag {
                    HStack(spacing: 5) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.arial(size: 9))
                        Text("Flagged program ranked here")
                            .font(.arial(size: 11, weight: .semibold))
                    }
                    .foregroundColor(.red.opacity(0.88))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.red.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }

                // Hospital name - allow wrapping
                Text(HospitalNameFormatter.format(program.hospital.isEmpty ? (program.name.isEmpty ? "Unnamed Program" : program.name) : program.hospital))
                    .font(.arial(size: 15, weight: .semibold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .fixedSize(horizontal: false, vertical: true)
                
                // Specialty badge (only badge-style element) - matching ProgramsListView
                if !program.specialty.isEmpty {
                    let specialtyColor = SpecialtyFormatter.color(for: program.specialty)
                    let specialtyAbbrev = SpecialtyFormatter.abbreviation(for: program.specialty)
                    
                    HStack(spacing: 3) {
                        Image(systemName: "stethoscope")
                            .font(.arial(size: 8))
                        Text(specialtyAbbrev)
                            .font(.arial(size: 10, weight: .semibold))
                    }
                    .foregroundColor(specialtyColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(specialtyColor.opacity(0.15))
                    .cornerRadius(4)
                }
                
                // Location and Accreditation ID on first row
                HStack(spacing: 10) {
                    // Location
                    if !program.city.isEmpty && !program.state.isEmpty {
                        HStack(spacing: 3) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.arial(size: 10))
                            Text("\(program.city), \(program.state)")
                                .font(.arial(size: 12))
                        }
                        .foregroundColor(.secondary)
                    }
                    
                    // Accreditation ID
                    if let acgmeID = program.accreditationID, !acgmeID.isEmpty {
                        HStack(spacing: 2) {
                            Image(systemName: "number.circle.fill")
                                .font(.arial(size: 10))
                            Text("ID:")
                                .font(.arial(size: 11, weight: .medium))
                            Text(acgmeID)
                                .font(.arial(size: 12, weight: .medium))
                        }
                        .foregroundColor(.secondary)
                    }
                }
                
                SavedProgramIMGBadge(program: program, iconSize: 9, textSize: 11)
                
                // Signal and Red Flags on third row
                HStack(spacing: 10) {
                    // Signal indicator
                    if program.signalType != .none {
                        let isTiered = SignalLimits.isTiered(for: program.specialty)
                        let signalText = isTiered 
                            ? (program.signalType == .gold ? "Gold Signal" : "Silver Signal")
                            : "Signal"
                        let signalColor = isTiered
                            ? (program.signalType == .gold ? Color.yellow : Color(white: 0.6))
                            : Color.blue
                        
                        HStack(spacing: 3) {
                            Image(systemName: program.signalType == .gold ? "star.fill" : "star")
                                .font(.arial(size: 9))
                            Text(signalText)
                                .font(.arial(size: 11, weight: .medium))
                        }
                        .foregroundColor(signalColor)
                    }
                    
                    // Red flag indicator
                    if program.hasRedFlags() {
                        HStack(spacing: 3) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.arial(size: 9))
                            Text("Red Flag")
                                .font(.arial(size: 11, weight: .medium))
                        }
                        .foregroundColor(.red)
                    }

                    ProgramVoiceMemoBadge(program: program, iconSize: 9, textSize: 11)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 10)
        .overlay(alignment: .leading) {
            if showsElevatedRedFlag {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(Color.red.opacity(0.75))
                    .frame(width: 3)
                    .padding(.vertical, 8)
            }
        }
    }
    
}

struct EmptyRankListView: View {
    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                
                Image(systemName: "chart.bar.xaxis")
                .font(.arial(size: 60))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            VStack(spacing: 8) {
            Text("No Programs to Rank")
                    .font(.arial(size: 24, weight: .bold))
            
            Text("Add programs to see your rank list")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
    }
}

struct ExportView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var dataManager: DataManager
    let orderedRankedPrograms: [Program]
    @State private var sharePayload: SharePayload?
    @State private var exportError: String?

    init(orderedRankedPrograms: [Program]) {
        self.orderedRankedPrograms = orderedRankedPrograms
    }

    private var applicantName: String {
        dataManager.preferences.profile.name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var applicantAAMCID: String? {
        let trimmed = dataManager.preferences.profile.aamcID?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private struct SharePayload: Identifiable {
        let id = UUID()
        let items: [Any]
    }

    private var allPrograms: [Program] {
        orderedRankedPrograms
    }

    private func shouldShowSpecialtyHeader(at index: Int) -> Bool {
        let program = orderedRankedPrograms[index]
        guard !program.hasRedFlags() else { return false }
        guard !program.specialty.isEmpty else { return false }
        if index == 0 { return true }
        let previous = orderedRankedPrograms[index - 1]
        if previous.hasRedFlags() { return true }
        return previous.specialty != program.specialty
    }

    private func shouldShowRedFlaggedBanner(at index: Int) -> Bool {
        guard orderedRankedPrograms[index].hasRedFlags() else { return false }
        guard index > 0 else { return false }
        guard !orderedRankedPrograms[index - 1].hasRedFlags() else { return false }
        return orderedRankedPrograms[index...].allSatisfy { $0.hasRedFlags() }
    }

    private func elevatedRedFlag(at index: Int) -> Bool {
        guard orderedRankedPrograms[index].hasRedFlags() else { return false }
        return orderedRankedPrograms[(index + 1)...].contains { !$0.hasRedFlags() }
    }
    
    var rankListText: String {
        var text = "My Residency Rank List"
        if !applicantName.isEmpty {
            text += "\n\(applicantName)"
        }
        if let aamcID = applicantAAMCID {
            text += "\nAAMC ID: \(aamcID)"
        }
        text += "\n\n"
        for (index, program) in allPrograms.enumerated() {
            let hospitalName = HospitalNameFormatter.format(program.hospital.isEmpty ? program.name : program.hospital)
            text += "\(index + 1). \(hospitalName)"
            if let acgmeID = program.accreditationID, !acgmeID.isEmpty {
                text += " (ID: \(acgmeID))"
            }
            if !program.city.isEmpty && !program.state.isEmpty {
                text += " - \(program.city), \(program.state)"
            }
            if !program.specialty.isEmpty {
                text += " - \(program.specialty)"
            }
            text += " (Score: \(String(format: "%.1f", program.finalScore)))\n"
        }
        return text
    }

    private var pdfConfiguration: RankListPDFExporter.Configuration {
        RankListPDFExporter.Configuration(
            orderedPrograms: orderedRankedPrograms,
            applicantName: applicantName.isEmpty ? nil : applicantName,
            aamcID: applicantAAMCID
        )
    }
    var body: some View {
        MatchlyNavigationView {
            VStack(spacing: 24) {
                VStack(spacing: 6) {
                    Text("Share Rank List")
                        .font(.arial(size: 24, weight: .bold))
                    Text("Export a polished PDF for mentors, advisors, or your own records.")
                        .font(.arial(size: 14))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top)

                exportPreviewHeader

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(Array(orderedRankedPrograms.enumerated()), id: \.element.id) { index, program in
                            if shouldShowSpecialtyHeader(at: index) {
                                HStack(spacing: 6) {
                                    Image(systemName: "stethoscope")
                                        .font(.arial(size: 12))
                                        .foregroundColor(SpecialtyFormatter.color(for: program.specialty))
                                    Text(SpecialtyFormatter.displayNameWithAbbreviation(program.specialty))
                                        .font(.arial(size: 13, weight: .semibold))
                                        .foregroundColor(SpecialtyFormatter.color(for: program.specialty))
                                }
                            }

                            if shouldShowRedFlaggedBanner(at: index) {
                                HStack(spacing: 6) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.arial(size: 12))
                                        .foregroundColor(.red)
                                    Text("Red Flagged Programs")
                                        .font(.arial(size: 13, weight: .semibold))
                                        .foregroundColor(.red)
                                }
                                .padding(.top, 4)
                            }

                            RankListItemView(
                                rank: index + 1,
                                program: program,
                                showsElevatedRedFlag: elevatedRedFlag(at: index)
                            )
                        }
                    }
                    .padding()
                    .glassEffect(.regular, in: .rect(cornerRadius: 12))
                    .padding(.horizontal)
                }

                if let exportError {
                    Text(exportError)
                        .font(.arial(size: 13))
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                VStack(spacing: 12) {
                    Button(action: sharePDF) {
                        Label("Share as PDF", systemImage: "doc.richtext")
                            .font(.arial(size: 18, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                    .buttonStyle(.glassProminent)
                    .tint(AppColors.primaryBlue)

                    Button(action: sharePlainText) {
                        Label("Share as Text", systemImage: "text.alignleft")
                            .font(.arial(size: 16, weight: .medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.glass)
                }
                .padding(.horizontal)
                .sheet(item: $sharePayload) { payload in
                    ShareSheet(activityItems: payload.items)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .appCanvasBackground()
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var exportPreviewHeader: some View {
        HStack(alignment: .center, spacing: 14) {
            MatchlyBrandLockup(style: .exportHeader, palette: .onDark)

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 3) {
                if !applicantName.isEmpty {
                    Text(applicantName)
                        .font(.arial(size: 13, weight: .medium))
                        .foregroundColor(.white)
                }
                if let aamcID = applicantAAMCID {
                    Text("AAMC ID \(aamcID)")
                        .font(.arial(size: 10, weight: .regular))
                        .foregroundColor(.white.opacity(0.82))
                        .kerning(0.8)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppColors.primaryGradient)
        )
        .padding(.horizontal)
    }

    private func sharePDF() {
        exportError = nil
        guard let url = RankListPDFExporter.generatePDF(configuration: pdfConfiguration) else {
            exportError = "Couldn't create the PDF. Try again or use Share as Text."
            return
        }
        sharePayload = SharePayload(items: [url])
    }

    private func sharePlainText() {
        exportError = nil
        sharePayload = SharePayload(items: [rankListText])
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    RankListView()
        .environmentObject(DataManager.shared)
}

