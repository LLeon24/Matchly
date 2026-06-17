//
//  ProgramDetailView.swift
//  Matchly
//
//  Created by Leoh N. Leon II on 11/14/25.
//

import SwiftUI

struct ProgramDetailView: View {
    @EnvironmentObject var dataManager: DataManager
    let program: Program
    @State private var showEdit = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text(program.name.isEmpty ? "Unnamed Program" : program.name)
                        .font(.arial(size: 28, weight: .bold))
                    
                    if !program.hospital.isEmpty {
                        Text(HospitalNameFormatter.format(program.hospital))
                            .font(.arial(size: 18))
                            .foregroundColor(.secondary)
                    }
                    
                    if !program.city.isEmpty && !program.state.isEmpty {
                        Text("\(program.city), \(program.state)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Spacer()
                        
                        VStack(alignment: .trailing) {
                            Text("Final Score")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(String(format: "%.1f", program.finalScore))
                                .font(.arial(size: 32, weight: .bold))
                                .foregroundColor(scoreColor(program.finalScore))
                        }
                    }
                }
                .padding()
                
                Divider()
                
                // Category Scores
                VStack(alignment: .leading, spacing: 16) {
                    CategoryScoreView(
                        title: "Program Quality",
                        score: program.programQuality.average(),
                        color: .blue
                    )
                    
                    CategoryScoreView(
                        title: "Culture / Fit",
                        score: program.cultureFit.average(),
                        color: .purple
                    )
                    
                    CategoryScoreView(
                        title: "Location",
                        score: program.location.average(),
                        color: .green
                    )
                    
                    CategoryScoreView(
                        title: "Logistics",
                        score: program.logistics.average(),
                        color: .orange
                    )
                    
                    CategoryScoreView(
                        title: "Career Alignment",
                        score: program.careerAlignment.average(),
                        color: .pink
                    )
                    
                    if program.redFlags.total() > 0 {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Red Flags")
                                .font(.arial(size: 16, weight: .semibold))
                            Text(String(format: "Total: %.1f", program.redFlags.total()))
                                .font(.arial(size: 18, weight: .bold))
                                .foregroundColor(.red)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(12)
                    }
                }
                .padding()
                
                // Electronic Medical Record (EMR)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Electronic Medical Record (EMR)")
                        .font(.arial(size: 18, weight: .semibold))
                        .padding(.horizontal)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text(program.emr ?? "Not specified")
                            .font(.arial(size: 15, weight: program.emr == nil ? .regular : .semibold))
                            .foregroundColor(program.emr == nil ? .secondary : .primary)
                        
                        if let indicator = emrMatchIndicator {
                            Label(indicator.text, systemImage: indicator.systemImage)
                                .font(.arial(size: 12, weight: .medium))
                                .foregroundColor(indicator.color)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassEffect(.regular, in: .rect(cornerRadius: 12))
                    .padding(.horizontal)
                }
                
                // Notes
                if !program.notes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes")
                            .font(.arial(size: 18, weight: .semibold))
                            .padding(.horizontal)
                        
                        Text(program.notes)
                            .font(.arial(size: 15))
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .glassEffect(.regular, in: .rect(cornerRadius: 12))
                            .padding(.horizontal)
                    }
                }
                
                // Interview Date
                if let date = program.interviewDate {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Interview Date")
                            .font(.arial(size: 18, weight: .semibold))
                            .padding(.horizontal)
                        
                        Text(date, style: .date)
                            .font(.arial(size: 15))
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .glassEffect(.regular, in: .rect(cornerRadius: 12))
                            .padding(.horizontal)
                    }
                }
                
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .appCanvasBackground()
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Edit") {
                    showEdit = true
                }
            }
        }
        .sheet(isPresented: $showEdit) {
            ProgramEntryView(program: program)
        }
    }
    
    // Match/mismatch indicator relative to the applicant's preferred EMR.
    // Returns nil when no preferred EMR is set (nothing to compare against).
    private var emrMatchIndicator: (text: String, systemImage: String, color: Color)? {
        guard let preferredRaw = dataManager.preferences.preferredEMR,
              let preferred = EMRSystem(rawValue: preferredRaw),
              preferred.isSpecific else {
            return nil
        }
        
        guard let programRaw = program.emr,
              let programSystem = EMRSystem(rawValue: programRaw),
              programSystem.isSpecific else {
            // Program EMR unknown / "Other" / "Not sure" -> neutral, not scored.
            return ("Not scored — EMR unknown for this program", "minus.circle", .secondary)
        }
        
        if programSystem == preferred {
            return ("Matches your preferred EMR", "checkmark.circle.fill", .green)
        } else {
            return ("Different from your preferred EMR (\(preferred.displayName))", "exclamationmark.circle", .orange)
        }
    }
    
}

struct CategoryScoreView: View {
    let title: String
    let score: Double
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.arial(size: 16, weight: .semibold))
                Spacer()
                Text(String(format: "%.1f", score))
                    .font(.arial(size: 18, weight: .bold))
                    .foregroundColor(color)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(height: 8)
                        .cornerRadius(4)
                    
                    Rectangle()
                        .fill(color)
                        .frame(width: geometry.size.width * CGFloat(score / 5.0), height: 8)
                        .cornerRadius(4)
                }
            }
            .frame(height: 8)
        }
        .padding()
        .glassEffect(.regular, in: .rect(cornerRadius: 12))
    }
}

#Preview {
    MatchlyNavigationView {
        ProgramDetailView(program: Program(
            specialty: "Internal Medicine",
            name: "Sample Program",
            hospital: "Sample Hospital",
            city: "New York",
            state: "NY"
        ))
        .environmentObject(DataManager.shared)
    }
}

