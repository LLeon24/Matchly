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
                        .font(.arial(size: 48))
                        .foregroundColor(signalType == .gold ? .yellow : .gray)
                    
                    Text("No \(signalType == .gold ? "Gold" : "Silver") Signals")
                        .font(.arial(size: 18, weight: .semibold))
                    
                    Text("You haven't assigned any \(signalType == .gold ? "gold" : "silver") signals yet")
                        .font(.arial(size: 14))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 60)
                .glassCardStyle(cornerRadius: 20)
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
                                        .font(.arial(size: 9))
                                        .foregroundColor(scoreColor(program.finalScore))
                                    Text(String(format: "%.0f", program.finalScore))
                                        .font(.arial(size: 15, weight: .bold))
                                        .foregroundColor(scoreColor(program.finalScore))
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
                                    if program.hasDisplayLocation {
                                        HStack(spacing: 3) {
                                            Image(systemName: "mappin.circle.fill")
                                                .font(.arial(size: 9))
                                            Text(program.displayCityState)
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
            }
        }
        .scrollContentBackground(.hidden)
        .appCanvasBackground()
        .navigationTitle("\(signalType == .gold ? "Gold" : "Silver") Signals")
        .navigationBarTitleDisplayMode(.inline)
        .padding(.bottom, 90) // Account for custom tab bar
    }
    
}

#Preview {
    MatchlyNavigationView {
        SignaledProgramsView(signalType: .gold)
            .environmentObject(DataManager.shared)
    }
}

