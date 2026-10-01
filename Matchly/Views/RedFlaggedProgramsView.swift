//
//  RedFlaggedProgramsView.swift
//  Matchly
//
//  Created on 11/22/25.
//

import SwiftUI
import Combine

struct RedFlaggedProgramsView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var sortOption: SortOption = .name
    @State private var isEditMode = false
    @State private var selectedPrograms = Set<String>()
    
    enum SortOption: String, CaseIterable {
        case name = "Name"
        case score = "Score"
        case location = "Location"
        case specialty = "Specialty"
    }
    
    // Get all programs with red flags
    private var redFlaggedPrograms: [Program] {
        dataManager.programs.filter { $0.hasRedFlags() }
    }
    
    var body: some View {
        Group {
            if redFlaggedPrograms.isEmpty {
                // Empty state
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.arial(size: 48))
                        .foregroundColor(.green)
                    
                    Text("No Red Flags")
                        .font(.arial(size: 18, weight: .semibold))
                    
                    Text("All your programs are clear of red flags")
                        .font(.arial(size: 14))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 60)
                .glassCardStyle(cornerRadius: 20)
            } else {
                // Group programs by specialty
                let groupedPrograms = Dictionary(grouping: sortedPrograms) { $0.specialty }
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
                .scrollContentBackground(.hidden)
                .appCanvasBackground()
                .padding(.bottom, 90) // Space for custom tab bar
                .refreshable {
                    dataManager.recalculateAllScores()
                    dataManager.objectWillChange.send()
                }
            }
        }
        .appCanvasBackground()
        .navigationTitle("Red Flagged Programs")
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
                    // Edit button
                    Button(action: {
                        isEditMode = true
                    }) {
                        Text("Edit")
                    }
                }
            }
        }
        .onAppear {
            // Refresh when view appears to ensure latest scores are shown
            dataManager.objectWillChange.send()
            // Invalidate cache to force recalculation
            cachedSortedPrograms = []
            lastSortOption = nil
            lastProgramsCount = 0
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
        let currentCount = redFlaggedPrograms.count
        if sortOption != lastSortOption || currentCount != lastProgramsCount {
            var programs = redFlaggedPrograms
            
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
        var programs = redFlaggedPrograms
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

#Preview {
    MatchlyNavigationView {
        RedFlaggedProgramsView()
            .environmentObject(DataManager.shared)
    }
}














