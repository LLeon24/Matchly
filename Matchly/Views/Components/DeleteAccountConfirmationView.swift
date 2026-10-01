//
//  DeleteAccountConfirmationView.swift
//  Matchly
//

import SwiftUI

struct DeleteAccountConfirmationView: View {
    let requiresPassword: Bool
    let provider: User.AuthProvider?
    var onConfirm: (String?) async -> String?

    @Environment(\.dismiss) private var dismiss
    @State private var password = ""
    @State private var isDeleting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(confirmationMessage)
                        .font(.arial(size: 15))
                        .foregroundColor(.secondary)
                }

                if requiresPassword {
                    Section {
                        SecureField("Password", text: $password)
                            .textContentType(.password)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    } footer: {
                        Text("Enter your Matchly password to confirm deletion.")
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.arial(size: 14))
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Delete Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isDeleting)
                }
                ToolbarItem(placement: .destructiveAction) {
                    Button("Delete", role: .destructive) {
                        Task { await confirmDeletion() }
                    }
                    .disabled(isDeleting || (requiresPassword && password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
                }
            }
            .interactiveDismissDisabled(isDeleting)
            .overlay {
                if isDeleting {
                    ZStack {
                        Color.black.opacity(0.15).ignoresSafeArea()
                        ProgressView("Deleting account…")
                            .padding(20)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
        }
    }

    private var confirmationMessage: String {
        var message = "This permanently deletes your account and all synced data. This cannot be undone."
        switch provider {
        case .apple:
            message += " You'll be asked to confirm with Sign in with Apple."
        case .google:
            message += " You may be asked to confirm with Google."
        default:
            break
        }
        return message
    }

    private func confirmDeletion() async {
        isDeleting = true
        errorMessage = nil
        let submittedPassword = requiresPassword ? password : nil
        if let error = await onConfirm(submittedPassword) {
            errorMessage = error
            isDeleting = false
        } else {
            dismiss()
        }
    }
}
