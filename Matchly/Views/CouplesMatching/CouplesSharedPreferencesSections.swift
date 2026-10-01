//
//  CouplesSharedPreferencesSections.swift
//  Matchly
//

import SwiftUI

struct CouplesSharedPreferencesSections: View {
    @Binding var mustMatchTogether: Bool
    @Binding var preferSameHospital: Bool
    @Binding var geographyStrictness: CouplesPreferences.GeographyStrictness
    @Binding var prioritizeIndividualRankLists: Bool
    @Binding var distanceTolerance: Double

    var body: some View {
        Section {
            SettingsLabeledToggle(
                title: "Must Match Together",
                infoMessage: CouplesSettingsCopy.mustMatchTogether,
                isOn: $mustMatchTogether
            )
            SettingsLabeledToggle(
                title: "Prefer Same Hospital",
                infoMessage: CouplesSettingsCopy.preferSameHospital,
                isOn: $preferSameHospital
            )
            SettingsLabeledToggle(
                title: "Prioritize Individual Rank Lists",
                infoMessage: CouplesSettingsCopy.prioritizeIndividualRankLists,
                isOn: $prioritizeIndividualRankLists
            )
        } header: {
            SettingsSectionHeader(
                title: "Matching Criteria",
                infoMessage: CouplesSettingsCopy.matchingCriteriaSection
            )
        }

        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 4) {
                    Text("Location requirement")
                        .font(.arial(size: 15))
                    SettingsInfoButton(
                        title: "Location Requirement",
                        message: CouplesSettingsCopy.locationRequirement
                    )
                }

                Picker("Location requirement", selection: $geographyStrictness) {
                    ForEach(CouplesPreferences.GeographyStrictness.allCases, id: \.self) { level in
                        Text(level.displayName).tag(level)
                    }
                }
                .labelsHidden()
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 4) {
                    Text("Maximum Distance: \(Int(distanceTolerance)) miles")
                        .font(.arial(size: 15, weight: .medium))
                    SettingsInfoButton(
                        title: "Maximum Distance",
                        message: CouplesSettingsCopy.maximumDistance
                    )
                }
                Slider(value: $distanceTolerance, in: 0...500, step: 25)
            }
            .padding(.vertical, 4)
        } header: {
            SettingsSectionHeader(
                title: "Geography",
                infoMessage: CouplesSettingsCopy.geographySection
            )
        } footer: {
            Text(geographyStrictness.detail)
                .font(.arial(size: 12))
        }
    }
}
