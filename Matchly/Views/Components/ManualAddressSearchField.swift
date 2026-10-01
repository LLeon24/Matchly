//
//  ManualAddressSearchField.swift
//  Matchly
//

import SwiftUI
import MapKit

struct ManualAddressSearchField: View {
    @Binding var address: String
    @Binding var city: String
    @Binding var state: String
    @Binding var postalCode: String

    @StateObject private var searchModel = AddressSearchCompleterModel()
    @State private var query = ""
    @FocusState private var isQueryFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.blue)

                TextField("Search address (Apple Maps)", text: $query)
                    .font(.arial(size: 16))
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .textContentType(.location)
                    .focused($isQueryFocused)
                    .onChange(of: query) { _, newValue in
                        searchModel.updateQuery(newValue)
                    }

                if searchModel.isResolving {
                    ProgressView()
                        .controlSize(.small)
                } else if !query.isEmpty {
                    Button {
                        query = ""
                        searchModel.clearResults()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary.opacity(0.55))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear address search")
                }
            }

            if isQueryFocused, !searchModel.completions.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(searchModel.completions.enumerated()), id: \.offset) { index, completion in
                        if index > 0 {
                            Divider()
                                .padding(.leading, 8)
                        }
                        Button {
                            apply(completion)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(completion.title)
                                    .font(.arial(size: 15, weight: .medium))
                                    .foregroundColor(.primary)
                                    .multilineTextAlignment(.leading)
                                if !completion.subtitle.isEmpty {
                                    Text(completion.subtitle)
                                        .font(.arial(size: 12))
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.leading)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 8)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .background(Color(.secondarySystemGroupedBackground).opacity(0.65))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            if showsAddressSearchHint {
                Text("Pick a result to fill street, city, state, and ZIP. You can still edit below.")
                    .font(.arial(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var showsAddressSearchHint: Bool {
        address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func apply(_ completion: MKLocalSearchCompletion) {
        isQueryFocused = false
        searchModel.clearResults()

        Task {
            guard let resolved = await searchModel.resolve(completion) else { return }
            if !resolved.street.isEmpty {
                address = resolved.street
            }
            if !resolved.city.isEmpty {
                city = resolved.city
            }
            if !resolved.state.isEmpty {
                state = resolved.state
            }
            if !resolved.postalCode.isEmpty {
                postalCode = resolved.postalCode
            }
            query = ""
            searchModel.clearResults()
        }
    }
}
