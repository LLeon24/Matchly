//
//  InviteManagementView.swift
//  Matchly
//
//  Created on 11/16/25.
//

import SwiftUI

struct InviteManagementView: View {
    @EnvironmentObject var dataManager: DataManager
    @StateObject private var authManager = AuthManager.shared
    @Environment(\.dismiss) var dismiss
    
    var pendingReceivedInvites: [CoupleInvite] {
        dataManager.preferences.receivedInvites.filter { $0.status == .pending && !$0.isExpired }
    }
    
    var pendingSentInvites: [CoupleInvite] {
        dataManager.preferences.sentInvites.filter { $0.status == .pending && !$0.isExpired }
    }
    
    var body: some View {
        NavigationView {
            List {
                // Received Invites
                if !pendingReceivedInvites.isEmpty {
                    Section {
                        ForEach(pendingReceivedInvites) { invite in
                            InviteRowView(invite: invite, isReceived: true) {
                                acceptInvite(invite)
                            } onDecline: {
                                declineInvite(invite)
                            }
                        }
                    } header: {
                        Text("Received Invites")
                    }
                }
                
                // Sent Invites
                if !pendingSentInvites.isEmpty {
                    Section {
                        ForEach(pendingSentInvites) { invite in
                            InviteRowView(invite: invite, isReceived: false) {
                                // No action for sent invites
                            } onDecline: {
                                cancelInvite(invite)
                            }
                        }
                    } header: {
                        Text("Sent Invites")
                    }
                }
                
                // Empty state
                if pendingReceivedInvites.isEmpty && pendingSentInvites.isEmpty {
                    Section {
                        VStack(spacing: 16) {
                            Image(systemName: "envelope")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary)
                            
                            Text("No Pending Invites")
                                .font(.system(size: 18, weight: .semibold))
                            
                            Text("You don't have any pending invites.")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    }
                }
            }
            .navigationTitle("Invites")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func acceptInvite(_ invite: CoupleInvite) {
        // Update invite status
        if let index = dataManager.preferences.receivedInvites.firstIndex(where: { $0.id == invite.id }) {
            var updatedInvite = invite
            updatedInvite.status = .accepted
            updatedInvite.respondedAt = Date()
            dataManager.preferences.receivedInvites[index] = updatedInvite
        }
        
        // Link the couple
        if let couple = dataManager.preferences.couple {
            var updatedCouple = couple
            updatedCouple.user2ID = invite.fromUserID
            updatedCouple.user2Name = invite.fromUserName
            updatedCouple.user2Email = invite.fromUserEmail
            updatedCouple.status = .linked
            updatedCouple.linkedAt = Date()
            dataManager.preferences.couple = updatedCouple
        } else {
            // Create new couple from invite
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
        }
        
        // Update sent invite status on sender's side (in real app, this would sync via server)
        if let index = dataManager.preferences.sentInvites.firstIndex(where: { $0.id == invite.id }) {
            var sentInvite = dataManager.preferences.sentInvites[index]
            sentInvite.status = .accepted
            sentInvite.respondedAt = Date()
            dataManager.preferences.sentInvites[index] = sentInvite
        }
        
        dataManager.savePreferences()
        dismiss()
    }
    
    private func declineInvite(_ invite: CoupleInvite) {
        if let index = dataManager.preferences.receivedInvites.firstIndex(where: { $0.id == invite.id }) {
            var updatedInvite = invite
            updatedInvite.status = .declined
            updatedInvite.respondedAt = Date()
            dataManager.preferences.receivedInvites[index] = updatedInvite
            dataManager.savePreferences()
        }
    }
    
    private func cancelInvite(_ invite: CoupleInvite) {
        dataManager.preferences.sentInvites.removeAll { $0.id == invite.id }
        dataManager.savePreferences()
    }
}

struct InviteRowView: View {
    let invite: CoupleInvite
    let isReceived: Bool
    let onAccept: () -> Void
    let onDecline: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(isReceived ? "From:" : "To:")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    Text(isReceived ? invite.fromUserName : (invite.toUserEmail ?? "Unknown"))
                        .font(.system(size: 16, weight: .semibold))
                    
                    if let email = isReceived ? invite.fromUserEmail : invite.toUserEmail {
                        Text(email)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if isReceived {
                    HStack(spacing: 8) {
                        Button(action: onAccept) {
                            Text("Accept")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.blue)
                                .cornerRadius(8)
                        }
                        
                        Button(action: onDecline) {
                            Text("Decline")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.red)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                } else {
                    Button(action: onDecline) {
                        Text("Cancel")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.red)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
            }
            
            if isReceived {
                Text("Tap Accept to link accounts and start couples matching.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            } else {
                Text("Waiting for response...")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    InviteManagementView()
        .environmentObject(DataManager.shared)
}

