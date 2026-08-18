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
    @State private var listFilter: ProgramListFilter = .all
    @State private var isEditMode = false
    @State private var selectedPrograms = Set<String>()
    
    enum SortOption: String, CaseIterable {
        case name = "Name"
        case score = "Score"
        case location = "Location"
        case specialty = "Specialty"
    }

    enum ProgramListFilter: String, CaseIterable {
        case all = "All"
        case completed = "Completed"
        case incomplete = "Incomplete"
    }

    private var incompleteProgramsCount: Int {
        dataManager.programs.filter { $0.needsScoring(preferences: dataManager.preferences) }.count
    }

    private var completedProgramsCount: Int {
        dataManager.programs.count - incompleteProgramsCount
    }

    private var programFilterTabs: [MatchlyColoredTabOption<ProgramListFilter>] {
        [
            MatchlyColoredTabOption(value: .all, title: "All", tint: AppColors.primaryBlue, count: dataManager.programs.count),
            MatchlyColoredTabOption(value: .completed, title: "Completed", tint: AppColors.pipelineScored, count: completedProgramsCount),
            MatchlyColoredTabOption(value: .incomplete, title: "Incomplete", tint: AppColors.pipelineToReview, count: incompleteProgramsCount)
        ]
    }
    
    var body: some View {
        MatchlyNavigationView {
            Group {
                if dataManager.programs.isEmpty {
                    EmptyProgramsView(showAddProgram: $showAddProgram)
                        .matchlyRootContentFrame()
                } else {
                    // Group programs by specialty
                    let groupedPrograms = Dictionary(grouping: filteredPrograms) {
                        SpecialtyFormatter.normalizedUserSpecialty($0.specialty)
                    }
                    let sortedSpecialties = groupedPrograms.keys.sorted()
                    
                    VStack(spacing: 0) {
                        MatchlyListPageTitleRow(title: "My Programs") {
                            Button {
                                showAddProgram = true
                            } label: {
                                MatchlyToolbarAddProgramButton()
                            }
                            .buttonStyle(.plain)
                        }

                        MatchlyColoredTabBar(options: programFilterTabs, selection: $listFilter)
                            .padding(.bottom, 4)

                        programsFilterToolbar

                        programsSectionDivider
                        programsSecondaryActionRow

                        programsSectionDivider
                            .padding(.bottom, 4)

                        if listFilter == .incomplete && filteredPrograms.isEmpty {
                            ContentUnavailableView {
                                Label("All Questionnaires Complete", systemImage: "checkmark.circle.fill")
                            } description: {
                                Text("Every program has answered all enabled questionnaire items.")
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(.horizontal, 24)
                        } else if listFilter == .completed && filteredPrograms.isEmpty {
                            ContentUnavailableView {
                                Label("No Completed Programs Yet", systemImage: "doc.text")
                            } description: {
                                Text("Finish questionnaires to mark programs as complete.")
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(.horizontal, 24)
                        } else {
                        List {
                            ForEach(sortedSpecialties, id: \.self) { specialty in
                                Section(header: MatchlySpecialtySectionHeader(specialty: specialty)) {
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
                                            .listRowInsets(programsListRowInsets)
                                        } else {
                                            NavigationLink(
                                                destination: ProgramEntryView(
                                                    program: program,
                                                    scrollToFirstMissing: program.needsScoring(preferences: dataManager.preferences)
                                                )
                                            ) {
                                                CompactProgramRowView(program: program)
                                            }
                                            .listRowInsets(programsListRowInsets)
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
                        .listSectionSpacing(16)
                        .matchlyReadableWidth()
                        .matchlyScrollTabBarClearance()
                        .refreshable {
                            dataManager.recalculateAllScores()
                            dataManager.objectWillChange.send()
                        }
                        }
                    }
                }
            }
            .matchlyRootContentFrame()
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showAddProgram) {
                ProgramSearchView(
                    onSelect: { _ in },
                    allowMultiSelect: true
                )
                .matchlyExpandedSheet()
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

    // MARK: - View Components

    private var programsSectionDivider: some View {
        MatchlyBrandHairline(fullWidth: true, color: AppColors.secondaryText.opacity(0.22))
            .padding(.horizontal, 16)
    }

    private var programsFilterToolbar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                sortMenu
                    .disabled(isEditMode)

                Spacer(minLength: 0)

                Text("\(filteredPrograms.count) program\(filteredPrograms.count == 1 ? "" : "s")")
                    .font(.arial(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 10)
    }

    private var programsSecondaryActionRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                if isEditMode {
                    Button {
                        for programId in selectedPrograms {
                            if let program = dataManager.programs.first(where: { $0.id == programId }) {
                                dataManager.deleteProgram(program)
                            }
                        }
                        selectedPrograms.removeAll()
                        isEditMode = false
                    } label: {
                        MatchlyFilterChipLabel(
                            icon: "trash.fill",
                            iconColor: selectedPrograms.isEmpty ? .secondary : AppColors.accentRed,
                            text: "Delete",
                            showsChevron: false
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(selectedPrograms.isEmpty)

                    Button {
                        isEditMode = false
                        selectedPrograms.removeAll()
                    } label: {
                        MatchlyFilterChipLabel(
                            icon: "checkmark",
                            iconColor: AppColors.primaryBlue,
                            text: "Done",
                            isActive: true,
                            showsChevron: false
                        )
                    }
                    .buttonStyle(.plain)
                } else {
                    if dataManager.programs.count >= 2 {
                        NavigationLink(destination: ProgramComparisonView()) {
                            MatchlyFilterChipLabel(
                                icon: "square.grid.2x2",
                                iconColor: AppColors.primaryBlue,
                                text: "Compare Programs",
                                showsChevron: false
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    Button {
                        isEditMode = true
                    } label: {
                        MatchlyFilterChipLabel(
                            icon: "pencil",
                            iconColor: .secondary,
                            text: "Edit",
                            showsChevron: false
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 10)
    }

    private var sortMenu: some View {
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
            MatchlyFilterChipLabel(
                icon: "arrow.up.arrow.down",
                text: "Sort: \(sortOption.rawValue)"
            )
        }
    }

    private var programsListRowInsets: EdgeInsets {
        EdgeInsets(top: 12, leading: 10, bottom: 12, trailing: 10)
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
    
    private var filteredPrograms: [Program] {
        switch listFilter {
        case .all:
            return sortedPrograms
        case .completed:
            return sortedPrograms.filter { !$0.needsScoring(preferences: dataManager.preferences) }
        case .incomplete:
            return sortedPrograms.filter { $0.needsScoring(preferences: dataManager.preferences) }
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
    @EnvironmentObject private var dataManager: DataManager
    let program: Program

    private var completionRatio: Double {
        program.questionnaireCompletionRatio(preferences: dataManager.preferences)
    }

    private var showsIncompleteBadge: Bool {
        program.needsScoring(preferences: dataManager.preferences)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            if showsIncompleteBadge {
                ProgramCompletionRing(ratio: completionRatio)
            } else {
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
                    MatchlyProgramSpecialtyBadge(specialty: program.specialty)
                }

                MatchlyProgramLocationAndIDRow(program: program)
                
                SavedProgramIMGBadge(program: program)
                
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

                    ProgramVoiceMemoBadge(program: program)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 6)
    }
    
}

struct ProgramCompletionRing: View {
    let ratio: Double

    private var percent: Int {
        Int((ratio * 100).rounded())
    }

    private var tint: Color {
        switch percent {
        case 80...: return AppColors.accentGreen
        case 50..<80: return AppColors.pipelineNeedDate
        default: return AppColors.pipelineToReview
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(tint.opacity(0.18), lineWidth: 3.5)
                .frame(width: 42, height: 42)

            Circle()
                .trim(from: 0, to: CGFloat(min(max(ratio, 0), 1)))
                .stroke(tint, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                .frame(width: 42, height: 42)
                .rotationEffect(.degrees(-90))

            Text("\(percent)%")
                .font(.arial(size: 11, weight: .bold))
                .foregroundStyle(tint)
                .minimumScaleFactor(0.8)
                .lineLimit(1)
        }
        .accessibilityLabel("\(percent) percent complete")
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

