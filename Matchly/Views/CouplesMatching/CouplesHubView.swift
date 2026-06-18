//
//  CouplesHubView.swift
//  Matchly
//
//  Central hub for linked couples: chat, shared rank list, and preferences.
//

import SwiftUI

struct CouplesHubView: View {
    @EnvironmentObject var dataManager: DataManager
    @ObservedObject private var coupleSync = CoupleSyncCoordinator.shared
    @ObservedObject private var authManager = AuthManager.shared

    @State private var selectedPage = 0

    private var couple: Couple? {
        dataManager.preferences.couple
    }

    var body: some View {
        Group {
            if let couple, couple.isLinked {
                linkedContent(couple: couple)
            } else {
                MatchlyNavigationView {
                    CouplesMatchingView()
                }
            }
        }
        .task {
            await coupleSync.refreshAll(dataManager: dataManager)
            dataManager.startCoupleSyncIfNeeded()
        }
    }

    @ViewBuilder
    private func linkedContent(couple: Couple) -> some View {
        MatchlyNavigationView {
            VStack(spacing: 0) {
                coupleHeader(couple: couple)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 12)

                Picker("Section", selection: $selectedPage) {
                    Text("Chat").tag(0)
                    Text("Rank List").tag(1)
                    Text("Settings").tag(2)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

                Group {
                    switch selectedPage {
                    case 0:
                        CoupleChatView(couple: couple, embeddedInHub: true)
                    case 1:
                        CouplesRankListView(embeddedInHub: true)
                    case 2:
                        CouplesHubSettingsView(couple: couple)
                    default:
                        CoupleChatView(couple: couple, embeddedInHub: true)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .navigationTitle("Couple Match")
            .navigationBarTitleDisplayMode(.inline)
            .appCanvasBackground()
        }
    }

    @ViewBuilder
    private func coupleHeader(couple: Couple) -> some View {
        let myName = displayName(for: couple, isPartner: false)
        let partnerName = displayName(for: couple, isPartner: true)

        HStack(spacing: 12) {
            HStack(spacing: 10) {
                ProfilePhotoView(
                    photoData: dataManager.preferences.profile.photoData,
                    size: 44
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text("You")
                        .font(.arial(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                    Text(myName)
                        .font(.arial(size: 15, weight: .semibold))
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 4)

            Image(systemName: "heart.fill")
                .foregroundColor(.pink)
                .font(.arial(size: 18))

            Spacer(minLength: 4)

            HStack(spacing: 10) {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Partner")
                        .font(.arial(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                    Text(partnerName)
                        .font(.arial(size: 15, weight: .semibold))
                        .lineLimit(1)
                }

                ProfilePhotoView(
                    photoData: coupleSync.partnerProfilePhotoData,
                    size: 44
                )
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private func displayName(for couple: Couple, isPartner: Bool) -> String {
        guard let myRecord = authManager.cloudKitUserRecordName else {
            return isPartner ? (couple.user2Name ?? "Partner") : couple.user1Name
        }

        let iAmUser1 = myRecord == couple.user1ID
        if isPartner {
            return iAmUser1 ? (couple.user2Name ?? "Partner") : couple.user1Name
        }
        return iAmUser1 ? couple.user1Name : (couple.user2Name ?? "You")
    }
}

struct CouplesHubSettingsView: View {
    @EnvironmentObject var dataManager: DataManager
    @ObservedObject private var coupleSync = CoupleSyncCoordinator.shared

    let couple: Couple

    @State private var mustMatchTogether: Bool = true
    @State private var preferSameHospital: Bool = false
    @State private var geographyStrictness: CouplesPreferences.GeographyStrictness = .sameState
    @State private var prioritizeIndividualRankLists: Bool = true
    @State private var distanceTolerance: Double = 100
    @State private var didLoad = false

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 4) {
                        Text("NRMP Couples Match")
                            .font(.arial(size: 15, weight: .semibold))
                        SettingsInfoButton(
                            title: "NRMP Couples Match",
                            message: "Rank joint pairs where both of you match. If you cannot match together, NRMP may match one partner individually depending on your list. Use Must Match Together when you only want to match as a couple."
                        )
                    }
                    Text("Rank joint pairs where both of you match. If you cannot match together, NRMP may match one partner individually depending on your list. Use \"Must Match Together\" when you only want to match as a couple.")
                        .font(.arial(size: 13))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }

            CouplesSharedPreferencesSections(
                mustMatchTogether: $mustMatchTogether,
                preferSameHospital: $preferSameHospital,
                geographyStrictness: $geographyStrictness,
                prioritizeIndividualRankLists: $prioritizeIndividualRankLists,
                distanceTolerance: $distanceTolerance
            )

            if coupleSync.isSyncing {
                Section {
                    HStack {
                        ProgressView()
                        Text("Syncing with partner…")
                            .font(.arial(size: 14))
                            .foregroundColor(.secondary)
                    }
                }
            }

            Section {
                NavigationLink(destination: CouplesMatchingView()) {
                    Label("Manage Link & Invites", systemImage: "person.2.fill")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .matchlyScrollTabBarClearance()
        .onAppear {
            guard !didLoad else { return }
            loadPreferences()
            didLoad = true
        }
        .onChange(of: mustMatchTogether) { _, _ in savePreferences() }
        .onChange(of: preferSameHospital) { _, _ in savePreferences() }
        .onChange(of: geographyStrictness) { _, _ in savePreferences() }
        .onChange(of: prioritizeIndividualRankLists) { _, _ in savePreferences() }
        .onChange(of: distanceTolerance) { _, _ in savePreferences() }
    }

    private func loadPreferences() {
        let prefs = dataManager.preferences.couplesPreferences
        mustMatchTogether = prefs.mustMatchTogether
        preferSameHospital = prefs.preferSameHospital
        geographyStrictness = prefs.geographyStrictness
        prioritizeIndividualRankLists = prefs.prioritizeIndividualRankLists
        distanceTolerance = Double(prefs.distanceTolerance)
    }

    private func savePreferences() {
        dataManager.preferences.couplesPreferences.mustMatchTogether = mustMatchTogether
        dataManager.preferences.couplesPreferences.preferSameHospital = preferSameHospital
        dataManager.preferences.couplesPreferences.geographyStrictness = geographyStrictness
        dataManager.preferences.couplesPreferences.normalizeGeography()
        dataManager.preferences.couplesPreferences.prioritizeIndividualRankLists = prioritizeIndividualRankLists
        dataManager.preferences.couplesPreferences.distanceTolerance = Int(distanceTolerance)
        dataManager.savePreferences()
        dataManager.scheduleCoupleCloudPublish()
    }
}
