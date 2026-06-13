//
//  UserSearchView.swift
//  Matchly
//
//  Created on 11/16/25.
//

import SwiftUI

struct UserSearchView: View {
    @EnvironmentObject var dataManager: DataManager
    @ObservedObject private var authManager = AuthManager.shared
    @Environment(\.dismiss) var dismiss
    @State private var searchText = ""
    @State private var searchResults: [User] = []
    @State private var isSearching = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.blue)
                        TextField("Search by email or name", text: $searchText)
                            .textContentType(.emailAddress)
                            .autocapitalization(.none)
                            .keyboardType(.emailAddress)
                            .onSubmit {
                                searchUsers()
                            }
                        
                        if isSearching {
                            ProgressView()
                                .padding(.leading, 8)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .glassEffect(.regular, in: .capsule)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
                } header: {
                    Text("Find Partner")
                } footer: {
                    Text("Search for your partner by their email address or display name.")
                }
                
                if !searchResults.isEmpty {
                    Section {
                        ForEach(searchResults) { user in
                            Button(action: {
                                sendInvite(to: user)
                            }) {
                                HStack(spacing: 12) {
                                    // Profile icon
                                    ZStack {
                                        Circle()
                                            .fill(Color.blue.opacity(0.2))
                                            .frame(width: 44, height: 44)
                                        
                                        if let photoURL = user.photoURL, !photoURL.isEmpty {
                                            AsyncImage(url: URL(string: photoURL)) { image in
                                                image
                                                    .resizable()
                                                    .scaledToFill()
                                            } placeholder: {
                                                Image(systemName: "person.fill")
                                                    .foregroundColor(.blue)
                                            }
                                            .frame(width: 44, height: 44)
                                            .clipShape(Circle())
                                        } else {
                                            Image(systemName: "person.fill")
                                                .foregroundColor(.blue)
                                                .font(.arial(size: 20))
                                        }
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(user.displayName ?? user.email ?? "User")
                                            .font(.arial(size: 16, weight: .semibold))
                                            .foregroundColor(.primary)
                                        
                                        if let email = user.email {
                                            Text(email)
                                                .font(.arial(size: 13))
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "person.badge.plus")
                                        .foregroundColor(.blue)
                                        .font(.arial(size: 18))
                                }
                                .padding(.vertical, 4)
                                .glassPanelStyle(cornerRadius: 12)
                            }
                            .buttonStyle(.plain)
                        }
                    } header: {
                        Text("Search Results")
                    }
                } else if !searchText.isEmpty && !isSearching {
                    Section {
                        Text("No users found")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 20)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .appCanvasBackground()
            .navigationTitle("Find Partner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func searchUsers() {
        guard !searchText.isEmpty else { return }
        
        isSearching = true
        searchResults = []
        
        // Simulate user search
        // In a real app, this would query a backend API
        // For now, we'll create a mock result if the email matches a pattern
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Mock search - in production, this would be an API call
            if searchText.contains("@") {
                // If it looks like an email, create a mock user
                let mockUser = User(
                    id: UUID().uuidString,
                    email: searchText,
                    displayName: searchText.components(separatedBy: "@").first?.capitalized,
                    provider: .email
                )
                searchResults = [mockUser]
            } else {
                // Search by name (mock)
                searchResults = []
            }
            
            isSearching = false
        }
    }
    
    private func sendInvite(to user: User) {
        // Check if user is trying to invite themselves
        if user.id == authManager.currentUser?.id {
            errorMessage = "You cannot invite yourself."
            showError = true
            return
        }
        
        // Check if already linked
        if let couple = dataManager.preferences.couple, couple.isLinked {
            errorMessage = "You are already linked with a partner. Unlink first to send a new invite."
            showError = true
            return
        }
        
        // Check if already sent an invite to this user
        if dataManager.preferences.sentInvites.contains(where: { $0.toUserID == user.id && $0.status == .pending && !$0.isExpired }) {
            errorMessage = "You have already sent an invite to this user."
            showError = true
            return
        }
        
        // Create or get existing couple
        var couple: Couple
        if let existingCouple = dataManager.preferences.couple {
            couple = existingCouple
        } else {
            couple = Couple(
                user1ID: authManager.currentUser?.id ?? dataManager.preferences.userID,
                user1Name: authManager.currentUser?.displayName ?? (dataManager.preferences.profile.name.isEmpty ? "You" : dataManager.preferences.profile.name),
                user1Email: authManager.currentUser?.email
            )
        }
        
        // Create invite
        let invite = CoupleInvite(
            fromUserID: authManager.currentUser?.id ?? dataManager.preferences.userID,
            fromUserName: authManager.currentUser?.displayName ?? (dataManager.preferences.profile.name.isEmpty ? "You" : dataManager.preferences.profile.name),
            fromUserEmail: authManager.currentUser?.email,
            toUserID: user.id,
            toUserEmail: user.email,
            coupleCode: couple.coupleCode,
            inviteLink: couple.inviteLink ?? Couple.generateInviteLink(code: couple.coupleCode)
        )
        
        // Add to sent invites
        dataManager.preferences.sentInvites.append(invite)
        dataManager.preferences.couple = couple
        dataManager.savePreferences()
        
        // In a real app, this would also:
        // 1. Send the invite to the server
        // 2. Send a push notification to the recipient
        // 3. Optionally send an email with the invite link
        
        // Show success and dismiss
        dismiss()
    }
}

#Preview {
    UserSearchView()
        .environmentObject(DataManager.shared)
}

