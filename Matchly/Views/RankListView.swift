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
    @State private var showInterviewFilter = false
    @State private var filterInterviewed = false
    @State private var selectedSpecialties: Set<String> = []
    @State private var showAllSpecialties: Bool = true
    
    enum SortOption: String, CaseIterable {
        case score = "Score"
        case name = "Name"
        case location = "Location"
        case interviewDate = "Interview Date"
    }
    
    // Cache ranked programs to avoid expensive recalculations
    @State private var cachedRankedPrograms: [Program] = []
    @State private var lastCacheKey: String = ""
    
    var rankedPrograms: [Program] {
        // Create cache key from all dependencies
        let specialtiesKey = selectedSpecialties.sorted().joined(separator: ",")
        let includeRedFlags = dataManager.preferences.includeRedFlaggedProgramsInRankList
        let cacheKey = "\(manualOrder.count)-\(showAllSpecialties)-\(specialtiesKey)-\(filterInterviewed)-\(sortOption.rawValue)-\(dataManager.programs.count)-\(includeRedFlags)"
        
        // Return cached result if nothing changed
        if cacheKey == lastCacheKey && !cachedRankedPrograms.isEmpty && cachedRankedPrograms.count == dataManager.programs.count {
            return cachedRankedPrograms
        }
        
        var programs: [Program]
        
        if manualOrder.isEmpty {
            // Start with all programs, sorted by score (highest first)
            programs = dataManager.programs.sorted { $0.finalScore > $1.finalScore }
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
            let sortedByScore = dataManager.programs.sorted(by: { $0.finalScore > $1.finalScore })
            for program in sortedByScore {
                if !manualIds.contains(program.id) {
                    ordered.append(program)
                }
            }
            programs = ordered
        }
        
        // Apply specialty filter (only if user has explicitly selected specialties)
        if !showAllSpecialties && !selectedSpecialties.isEmpty {
            programs = programs.filter { selectedSpecialties.contains($0.specialty) }
        }
        // If showAllSpecialties is true OR selectedSpecialties is empty, show all programs
        
        // Apply interview filter
        if filterInterviewed {
            programs = programs.filter { $0.interviewDate != nil }
        }
        
        // Filter out red flagged programs from main list (they'll be shown separately at bottom if enabled)
        if includeRedFlags {
            // Filter out red flagged programs from main list - they'll be shown at bottom
            programs = programs.filter { !$0.hasRedFlags() }
        } else {
            // Filter out red flagged programs completely
            programs = programs.filter { !$0.hasRedFlags() }
        }
        
        // Apply sorting (only if not using manual order)
        if manualOrder.isEmpty {
            switch sortOption {
            case .score:
                programs = programs.sorted { $0.finalScore > $1.finalScore }
            case .name:
                programs = programs.sorted { HospitalNameFormatter.format($0.hospital) < HospitalNameFormatter.format($1.hospital) }
            case .location:
                programs = programs.sorted { 
                    if $0.state != $1.state {
                        return $0.state < $1.state
                    }
                    return $0.city < $1.city
                }
            case .interviewDate:
                programs = programs.sorted {
                    guard let date1 = $0.interviewDate, let date2 = $1.interviewDate else {
                        if $0.interviewDate != nil { return true }
                        if $1.interviewDate != nil { return false }
                        return $0.finalScore > $1.finalScore
                    }
                    return date1 < date2
                }
            }
        }
        
        // Cache the result asynchronously
        DispatchQueue.main.async {
            cachedRankedPrograms = programs
            lastCacheKey = cacheKey
        }
        
        return programs
    }
    
    // Get red flagged programs separately (for bottom section)
    private var redFlaggedPrograms: [Program] {
        var programs = dataManager.programs.filter { $0.hasRedFlags() }
        
        // Apply specialty filter
        if !showAllSpecialties && !selectedSpecialties.isEmpty {
            programs = programs.filter { selectedSpecialties.contains($0.specialty) }
        }
        
        // Apply interview filter
        if filterInterviewed {
            programs = programs.filter { $0.interviewDate != nil }
        }
        
        // Sort by score (highest first)
        return programs.sorted { $0.finalScore > $1.finalScore }
    }
    
    private var allSpecialties: [String] {
        Array(Set(dataManager.programs.map { $0.specialty })).sorted()
    }
    
    var body: some View {
        NavigationView {
            Group {
                if rankedPrograms.isEmpty {
                    EmptyRankListView()
                } else {
                    VStack(spacing: 0) {
                        // Sort and filter options
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                // Specialty filter
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
                                    HStack(spacing: 6) {
                                        Image(systemName: "stethoscope")
                                            .font(.system(size: 11))
                                            .foregroundColor(.blue)
                                        Text(showAllSpecialties ? "All" : "\(selectedSpecialties.count)")
                                            .font(.system(size: 12, weight: .medium))
                                        Image(systemName: "chevron.down")
                                            .font(.system(size: 9))
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(!showAllSpecialties && !selectedSpecialties.isEmpty ? Color.blue.opacity(0.15) : Color(.systemGray5))
                                    .cornerRadius(8)
                                }
                                
                                Menu {
                                    ForEach(SortOption.allCases, id: \.self) { option in
                                        Button(action: {
                                            sortOption = option
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
                                    HStack(spacing: 6) {
                                        Image(systemName: "arrow.up.arrow.down")
                                            .font(.system(size: 11))
                                        Text("Sort: \(sortOption.rawValue)")
                                            .font(.system(size: 12, weight: .medium))
                                        Image(systemName: "chevron.down")
                                            .font(.system(size: 9))
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color(.systemGray5))
                                    .cornerRadius(8)
                                }
                                
                                Spacer()
                                
                                Text("\(rankedPrograms.count) programs")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 4)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        
                        // Separate regular and red flagged programs
                        let regularPrograms = rankedPrograms.filter { !$0.hasRedFlags() }
                        let redFlagged = dataManager.preferences.includeRedFlaggedProgramsInRankList ? redFlaggedPrograms : []
                        
                        // Group regular programs by specialty
                        let groupedPrograms = Dictionary(grouping: regularPrograms) { $0.specialty }
                        let sortedSpecialties = groupedPrograms.keys.sorted()
                        
                        // Group red flagged programs by specialty
                        let groupedRedFlagged = Dictionary(grouping: redFlagged) { $0.specialty }
                        let sortedRedFlaggedSpecialties = groupedRedFlagged.keys.sorted()
                        
                    List {
                            // Regular programs by specialty
                            ForEach(sortedSpecialties, id: \.self) { specialty in
                                Section(header: 
                                    HStack(spacing: 6) {
                                        Image(systemName: "stethoscope")
                                            .font(.system(size: 12))
                                            .foregroundColor(SpecialtyFormatter.color(for: specialty))
                                        Text("\(specialty) (\(SpecialtyFormatter.abbreviation(for: specialty)))")
                                            .font(.system(size: 13, weight: .semibold))
                                    }
                                    .foregroundColor(.secondary)
                                ) {
                                    ForEach(Array(groupedPrograms[specialty] ?? []), id: \.id) { program in
                                        NavigationLink(destination: ProgramEntryView(program: program)) {
                            RankListItemView(
                                                rank: (regularPrograms.firstIndex(where: { $0.id == program.id }) ?? 0) + 1,
                                program: program
                            )
                                        }
                                    }
                                    .onMove { source, destination in
                                        // Handle move within specialty
                                        moveProgramsInSpecialty(specialty, from: source, to: destination, in: groupedPrograms[specialty] ?? [])
                                    }
                                }
                            }
                            
                            // Red Flagged Programs section at bottom (if enabled and there are any)
                            if !redFlagged.isEmpty {
                                Section(header:
                                    HStack(spacing: 6) {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .font(.system(size: 12))
                                            .foregroundColor(.red)
                                        Text("Red Flagged Programs")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(.red)
                                    }
                                ) {
                                    ForEach(sortedRedFlaggedSpecialties, id: \.self) { specialty in
                                        ForEach(Array(groupedRedFlagged[specialty] ?? []), id: \.id) { program in
                                            NavigationLink(destination: ProgramEntryView(program: program)) {
                                                RankListItemView(
                                                    rank: regularPrograms.count + (redFlagged.firstIndex(where: { $0.id == program.id }) ?? 0) + 1,
                                                    program: program
                                                )
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .listStyle(.insetGrouped)
                        .padding(.bottom, 90) // Space for custom tab bar
                        .environment(\.editMode, isEditing ? .constant(.active) : .constant(.inactive))
                    }
                }
            }
            .navigationTitle("Rank List")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if !rankedPrograms.isEmpty {
                        HStack {
                            Button(action: {
                                isEditing.toggle()
                            }) {
                                Text(isEditing ? "Done" : "Edit")
                            }
                            
                            if !manualOrder.isEmpty {
                                Button(action: {
                                    // Reset to score-based ordering
                                    manualOrder = []
                                    saveManualOrder()
                                }) {
                                    Text("Reset")
                                        .font(.caption)
                                }
                            }
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !rankedPrograms.isEmpty {
                        HStack(spacing: 16) {
                            NavigationLink(destination: ProgramComparisonView()) {
                                Image(systemName: "square.grid.2x2")
                            }
                            
                        Button(action: {
                            showExportSheet = true
                        }) {
                            Image(systemName: "square.and.arrow.up")
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showExportSheet) {
                ExportView(programs: rankedPrograms)
            }
            .onAppear {
                loadManualOrder()
                // Show all programs by default - don't filter by specialty preferences
                // User can manually filter if they want
                showAllSpecialties = true
                selectedSpecialties = []
            }
        }
    }
    
    private func movePrograms(from source: IndexSet, to destination: Int) {
        var programs = rankedPrograms
        programs.move(fromOffsets: source, toOffset: destination)
        manualOrder = programs.map { $0.id }
        saveManualOrder()
    }
    
    private func moveProgramsInSpecialty(_ specialty: String, from source: IndexSet, to destination: Int, in specialtyPrograms: [Program]) {
        // Get all programs in order
        let allPrograms = rankedPrograms
        // Find the specialty section
        _ = allPrograms.firstIndex(where: { $0.specialty == specialty }) ?? 0
        // Move within specialty
        var specialtyList = specialtyPrograms
        specialtyList.move(fromOffsets: source, toOffset: destination)
        // Rebuild full list
        var newOrder: [Program] = []
        var specialtyIndex = 0
        for (_, program) in allPrograms.enumerated() {
            if program.specialty == specialty {
                if specialtyIndex < specialtyList.count {
                    newOrder.append(specialtyList[specialtyIndex])
                    specialtyIndex += 1
                }
            } else {
                newOrder.append(program)
            }
        }
        manualOrder = newOrder.map { $0.id }
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

struct RankListItemView: View {
    let rank: Int
    let program: Program
    
    var body: some View {
        HStack(spacing: 12) {
            // Rank number with icon - smaller
            ZStack {
                Circle()
                    .fill(rankColor(rank).opacity(0.15))
                    .frame(width: 40, height: 40)
                
                VStack(spacing: 0) {
                    Image(systemName: rank <= 3 ? "trophy.fill" : "star.fill")
                        .font(.system(size: 10))
                        .foregroundColor(rankColor(rank))
                Text("\(rank)")
                        .font(.system(size: 16, weight: .bold))
                    .foregroundColor(rankColor(rank))
                }
            }
            
            // Program info - more compact, similar to ProgramsListView
            VStack(alignment: .leading, spacing: 4) {
                // Hospital name with signal indicator and red flag - single line, no wrapping
                HStack(spacing: 6) {
                    Text(HospitalNameFormatter.format(program.hospital.isEmpty ? (program.name.isEmpty ? "Unnamed Program" : program.name) : program.hospital))
                        .font(.system(size: 15, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    
                    // Red flag indicator
                    if program.hasRedFlags() {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.red)
                    }
                    
                    // Signal indicator - subtle
                    if program.signalType != .none {
                        Image(systemName: program.signalType == .gold ? "star.fill" : "star")
                            .font(.system(size: 11))
                            .foregroundColor(program.signalType == .gold ? .yellow : .gray)
                    }
                }
                
                // Metadata - wrap properly
                VStack(alignment: .leading, spacing: 3) {
                    // First row: Location and Type
                    HStack(spacing: 8) {
                if !program.city.isEmpty && !program.state.isEmpty {
                            HStack(spacing: 3) {
                                Image(systemName: "mappin.circle.fill")
                                    .font(.system(size: 9))
                    Text("\(program.city), \(program.state)")
                                    .font(.system(size: 11))
                            }
                        .foregroundColor(.secondary)
                            .lineLimit(1)
                        }
                        
                        if !program.type.isEmpty {
                            HStack(spacing: 3) {
                                Image(systemName: programTypeIcon(program.type))
                                    .font(.system(size: 8))
                                Text(program.type)
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .foregroundColor(programTypeColor(program.type))
                            .lineLimit(1)
                        }
                    }
                    
                    // Second row: Interview date (if exists) or Signal
                    if let interviewDate = program.interviewDate {
                        HStack(spacing: 3) {
                            Image(systemName: "calendar.badge.clock")
                                .font(.system(size: 9))
                            Text(interviewDate, style: .date)
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(.blue)
                        .lineLimit(1)
                    } else if program.signalType != .none {
                        HStack(spacing: 3) {
                            Image(systemName: program.signalType.icon)
                                .font(.system(size: 9))
                            Text(program.signalType == .gold ? "Gold Signal" : "Silver Signal")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(program.signalType == .gold ? .yellow : .gray)
                        .lineLimit(1)
                    }
                }
            }
            
            Spacer(minLength: 8)
            
            // Score with icon - smaller
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 3) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 10))
                        .foregroundColor(scoreColor(program.finalScore))
                Text(String(format: "%.1f", program.finalScore))
                        .font(.system(size: 16, weight: .bold))
                    .foregroundColor(scoreColor(program.finalScore))
                }
                
                Text("pts")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
    
    private func rankColor(_ rank: Int) -> Color {
        if rank <= 3 { return .green }
        if rank <= 10 { return .blue }
        return .gray
    }
    
    private func scoreColor(_ score: Double) -> Color {
        if score >= 80 { return .green }
        if score >= 60 { return .blue }
        if score >= 40 { return .orange }
        return .red
    }
    
    private func programTypeColor(_ type: String) -> Color {
        switch type {
        case "Academic": return .blue
        case "Community": return .green
        case "Hybrid": return .orange
        default: return .secondary
        }
    }
    
    private func programTypeIcon(_ type: String) -> String {
        switch type {
        case "Academic": return "graduationcap.fill"
        case "Community": return "house.fill"
        case "Hybrid": return "square.stack.3d.up.fill"
        default: return "building.2.fill"
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
                .font(.system(size: 60))
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
                    .font(.system(size: 24, weight: .bold))
            
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
    let programs: [Program]
    @State private var showShareSheet = false
    
    var rankListText: String {
        var text = "My Residency Rank List\n\n"
        for (index, program) in programs.enumerated() {
            text += "\(index + 1). \(program.name.isEmpty ? "Unnamed Program" : program.name)"
            if !program.city.isEmpty && !program.state.isEmpty {
                text += " - \(program.city), \(program.state)"
            }
            text += " (Score: \(String(format: "%.1f", program.finalScore)))\n"
        }
        return text
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Text("Export Rank List")
                    .font(.system(size: 24, weight: .bold))
                    .padding(.top)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(Array(programs.enumerated()), id: \.element.id) { index, program in
                            HStack {
                                Text("\(index + 1).")
                                    .font(.system(size: 16, weight: .semibold))
                                    .frame(width: 40)
                                
                                Text(program.name.isEmpty ? "Unnamed Program" : program.name)
                                    .font(.system(size: 16))
                                
                                Spacer()
                                
                                Text(String(format: "%.1f", program.finalScore))
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
                
                Button(action: {
                    showShareSheet = true
                }) {
                    Text("Share Rank List")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                .sheet(isPresented: $showShareSheet) {
                    ShareSheet(activityItems: [rankListText])
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
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

