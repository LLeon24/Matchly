//
//  StateFilterSheet.swift
//  Matchly
//
//  Created on 11/16/25.
//

import SwiftUI

struct StateFilterSheet: View {
    let allStates: [String]
    @Binding var selectedStates: Set<String>
    @Binding var showAll: Bool
    let onApply: () -> Void
    let onClear: () -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section("States") {
                    ForEach(allStates, id: \.self) { state in
                        Button(action: {
                            if state == "All" {
                                // Selecting "All" clears all selections
                                selectedStates.removeAll()
                                showAll = true
                            } else {
                                if selectedStates.contains(state) {
                                    selectedStates.remove(state)
                                } else {
                                    selectedStates.insert(state)
                                }
                                // If nothing selected, show all
                                showAll = selectedStates.isEmpty
                            }
                        }) {
                            HStack {
                                ZStack {
                                    Circle()
                                        .fill((state == "All" && showAll) || (state != "All" && selectedStates.contains(state)) ? Color.blue : Color.clear)
                                        .frame(width: 22, height: 22)
                                        .overlay(
                                            Circle()
                                                .stroke((state == "All" && showAll) || (state != "All" && selectedStates.contains(state)) ? Color.blue : Color.secondary, lineWidth: 2)
                                        )
                                    
                                    if (state == "All" && showAll) || (state != "All" && selectedStates.contains(state)) {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                }
                                .frame(width: 22, height: 22)
                                
                                Text(state)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("Filter States")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Clear") {
                        selectedStates.removeAll()
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

