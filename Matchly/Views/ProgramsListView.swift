//
//  ProgramsListView.swift
//  Matchly
//
//  Created by Leoh N. Leon II on 11/14/25.
//

import SwiftUI
import Combine

struct ProgramsListView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var showAddProgram = false
    @State private var sortOption: SortOption = .name
    @State private var isEditMode = false
    @State private var selectedPrograms = Set<String>()
    
    enum SortOption: String, CaseIterable {
        case name = "Name"
        case score = "Score"
        case location = "Location"
        case specialty = "Specialty"
    }
    
    var body: some View {
        MatchlyNavigationView {
            Group {
                if dataManager.programs.isEmpty {
                    EmptyProgramsView(showAddProgram: $showAddProgram)
                        .matchlyRootContentFrame()
                } else {
                    // Group programs by specialty
                    let groupedPrograms = Dictionary(grouping: sortedPrograms) {
                        SpecialtyFormatter.normalizedUserSpecialty($0.specialty)
                    }
                    let sortedSpecialties = groupedPrograms.keys.sorted()
                    
                    List {
                        ForEach(sortedSpecialties, id: \.self) { specialty in
                            Section(header: 
                                HStack(spacing: 6) {
                                    Image(systemName: "stethoscope")
                                        .font(.arial(size: 12))
                                        .foregroundColor(SpecialtyFormatter.color(for: specialty))
                                    Text("\(specialty) (\(SpecialtyFormatter.abbreviation(for: specialty)))")
                                        .font(.arial(size: 13, weight: .semibold))
                                }
                                .foregroundColor(.secondary)
                            ) {
                                ForEach(groupedPrograms[specialty] ?? []) { program in
                                    if isEditMode {
                                        HStack {
                                            Button(action: {
                                                if selectedPrograms.contains(program.id) {
                                                    selectedPrograms.remove(program.id)
                                                } else {
                                                    selectedPrograms.insert(program.id)
                                                }
                                            }) {
                                                Image(systemName: selectedPrograms.contains(program.id) ? "checkmark.circle.fill" : "circle")
                                                    .foregroundColor(selectedPrograms.contains(program.id) ? .blue : .gray)
                                                    .font(.arial(size: 22))
                                            }
                                            .buttonStyle(.plain)
                                            
                                            CompactProgramRowView(program: program)
                                        }
                                    } else {
                                        NavigationLink(destination: ProgramEntryView(program: program)) {
                                            CompactProgramRowView(program: program)
                                        }
                                    }
                                }
                                .onDelete { offsets in
                                    deleteProgramsInSpecialty(specialty, at: offsets, from: groupedPrograms[specialty] ?? [])
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .matchlyReadableWidth()
                    .matchlyScrollTabBarClearance()
                    .refreshable {
                        dataManager.recalculateAllScores()
                        dataManager.objectWillChange.send()
                    }
                }
            }
            .matchlyRootContentFrame()
            .navigationTitle("My Programs")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        ForEach(SortOption.allCases, id: \.self) { option in
                            Button(action: {
                                sortOption = option
                            }) {
                                HStack {
                                    Text(option.rawValue)
                                    if sortOption == option {
                                        Spacer()
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.arrow.down")
                                .font(.arial(size: 14))
                            Text("Sort")
                                .font(.arial(size: 15))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .glassEffect(.regular.interactive(), in: .capsule)
                    }
                }
                
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    if isEditMode {
                        // Delete selected programs
                        Button(action: {
                            for programId in selectedPrograms {
                                if let program = dataManager.programs.first(where: { $0.id == programId }) {
                                    dataManager.deleteProgram(program)
                                }
                            }
                            selectedPrograms.removeAll()
                            isEditMode = false
                        }) {
                            Image(systemName: "trash.fill")
                                .foregroundColor(selectedPrograms.isEmpty ? .gray : .red)
                        }
                        .disabled(selectedPrograms.isEmpty)
                        
                        // Done button
                        Button("Done") {
                            isEditMode = false
                            selectedPrograms.removeAll()
                        }
                    } else {
                        NavigationLink(destination: ProgramsMapView()) {
                            Image(systemName: "map.fill")
                                .font(.arial(size: 18))
                                .foregroundColor(.blue)
                                .frame(width: 36, height: 36)
                                .glassCircleButtonStyle()
                        }
                        
                        Button(action: {
                            showAddProgram = true
                        }) {
                            Image(systemName: "plus")
                                .font(.arial(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 36, height: 36)
                                .glassEffect(.regular.tint(AppColors.primaryBlue.opacity(0.35)).interactive(), in: .circle)
                        }
                        
                        // Edit button
                        Button(action: {
                            isEditMode = true
                        }) {
                            Text("Edit")
                        }
                    }
                }
            }
            .sheet(isPresented: $showAddProgram) {
                ProgramSearchView(
                    onSelect: { _ in },
                    allowMultiSelect: true
                )
            }
            .onAppear {
                // Refresh when view appears to ensure latest scores are shown
                dataManager.objectWillChange.send()
                // Invalidate cache to force recalculation
                cachedSortedPrograms = []
                lastSortOption = nil
                lastProgramsCount = 0
            }
            .appCanvasBackground()
        }
    }
    
    private func deletePrograms(at offsets: IndexSet) {
        for index in offsets {
            dataManager.deleteProgram(dataManager.programs[index])
        }
    }
    
    private func deleteProgramsInSpecialty(_ specialty: String, at offsets: IndexSet, from programs: [Program]) {
        for index in offsets {
            dataManager.deleteProgram(programs[index])
        }
    }
    
    // Cache sorted programs to avoid recalculating on every view update
    @State private var cachedSortedPrograms: [Program] = []
    @State private var lastSortOption: SortOption?
    @State private var lastProgramsCount: Int = 0
    
    private var sortedPrograms: [Program] {
        // Only recalculate if sort option changed or programs changed
        let currentCount = dataManager.programs.count
        if sortOption != lastSortOption || currentCount != lastProgramsCount {
            var programs = dataManager.programs
            
            switch sortOption {
            case .name:
                programs = programs.sorted { 
                    HospitalNameFormatter.format($0.hospital) < HospitalNameFormatter.format($1.hospital)
                }
            case .score:
                programs = programs.sorted { $0.finalScore > $1.finalScore }
            case .location:
                programs = programs.sorted {
                    if $0.state != $1.state {
                        return $0.state < $1.state
                    }
                    return $0.city < $1.city
                }
            case .specialty:
                programs = programs.sorted { $0.specialty < $1.specialty }
            }
            
            // Update cache asynchronously to avoid blocking UI
            DispatchQueue.main.async {
                cachedSortedPrograms = programs
                lastSortOption = sortOption
                lastProgramsCount = currentCount
            }
            
            return programs
        }
        
        // Return cached result if available, otherwise calculate
        if !cachedSortedPrograms.isEmpty && cachedSortedPrograms.count == currentCount {
            return cachedSortedPrograms
        }
        
        // Fallback: calculate if cache is invalid
        var programs = dataManager.programs
        switch sortOption {
        case .name:
            programs = programs.sorted { 
                HospitalNameFormatter.format($0.hospital) < HospitalNameFormatter.format($1.hospital)
            }
        case .score:
            programs = programs.sorted { $0.finalScore > $1.finalScore }
        case .location:
            programs = programs.sorted {
                if $0.state != $1.state {
                    return $0.state < $1.state
                }
                return $0.city < $1.city
            }
        case .specialty:
            programs = programs.sorted { $0.specialty < $1.specialty }
        }
        return programs
    }
}

struct CompactProgramRowView: View {
    let program: Program
    
    var body: some View {
        HStack(spacing: 12) {
            // Score indicator with icon - smaller
            ZStack {
                Circle()
                    .fill(scoreColor(program.finalScore).opacity(0.15))
                    .frame(width: 42, height: 42)
                
                VStack(spacing: 0) {
                    Image(systemName: "star.fill")
                        .font(.arial(size: 9))
                        .foregroundColor(scoreColor(program.finalScore))
                    Text(String(format: "%.0f", program.finalScore))
                        .font(.arial(size: 15, weight: .bold))
                        .foregroundColor(scoreColor(program.finalScore))
                }
            }
            
            // Program info - EXACT same layout as ProgramSearchRowView
            VStack(alignment: .leading, spacing: 3) {
                // Hospital name
                Text(HospitalNameFormatter.format(program.hospital.isEmpty ? (program.name.isEmpty ? "Unnamed Program" : program.name) : program.hospital))
                    .font(.arial(size: 15, weight: .semibold))
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                
                // Specialty badge (only badge-style element) - matching search
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
                
                // Location and Accreditation ID on first line - EXACT match to search
                HStack(spacing: 8) {
                    // Location
                    if !program.city.isEmpty && !program.state.isEmpty {
                        HStack(spacing: 3) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.arial(size: 9))
                            Text("\(program.city), \(program.state)")
                                .font(.arial(size: 11))
                        }
                        .foregroundColor(.secondary)
                    }
                    
                    // Accreditation ID - subtle, no background (matching search exactly)
                    if let acgmeID = program.accreditationID, !acgmeID.isEmpty {
                        HStack(spacing: 2) {
                            Image(systemName: "number.circle.fill")
                                .font(.arial(size: 9))
                            Text("ID:")
                                .font(.arial(size: 10, weight: .medium))
                            Text(acgmeID)
                                .font(.arial(size: 11, weight: .medium))
                        }
                        .foregroundColor(.secondary)
                    }
                }
                
                // Program Type and IMG on second line
                HStack(spacing: 8) {
                    // Program Type - full text, not abbreviated (matching search)
                    if !program.type.isEmpty {
                        HStack(spacing: 3) {
                            Image(systemName: programTypeIcon(program.type))
                                .font(.arial(size: 8))
                            Text(program.type)
                                .font(.arial(size: 10, weight: .medium))
                        }
                        .foregroundColor(programTypeColor(program.type))
                    }
                    
                    SavedProgramIMGBadge(program: program)
                }
                
                // Signal and Red Flags on third line
                HStack(spacing: 8) {
                    // Signal indicator - clear tag showing signal type
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
                                .font(.arial(size: 8))
                            Text(signalText)
                                .font(.arial(size: 10, weight: .medium))
                        }
                        .foregroundColor(signalColor)
                    }
                    
                    // Red flag indicator
                    if program.hasRedFlags() {
                        HStack(spacing: 3) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.arial(size: 8))
                            Text("Red Flag")
                                .font(.arial(size: 10, weight: .medium))
                        }
                        .foregroundColor(.red)
                    }
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 6)
    }
    
}

struct EmptyProgramsView: View {
    @Binding var showAddProgram: Bool
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 0)
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
                
                Image(systemName: "heart.text.square.fill")
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
                Text("No Programs Yet")
                    .font(.arial(size: 24, weight: .bold))
                
                Text("Add your first residency program to get started")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Button(action: {
                showAddProgram = true
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.arial(size: 18))
                    Text("Add Program")
                        .font(.arial(size: 17, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 32)
                .padding(.vertical, 14)
            }
            .buttonStyle(.glassProminent)
            .tint(AppColors.primaryBlue)
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
    }
}

#Preview {
    ProgramsListView()
        .environmentObject(DataManager.shared)
}

