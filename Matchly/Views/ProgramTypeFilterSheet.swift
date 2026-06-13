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
                Section("Program Types") {
                    ForEach(programTypes, id: \.self) { type in
                        let isSelected = selectedTypes.contains(type)
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
                                        .fill(isSelected ? Color.blue : Color.clear)
                                        .frame(width: 22, height: 22)
                                        .overlay(
                                            Circle()
                                                .stroke(isSelected ? Color.blue : Color.secondary, lineWidth: 2)
                                        )
                                    
                                    if isSelected {
                                        Image(systemName: "checkmark")
                                            .font(.arial(size: 12, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                }
                                .frame(width: 22, height: 22)
                                
                                Text(type)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .glassChipStyle(tint: isSelected ? .blue : nil)
                        }
                        .buttonStyle(.plain)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                        .listRowBackground(Color.clear)
                    }
                }
                
                Section {
                    let isIMGSelected = selectedTypes.contains("IMG-Friendly")
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
                                    .fill(isIMGSelected ? Color.blue : Color.clear)
                                    .frame(width: 22, height: 22)
                                    .overlay(
                                        Circle()
                                            .stroke(isIMGSelected ? Color.blue : Color.secondary, lineWidth: 2)
                                    )
                                
                                if isIMGSelected {
                                    Image(systemName: "checkmark")
                                        .font(.arial(size: 12, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }
                            .frame(width: 22, height: 22)
                            
                            Image(systemName: "globe.americas.fill")
                                .foregroundColor(.purple)
                                .font(.arial(size: 12))
                            
                            Text("IMG-Friendly")
                                .foregroundColor(.primary)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .glassChipStyle(tint: isIMGSelected ? .purple : nil)
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    .listRowBackground(Color.clear)
                }
            }
            .scrollContentBackground(.hidden)
            .appCanvasBackground()
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
                    .buttonStyle(.glassProminent)
                    .tint(AppColors.primaryBlue)
                }
            }
        }
    }
}
