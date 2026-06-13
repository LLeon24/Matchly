//
//  SignaledProgramsView.swift
//  Matchly
//
//  Created on 11/16/25.
//

import SwiftUI

struct SignaledProgramsView: View {
    @EnvironmentObject var dataManager: DataManager
    let signalType: SignalType
    
    var signaledPrograms: [Program] {
        dataManager.programs.filter { $0.signalType == signalType }
            .sorted { $0.finalScore > $1.finalScore }
    }
    
    var body: some View {
        List {
            if signaledPrograms.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: signalType == .gold ? "star.fill" : "star")
                        .font(.system(size: 48))
                        .foregroundColor(signalType == .gold ? .yellow : .gray)
                    
                    Text("No \(signalType == .gold ? "Gold" : "Silver") Signals")
                        .font(.system(size: 18, weight: .semibold))
                    
                    Text("You haven't assigned any \(signalType == .gold ? "gold" : "silver") signals yet")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 60)
            } else {
                // Programs list - matching ProgramsListView style
                ForEach(signaledPrograms) { program in
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
                            
                            // Program info - EXACT same layout as ProgramsListView
                            VStack(alignment: .leading, spacing: 3) {
                                // Hospital name with signal indicator
                                HStack(spacing: 6) {
                                    Text(HospitalNameFormatter.format(program.hospital.isEmpty ? (program.name.isEmpty ? "Unnamed Program" : program.name) : program.hospital))
                                        .font(.system(size: 15, weight: .semibold))
                                        .lineLimit(2)
                                    
                                    // Signal indicator - subtle
                                    Image(systemName: signalType == .gold ? "star.fill" : "star")
                                        .font(.system(size: 11))
                                        .foregroundColor(signalType == .gold ? .yellow : .gray)
                                }
                                
                                // Specialty badge (only badge-style element) - matching ProgramsListView
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
                                
                                // Location and Accreditation ID on first line - EXACT match to ProgramsListView
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
                                    
                                    // Accreditation ID - subtle, no background (matching ProgramsListView exactly)
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
                                
                                // Program Type and IMG on second line - EXACT match to ProgramsListView
                                HStack(spacing: 8) {
                                    // Program Type - full text, not abbreviated (matching ProgramsListView)
                                    if !program.type.isEmpty {
                                        HStack(spacing: 3) {
                                            Image(systemName: programTypeIcon(program.type))
                                                .font(.system(size: 8))
                                            Text(program.type)
                                                .font(.system(size: 10, weight: .medium))
                                        }
                                        .foregroundColor(programTypeColor(program.type))
                                    }
                                    
                                    // IMG-Friendly - same style as Program Type (text with icon, no badge) - matching ProgramsListView
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
        .navigationTitle("\(signalType == .gold ? "Gold" : "Silver") Signals")
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
        SignaledProgramsView(signalType: .gold)
            .environmentObject(DataManager.shared)
    }
}

