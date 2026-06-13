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
    let onApply: () -> Void
    let onClear: () -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section("Specialties") {
                    ForEach(allSpecialties, id: \.self) { specialty in
                        Button(action: {
                            if selectedSpecialties.contains(specialty) {
                                selectedSpecialties.remove(specialty)
                            } else {
                                selectedSpecialties.insert(specialty)
                            }
                            showAll = selectedSpecialties.isEmpty // If nothing selected, show all
                        }) {
                            HStack {
                                ZStack {
                                    Circle()
                                        .fill(selectedSpecialties.contains(specialty) ? Color.blue : Color.clear)
                                        .frame(width: 22, height: 22)
                                        .overlay(
                                            Circle()
                                                .stroke(selectedSpecialties.contains(specialty) ? Color.blue : Color.secondary, lineWidth: 2)
                                        )
                                    
                                    if selectedSpecialties.contains(specialty) {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                }
                                .frame(width: 22, height: 22)
                                
                                Text(SpecialtyFormatter.displayNameWithAbbreviation(specialty))
                                    .foregroundColor(.primary)
                                
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("Filter Specialties")
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
                }
            }
        }
    }
}

