//
//  EmailLoginView.swift
//  Matchly
//
//  Created on 11/16/25.
//

import SwiftUI

struct EmailLoginView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var authManager = AuthManager.shared
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
                    VStack(spacing: 12) {
                        TextField("Email", text: $email)
                            .textContentType(.emailAddress)
                            .autocapitalization(.none)
                            .keyboardType(.emailAddress)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .glassEffect(.regular, in: .capsule)
                        
                        SecureField("Password", text: $password)
                            .textContentType(.password)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .glassEffect(.regular, in: .capsule)
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
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
                    .buttonStyle(.glassProminent)
                    .tint(AppColors.primaryBlue)
                    .disabled(isLoading || email.isEmpty || password.isEmpty)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
                    
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
                            .font(.arial(size: 14))
                            .foregroundColor(.secondary)
                        Button(action: {
                            showSignUp = true
                        }) {
                            Text("Sign Up")
                                .font(.arial(size: 14, weight: .semibold))
                                .foregroundColor(.blue)
                        }
                        Spacer()
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .appCanvasBackground()
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

