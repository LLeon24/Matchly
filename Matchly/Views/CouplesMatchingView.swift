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
                            unlinkCouple()
                        }) {
                            Text("Unlink Couple")
                        }
                    }
                } else {
                    // Pending link state
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Share this code with your partner:")
                                .font(.arial(size: 14))
                                .foregroundColor(.secondary)
                            
                            HStack {
                                Text(couple.coupleCode)
                                    .font(.arial(size: 24, weight: .bold, design: .monospaced))
                                    .foregroundColor(.blue)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(10)
                                
                                Button(action: {
                                    UIPasteboard.general.string = couple.coupleCode
                                }) {
                                    Image(systemName: "doc.on.doc")
                                        .font(.arial(size: 18))
                                        .foregroundColor(.blue)
                                        .padding()
                                        .background(Color.blue.opacity(0.1))
                                        .cornerRadius(10)
                                }
                            }
                            
                            Text("Your partner should enter this code in their app to link accounts.")
                                .font(.arial(size: 12))
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 8)
                    } header: {
                        Text("Your Couple Code")
                    }
                    
                    Section {
                        // Share invite link
                        if let inviteLink = couple.inviteLink {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Share this link with your partner:")
                                    .font(.arial(size: 14))
                                    .foregroundColor(.secondary)
                                
                                HStack {
                                    Text(inviteLink)
                                        .font(.arial(size: 12, design: .monospaced))
                                        .foregroundColor(.blue)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                        .padding()
                                        .frame(maxWidth: .infinity)
                                        .background(Color.blue.opacity(0.1))
                                        .cornerRadius(10)
                                    
                                    Button(action: {
                                        UIPasteboard.general.string = inviteLink
                                    }) {
                                        Image(systemName: "doc.on.doc")
                                            .font(.arial(size: 18))
                                            .foregroundColor(.blue)
                                            .padding()
                                            .background(Color.blue.opacity(0.1))
                                            .cornerRadius(10)
                                    }
                                    
                                    ShareLink(item: inviteLink) {
                                        Image(systemName: "square.and.arrow.up")
                                            .font(.arial(size: 18))
                                            .foregroundColor(.blue)
                                            .padding()
                                            .background(Color.blue.opacity(0.1))
                                            .cornerRadius(10)
                                    }
                                }
                                
                                Text("Your partner can tap this link or enter the code below.")
                                    .font(.arial(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 8)
                        }
                        
                        Button(action: {
                            showLinkPartner = true
                        }) {
                            HStack {
                                Image(systemName: "qrcode")
                                    .foregroundColor(.blue)
                                Text("I Have a Partner Code")
                            }
                        }
                    } header: {
                        Text("Link Options")
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
                    Button(action: {
                        showUserSearch = true
                    }) {
                        HStack {
                            Image(systemName: "person.crop.circle.badge.plus")
                                .foregroundColor(.blue)
                            Text("Find Partner by Account")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.arial(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Button(action: {
                        createCouple()
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.blue)
                            Text("Create Couple Code")
                        }
                    }
                    
                    Button(action: {
                        showLinkPartner = true
                    }) {
                        HStack {
                            Image(systemName: "qrcode")
                                .foregroundColor(.blue)
                            Text("Link with Partner Code")
                        }
                    }
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
        .navigationTitle("Couples Matching")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showLinkPartner) {
            LinkPartnerView()
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
    }
    
    private func unlinkCouple() {
        dataManager.preferences.couple = nil
        dataManager.preferences.couplesRankPairs = []
        dataManager.savePreferences()
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
    @State private var inviteLink = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var useLink = false
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    Picker("Link Method", selection: $useLink) {
                        Text("Code").tag(false)
                        Text("Invite Link").tag(true)
                    }
                    .pickerStyle(.segmented)
                }
                
                if useLink {
                    Section {
                        TextField("Paste invite link", text: $inviteLink)
                            .textFieldStyle(.roundedBorder)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .keyboardType(.URL)
                    } header: {
                        Text("Invite Link")
                    } footer: {
                        Text("Paste the invite link your partner shared with you, or tap a link they sent you.")
                    }
                } else {
                    Section {
                        TextField("Enter Partner Code", text: $partnerCode)
                            .textFieldStyle(.roundedBorder)
                            .autocapitalization(.allCharacters)
                            .disableAutocorrection(true)
                            .font(.arial(size: 18, weight: .medium, design: .monospaced))
                    } header: {
                        Text("Partner Code")
                    } footer: {
                        Text("Enter the 6-character code your partner shared with you.")
                    }
                }
                
                Section {
                    Button(action: {
                        linkPartner()
                    }) {
                        Text("Link Accounts")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(useLink ? inviteLink.isEmpty : partnerCode.count != 6)
                }
            }
            .navigationTitle("Link Partner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
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
        var codeToUse = partnerCode.uppercased()
        
        // If using invite link, extract code from it
        if useLink {
            if let code = Couple.parseInviteLink(inviteLink) {
                codeToUse = code
            } else {
                errorMessage = "Invalid invite link. Please check the link and try again."
                showError = true
                return
            }
        }
        
        guard codeToUse.count == 6 else {
            errorMessage = "Please enter a valid 6-character code."
            showError = true
            return
        }
        
        // Check if this code matches an existing couple
        if let couple = dataManager.preferences.couple {
            // If user already has a couple, they're trying to link
            if couple.coupleCode.uppercased() == codeToUse {
                errorMessage = "You cannot link with your own code. Share this code with your partner."
                showError = true
                return
            }
        }
        
        // NOTE (Phase 1): Real partner linking is not built yet. It requires CloudKit sharing
        // (CKShare invite/accept across two iCloud accounts), which lands in a later phase.
        // Previously this method faked a link by assigning `user2ID = UUID()` and
        // `user2Name = "Partner"`, which only ever existed on this one device. We no longer do
        // that — we never fabricate a partner identity. Surface an honest "coming soon" message
        // instead of masquerading as a real link.
        errorMessage = "Partner linking is coming soon. It will use secure iCloud sharing so both of you see the same list. For now you can set up your own side."
        showError = true
    }
    
    private func acceptInviteFromCode(_ invite: CoupleInvite) {
        // Update invite status
        if let index = dataManager.preferences.receivedInvites.firstIndex(where: { $0.id == invite.id }) {
            var updatedInvite = invite
            updatedInvite.status = .accepted
            updatedInvite.respondedAt = Date()
            dataManager.preferences.receivedInvites[index] = updatedInvite
        }
        
        // Link the couple
        let newCouple = Couple(
            user1ID: authManager.currentUser?.id ?? dataManager.preferences.userID,
            user1Name: authManager.currentUser?.displayName ?? (dataManager.preferences.profile.name.isEmpty ? "You" : dataManager.preferences.profile.name),
            user1Email: authManager.currentUser?.email,
            coupleCode: invite.coupleCode,
            inviteLink: invite.inviteLink,
            status: .linked
        )
        var updatedCouple = newCouple
        updatedCouple.user2ID = invite.fromUserID
        updatedCouple.user2Name = invite.fromUserName
        updatedCouple.user2Email = invite.fromUserEmail
        updatedCouple.linkedAt = Date()
        dataManager.preferences.couple = updatedCouple
        
        dataManager.savePreferences()
        dismiss()
    }
}

