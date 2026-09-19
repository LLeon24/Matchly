//
//  TrainingLevelFilterSheet.swift
//  Matchly
//

import SwiftUI

struct TrainingLevelFilterSheet: View {
    @Binding var selection: ProgramTrainingLevelFilter
    let onApply: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        MatchlyNavigationView {
            List {
                Section("Program Track") {
                    ForEach(ProgramTrainingLevelFilter.allCases) { level in
                        let isSelected = selection == level
                        Button {
                            selection = level
                        } label: {
                            HStack(spacing: 12) {
                                selectionBubble(isSelected: isSelected, tint: .purple)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(level.rawValue)
                                        .foregroundColor(.primary)
                                    if let subtitle = level.subtitle {
                                        Text(subtitle)
                                            .font(.arial(size: 12))
                                            .foregroundColor(.secondary)
                                    }
                                }

                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .glassChipStyle(tint: isSelected ? .purple : nil)
                        }
                        .buttonStyle(.plain)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                        .listRowBackground(Color.clear)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .appCanvasBackground()
            .navigationTitle("Program Track")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Apply") {
                        onApply()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .buttonStyle(.glassProminent)
                    .tint(AppColors.primaryBlue)
                }
            }
        }
    }

    @ViewBuilder
    private func selectionBubble(isSelected: Bool, tint: Color) -> some View {
        ZStack {
            Circle()
                .fill(isSelected ? tint : Color.clear)
                .frame(width: 22, height: 22)
                .overlay(
                    Circle()
                        .stroke(isSelected ? tint : Color.secondary, lineWidth: 2)
                )

            if isSelected {
                Image(systemName: "checkmark")
                    .font(.arial(size: 12, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        .frame(width: 22, height: 22)
    }
}

private extension ProgramTrainingLevelFilter {
    var subtitle: String? {
        switch self {
        case .all: return "Residencies and fellowships"
        case .residency: return "Core and combined programs"
        case .fellowship: return "Subspecialty fellowships"
        }
    }
}
