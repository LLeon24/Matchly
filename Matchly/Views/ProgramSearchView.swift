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
    @State private var selectedFellowshipCodes: Set<String> = []
    @State private var showAllFellowshipTypes: Bool = true
    @State private var showFellowshipTypeFilter: Bool = false
    @State private var tempSelectedFellowshipCodes: Set<String> = []
    @State private var tempShowAllFellowshipTypes: Bool = true
    @State private var trainingLevelFilter: ProgramTrainingLevelFilter = .residency
    @State private var searchResults: [ResidencyProgramInfo] = []
    @State private var totalMatchCount = 0
    @State private var isResultSetTruncated = false
    @State private var resultLimit = ResidencyProgramDatabase.defaultResultLimit
    @State private var hasRunSearch = false
    @State private var searchRefreshTask: Task<Void, Never>?
    
    let onSelect: (ResidencyProgramInfo) -> Void
    var allowMultiSelect: Bool = false
    
    @ObservedObject private var database = ResidencyProgramDatabase.shared
    
    // All available specialties (residency + common fellowship areas)
    private var allSpecialties: [String] {
        SpecialtyFormatter.commonSpecialties
    }

    private var parentSpecialtiesForFellowship: [String] {
        if !showAllSpecialties, !selectedSpecialties.isEmpty {
            return Array(selectedSpecialties)
        }
        if !dataManager.preferences.specialties.isEmpty {
            return dataManager.preferences.specialties
        }
        return []
    }

    private var fellowshipCodesToUse: Set<String>? {
        guard trainingLevelFilter == .fellowship,
              !showAllFellowshipTypes,
              !selectedFellowshipCodes.isEmpty
        else { return nil }
        return selectedFellowshipCodes
    }

    private func pruneInvalidFellowshipSelections() {
        let valid = Set(FellowshipFilterCatalog.options(forUserSpecialties: parentSpecialtiesForFellowship).map(\.code))
        selectedFellowshipCodes = selectedFellowshipCodes.intersection(valid)
        if selectedFellowshipCodes.isEmpty {
            showAllFellowshipTypes = true
        }
    }

    private var preferredTrainingLevel: ProgramTrainingLevelFilter {
        ProgramTrainingLevelFilter(rawValue: dataManager.preferences.applyingTrack) ?? .residency
    }

    private var hasSpecialtySelection: Bool {
        !selectedSpecialties.isEmpty
            || (!showAllSpecialties && !dataManager.preferences.specialties.isEmpty)
    }

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

    private var hasActiveFilters: Bool {
        !searchText.trimmingCharacters(in: .whitespaces).isEmpty
            || !showAllStates && !selectedStates.isEmpty
            || !showAllProgramTypes && !selectedProgramTypes.isEmpty
            || hasSpecialtySelection
            || !showAllFellowshipTypes && !selectedFellowshipCodes.isEmpty
            || trainingLevelFilter != preferredTrainingLevel
            || trainingLevelFilter == .all
    }

    private var specialtiesToUse: [String]? {
        if showAllSpecialties || (selectedSpecialties.isEmpty && dataManager.preferences.specialties.isEmpty) {
            return nil
        }
        if !selectedSpecialties.isEmpty {
            return Array(selectedSpecialties)
        }
        return dataManager.preferences.specialties
    }

    private var programTypesToUse: [String]? {
        if showAllProgramTypes || selectedProgramTypes.isEmpty {
            return nil
        }
        return Array(selectedProgramTypes)
    }

    private var stateFiltersToUse: Set<String>? {
        if showAllStates || selectedStates.isEmpty {
            return nil
        }
        return selectedStates
    }

    private func refreshSearch(resetLimit: Bool = false) {
        guard database.isReady else { return }
        if resetLimit {
            resultLimit = ResidencyProgramDatabase.defaultResultLimit
        }
        guard hasActiveFilters else {
            searchResults = []
            totalMatchCount = 0
            isResultSetTruncated = false
            hasRunSearch = false
            return
        }

        let results = database.search(
            query: searchText,
            specialty: nil,
            specialties: specialtiesToUse,
            fellowshipCodes: fellowshipCodesToUse,
            stateFilter: nil,
            stateFilters: stateFiltersToUse,
            programTypeFilter: nil,
            programTypes: programTypesToUse,
            trainingLevel: trainingLevelFilter.trainingLevel,
            imgFriendlyOnly: false,
            limit: resultLimit
        )

        searchResults = results.programs
        totalMatchCount = results.totalCount
        isResultSetTruncated = results.isTruncated
        hasRunSearch = true
    }

    private func loadMoreResults() {
        resultLimit += ResidencyProgramDatabase.defaultResultLimit
        refreshSearch()
    }

    private func scheduleSearchRefresh() {
        searchRefreshTask?.cancel()
        searchRefreshTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 200_000_000)
            guard !Task.isCancelled else { return }
            refreshSearch(resetLimit: true)
        }
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
                trainingLevelFilter = preferredTrainingLevel
                if !dataManager.preferences.specialties.isEmpty {
                    selectedSpecialties = Set(dataManager.preferences.specialties)
                }
                refreshSearch()
            }
            .onChange(of: searchText) { _, _ in scheduleSearchRefresh() }
            .onChange(of: selectedStates) { _, _ in refreshSearch(resetLimit: true) }
            .onChange(of: showAllStates) { _, _ in refreshSearch(resetLimit: true) }
            .onChange(of: selectedProgramTypes) { _, _ in refreshSearch(resetLimit: true) }
            .onChange(of: showAllProgramTypes) { _, _ in refreshSearch(resetLimit: true) }
            .onChange(of: selectedSpecialties) { _, _ in
                pruneInvalidFellowshipSelections()
                refreshSearch(resetLimit: true)
            }
            .onChange(of: showAllSpecialties) { _, _ in
                pruneInvalidFellowshipSelections()
                refreshSearch(resetLimit: true)
            }
            .onChange(of: selectedFellowshipCodes) { _, _ in refreshSearch(resetLimit: true) }
            .onChange(of: showAllFellowshipTypes) { _, _ in refreshSearch(resetLimit: true) }
            .onChange(of: trainingLevelFilter) { _, newValue in
                dataManager.preferences.applyingTrack = newValue.rawValue
                dataManager.savePreferences()
                if newValue != .fellowship {
                    selectedFellowshipCodes.removeAll()
                    showAllFellowshipTypes = true
                }
                refreshSearch(resetLimit: true)
            }
            .onChange(of: database.isReady) { _, isReady in
                if isReady { refreshSearch() }
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
                .font(.arial(size: 16))
            TextField("Search programs...", text: $searchText)
                .textFieldStyle(.plain)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .font(.arial(size: 16))
            
            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary.opacity(0.6))
                        .font(.arial(size: 16))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        // Floating search field → Liquid Glass capsule. The native material
        // adapts to light/dark and to whatever scrolls beneath it.
        .glassEffect(.regular, in: .capsule)
    }
    
    private var filtersView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
                    GlassEffectContainer(spacing: 10) {
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
                                        .font(.arial(size: 13))
                                        .foregroundColor(.blue)
                                    
                                    let displayText: String = {
                                        if showAllSpecialties {
                                            return trainingLevelFilter == .fellowship ? "All Fields" : "All"
                                        } else if selectedSpecialties.count == 1, let one = selectedSpecialties.first {
                                            return SpecialtyFormatter.abbreviation(for: one)
                                        } else if !selectedSpecialties.isEmpty {
                                            return "\(selectedSpecialties.count)"
                                        } else if !dataManager.preferences.specialties.isEmpty {
                                            if dataManager.preferences.specialties.count == 1,
                                               let one = dataManager.preferences.specialties.first {
                                                return SpecialtyFormatter.abbreviation(for: one)
                                            }
                                            return "\(dataManager.preferences.specialties.count)"
                                        } else {
                                            return trainingLevelFilter == .fellowship ? "All Fields" : "All"
                                        }
                                    }()
                                    
                                    Text(displayText)
                                        .font(.arial(size: 12, weight: .medium))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                    
                                    Image(systemName: "chevron.down")
                                        .font(.arial(size: 9))
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .glassEffect(
                                    (!showAllSpecialties && (!selectedSpecialties.isEmpty || !dataManager.preferences.specialties.isEmpty))
                                        ? .regular.tint(Color.blue.opacity(0.25)).interactive()
                                        : .regular.interactive(),
                                    in: .capsule
                                )
                            }
                            .sheet(isPresented: $showSpecialtyFilter) {
                                SpecialtyFilterSheet(
                                    allSpecialties: allSpecialties,
                                    selectedSpecialties: $tempSelectedSpecialties,
                                    showAll: $tempShowAllSpecialties,
                                    navigationTitle: trainingLevelFilter == .fellowship ? "Your Specialty" : "Filter Specialties",
                                    onApply: {
                                        selectedSpecialties = tempSelectedSpecialties
                                        showAllSpecialties = tempShowAllSpecialties
                                        showSpecialtyFilter = false
                                        pruneInvalidFellowshipSelections()
                                        refreshSearch()
                                    },
                                    onClear: {
                                        tempSelectedSpecialties.removeAll()
                                        tempShowAllSpecialties = true
                                    }
                                )
                            }

                            ForEach(ProgramTrainingLevelFilter.allCases) { level in
                                Button(action: {
                                    trainingLevelFilter = level
                                }) {
                                    Text(level.rawValue)
                                        .font(.arial(size: 12, weight: trainingLevelFilter == level ? .semibold : .medium))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .glassEffect(
                                            trainingLevelFilter == level
                                                ? .regular.tint(Color.purple.opacity(0.25)).interactive()
                                                : .regular.interactive(),
                                            in: .capsule
                                        )
                                }
                                .buttonStyle(.plain)
                            }

                            if trainingLevelFilter == .fellowship {
                                Button(action: {
                                    tempSelectedFellowshipCodes = selectedFellowshipCodes
                                    tempShowAllFellowshipTypes = showAllFellowshipTypes
                                    showFellowshipTypeFilter = true
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "arrow.triangle.branch")
                                            .font(.arial(size: 13))
                                            .foregroundColor(.purple)

                                        let fellowshipDisplayText: String = {
                                            if showAllFellowshipTypes || selectedFellowshipCodes.isEmpty {
                                                return "All Types"
                                            }
                                            if selectedFellowshipCodes.count == 1,
                                               let code = selectedFellowshipCodes.first,
                                               let name = FellowshipFilterCatalog.displayName(forCode: code) {
                                                if let paren = name.firstIndex(of: "(") {
                                                    return String(name[..<paren]).trimmingCharacters(in: .whitespaces)
                                                }
                                                return name
                                            }
                                            return "\(selectedFellowshipCodes.count) types"
                                        }()

                                        Text(fellowshipDisplayText)
                                            .font(.arial(size: 12, weight: .medium))
                                            .lineLimit(2)
                                            .multilineTextAlignment(.leading)
                                            .fixedSize(horizontal: false, vertical: true)

                                        Image(systemName: "chevron.down")
                                            .font(.arial(size: 9))
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .glassEffect(
                                        (!showAllFellowshipTypes && !selectedFellowshipCodes.isEmpty)
                                            ? .regular.tint(Color.purple.opacity(0.25)).interactive()
                                            : .regular.interactive(),
                                        in: .capsule
                                    )
                                }
                                .sheet(isPresented: $showFellowshipTypeFilter) {
                                    FellowshipTypeFilterSheet(
                                        userSpecialties: parentSpecialtiesForFellowship,
                                        selectedCodes: $tempSelectedFellowshipCodes,
                                        showAll: $tempShowAllFellowshipTypes,
                                        onApply: {
                                            selectedFellowshipCodes = tempSelectedFellowshipCodes
                                            showAllFellowshipTypes = tempShowAllFellowshipTypes
                                            showFellowshipTypeFilter = false
                                            refreshSearch()
                                        },
                                        onClear: {
                                            tempSelectedFellowshipCodes.removeAll()
                                            tempShowAllFellowshipTypes = true
                                        }
                                    )
                                }
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
                                    .font(.arial(size: 13))
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
                                    .font(.arial(size: 12, weight: .medium))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                                
                                Image(systemName: "chevron.down")
                                    .font(.arial(size: 9))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .glassEffect(
                                (!showAllStates && !selectedStates.isEmpty)
                                    ? .regular.tint(Color.green.opacity(0.25)).interactive()
                                    : .regular.interactive(),
                                in: .capsule
                            )
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
                                    refreshSearch()
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
                                    .font(.arial(size: 13))
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
                                    .font(.arial(size: 12, weight: .medium))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                                
                                Image(systemName: "chevron.down")
                                    .font(.arial(size: 9))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .glassEffect(
                                (!showAllProgramTypes && !selectedProgramTypes.isEmpty)
                                    ? .regular.tint(Color.orange.opacity(0.25)).interactive()
                                    : .regular.interactive(),
                                in: .capsule
                            )
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
                                    refreshSearch()
                                },
                                onClear: {
                                    tempSelectedProgramTypes.removeAll()
                                    tempShowAllProgramTypes = true
                                }
                            )
                        }
                        
                        Spacer()
                        
                        // Clear filters button
                        if (!selectedStates.isEmpty && !showAllStates) || (!selectedProgramTypes.isEmpty && !showAllProgramTypes) || (!selectedSpecialties.isEmpty && !showAllSpecialties) || (!selectedFellowshipCodes.isEmpty && !showAllFellowshipTypes) || trainingLevelFilter != preferredTrainingLevel {
                            Button(action: {
                                withAnimation {
                                    searchText = ""
                                    selectedStates.removeAll()
                                    showAllStates = true
                                    selectedProgramTypes.removeAll()
                                    showAllProgramTypes = true
                                    selectedSpecialties.removeAll()
                                    showAllSpecialties = true
                                    selectedFellowshipCodes.removeAll()
                                    showAllFellowshipTypes = true
                                    trainingLevelFilter = preferredTrainingLevel
                                    refreshSearch(resetLimit: true)
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.arial(size: 10))
                                    Text("Clear")
                                        .font(.arial(size: 12, weight: .medium))
                                }
                                .foregroundColor(.blue)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .glassEffect(.regular.tint(Color.blue.opacity(0.18)).interactive(), in: .capsule)
                            }
                        }
                        }
                        .padding(.horizontal, 4)
                    }
        }
    }
    
    private var resultsView: some View {
        Group {
            if !database.isReady {
                VStack(spacing: 16) {
                    ProgressView()
                    Text("Loading \(database.programCount > 0 ? "\(database.programCount)" : "program") catalog…")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !hasActiveFilters {
                promptToSearchView
            } else if searchResults.isEmpty && hasRunSearch {
                emptyResultsView
            } else {
                programsListView(displayResults: searchResults)
            }
        }
    }

    private var promptToSearchView: some View {
        VStack(spacing: 16) {
            Image(systemName: "text.magnifyingglass")
                .font(.arial(size: 50))
                .foregroundColor(.secondary)
            Text("Search \(database.programCount.formatted()) programs")
                .font(.headline)
            Text("Type a hospital, city, or state — or apply specialty/state filters. Defaults to \(trainingLevelFilter.rawValue.lowercased()) programs.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            if trainingLevelFilter == .fellowship {
                Text("Use Your Specialty for your field, then Fellowship Type to narrow subspecialties.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            if database.fellowshipCount > 0 {
                Text("\(database.residencyCount.formatted()) residencies · \(database.fellowshipCount.formatted()) fellowships")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyResultsView: some View {
        VStack(spacing: 20) {
            Image(systemName: "magnifyingglass")
                .font(.arial(size: 50))
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
            let sortedResults = displayResults.sorted {
                $0.formattedHospital.localizedCaseInsensitiveCompare($1.formattedHospital) == .orderedAscending
            }
            let useGroupedList = sortedResults.count <= 120

            if useGroupedList {
                let groupedPrograms = Dictionary(grouping: sortedResults) { program in
                    String(program.formattedHospital.prefix(1).uppercased())
                }
                let sortedKeys = groupedPrograms.keys.sorted()

                ScrollViewReader { proxy in
                    HStack(spacing: 0) {
                        List {
                            ForEach(sortedKeys, id: \.self) { key in
                                Section(header:
                                    Text(key)
                                        .font(.arial(size: 13, weight: .semibold))
                                        .foregroundColor(.secondary)
                                        .textCase(.none)
                                ) {
                                    ForEach(groupedPrograms[key] ?? []) { program in
                                        programRow(for: program)
                                    }
                                }
                                .id(key)
                            }
                        }
                        .listStyle(.insetGrouped)

                        alphabetScrollIndex(sortedKeys: sortedKeys, proxy: proxy)
                    }
                }
            } else {
                List(sortedResults) { program in
                    programRow(for: program)
                }
                .listStyle(.insetGrouped)
            }

            footerWithCount(displayed: sortedResults.count)

            if allowMultiSelect && !selectedPrograms.isEmpty {
                addSelectedButton
            }
        }
    }

    @ViewBuilder
    private func programRow(for program: ResidencyProgramInfo) -> some View {
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
    
    private func alphabetScrollIndex(sortedKeys: [String], proxy: ScrollViewProxy) -> some View {
        VStack(spacing: 2) {
            ForEach(sortedKeys, id: \.self) { key in
                Button(action: {
                    withAnimation {
                        proxy.scrollTo(key, anchor: .top)
                    }
                }) {
                    Text(key)
                        .font(.arial(size: 11, weight: .medium))
                        .foregroundColor(.blue)
                        .frame(width: 20)
                }
            }
        }
        .padding(.trailing, 4)
        .padding(.vertical, 8)
    }
    
    private func footerWithCount(displayed: Int) -> some View {
        VStack(spacing: 0) {
            Divider()
            VStack(spacing: 8) {
                HStack(spacing: 5) {
                    Image(systemName: "list.bullet")
                        .font(.arial(size: 11))
                        .foregroundColor(.secondary.opacity(0.7))
                    Text("\(displayed) shown")
                        .font(.arial(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    if isResultSetTruncated {
                        Text("of \(totalMatchCount.formatted())")
                            .font(.arial(size: 12))
                            .foregroundColor(.secondary)
                    }
                }

                if isResultSetTruncated {
                    Button(action: loadMoreResults) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.arial(size: 14))
                            Text("Show \(min(ResidencyProgramDatabase.defaultResultLimit, totalMatchCount - displayed)) more")
                                .font(.arial(size: 14, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.glass)
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal)
            .glassEffect(.regular, in: .rect(cornerRadius: 0))
        }
    }
    
    private var addSelectedButton: some View {
        VStack(spacing: 0) {
            Divider()
            Button(action: {
                for program in searchResults where selectedPrograms.contains(program.id) {
                    dataManager.addProgram(CatalogProgramMapper.toSavedProgram(program))
                }
                dismiss()
            }) {
                HStack {
                    Spacer()
                    Text("Add \(selectedPrograms.count) Program\(selectedPrograms.count == 1 ? "" : "s")")
                        .font(.arial(size: 17, weight: .semibold))
                        .padding(.vertical, 14)
                    Spacer()
                }
            }
            // Primary confirm action → prominent Liquid Glass tinted brand blue.
            .buttonStyle(.glassProminent)
            .tint(.blue)
            .padding()
            .glassEffect(.regular, in: .rect(cornerRadius: 0))
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

