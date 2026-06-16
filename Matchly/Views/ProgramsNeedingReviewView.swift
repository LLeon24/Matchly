//
//  ProgramsNeedingReviewView.swift
//  Matchly
//
//  Created on 11/14/25.
//

import SwiftUI

struct ProgramsNeedingReviewView: View {
    @EnvironmentObject var dataManager: DataManager
    
    var programsNeedingReview: [Program] {
        dataManager.programs.filter { program in
            // Program has no questionnaire data
            let hasAnyRating = program.questionnaire.sections.contains { section in
                section.items.contains { $0.programRating > 0 }
            }
            return !hasAnyRating
        }
    }
    
    var body: some View {
        Group {
            if programsNeedingReview.isEmpty {
                List {
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.arial(size: 60))
                            .foregroundColor(.green)
                        
                        Text("All Programs Reviewed")
                            .font(.arial(size: 20, weight: .bold))
                        
                        Text("All your programs have questionnaire data")
                            .font(.arial(size: 15))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .glassCardStyle(cornerRadius: 20)
                }
            } else {
                // Group programs by specialty (matching ProgramsListView)
                let groupedPrograms = Dictionary(grouping: programsNeedingReview) { $0.specialty }
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
                                NavigationLink(destination: ProgramEntryView(program: program)) {
                                    HStack(spacing: 12) {
                                        // Score indicator - showing 0.0 since no data (matching ProgramsListView)
                                        ZStack {
                                            Circle()
                                                .fill(scoreColor(0.0).opacity(0.15))
                                                .frame(width: 42, height: 42)
                                            
                                            VStack(spacing: 0) {
                                                Image(systemName: "star.fill")
                                                    .font(.arial(size: 9))
                                                    .foregroundColor(scoreColor(0.0))
                                                Text("0")
                                                    .font(.arial(size: 15, weight: .bold))
                                                    .foregroundColor(scoreColor(0.0))
                                            }
                                        }
                                        
                                        // Program info - EXACT same layout as ProgramsListView
                                        VStack(alignment: .leading, spacing: 3) {
                                            // Hospital name
                                            Text(HospitalNameFormatter.format(program.hospital.isEmpty ? (program.name.isEmpty ? "Unnamed Program" : program.name) : program.hospital))
                                                .font(.arial(size: 15, weight: .semibold))
                                                .lineLimit(3)
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
                                                .glassChipStyle(tint: specialtyColor, interactive: false)
                                            }
                                            
                                            // Location and Accreditation ID on first line - EXACT match to ProgramsListView
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
                                                
                                                // Accreditation ID - subtle, no background (matching ProgramsListView exactly)
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
                                                // Program Type - full text, not abbreviated (matching ProgramsListView)
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
                                                
                                                // "No Data" indicator - styled consistently
                                                HStack(spacing: 3) {
                                                    Image(systemName: "exclamationmark.circle.fill")
                                                        .font(.arial(size: 8))
                                                    Text("No Data")
                                                        .font(.arial(size: 10, weight: .medium))
                                                }
                                                .foregroundColor(.red)
                                            }
                                        }
                                        
                                        Spacer()
                                    }
                                    .padding(.vertical, 6)
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .appCanvasBackground()
            }
        }
        .appCanvasBackground()
        .navigationTitle("Programs Needing Review")
        .navigationBarTitleDisplayMode(.inline)
    }
    
}

#Preview {
    NavigationView {
        ProgramsNeedingReviewView()
            .environmentObject(DataManager.shared)
    }
}

