//
//  SpecialtyFilterSheet.swift
//  Matchly
//
//  Created on 11/16/25.
//

import SwiftUI

struct SpecialtyFilterSheet: View {
    let allSpecialties: [String]
    @Binding var selectedSpecialties: Set<String>
    @Binding var showAll: Bool
    var navigationTitle: String = "Filter Specialties"
    let onApply: () -> Void
    let onClear: () -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        MatchlyNavigationView {
            List {
                Section("Specialties") {
                    ForEach(allSpecialties, id: \.self) { specialty in
                        let isSelected = selectedSpecialties.contains(specialty)
                        Button(action: {
                            if selectedSpecialties.contains(specialty) {
                                selectedSpecialties.remove(specialty)
                            } else {
                                selectedSpecialties.insert(specialty)
                            }
                            showAll = selectedSpecialties.isEmpty
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
                                
                                Text(SpecialtyFormatter.displayNameWithAbbreviation(specialty))
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
            }
            .scrollContentBackground(.hidden)
            .appCanvasBackground()
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Clear") {
                        selectedSpecialties.removeAll()
                        showAll = true
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
