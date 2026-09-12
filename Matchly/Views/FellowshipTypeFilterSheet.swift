//
//  FellowshipTypeFilterSheet.swift
//  Matchly
//

import SwiftUI

struct FellowshipTypeFilterSheet: View {
  let userSpecialties: [String]
  @Binding var selectedCodes: Set<String>
  @Binding var showAll: Bool
  let onApply: () -> Void
  let onClear: () -> Void

  @State private var searchText = ""

  private var groupedOptions: [(parent: String, options: [FellowshipFilterOption])] {
    FellowshipFilterCatalog.groupedOptions(forUserSpecialties: userSpecialties)
  }

  private func filteredGroups() -> [(parent: String, options: [FellowshipFilterOption])] {
    let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !query.isEmpty else { return groupedOptions }

    return groupedOptions.compactMap { group in
      let matches = group.options.filter {
        $0.displayName.localizedCaseInsensitiveContains(query)
          || $0.parentLabel.localizedCaseInsensitiveContains(query)
      }
      return matches.isEmpty ? nil : (parent: group.parent, options: matches)
    }
  }

  var body: some View {
    MatchlyNavigationView {
      List {
        if userSpecialties.isEmpty {
          Section {
            Text("Select your specialty first to see eligible fellowship types.")
              .font(.arial(size: 14))
              .foregroundColor(.secondary)
          }
        } else if groupedOptions.isEmpty {
          Section {
            Text("No fellowship types found for your selected specialty.")
              .font(.arial(size: 14))
              .foregroundColor(.secondary)
          }
        } else {
          ForEach(filteredGroups(), id: \.parent) { group in
            Section(group.parent) {
              ForEach(group.options) { option in
                fellowshipRow(option)
              }
            }
          }
        }
      }
      .searchable(text: $searchText, prompt: "Search fellowship types")
      .scrollContentBackground(.hidden)
      .appCanvasBackground()
      .navigationTitle("Fellowship Type")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button("Clear") {
            selectedCodes.removeAll()
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

  @ViewBuilder
  private func fellowshipRow(_ option: FellowshipFilterOption) -> some View {
    let isSelected = selectedCodes.contains(option.code)
    Button(action: {
      if isSelected {
        selectedCodes.remove(option.code)
      } else {
        selectedCodes.insert(option.code)
      }
      showAll = selectedCodes.isEmpty
    }) {
      HStack(alignment: .top, spacing: 12) {
        ZStack {
          Circle()
            .fill(isSelected ? Color.purple : Color.clear)
            .frame(width: 22, height: 22)
            .overlay(
              Circle()
                .stroke(isSelected ? Color.purple : Color.secondary, lineWidth: 2)
            )

          if isSelected {
            Image(systemName: "checkmark")
              .font(.arial(size: 12, weight: .bold))
              .foregroundColor(.white)
          }
        }
        .frame(width: 22, height: 22)
        .padding(.top, 2)

        Text(option.displayName)
          .font(.arial(size: 15))
          .foregroundColor(.primary)
          .multilineTextAlignment(.leading)
          .fixedSize(horizontal: false, vertical: true)

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
