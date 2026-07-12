//
//  CouplesMatchingView.swift
//  Matchly
//
//  Created on 11/16/25.
//

import SwiftUI

struct CouplesMatchingView: View {
    @EnvironmentObject var dataManager: DataManager
    @EnvironmentObject var deepLinkHandler: CoupleDeepLinkHandler
    @ObservedObject private var authManager = AuthManager.shared
    @ObservedObject private var coupleSync = CoupleSyncCoordinator.shared
    @ObservedObject private var notifications = CoupleNotificationService.shared
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
    @State private var isPublishingInvite = false
    @State private var invitePublishError: String?
    @State private var inviteIsPublished = false
    
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
                    } footer: {
                        Text("Use the Couple tab in the bottom bar for chat, your shared rank list, and matching settings.")
                    }
                    
                    Section {
                        if notifications.authorizationStatus == .notDetermined {
                            Button(action: {
                                Task { await notifications.requestAuthorizationIfNeeded() }
                            }) {
                                HStack {
                                    Image(systemName: "bell.badge")
                                        .foregroundColor(.blue)
                                    Text("Enable Notifications")
                                }
                            }
                        }

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

                            invitePublishStatusView
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    } header: {
                        Text("Your Invite QR")
                    }

                    partnerLinkingActionsSection

                    Section {
                        if let inviteURL = Couple.inviteURL(for: couple.coupleCode) {
                            ShareLink(
                                item: inviteURL,
                                subject: Text(Couple.shareInviteSubject(inviterName: couple.user1Name)),
                                message: Text(Couple.shareInviteMessage(
                                    code: couple.coupleCode,
                                    inviterName: couple.user1Name
                                ))
                            ) {
                                HStack {
                                    Image(systemName: "message.fill")
                                        .foregroundColor(.blue)
                                    Text("Send Invite via Text")
                                }
                            }
                        }

                        Button(action: {
                            UIPasteboard.general.string = couple.coupleCode
                        }) {
                            HStack {
                                Image(systemName: "doc.on.doc")
                                    .foregroundColor(.blue)
                                Text("Copy Invite Code")
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
                        Text("Send the code by text if you're apart. QR scan is fastest when you're together. One-tap links in Messages need a Matchly website (planned).")
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
        .matchlyScrollTabBarClearance()
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
                    inviterName: couple.user1Name,
                    onAppear: {
                        Task { await publishPendingInviteIfNeeded(force: true) }
                    }
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
            await publishPendingInviteIfNeeded()
            await coupleSync.startMonitoringIfNeeded(dataManager: dataManager)
            await CoupleNotificationService.shared.requestAuthorizationIfNeeded()
            if let code = deepLinkHandler.pendingCoupleCode {
                await handleDeepLinkCode(code)
            }
        }
        .onChange(of: authManager.cloudKitUserRecordName) { _, _ in
            Task { await publishPendingInviteIfNeeded() }
        }
        .onChange(of: authManager.cloudAccountStatus) { _, _ in
            Task { await publishPendingInviteIfNeeded() }
        }
        .onChange(of: deepLinkHandler.pendingCoupleCode) { _, newCode in
            guard let newCode else { return }
            Task { await handleDeepLinkCode(newCode) }
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

    private func handleDeepLinkCode(_ code: String) async {
        isLinkingFromScan = true
        defer {
            isLinkingFromScan = false
            _ = deepLinkHandler.consumePendingCode()
        }
        do {
            try await CoupleLinkingActions.link(
                withCode: code,
                dataManager: dataManager,
                authManager: authManager
            )
            await coupleSync.startMonitoringIfNeeded(dataManager: dataManager)
        } catch let error as CoupleLinkingError {
            linkErrorMessage = error.localizedDescription
        } catch {
            linkErrorMessage = "Could not link from invite link."
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
            await coupleSync.startMonitoringIfNeeded(dataManager: dataManager)
        } catch let error as CoupleLinkingError {
            linkErrorMessage = error.localizedDescription
        } catch {
            linkErrorMessage = "Could not link with that QR code. Try again or enter the code manually."
        }
    }

    @ViewBuilder
    private var invitePublishStatusView: some View {
        if isPublishingInvite {
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("Publishing invite to iCloud…")
                    .font(.arial(size: 12))
                    .foregroundColor(.secondary)
            }
        } else if let invitePublishError {
            VStack(spacing: 6) {
                Text(invitePublishError)
                    .font(.arial(size: 11))
                    .foregroundColor(.orange)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Button("Retry Publishing Invite") {
                    Task { await publishPendingInviteIfNeeded(force: true) }
                }
                .font(.arial(size: 12, weight: .semibold))
            }
        } else if inviteIsPublished {
            Label("Invite ready for your partner", systemImage: "checkmark.circle.fill")
                .font(.arial(size: 12, weight: .medium))
                .foregroundColor(.green)
        } else if !authManager.isCloudKitAvailable, let message = authManager.cloudUnavailableMessage {
            Text(message)
                .font(.arial(size: 12))
                .foregroundColor(.orange)
                .multilineTextAlignment(.center)
        }
    }

    private func publishPendingInviteIfNeeded(force: Bool = false) async {
        guard let couple = dataManager.preferences.couple, !couple.isLinked else {
            inviteIsPublished = false
            invitePublishError = nil
            return
        }

        if inviteIsPublished, !force { return }

        isPublishingInvite = true
        invitePublishError = nil
        defer { isPublishingInvite = false }

        do {
            try await CoupleLinkingService.registerInviteIfNeeded(
                couple: couple,
                authManager: authManager
            )
            inviteIsPublished = true
            invitePublishError = nil
        } catch let error as CoupleLinkingError {
            inviteIsPublished = false
            invitePublishError = error.localizedDescription
        } catch {
            inviteIsPublished = false
            invitePublishError = CoupleLinkingService.mapError(error).localizedDescription
        }
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

        if couple.id != registration.coupleID {
            couple = Couple(copying: couple, id: registration.coupleID)
        }
        couple.user1ID = registration.inviterRecordName
        couple.user1Name = registration.inviterName
        couple.user1Email = registration.inviterEmail
        couple.user2ID = partnerID
        couple.user2Name = partnerName
        couple.user2Email = registration.partnerEmail
        couple.status = .linked
        couple.linkedAt = Date()
        dataManager.preferences.couple = couple
        dataManager.savePreferences()

        await coupleSync.ensureSyncStarted(dataManager: dataManager)
        try? await coupleSync.publishOwnData(dataManager: dataManager)
    }

    private func registerCoupleCodeInCloud(_ couple: Couple) {
        Task {
            await publishPendingInviteIfNeeded(force: true)
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
        Task {
            try? await CoupleSyncCoordinator.shared.publishOwnData(dataManager: dataManager)
        }
    }
    
    private func unlinkCouple() {
        CoupleSyncCoordinator.shared.stopMonitoring()
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

