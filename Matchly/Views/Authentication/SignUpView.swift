//
//  SignUpView.swift
//  Matchly
//
//  Created on 11/16/25.
//

import SwiftUI

struct SignUpView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var authManager = AuthManager.shared
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var displayName = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        MatchlyNavigationView {
            Form {
                Section {
                    VStack(spacing: 12) {
                        TextField("Display Name (Optional)", text: $displayName)
                            .textContentType(.name)
                            .autocapitalization(.words)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .glassEffect(.regular, in: .capsule)
                        
                        TextField("Email", text: $email)
                            .textContentType(.emailAddress)
                            .autocapitalization(.none)
                            .keyboardType(.emailAddress)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .glassEffect(.regular, in: .capsule)
                        
                        SecureField("Password", text: $password)
                            .textContentType(.newPassword)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .glassEffect(.regular, in: .capsule)
                        
                        SecureField("Confirm Password", text: $confirmPassword)
                            .textContentType(.newPassword)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .glassEffect(.regular, in: .capsule)
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
                } header: {
                    Text("Create Account")
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        if let error = errorMessage {
                            Text(error)
                                .foregroundColor(.red)
                        }
                        Text("Password must be at least 6 characters long.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section {
                    Button(action: {
                        Task {
                            await signUp()
                        }
                    }) {
                        HStack {
                            Spacer()
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                            } else {
                                Text("Create Account")
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                    }
                    .buttonStyle(.glassProminent)
                    .tint(AppColors.primaryBlue)
                    .disabled(isLoading || !isFormValid)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
                }
            }
            .scrollContentBackground(.hidden)
            .appCanvasBackground()
            .navigationTitle("Sign Up")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var isFormValid: Bool {
        !email.isEmpty &&
        !password.isEmpty &&
        password == confirmPassword &&
        password.count >= 6 &&
        email.contains("@")
    }
    
    private func signUp() async {
        isLoading = true
        errorMessage = nil
        
        guard password == confirmPassword else {
            errorMessage = "Passwords do not match."
            isLoading = false
            return
        }
        
        guard password.count >= 6 else {
            errorMessage = "Password must be at least 6 characters."
            isLoading = false
            return
        }
        
        do {
            try await authManager.signUpWithEmail(
                email: email,
                password: password,
                displayName: displayName.isEmpty ? nil : displayName
            )
            await MainActor.run {
                dismiss()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
}

#Preview {
    SignUpView()
}

