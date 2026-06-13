//
//  CouplesMatchingView.swift
//  Matchly
//
//  Created on 11/16/25.
//

import SwiftUI

struct CouplesMatchingView: View {
    @EnvironmentObject var dataManager: DataManager
    @StateObject private var authManager = AuthManager.shared
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
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.secondary)
                                Text(couple.user1Name)
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            
                            Spacer()
                            
                            Image(systemName: "heart.fill")
                                .foregroundColor(.pink)
                                .font(.system(size: 20))
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("Partner")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.secondary)
                                Text(couple.user2Name ?? "Unknown")
                                    .font(.system(size: 16, weight: .semibold))
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
                                        .font(.system(size: 13))
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
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                            
                            HStack {
                                Text(couple.coupleCode)
                                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                                    .foregroundColor(.blue)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(10)
                                
                                Button(action: {
                                    UIPasteboard.general.string = couple.coupleCode
                                }) {
                                    Image(systemName: "doc.on.doc")
                                        .font(.system(size: 18))
                                        .foregroundColor(.blue)
                                        .padding()
                                        .background(Color.blue.opacity(0.1))
                                        .cornerRadius(10)
                                }
                            }
                            
                            Text("Your partner should enter this code in their app to link accounts.")
                                .font(.system(size: 12))
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
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                                
                                HStack {
                                    Text(inviteLink)
                                        .font(.system(size: 12, design: .monospaced))
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
                                            .font(.system(size: 18))
                                            .foregroundColor(.blue)
                                            .padding()
                                            .background(Color.blue.opacity(0.1))
                                            .cornerRadius(10)
                                    }
                                    
                                    ShareLink(item: inviteLink) {
                                        Image(systemName: "square.and.arrow.up")
                                            .font(.system(size: 18))
                                            .foregroundColor(.blue)
                                            .padding()
                                            .background(Color.blue.opacity(0.1))
                                            .cornerRadius(10)
                                    }
                                }
                                
                                Text("Your partner can tap this link or enter the code below.")
                                    .font(.system(size: 12))
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
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                        
                        Text("Key Features:")
                            .font(.system(size: 15, weight: .semibold))
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
                                .font(.system(size: 12))
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
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.red)
                                        .clipShape(Capsule())
                                }
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12))
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
        let newCouple = Couple(
            user1ID: authManager.currentUser?.id ?? dataManager.preferences.userID,
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
                .font(.system(size: 14))
                .foregroundColor(.blue)
                .frame(width: 20)
            Text(text)
                .font(.system(size: 14))
        }
    }
}

struct LinkPartnerView: View {
    @EnvironmentObject var dataManager: DataManager
    @StateObject private var authManager = AuthManager.shared
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
                            .font(.system(size: 18, weight: .medium, design: .monospaced))
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
        
        // Check if there's a pending invite for this code
        if let invite = dataManager.preferences.receivedInvites.first(where: { $0.coupleCode.uppercased() == codeToUse && $0.status == .pending }) {
            // Accept the invite
            acceptInviteFromCode(invite)
            return
        }
        
        // Create or update couple
        if let couple = dataManager.preferences.couple {
            // Update existing couple
            var updatedCouple = couple
            updatedCouple.user2ID = UUID().uuidString // In real app, this would come from server
            updatedCouple.user2Name = "Partner" // In real app, this would come from server
            updatedCouple.status = .linked
            updatedCouple.linkedAt = Date()
            dataManager.preferences.couple = updatedCouple
        } else {
            // Create new couple (user is linking to someone else's code)
            var newCouple = Couple(
                user1ID: authManager.currentUser?.id ?? dataManager.preferences.userID,
                user1Name: authManager.currentUser?.displayName ?? (dataManager.preferences.profile.name.isEmpty ? "You" : dataManager.preferences.profile.name),
                user1Email: authManager.currentUser?.email,
                coupleCode: codeToUse,
                status: .linked
            )
            newCouple.user2ID = UUID().uuidString // In real app, from server
            newCouple.user2Name = "Partner" // In real app, from server
            newCouple.linkedAt = Date()
            dataManager.preferences.couple = newCouple
        }
        
        dataManager.savePreferences()
        dismiss()
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

