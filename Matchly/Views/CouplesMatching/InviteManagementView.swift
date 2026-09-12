//
//  InviteManagementView.swift
//  Matchly
//
//  Created on 11/16/25.
//

import SwiftUI

struct InviteManagementView: View {
    @EnvironmentObject var dataManager: DataManager
    @ObservedObject private var authManager = AuthManager.shared
    @Environment(\.dismiss) var dismiss
    
    @State private var linkingError: String?
    @State private var isLinkingInvite = false
    
    var pendingReceivedInvites: [CoupleInvite] {
        dataManager.preferences.receivedInvites.filter { $0.status == .pending && !$0.isExpired }
    }
    
    var pendingSentInvites: [CoupleInvite] {
        dataManager.preferences.sentInvites.filter { $0.status == .pending && !$0.isExpired }
    }
    
    var body: some View {
        MatchlyNavigationView {
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
                                .font(.arial(size: 48))
                                .foregroundColor(.secondary)
                            
                            Text("No Pending Invites")
                                .font(.arial(size: 18, weight: .semibold))
                            
                            Text("You don't have any pending invites.")
                                .font(.arial(size: 14))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .appCanvasBackground()
            .navigationTitle("Invites")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Could Not Link", isPresented: Binding(
                get: { linkingError != nil },
                set: { if !$0 { linkingError = nil } }
            )) {
                Button("OK") { linkingError = nil }
            } message: {
                Text(linkingError ?? "")
            }
        }
    }
    
    private func acceptInvite(_ invite: CoupleInvite) {
        guard !isLinkingInvite else { return }
        isLinkingInvite = true
        Task { @MainActor in
            defer { isLinkingInvite = false }
            do {
                try await CoupleLinkingActions.acceptReceivedInvite(
                    invite,
                    dataManager: dataManager,
                    authManager: authManager
                )
                dismiss()
            } catch let error as CoupleLinkingError {
                linkingError = error.localizedDescription
            } catch {
                linkingError = CoupleLinkingService.mapError(error).localizedDescription
            }
        }
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
                        .font(.arial(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    Text(isReceived ? invite.fromUserName : (invite.toUserEmail ?? "Unknown"))
                        .font(.arial(size: 16, weight: .semibold))
                    
                    if let email = isReceived ? invite.fromUserEmail : invite.toUserEmail {
                        Text(email)
                            .font(.arial(size: 13))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if isReceived {
                    HStack(spacing: 8) {
                        Button(action: onAccept) {
                            Text("Accept")
                                .font(.arial(size: 14, weight: .semibold))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(.glassProminent)
                        .tint(AppColors.primaryBlue)
                        
                        Button(action: onDecline) {
                            Text("Decline")
                                .font(.arial(size: 14, weight: .semibold))
                                .foregroundColor(.red)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(.glass)
                    }
                } else {
                    Button(action: onDecline) {
                        Text("Cancel")
                            .font(.arial(size: 14, weight: .semibold))
                            .foregroundColor(.red)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.glass)
                }
            }
            
            if isReceived {
                Text("Tap Accept to link accounts and start couples matching.")
                    .font(.arial(size: 12))
                    .foregroundColor(.secondary)
            } else {
                Text("Waiting for response...")
                    .font(.arial(size: 12))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
        .glassPanelStyle(cornerRadius: 14)
    }
}

#Preview {
    InviteManagementView()
        .environmentObject(DataManager.shared)
}

