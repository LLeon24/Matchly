//
//  ProgramSearchView.swift
//  Matchly
//
//  Created by Leoh N. Leon II on 11/14/25.
//

import SwiftUI

struct ProgramSearchView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var dataManager: DataManager
    @State private var searchText = ""
    @State private var selectedStates: Set<String> = []
    @State private var showAllStates: Bool = true
    @State private var showStateFilter: Bool = false
    @State private var tempSelectedStates: Set<String> = []
    @State private var tempShowAllStates: Bool = true
    @State private var selectedProgramTypes: Set<String> = []
    @State private var showAllProgramTypes: Bool = true
    @State private var showProgramTypeFilter: Bool = false
    @State private var tempSelectedProgramTypes: Set<String> = [] // Temporary selections while sheet is open
    @State private var tempShowAllProgramTypes: Bool = true
    @State private var selectedPrograms: Set<String> = []
    @State private var selectedSpecialties: Set<String> = []
    @State private var showAllSpecialties: Bool = false // Track if user explicitly wants all
    @State private var showSpecialtyFilter: Bool = false
    @State private var tempSelectedSpecialties: Set<String> = [] // Temporary selections while sheet is open
    @State private var tempShowAllSpecialties: Bool = true
    
    let onSelect: (ResidencyProgramInfo) -> Void
    var allowMultiSelect: Bool = false
    
    private var database = ResidencyProgramDatabase.shared
    
    // All available specialties
    private let allSpecialties = [
        "Internal Medicine", "Family Medicine", "Emergency Medicine", "Pediatrics",
        "General Surgery", "OB/GYN", "Psychiatry", "Neurology", "Anesthesiology",
        "Radiology", "Pathology", "Orthopedics", "ENT", "Urology", "PM&R",
        "Dermatology", "Neurosurgery", "Child Neurology", "Nuclear Medicine",
        "Radiation Oncology", "Plastic Surgery", "Ophthalmology", "Interventional Radiology - Integrated",
        "Thoracic Surgery - Integrated", "Vascular Surgery - Integrated", "Transitional Year",
        "Aerospace Medicine", "Occupational and Environmental Medicine",
        "Public Health and General Preventive Medicine", "Osteopathic Neuromusculoskeletal Medicine"
    ]
    
    // All US states for filter
    private let allStates = [
        "All", "AL", "AK", "AZ", "AR", "CA", "CO", "CT", "DE", "FL", "GA", "HI", "ID",
        "IL", "IN", "IA", "KS", "KY", "LA", "ME", "MD", "MA", "MI", "MN", "MS", "MO",
        "MT", "NE", "NV", "NH", "NJ", "NM", "NY", "NC", "ND", "OH", "OK", "OR", "PA",
        "RI", "SC", "SD", "TN", "TX", "UT", "VT", "VA", "WA", "WV", "WI", "WY", "DC", "PR"
    ]
    
    private let programTypes = ["Academic", "Community", "Hybrid"]
    
    init(onSelect: @escaping (ResidencyProgramInfo) -> Void, allowMultiSelect: Bool = false) {
        self.onSelect = onSelect
        self.allowMultiSelect = allowMultiSelect
    }
    
    // Cache search results to avoid recalculating on every view update
    @State private var cachedSearchResults: [ResidencyProgramInfo] = []
    @State private var lastSearchCacheKey: String = ""
    
    private var searchResults: [ResidencyProgramInfo] {
        // Create cache key from all search parameters
        let specialtiesKey = showAllSpecialties ? "all" : (selectedSpecialties.isEmpty ? "prefs" : selectedSpecialties.sorted().joined(separator: ","))
        let typesKey = showAllProgramTypes ? "all" : selectedProgramTypes.sorted().joined(separator: ",")
        let statesKey = showAllStates ? "all" : selectedStates.sorted().joined(separator: ",")
        let cacheKey = "\(searchText)-\(specialtiesKey)-\(typesKey)-\(statesKey)"
        
        // Return cached result if search parameters haven't changed
        if cacheKey == lastSearchCacheKey && !cachedSearchResults.isEmpty {
            return cachedSearchResults
        }
        
        // Determine which specialties to use
        let specialtiesToUse: [String]?
        if showAllSpecialties || (selectedSpecialties.isEmpty && dataManager.preferences.specialties.isEmpty) {
            specialtiesToUse = nil // Show all
        } else if !selectedSpecialties.isEmpty {
            specialtiesToUse = Array(selectedSpecialties) // User's explicit selection
        } else {
            specialtiesToUse = dataManager.preferences.specialties // Use preferences
        }
        
        // Determine which program types to use
        let programTypesToUse: [String]?
        if showAllProgramTypes || selectedProgramTypes.isEmpty {
            programTypesToUse = nil // Show all
        } else {
            programTypesToUse = Array(selectedProgramTypes)
        }
        
        // Use stateFilters (Set) if states are selected, otherwise nil
        let stateFilters: Set<String>? = {
            if showAllStates || selectedStates.isEmpty {
                return nil
            } else {
                return selectedStates
            }
        }()
        
        let results = database.search(
            query: searchText,
            specialty: nil,
            specialties: specialtiesToUse,
            stateFilter: nil, // Use stateFilters instead
            stateFilters: stateFilters,
            programTypeFilter: nil, // Use programTypes instead
            programTypes: programTypesToUse,
            imgFriendlyOnly: false // IMG-Friendly is now handled via programTypes
        )
        
        // Cache the results asynchronously
        DispatchQueue.main.async {
            cachedSearchResults = results
            lastSearchCacheKey = cacheKey
        }
        
        return results
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                searchAndFiltersView
                resultsView
            }
            .navigationTitle("Search Programs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    EmptyView()
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                if !dataManager.preferences.specialties.isEmpty {
                    selectedSpecialties = Set(dataManager.preferences.specialties)
                }
            }
        }
    }
    
    private var searchAndFiltersView: some View {
        VStack(spacing: 12) {
            searchBarView
            filtersView
        }
        .padding(.horizontal)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }
    
    private var searchBarView: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.blue)
                .font(.system(size: 16))
            TextField("Search programs...", text: $searchText)
                .textFieldStyle(.plain)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .font(.system(size: 16))
            
            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary.opacity(0.6))
                        .font(.system(size: 16))
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.03), radius: 1, x: 0, y: 1)
    }
    
    private var filtersView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            // Specialty filter - sheet-based like program types
                            Button(action: {
                                // Initialize temp selections from current state
                                tempSelectedSpecialties = selectedSpecialties.isEmpty && !showAllSpecialties
                                    ? Set(dataManager.preferences.specialties)
                                    : selectedSpecialties
                                tempShowAllSpecialties = showAllSpecialties
                                showSpecialtyFilter = true
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "stethoscope")
                                        .font(.system(size: 13))
                                        .foregroundColor(.blue)
                                    
                                    let displayText: String = {
                                        if showAllSpecialties {
                                            return "All"
                                        } else if !selectedSpecialties.isEmpty {
                                            return "\(selectedSpecialties.count)"
                                        } else if !dataManager.preferences.specialties.isEmpty {
                                            return "\(dataManager.preferences.specialties.count)"
                                        } else {
                                            return "All"
                                        }
                                    }()
                                    
                                    Text(displayText)
                                        .font(.system(size: 12, weight: .medium))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                    
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 9))
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background({
                                    let hasSelection = !showAllSpecialties && (!selectedSpecialties.isEmpty || !dataManager.preferences.specialties.isEmpty)
                                    return hasSelection 
                                        ? Color.blue.opacity(0.12) 
                                        : Color(.systemGray5)
                                }())
                                .cornerRadius(7)
                            }
                            .sheet(isPresented: $showSpecialtyFilter) {
                                SpecialtyFilterSheet(
                                    allSpecialties: allSpecialties,
                                    selectedSpecialties: $tempSelectedSpecialties,
                                    showAll: $tempShowAllSpecialties,
                                    onApply: {
                                        selectedSpecialties = tempSelectedSpecialties
                                        showAllSpecialties = tempShowAllSpecialties
                                        showSpecialtyFilter = false
                                    },
                                    onClear: {
                                        tempSelectedSpecialties.removeAll()
                                        tempShowAllSpecialties = true
                                    }
                                )
                            }
                        
                        // State filter - sheet-based like specialty and program types
                        Button(action: {
                            // Initialize temp selections from current state
                            tempSelectedStates = selectedStates
                            tempShowAllStates = showAllStates
                            showStateFilter = true
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "map.fill")
                                    .font(.system(size: 13))
                                    .foregroundColor(.green)
                                
                                let displayText: String = {
                                    if showAllStates {
                                        return "All States"
                                    } else if !selectedStates.isEmpty {
                                        return "\(selectedStates.count)"
                                    } else {
                                        return "All States"
                                    }
                                }()
                                
                                Text(displayText)
                                    .font(.system(size: 12, weight: .medium))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                                
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 9))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background({
                                let hasSelection = !showAllStates && !selectedStates.isEmpty
                                return hasSelection 
                                    ? Color.green.opacity(0.12) 
                                    : Color(.systemGray5)
                            }())
                            .cornerRadius(7)
                        }
                        .sheet(isPresented: $showStateFilter) {
                            StateFilterSheet(
                                allStates: allStates,
                                selectedStates: $tempSelectedStates,
                                showAll: $tempShowAllStates,
                                onApply: {
                                    selectedStates = tempSelectedStates
                                    showAllStates = tempShowAllStates
                                    showStateFilter = false
                                },
                                onClear: {
                                    tempSelectedStates.removeAll()
                                    tempShowAllStates = true
                                }
                            )
                        }
                        
                        // Program type filter - opens a sheet that stays open
                        Button(action: {
                            // Initialize temp selections with current selections
                            tempSelectedProgramTypes = selectedProgramTypes
                            tempShowAllProgramTypes = showAllProgramTypes
                            showProgramTypeFilter = true
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "building.2.fill")
                                    .font(.system(size: 13))
                                    .foregroundColor(.orange)
                                
                                let displayText: String = {
                                    if showAllProgramTypes {
                                        return "All"
                                    } else if !selectedProgramTypes.isEmpty {
                                        return "\(selectedProgramTypes.count)"
                                    } else {
                                        return "All"
                                    }
                                }()
                                
                                Text(displayText)
                                    .font(.system(size: 12, weight: .medium))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                                
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 9))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background({
                                let hasSelection = !showAllProgramTypes && !selectedProgramTypes.isEmpty
                                return hasSelection 
                                    ? Color.orange.opacity(0.12) 
                                    : Color(.systemGray5)
                            }())
                            .cornerRadius(7)
                        }
                        .sheet(isPresented: $showProgramTypeFilter) {
                            ProgramTypeFilterSheet(
                                programTypes: programTypes,
                                selectedTypes: $tempSelectedProgramTypes,
                                showAll: $tempShowAllProgramTypes,
                                onApply: {
                                    selectedProgramTypes = tempSelectedProgramTypes
                                    showAllProgramTypes = tempShowAllProgramTypes
                                    showProgramTypeFilter = false
                                },
                                onClear: {
                                    tempSelectedProgramTypes.removeAll()
                                    tempShowAllProgramTypes = true
                                }
                            )
                        }
                        
                        Spacer()
                        
                        // Clear filters button
                        if (!selectedStates.isEmpty && !showAllStates) || (!selectedProgramTypes.isEmpty && !showAllProgramTypes) || (!selectedSpecialties.isEmpty && !showAllSpecialties) {
                            Button(action: {
                                withAnimation {
                                    selectedStates.removeAll()
                                    showAllStates = true
                                    selectedProgramTypes.removeAll()
                                    showAllProgramTypes = true
                                    selectedSpecialties.removeAll()
                                    showAllSpecialties = true
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 10))
                                    Text("Clear")
                                        .font(.system(size: 12, weight: .medium))
                                }
                                .foregroundColor(.blue)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(7)
                            }
                        }
                        }
                        .padding(.horizontal, 4)
        }
    }
    
    private var resultsView: some View {
        Group {
            let specialtiesToUse: [String]? = {
                if showAllSpecialties || (selectedSpecialties.isEmpty && dataManager.preferences.specialties.isEmpty) {
                    return nil
                } else if !selectedSpecialties.isEmpty {
                    return Array(selectedSpecialties)
                } else {
                    return dataManager.preferences.specialties
                }
            }()
            
            let allPrograms = specialtiesToUse == nil
                ? database.getAllPrograms()
                : database.getAllPrograms(specialties: specialtiesToUse!)
            let displayResults = searchText.isEmpty && showAllStates && showAllProgramTypes && (selectedSpecialties.isEmpty || showAllSpecialties)
                ? allPrograms
                : searchResults
            
            if displayResults.isEmpty {
                emptyResultsView
            } else {
                programsListView(displayResults: displayResults)
            }
        }
    }
    
    private var emptyResultsView: some View {
        VStack(spacing: 20) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            Text("No programs found")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("Try a different search term")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func programsListView(displayResults: [ResidencyProgramInfo]) -> some View {
        VStack(spacing: 0) {
            // Optimize: Pre-sort once instead of in Dictionary grouping
            let sortedResults = displayResults.sorted {
                HospitalNameFormatter.format($0.hospital) < HospitalNameFormatter.format($1.hospital)
            }
            let groupedPrograms = Dictionary(grouping: sortedResults) { program in
                String(HospitalNameFormatter.format(program.hospital).prefix(1).uppercased())
            }
            let sortedKeys = groupedPrograms.keys.sorted()
            
            ScrollViewReader { proxy in
                HStack(spacing: 0) {
                            List {
                                ForEach(sortedKeys, id: \.self) { key in
                                    Section(header: 
                                        Text(key)
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(.secondary)
                                            .textCase(.none)
                                    ) {
                                ForEach(groupedPrograms[key] ?? []) { program in
                                    ProgramSearchRowView(
                                        program: program,
                                        isSelected: selectedPrograms.contains(program.id),
                                        allowMultiSelect: allowMultiSelect,
                                        onTap: {
                                            if allowMultiSelect {
                                                if selectedPrograms.contains(program.id) {
                                                    selectedPrograms.remove(program.id)
                                                } else {
                                                    selectedPrograms.insert(program.id)
                                                }
                                            } else {
                                                onSelect(program)
                                                dismiss()
                                            }
                                        }
                                    )
                                }
                            }
                            .id(key)
                        }
                    }
                    .listStyle(.insetGrouped)
                    
                    alphabetScrollIndex(sortedKeys: sortedKeys, proxy: proxy)
                }
            }
            
            footerWithCount(count: displayResults.count)
            
            if allowMultiSelect && !selectedPrograms.isEmpty {
                addSelectedButton
            }
        }
    }
    
    private func alphabetScrollIndex(sortedKeys: [String], proxy: ScrollViewProxy) -> some View {
        VStack(spacing: 2) {
            ForEach(sortedKeys, id: \.self) { key in
                Button(action: {
                    withAnimation {
                        proxy.scrollTo(key, anchor: .top)
                    }
                }) {
                    Text(key)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.blue)
                        .frame(width: 20)
                }
            }
        }
        .padding(.trailing, 4)
        .padding(.vertical, 8)
    }
    
    private func footerWithCount(count: Int) -> some View {
        VStack(spacing: 0) {
            Divider()
            HStack {
                Spacer()
                HStack(spacing: 5) {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary.opacity(0.7))
                    Text("\(count) program\(count == 1 ? "" : "s")")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
                Spacer()
            }
            .background(Color(.systemGray6).opacity(0.5))
        }
    }
    
    private var addSelectedButton: some View {
        VStack(spacing: 0) {
            Divider()
            Button(action: {
                for program in searchResults where selectedPrograms.contains(program.id) {
                    let newProgram = Program(
                        specialty: program.specialty,
                        name: program.name,
                        hospital: HospitalNameFormatter.format(program.hospital),
                        city: program.city,
                        state: program.state,
                        address: program.address,
                        type: program.type,
                        accreditationID: program.accreditationID,
                        isIMGFriendly: program.isIMGFriendly
                    )
                    dataManager.addProgram(newProgram)
                }
                dismiss()
            }) {
                HStack {
                    Spacer()
                    Text("Add \(selectedPrograms.count) Program\(selectedPrograms.count == 1 ? "" : "s")")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.vertical, 14)
                    Spacer()
                }
                .background(Color.blue)
                .cornerRadius(12)
            }
            .padding()
            .background(Color(.systemBackground))
        }
    }
    
    private func programTypeColor(_ type: String) -> Color {
        switch type {
        case "Academic":
            return .blue
        case "Community":
            return .green
        case "Hybrid":
            return .orange
        default:
            return .gray
        }
    }
}

#Preview {
    ProgramSearchView(onSelect: { _ in })
        .environmentObject(DataManager.shared)
}

