//
//  CouplesMatchingView.swift
//  Matchly
//
//  Created on 11/16/25.
//

import SwiftUI

struct CouplesMatchingView: View {
    @EnvironmentObject var dataManager: DataManager
    @ObservedObject private var authManager = AuthManager.shared
    @Environment(\.dismiss) var dismiss
    @State private var showLinkPartner = false
    @State private var showUserSearch = false
    @State private var showInvites = false
    @State private var partnerCode = ""
    @State private var showCouplesRankList = false
    @State private var showPreferences = false
    @State private var showMyQRCode = false
    @State private var showQRScanner = false
    @State private var showUnlinkConfirm = false
    @State private var linkErrorMessage: String?
    @State private var isLinkingFromScan = false
    
    var body: some View {
        Form {
            if let couple = dataManager.preferences.couple {
                if couple.isLinked {
                    // Linked state
                    Section {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("You")
                                    .font(.arial(size: 12, weight: .medium))
                                    .foregroundColor(.secondary)
                                Text(couple.user1Name)
                                    .font(.arial(size: 16, weight: .semibold))
                            }
                            
                            Spacer()
                            
                            Image(systemName: "heart.fill")
                                .foregroundColor(.pink)
                                .font(.arial(size: 20))
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("Partner")
                                    .font(.arial(size: 12, weight: .medium))
                                    .foregroundColor(.secondary)
                                Text(couple.user2Name ?? "Unknown")
                                    .font(.arial(size: 16, weight: .semibold))
                            }
                        }
                        .padding(.vertical, 8)
                    } header: {
                        Text("Couple Status")
                    }
                    
                    Section {
                        NavigationLink(destination: CoupleChatView(couple: couple)) {
                            HStack {
                                Image(systemName: "bubble.left.and.bubble.right.fill")
                                    .foregroundColor(.blue)
                                Text("Partner Chat")
                                Spacer()
                                Text("Coordinate together")
                                    .font(.arial(size: 12))
                                    .foregroundColor(.secondary)
                            }
                        }

                        NavigationLink(destination: CouplesRankListView()) {
                            HStack {
                                Image(systemName: "list.number")
                                    .foregroundColor(.blue)
                                Text("Couples Rank List")
                                Spacer()
                                if !dataManager.preferences.couplesRankPairs.isEmpty {
                                    Text("\(dataManager.preferences.couplesRankPairs.count) pairs")
                                        .font(.arial(size: 13))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        
                        Button(action: {
                            showPreferences = true
                        }) {
                            HStack {
                                Image(systemName: "slider.horizontal.3")
                                    .foregroundColor(.blue)
                                Text("Couples Preferences")
                            }
                        }
                    }
                    
                    Section {
                        Button(role: .destructive, action: {
                            showUnlinkConfirm = true
                        }) {
                            Text("Unlink Partner")
                        }
                    } footer: {
                        Text("Unlinking removes the connection on this device. You can link again anytime with a new QR code.")
                    }
                } else {
                    // Pending link state — waiting for partner
                    Section {
                        VStack(spacing: 16) {
                            CoupleQRCodeView(code: couple.coupleCode, size: 180)

                            Text("Waiting for your partner to scan or enter this code.")
                                .font(.arial(size: 13))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    } header: {
                        Text("Your Invite QR")
                    }

                    partnerLinkingActionsSection

                    Section {
                        ShareLink(item: Couple.shareInviteMessage(
                            code: couple.coupleCode,
                            inviterName: couple.user1Name
                        )) {
                            HStack {
                                Image(systemName: "message.fill")
                                    .foregroundColor(.blue)
                                Text("Send Invite via Text")
                            }
                        }

                        Button(action: regenerateCoupleCode) {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                    .foregroundColor(.blue)
                                Text("Generate New Code")
                            }
                        }

                        Button(role: .destructive, action: {
                            showUnlinkConfirm = true
                        }) {
                            Text("Cancel Invite")
                        }
                    } footer: {
                        Text("Send the invite by text if you're apart. Scanning works best when you're together.")
                    }
                }
            } else {
                // No couple set up
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Couples Matching allows you and your partner to create synchronized rank lists for the NRMP Match.")
                            .font(.arial(size: 14))
                            .foregroundColor(.secondary)
                        
                        Text("Key Features:")
                            .font(.arial(size: 15, weight: .semibold))
                            .padding(.top, 8)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            FeatureRow(icon: "person.2.fill", text: "Individual rank lists for each partner")
                            FeatureRow(icon: "list.number", text: "Generate synchronized couples rank list")
                            FeatureRow(icon: "slider.horizontal.3", text: "Set priorities and preferences")
                            FeatureRow(icon: "map.fill", text: "Geographic coordination tools")
                        }
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("About Couples Matching")
                }
                
                Section {
                    partnerLinkingActionsSection
                } footer: {
                    Text("Together? Scan each other's QR. Apart? Show your QR and send the invite by text.")
                }
                
                // Invites section
                if !dataManager.preferences.receivedInvites.filter({ $0.status == .pending && !$0.isExpired }).isEmpty ||
                   !dataManager.preferences.sentInvites.filter({ $0.status == .pending && !$0.isExpired }).isEmpty {
                    Section {
                        Button(action: {
                            showInvites = true
                        }) {
                            HStack {
                                Image(systemName: "envelope.fill")
                                    .foregroundColor(.blue)
                                Text("View Invites")
                                Spacer()
                                
                                let pendingCount = dataManager.preferences.receivedInvites.filter { $0.status == .pending && !$0.isExpired }.count
                                if pendingCount > 0 {
                                    Text("\(pendingCount)")
                                        .font(.arial(size: 13, weight: .semibold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.red)
                                        .clipShape(Capsule())
                                }
                                
                                Image(systemName: "chevron.right")
                                    .font(.arial(size: 12))
                                    .foregroundColor(.secondary)
                            }
                        }
                    } header: {
                        Text("Invites")
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .appCanvasBackground()
        .navigationTitle("Couples Matching")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showLinkPartner) {
            LinkPartnerView()
        }
        .sheet(isPresented: $showMyQRCode) {
            if let couple = dataManager.preferences.couple {
                CoupleInviteQRSheet(
                    couple: couple,
                    inviterName: couple.user1Name
                )
            }
        }
        .sheet(isPresented: $showQRScanner) {
            CoupleQRScannerView { code in
                Task { await linkFromScannedCode(code) }
            }
        }
        .sheet(isPresented: $showUserSearch) {
            UserSearchView()
        }
        .sheet(isPresented: $showInvites) {
            InviteManagementView()
        }
        .sheet(isPresented: $showPreferences) {
            CouplesPreferencesView()
        }
        .task {
            await refreshPendingCoupleLinkIfNeeded()
            await ensurePendingCoupleCodeIsRegistered()
        }
        .confirmationDialog(
            "Unlink from your partner?",
            isPresented: $showUnlinkConfirm,
            titleVisibility: .visible
        ) {
            Button("Unlink Partner", role: .destructive) {
                unlinkCouple()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the couple connection on your device. Your individual programs are not deleted.")
        }
        .alert("Link Error", isPresented: Binding(
            get: { linkErrorMessage != nil },
            set: { if !$0 { linkErrorMessage = nil } }
        )) {
            Button("OK") { linkErrorMessage = nil }
        } message: {
            Text(linkErrorMessage ?? "")
        }
        .overlay {
            if isLinkingFromScan {
                ZStack {
                    Color.black.opacity(0.2).ignoresSafeArea()
                    ProgressView("Linking…")
                        .padding()
                        .glassEffect(.regular, in: .rect(cornerRadius: 14))
                }
            }
        }
    }

    private var partnerLinkingActionsSection: some View {
        Group {
            Button(action: presentMyQRCode) {
                HStack {
                    Image(systemName: "qrcode")
                        .foregroundColor(.blue)
                    Text("Show My QR Code")
                }
            }

            Button(action: {
                showQRScanner = true
            }) {
                HStack {
                    Image(systemName: "qrcode.viewfinder")
                        .foregroundColor(.blue)
                    Text("Scan Partner's QR Code")
                }
            }

            Button(action: {
                showLinkPartner = true
            }) {
                HStack {
                    Image(systemName: "keyboard")
                        .foregroundColor(.blue)
                    Text("Enter Code Manually")
                }
            }
        }
    }

    private func presentMyQRCode() {
        if dataManager.preferences.couple == nil {
            createCouple()
        }
        showMyQRCode = true
    }

    private func linkFromScannedCode(_ code: String) async {
        isLinkingFromScan = true
        defer { isLinkingFromScan = false }
        do {
            try await CoupleLinkingActions.link(
                withCode: code,
                dataManager: dataManager,
                authManager: authManager
            )
            showQRScanner = false
        } catch let error as CoupleLinkingError {
            linkErrorMessage = error.localizedDescription
        } catch {
            linkErrorMessage = "Could not link with that QR code. Try again or enter the code manually."
        }
    }

    private func ensurePendingCoupleCodeIsRegistered() async {
        guard let couple = dataManager.preferences.couple,
              !couple.isLinked,
              authManager.isCloudKitAvailable else { return }

        if let existing = try? await CoupleLinkingService.fetchRegistration(for: couple.coupleCode),
           existing.inviterRecordName == authManager.cloudKitUserRecordName {
            return
        }

        registerCoupleCodeInCloud(couple)
    }

    private func refreshPendingCoupleLinkIfNeeded() async {
        guard var couple = dataManager.preferences.couple,
              !couple.isLinked,
              authManager.isCloudKitAvailable else { return }

        guard let registration = try? await CoupleLinkingService.fetchRegistration(for: couple.coupleCode),
              registration.isClaimed,
              let partnerID = registration.partnerRecordName,
              let partnerName = registration.partnerName else {
            return
        }

        couple.user2ID = partnerID
        couple.user2Name = partnerName
        couple.user2Email = registration.partnerEmail
        couple.status = .linked
        couple.linkedAt = Date()
        dataManager.preferences.couple = couple
        dataManager.savePreferences()
    }

    private func registerCoupleCodeInCloud(_ couple: Couple) {
        guard authManager.isCloudKitAvailable,
              let inviterRecordName = authManager.cloudKitUserRecordName else { return }

        Task {
            do {
                try await CoupleLinkingService.registerPendingCouple(
                    couple: couple,
                    inviterRecordName: inviterRecordName,
                    inviterName: couple.user1Name,
                    inviterEmail: couple.user1Email
                )
            } catch {
                // Registration is best-effort; local code still works for sharing manually.
            }
        }
    }
    
    private func createCouple() {
        // Use the stable CloudKit user record name as the canonical identity when available
        // (per the couples plan), falling back to the Apple login id / local id only until
        // CloudKit resolves. We never mint a throwaway UUID for the user here.
        let ownerID = authManager.cloudKitUserRecordName
            ?? authManager.currentUser?.id
            ?? dataManager.preferences.userID
        let newCouple = Couple(
            user1ID: ownerID,
            user1Name: authManager.currentUser?.displayName ?? (dataManager.preferences.profile.name.isEmpty ? "You" : dataManager.preferences.profile.name),
            user1Email: authManager.currentUser?.email
        )
        dataManager.preferences.couple = newCouple
        dataManager.savePreferences()
        registerCoupleCodeInCloud(newCouple)
    }
    
    private func unlinkCouple() {
        if let code = dataManager.preferences.couple?.coupleCode {
            Task {
                await CoupleLinkingService.deleteRegistration(for: code)
            }
        }
        dataManager.preferences.couple = nil
        dataManager.preferences.couplesRankPairs = []
        dataManager.savePreferences()
    }


    private func regenerateCoupleCode() {
        guard var couple = dataManager.preferences.couple, !couple.isLinked else { return }
        let oldCode = couple.coupleCode
        let newCode = Couple.generateCoupleCode()
        couple.coupleCode = newCode
        couple.inviteLink = Couple.generateInviteLink(code: newCode)
        dataManager.preferences.couple = couple
        dataManager.savePreferences()

        Task {
            await CoupleLinkingService.deleteRegistration(for: oldCode)
            registerCoupleCodeInCloud(couple)
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.arial(size: 14))
                .foregroundColor(.blue)
                .frame(width: 20)
            Text(text)
                .font(.arial(size: 14))
        }
    }
}

struct LinkPartnerView: View {
    @EnvironmentObject var dataManager: DataManager
    @ObservedObject private var authManager = AuthManager.shared
    @Environment(\.dismiss) var dismiss
    @State private var partnerCode = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isLinking = false
    @State private var showScanner = false

    var body: some View {
        MatchlyNavigationView {
            Form {
                Section {
                    Button(action: { showScanner = true }) {
                        HStack {
                            Image(systemName: "qrcode.viewfinder")
                                .foregroundColor(.blue)
                            Text("Scan Partner's QR Code")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.arial(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }
                } footer: {
                    Text("Fastest when you're together — scan the QR on your partner's phone.")
                }

                Section {
                    TextField("Enter 6-character code", text: $partnerCode)
                        .autocapitalization(.allCharacters)
                        .disableAutocorrection(true)
                        .font(.arial(size: 20, weight: .medium, design: .monospaced))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .glassEffect(.regular, in: .capsule)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowBackground(Color.clear)
                } header: {
                    Text("Or Enter Code")
                } footer: {
                    Text("Use this if your partner texted you the code. Both devices need iCloud.")
                }

                Section {
                    Button(action: linkPartner) {
                        HStack {
                            Spacer()
                            if isLinking {
                                ProgressView()
                            } else {
                                Text("Link Accounts")
                            }
                            Spacer()
                        }
                    }
                    .buttonStyle(.glassProminent)
                    .tint(AppColors.primaryBlue)
                    .disabled(isLinking || partnerCode.count != 6)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
                }
            }
            .scrollContentBackground(.hidden)
            .appCanvasBackground()
            .navigationTitle("Link Partner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showScanner) {
                CoupleQRScannerView { code in
                    partnerCode = code
                    linkPartner()
                }
            }
            .alert("Link Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func linkPartner() {
        let codeToUse = partnerCode.uppercased()
        guard codeToUse.count == 6 else {
            errorMessage = "Please enter a valid 6-character code."
            showError = true
            return
        }

        isLinking = true
        Task { @MainActor in
            defer { isLinking = false }
            do {
                try await CoupleLinkingActions.link(
                    withCode: codeToUse,
                    dataManager: dataManager,
                    authManager: authManager
                )
                dismiss()
            } catch let error as CoupleLinkingError {
                errorMessage = error.localizedDescription
                showError = true
            } catch {
                errorMessage = "Could not link with that code. Make sure your partner showed their QR code in Matchly first."
                showError = true
            }
        }
    }
}

