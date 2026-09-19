//
//  LinkEmailPasswordView.swift
//  Matchly
//

import SwiftUI

/// Lets an Apple/Google (etc.) signed-in user attach Email/Password to the same account.
struct LinkEmailPasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var authManager = AuthManager.shared

    @State private var email: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showSuccess = false

    var body: some View {
        MatchlyNavigationView {
            Form {
                Section {
                    Text("Add an email and password to this Matchly account. You can keep signing in with \(authManager.currentUser?.provider.rawValue.capitalized ?? "your current method"), and also use email next time.")
                        .font(.arial(size: 14))
                        .foregroundColor(.secondary)
                        .listRowBackground(Color.clear)
                }

                Section {
                    ClearableTextField("Email", text: $email, textContentType: .emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    SecureField("Password (min 6 characters)", text: $password)
                        .textContentType(.newPassword)

                    SecureField("Confirm Password", text: $confirmPassword)
                        .textContentType(.newPassword)
                } footer: {
                    if let errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                }

                Section {
                    Button {
                        Task { await link() }
                    } label: {
                        HStack {
                            Spacer()
                            if isLoading {
                                ProgressView()
                            } else {
                                Text("Enable Email Login")
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                    }
                    .buttonStyle(.glassProminent)
                    .tint(AppColors.primaryBlue)
                    .disabled(isLoading || !canSubmit)
                }
            }
            .scrollContentBackground(.hidden)
            .appCanvasBackground()
            .navigationTitle("Email Login")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                if email.isEmpty {
                    email = authManager.currentUser?.email ?? ""
                }
            }
            .alert("Email Login Enabled", isPresented: $showSuccess) {
                Button("OK") { dismiss() }
            } message: {
                Text("You can now sign in with this email and password, or keep using \(authManager.currentUser?.provider.rawValue.capitalized ?? "your other sign-in method").")
            }
        }
    }

    private var canSubmit: Bool {
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && password.count >= 6
            && password == confirmPassword
    }

    private func link() async {
        guard password == confirmPassword else {
            errorMessage = "Passwords do not match."
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await authManager.linkEmailPassword(email: email, password: password)
            showSuccess = true
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}

#Preview {
    LinkEmailPasswordView()
}
