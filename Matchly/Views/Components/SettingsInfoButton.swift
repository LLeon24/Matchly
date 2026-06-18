//
//  SettingsInfoButton.swift
//  Matchly
//

import SwiftUI

struct SettingsInfoButton: View {
    let title: String
    let message: String

    @State private var showInfo = false

    var body: some View {
        Button {
            showInfo = true
        } label: {
            Image(systemName: "info.circle")
                .font(.arial(size: 14))
                .foregroundColor(.secondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("About \(title)")
        .alert(title, isPresented: $showInfo) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(message)
        }
    }
}

struct SettingsSectionHeader: View {
    let title: String
    let infoMessage: String

    var body: some View {
        HStack(spacing: 4) {
            Text(title)
            SettingsInfoButton(title: title, message: infoMessage)
        }
    }
}

struct SettingsLabeledToggle: View {
    let title: String
    let infoMessage: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 6) {
            Text(title)
            SettingsInfoButton(title: title, message: infoMessage)
            Spacer(minLength: 8)
            Toggle("", isOn: $isOn)
                .labelsHidden()
        }
    }
}

enum CouplesSettingsCopy {
    static let matchingCriteriaSection = """
        Controls how Matchly builds your suggested couples rank list. These settings affect automatic generation only — you can always edit pairs manually afterward.
        """

    static let mustMatchTogether = """
        When on, the suggested list focuses on pairs where both of you could match together. When off, Matchly may include \"No Match\" rows so NRMP can match one partner individually if you cannot match as a couple.
        """

    static let preferSameHospital = """
        Boosts pairs where both programs are at the same hospital or health system. It does not automatically remove other pairs unless your geography rules exclude them.
        """

    static let prioritizeIndividualRankLists = """
        When on, suggested pairs favor programs that are high on each partner's personal rank list. When off, overall program scores and geography matter more.
        """

    static let geographySection = """
        Sets how strictly program locations must align when Matchly suggests pairs. Same city is strictest. Same state allows different cities. Within max distance only uses your mile limit.
        """

    static let locationRequirement = """
        Same City requires both programs to be in the same city (and state). Same State requires the same state but allows different cities. Within Max Distance only enforces your distance slider below.
        """

    static let maximumDistance = """
        Pairs farther apart than this are excluded from the suggested list. This always applies, even when same state or same city is selected, as a backstop for incomplete address data.
        """
}
