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
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    
                    Text("No Signals Assigned")
                        .font(.system(size: 18, weight: .semibold))
                    
                    Text("You haven't assigned any signals yet")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 60)
            } else {
                List {
                    ForEach(sortedSpecialties, id: \.self) { specialty in
                        Section(header: 
                            HStack(spacing: 6) {
                                Image(systemName: "stethoscope")
                                    .font(.system(size: 12))
                                    .foregroundColor(SpecialtyFormatter.color(for: specialty))
                                Text("\(specialty) (\(SpecialtyFormatter.abbreviation(for: specialty)))")
                                    .font(.system(size: 13, weight: .semibold))
                                
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
                                                    .font(.system(size: 9))
                                                Text("\(usage.goldUsed)/\(usage.goldLimit)")
                                                    .font(.system(size: 10, weight: .medium))
                                            }
                                            .foregroundColor(.yellow)
                                        }
                                        
                                        // Silver signal usage
                                        if usage.silverLimit > 0 {
                                            HStack(spacing: 2) {
                                                Image(systemName: "star")
                                                    .font(.system(size: 9))
                                                Text("\(usage.silverUsed)/\(usage.silverLimit)")
                                                    .font(.system(size: 10, weight: .medium))
                                            }
                                            .foregroundColor(.gray)
                                        }
                                    }
                                } else {
                                    // Show single-level signal usage
                                    if usage.goldLimit > 0 {
                                        HStack(spacing: 2) {
                                            Image(systemName: "star.fill")
                                                .font(.system(size: 9))
                                            Text("\(usage.goldUsed)/\(usage.goldLimit)")
                                                .font(.system(size: 10, weight: .medium))
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
                                                    .font(.system(size: 9))
                                                    .foregroundColor(scoreColor(program.finalScore))
                                                Text(String(format: "%.0f", program.finalScore))
                                                    .font(.system(size: 15, weight: .bold))
                                                    .foregroundColor(scoreColor(program.finalScore))
                                            }
                                        }
                                        
                                        // Program info - matching ProgramsListView style
                                        VStack(alignment: .leading, spacing: 3) {
                                            // Hospital name with signal indicator
                                            HStack(spacing: 6) {
                                                Text(HospitalNameFormatter.format(program.hospital.isEmpty ? (program.name.isEmpty ? "Unnamed Program" : program.name) : program.hospital))
                                                    .font(.system(size: 15, weight: .semibold))
                                                    .lineLimit(2)
                                                
                                                // Red flag indicator
                                                if program.hasRedFlags() {
                                                    Image(systemName: "exclamationmark.triangle.fill")
                                                        .font(.system(size: 12))
                                                        .foregroundColor(.red)
                                                }
                                                
                                                // Signal indicator - show different icons for tiered vs single-level
                                                if SignalLimits.isTiered(for: program.specialty) {
                                                    // Tiered: Gold = filled star (yellow), Silver = empty star (gray)
                                                    Image(systemName: program.signalType == .gold ? "star.fill" : "star")
                                                        .font(.system(size: 11))
                                                        .foregroundColor(program.signalType == .gold ? .yellow : .gray)
                                                } else {
                                                    // Single-level: always filled star (blue)
                                                    Image(systemName: "star.fill")
                                                        .font(.system(size: 11))
                                                        .foregroundColor(.blue)
                                                }
                                            }
                                            
                                            // Specialty badge - matching ProgramsListView
                                            if !program.specialty.isEmpty {
                                                let specialtyColor = SpecialtyFormatter.color(for: program.specialty)
                                                let specialtyAbbrev = SpecialtyFormatter.abbreviation(for: program.specialty)
                                                
                                                HStack(spacing: 3) {
                                                    Image(systemName: "stethoscope")
                                                        .font(.system(size: 8))
                                                    Text(specialtyAbbrev)
                                                        .font(.system(size: 10, weight: .semibold))
                                                }
                                                .foregroundColor(specialtyColor)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(specialtyColor.opacity(0.15))
                                                .cornerRadius(4)
                                            }
                                            
                                            // Location and Accreditation ID on first line - matching ProgramsListView
                                            HStack(spacing: 8) {
                                                // Location
                                                if !program.city.isEmpty && !program.state.isEmpty {
                                                    HStack(spacing: 3) {
                                                        Image(systemName: "mappin.circle.fill")
                                                            .font(.system(size: 9))
                                                        Text("\(program.city), \(program.state)")
                                                            .font(.system(size: 11))
                                                    }
                                                    .foregroundColor(.secondary)
                                                }
                                                
                                                // Accreditation ID
                                                if let acgmeID = program.accreditationID, !acgmeID.isEmpty {
                                                    HStack(spacing: 2) {
                                                        Image(systemName: "number.circle.fill")
                                                            .font(.system(size: 9))
                                                        Text("ID:")
                                                            .font(.system(size: 10, weight: .medium))
                                                        Text(acgmeID)
                                                            .font(.system(size: 11, weight: .medium))
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
                                                            .font(.system(size: 8))
                                                        Text(program.type)
                                                            .font(.system(size: 10, weight: .medium))
                                                    }
                                                    .foregroundColor(programTypeColor(program.type))
                                                }
                                                
                                                // IMG-Friendly
                                                let imgStatus = program.isIMGFriendly ?? IMGFriendlyHelper.shared.assessIMGFriendlinessForProgram(program)
                                                if imgStatus == true {
                                                    HStack(spacing: 3) {
                                                        Image(systemName: "globe.americas.fill")
                                                            .font(.system(size: 8))
                                                        Text("IMG")
                                                            .font(.system(size: 10, weight: .medium))
                                                    }
                                                    .foregroundColor(.purple)
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
            }
        }
        .navigationTitle("Signals")
        .navigationBarTitleDisplayMode(.inline)
        .padding(.bottom, 90) // Account for custom tab bar
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

#Preview {
    NavigationView {
        AllSignaledProgramsView()
            .environmentObject(DataManager.shared)
    }
}
