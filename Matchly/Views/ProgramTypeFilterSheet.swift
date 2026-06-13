//
//  ProgramTypeFilterSheet.swift
//  Matchly
//
//  Created on 11/15/25.
//

import SwiftUI

struct ProgramTypeFilterSheet: View {
    let programTypes: [String]
    @Binding var selectedTypes: Set<String>
    @Binding var showAll: Bool
    let onApply: () -> Void
    let onClear: () -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List {
                // Program Types section
                Section("Program Types") {
                    ForEach(programTypes, id: \.self) { type in
                        Button(action: {
                            showAll = false
                            if selectedTypes.contains(type) {
                                selectedTypes.remove(type)
                            } else {
                                selectedTypes.insert(type)
                            }
                        }) {
                            HStack {
                                ZStack {
                                    Circle()
                                        .fill(selectedTypes.contains(type) ? Color.blue : Color.clear)
                                        .frame(width: 22, height: 22)
                                        .overlay(
                                            Circle()
                                                .stroke(selectedTypes.contains(type) ? Color.blue : Color.secondary, lineWidth: 2)
                                        )
                                    
                                    if selectedTypes.contains(type) {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                }
                                .frame(width: 22, height: 22)
                                
                                Text(type)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                // IMG-Friendly section
                Section {
                    Button(action: {
                        showAll = false
                        if selectedTypes.contains("IMG-Friendly") {
                            selectedTypes.remove("IMG-Friendly")
                        } else {
                            selectedTypes.insert("IMG-Friendly")
                        }
                    }) {
                        HStack {
                            ZStack {
                                Circle()
                                    .fill(selectedTypes.contains("IMG-Friendly") ? Color.blue : Color.clear)
                                    .frame(width: 22, height: 22)
                                    .overlay(
                                        Circle()
                                            .stroke(selectedTypes.contains("IMG-Friendly") ? Color.blue : Color.secondary, lineWidth: 2)
                                    )
                                
                                if selectedTypes.contains("IMG-Friendly") {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }
                            .frame(width: 22, height: 22)
                            
                            Image(systemName: "globe.americas.fill")
                                .foregroundColor(.purple)
                                .font(.system(size: 12))
                            
                            Text("IMG-Friendly")
                                .foregroundColor(.primary)
                            
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("Program Types")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Clear") {
                        onClear()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Apply") {
                        onApply()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

