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
        List {
            if programsNeedingReview.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.green)
                    
                    Text("All Programs Reviewed")
                        .font(.system(size: 20, weight: .bold))
                    
                    Text("All your programs have questionnaire data")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                ForEach(programsNeedingReview) { program in
                    NavigationLink(destination: ProgramEntryView(program: program)) {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.red.opacity(0.15))
                                    .frame(width: 40, height: 40)
                                
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.red)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(HospitalNameFormatter.format(program.hospital.isEmpty ? program.name : program.hospital))
                                    .font(.system(size: 16, weight: .semibold))
                                    .lineLimit(2)
                                
                                if !program.city.isEmpty && !program.state.isEmpty {
                                    Text("\(program.city), \(program.state)")
                                        .font(.system(size: 13))
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            // Signal buttons
                            HStack(spacing: 8) {
                                Button(action: {
                                    // Handle gold signal
                                    let result = dataManager.canAssignSignal(type: .gold, specialty: program.specialty, excludingProgramId: program.id)
                                    if result.canAssign {
                                        var updatedProgram = program
                                        updatedProgram.signalType = updatedProgram.signalType == .gold ? .none : .gold
                                        dataManager.updateProgram(updatedProgram)
                                    }
                                }) {
                                    Image(systemName: program.signalType == .gold ? "star.fill" : "star")
                                        .font(.system(size: 14))
                                        .foregroundColor(program.signalType == .gold ? .yellow : .gray.opacity(0.4))
                                }
                                .buttonStyle(.plain)
                                
                                Button(action: {
                                    // Handle silver signal
                                    let result = dataManager.canAssignSignal(type: .silver, specialty: program.specialty, excludingProgramId: program.id)
                                    if result.canAssign {
                                        var updatedProgram = program
                                        updatedProgram.signalType = updatedProgram.signalType == .silver ? .none : .silver
                                        dataManager.updateProgram(updatedProgram)
                                    }
                                }) {
                                    Image(systemName: program.signalType == .silver ? "star.fill" : "star")
                                        .font(.system(size: 14))
                                        .foregroundColor(program.signalType == .silver ? Color(white: 0.6) : .gray.opacity(0.4))
                                }
                                .buttonStyle(.plain)
                            }
                            
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("No Data")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.red)
                                
                                Text("Tap to review")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
        }
        .navigationTitle("Programs Needing Review")
        .navigationBarTitleDisplayMode(.large)
    }
}

#Preview {
    NavigationView {
        ProgramsNeedingReviewView()
            .environmentObject(DataManager.shared)
    }
}

