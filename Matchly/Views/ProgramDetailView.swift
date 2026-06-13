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
                        .font(.system(size: 28, weight: .bold))
                    
                    if !program.hospital.isEmpty {
                        Text(HospitalNameFormatter.format(program.hospital))
                            .font(.system(size: 18))
                            .foregroundColor(.secondary)
                    }
                    
                    if !program.city.isEmpty && !program.state.isEmpty {
                        Text("\(program.city), \(program.state)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text(program.type)
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                        
                        Spacer()
                        
                        VStack(alignment: .trailing) {
                            Text("Final Score")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(String(format: "%.1f", program.finalScore))
                                .font(.system(size: 32, weight: .bold))
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
                                .font(.system(size: 16, weight: .semibold))
                            Text(String(format: "Total: %.1f", program.redFlags.total()))
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.red)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(12)
                    }
                }
                .padding()
                
                // Notes
                if !program.notes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes")
                            .font(.system(size: 18, weight: .semibold))
                            .padding(.horizontal)
                        
                        Text(program.notes)
                            .font(.system(size: 15))
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                            .padding(.horizontal)
                    }
                }
                
                // Interview Date
                if let date = program.interviewDate {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Interview Date")
                            .font(.system(size: 18, weight: .semibold))
                            .padding(.horizontal)
                        
                        Text(date, style: .date)
                            .font(.system(size: 15))
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                            .padding(.horizontal)
                    }
                }
                
                // Voice Memo
                if program.voiceMemoURL != nil {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Voice Memo")
                            .font(.system(size: 18, weight: .semibold))
                            .padding(.horizontal)
                        
                        VoiceMemoPlayer(voiceMemoURL: program.voiceMemoURL)
                            .padding(.horizontal)
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
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
    
    private func scoreColor(_ score: Double) -> Color {
        if score >= 80 { return .green }
        if score >= 60 { return .blue }
        if score >= 40 { return .orange }
        return .red
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
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                Text(String(format: "%.1f", score))
                    .font(.system(size: 18, weight: .bold))
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
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

#Preview {
    NavigationView {
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

