//
//  ProgramComparisonView.swift
//  Matchly
//
//  Created on 11/14/25.
//

import SwiftUI

struct ProgramComparisonView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var selectedPrograms: Set<String> = []
    @State private var showProgramPicker = false
    
    var comparisonPrograms: [Program] {
        dataManager.programs.filter { selectedPrograms.contains($0.id) }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if selectedPrograms.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "square.grid.2x2")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        
                        Text("Compare Programs")
                            .font(.system(size: 24, weight: .semibold))
                        
                        Text("Select 2-4 programs to compare side-by-side")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button(action: {
                            showProgramPicker = true
                        }) {
                            Text("Select Programs")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 30)
                                .padding(.vertical, 12)
                                .background(Color.blue)
                                .cornerRadius(10)
                        }
                    }
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(comparisonPrograms) { program in
                                ComparisonCard(program: program, onRemove: {
                                    selectedPrograms.remove(program.id)
                                })
                            }
                            
                            // Add more button
                            if comparisonPrograms.count < 4 {
                                Button(action: {
                                    showProgramPicker = true
                                }) {
                                    VStack(spacing: 12) {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.system(size: 40))
                                            .foregroundColor(.blue)
                                        Text("Add Program")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .frame(width: 200, height: 300)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(12)
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Compare Programs")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !selectedPrograms.isEmpty {
                        Menu {
                            Button(action: {
                                showProgramPicker = true
                            }) {
                                Label("Add Program", systemImage: "plus")
                            }
                            
                            Button(role: .destructive, action: {
                                selectedPrograms.removeAll()
                            }) {
                                Label("Clear All", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
            .sheet(isPresented: $showProgramPicker) {
                ProgramComparisonPickerView(
                    selectedPrograms: $selectedPrograms,
                    currentSelections: selectedPrograms
                )
            }
        }
    }
}

struct ComparisonCard: View {
    let program: Program
    let onRemove: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(HospitalNameFormatter.format(program.hospital))
                        .font(.system(size: 18, weight: .bold))
                        .lineLimit(2)
                    
                    Spacer()
                    
                    Button(action: onRemove) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
                
                Text(program.specialty)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("\(program.city), \(program.state)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            // Scores
            VStack(alignment: .leading, spacing: 12) {
                ComparisonRow(label: "Overall Score", value: String(format: "%.1f", program.finalScore), color: scoreColor(program.finalScore))
                ComparisonRow(label: "Program Quality", value: String(format: "%.1f", program.programQuality.average()), color: .blue)
                ComparisonRow(label: "Culture Fit", value: String(format: "%.1f", program.cultureFit.average()), color: .purple)
                ComparisonRow(label: "Location", value: String(format: "%.1f", program.location.average()), color: .green)
                ComparisonRow(label: "Logistics", value: String(format: "%.1f", program.logistics.average()), color: .orange)
                ComparisonRow(label: "Career Alignment", value: String(format: "%.1f", program.careerAlignment.average()), color: .pink)
                
                if program.redFlags.total() > 0 {
                    ComparisonRow(label: "Red Flags", value: String(format: "%.1f", program.redFlags.total()), color: .red)
                }
            }
            
            // Interview date
            if let date = program.interviewDate {
                Divider()
                VStack(alignment: .leading, spacing: 4) {
                    Text("Interview Date")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(date, style: .date)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
            }
        }
        .padding()
        .frame(width: 250)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    private func scoreColor(_ score: Double) -> Color {
        if score >= 80 { return .green }
        if score >= 60 { return .blue }
        if score >= 40 { return .orange }
        return .red
    }
}

struct ComparisonRow: View {
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
    }
}

struct ProgramComparisonPickerView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var dataManager: DataManager
    @Binding var selectedPrograms: Set<String>
    let currentSelections: Set<String>
    @State private var tempSelections: Set<String>
    
    init(selectedPrograms: Binding<Set<String>>, currentSelections: Set<String>) {
        self._selectedPrograms = selectedPrograms
        self.currentSelections = currentSelections
        self._tempSelections = State(initialValue: currentSelections)
    }
    
    var body: some View {
        NavigationView {
            List {
                ForEach(dataManager.programs) { program in
                    Button(action: {
                        if tempSelections.contains(program.id) {
                            tempSelections.remove(program.id)
                        } else if tempSelections.count < 4 {
                            tempSelections.insert(program.id)
                        }
                    }) {
                        HStack {
                            Image(systemName: tempSelections.contains(program.id) ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(tempSelections.contains(program.id) ? .blue : .gray)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(HospitalNameFormatter.format(program.hospital))
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.primary)
                                Text("\(program.city), \(program.state)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if tempSelections.count >= 4 && !tempSelections.contains(program.id) {
                                Text("Max 4")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Programs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        selectedPrograms = tempSelections
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(tempSelections.count < 2)
                }
            }
        }
    }
}

#Preview {
    ProgramComparisonView()
        .environmentObject(DataManager.shared)
}

