//
//  AllSignaledProgramsView.swift
//  Matchly
//
//  Created on 11/16/25.
//

import SwiftUI

struct AllSignaledProgramsView: View {
    @EnvironmentObject var dataManager: DataManager
    
    // Get all programs that have signals
    private var signaledPrograms: [Program] {
        dataManager.programs.filter { $0.signalType != .none }
    }
    
    // Group signaled programs by specialty
    private var groupedBySpecialty: [String: [Program]] {
        Dictionary(grouping: signaledPrograms) { $0.specialty }
    }
    
    private var sortedSpecialties: [String] {
        groupedBySpecialty.keys.sorted()
    }
    
    var body: some View {
        Group {
            if signaledPrograms.isEmpty {
                // Empty state
                VStack(spacing: 16) {
                    Image(systemName: "star.circle")
                        .font(.arial(size: 48))
                        .foregroundColor(.secondary)
                    
                    Text("No Signals Assigned")
                        .font(.arial(size: 18, weight: .semibold))
                    
                    Text("You haven't assigned any signals yet")
                        .font(.arial(size: 14))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 60)
                .glassCardStyle(cornerRadius: 20)
            } else {
                List {
                    ForEach(sortedSpecialties, id: \.self) { specialty in
                        Section(header: 
                            HStack(spacing: 6) {
                                Image(systemName: "stethoscope")
                                    .font(.arial(size: 12))
                                    .foregroundColor(SpecialtyFormatter.color(for: specialty))
                                Text("\(specialty) (\(SpecialtyFormatter.abbreviation(for: specialty)))")
                                    .font(.arial(size: 13, weight: .semibold))
                                
                                Spacer()
                                
                                // Show signal usage (used/total) for this specialty
                                let usage = dataManager.getSignalUsage(for: specialty)
                                
                                if SignalLimits.isTiered(for: specialty) {
                                    // Show Gold/Silver usage for tiered specialties
                                    HStack(spacing: 8) {
                                        // Gold signal usage
                                        if usage.goldLimit > 0 {
                                            HStack(spacing: 2) {
                                                Image(systemName: "star.fill")
                                                    .font(.arial(size: 9))
                                                Text("\(usage.goldUsed)/\(usage.goldLimit)")
                                                    .font(.arial(size: 10, weight: .medium))
                                            }
                                            .foregroundColor(.yellow)
                                        }
                                        
                                        // Silver signal usage
                                        if usage.silverLimit > 0 {
                                            HStack(spacing: 2) {
                                                Image(systemName: "star")
                                                    .font(.arial(size: 9))
                                                Text("\(usage.silverUsed)/\(usage.silverLimit)")
                                                    .font(.arial(size: 10, weight: .medium))
                                            }
                                            .foregroundColor(.gray)
                                        }
                                    }
                                } else {
                                    // Show single-level signal usage
                                    if usage.goldLimit > 0 {
                                        HStack(spacing: 2) {
                                            Image(systemName: "star.fill")
                                                .font(.arial(size: 9))
                                            Text("\(usage.goldUsed)/\(usage.goldLimit)")
                                                .font(.arial(size: 10, weight: .medium))
                                        }
                                        .foregroundColor(.blue)
                                    }
                                }
                            }
                            .foregroundColor(.secondary)
                        ) {
                            // Sort programs within specialty by score (highest first)
                            ForEach((groupedBySpecialty[specialty] ?? []).sorted { $0.finalScore > $1.finalScore }) { program in
                                NavigationLink(destination: ProgramEntryView(program: program)) {
                                    HStack(spacing: 12) {
                                        // Score indicator with icon - matching ProgramsListView
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
                                        
                                        // Program info - matching ProgramsListView style
                                        VStack(alignment: .leading, spacing: 3) {
                                            // Hospital name
                                            Text(HospitalNameFormatter.format(program.hospital.isEmpty ? (program.name.isEmpty ? "Unnamed Program" : program.name) : program.hospital))
                                                .font(.arial(size: 15, weight: .semibold))
                                                .lineLimit(3)
                                                .fixedSize(horizontal: false, vertical: true)
                                            
                                            // Specialty badge - matching ProgramsListView
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
                                            
                                            // Location and Accreditation ID on first line - matching ProgramsListView
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
                                                
                                                // Accreditation ID
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
                                            
                                            // Program Type and IMG on second line - matching ProgramsListView
                                            HStack(spacing: 8) {
                                                // Program Type
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
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .appCanvasBackground()
            }
        }
        .appCanvasBackground()
        .navigationTitle("Signals")
        .navigationBarTitleDisplayMode(.inline)
        .padding(.bottom, 90) // Account for custom tab bar
    }
    
}

#Preview {
    MatchlyNavigationView {
        AllSignaledProgramsView()
            .environmentObject(DataManager.shared)
    }
}
