//
//  EmailLoginView.swift
//  Matchly
//
//  Created on 11/16/25.
//

import SwiftUI

struct EmailLoginView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var authManager = AuthManager.shared
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showSignUp = false
    @State private var showForgotPassword = false
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .autocapitalization(.none)
                        .keyboardType(.emailAddress)
                    
                    SecureField("Password", text: $password)
                        .textContentType(.password)
                } header: {
                    Text("Sign In")
                } footer: {
                    if let error = errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
                
                Section {
                    Button(action: {
                        Task {
                            await signIn()
                        }
                    }) {
                        HStack {
                            Spacer()
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                            } else {
                                Text("Sign In")
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                    }
                    .disabled(isLoading || email.isEmpty || password.isEmpty)
                    
                    Button(action: {
                        showForgotPassword = true
                    }) {
                        Text("Forgot Password?")
                            .foregroundColor(.blue)
                    }
                }
                
                Section {
                    HStack {
                        Spacer()
                        Text("Don't have an account?")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                        Button(action: {
                            dismiss()
                            showSignUp = true
                        }) {
                            Text("Sign Up")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.blue)
                        }
                        Spacer()
                    }
                }
            }
            .navigationTitle("Sign In")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showSignUp) {
                SignUpView()
            }
            .alert("Reset Password", isPresented: $showForgotPassword) {
                TextField("Email", text: $email)
                Button("Send Reset Link") {
                    Task {
                        await resetPassword()
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Enter your email address and we'll send you a password reset link.")
            }
        }
    }
    
    private func signIn() async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await authManager.signInWithEmail(email: email, password: password)
            await MainActor.run {
                dismiss()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    private func resetPassword() async {
        do {
            try await authManager.resetPassword(email: email)
            errorMessage = "Password reset email sent. Please check your inbox."
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    EmailLoginView()
}


