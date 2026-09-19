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
        MatchlyNavigationView {
            List {
                Section("States") {
                    ForEach(allStates, id: \.self) { state in
                        let isSelected = (state == "All" && showAll) || (state != "All" && selectedStates.contains(state))
                        Button(action: {
                            if state == "All" {
                                selectedStates.removeAll()
                                showAll = true
                            } else {
                                if selectedStates.contains(state) {
                                    selectedStates.remove(state)
                                } else {
                                    selectedStates.insert(state)
                                }
                                showAll = selectedStates.isEmpty
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
                                
                                Text(state)
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
                    .buttonStyle(.glassProminent)
                    .tint(AppColors.primaryBlue)
                }
            }
        }
    }
}
