//
//  BiometricLockView.swift
//  Matchly
//

import SwiftUI

struct BiometricLockView: View {
    @ObservedObject private var authManager = AuthManager.shared
    @State private var isAuthenticating = false
    @State private var errorMessage: String?

    private var biometric: BiometricKind {
        BiometricAuthManager.shared.kind
    }

    var body: some View {
        ZStack {
            AppColors.dashboardCanvas
                .ignoresSafeArea()

            Color.black.opacity(0.35)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Image("MatchlyIcon")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 72, height: 72)
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.12), radius: 8, y: 4)

                Text("Matchly is Locked")
                    .font(.arial(size: 24, weight: .semibold))
                    .foregroundColor(.primary)

                Text("Use \(biometric.displayName) to continue.")
                    .font(.arial(size: 15))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                Button(action: unlock) {
                    HStack(spacing: 10) {
                        Image(systemName: biometric.systemImageName)
                            .font(.arial(size: 18, weight: .semibold))
                        Text("Unlock with \(biometric.displayName)")
                            .font(.arial(size: 16, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                }
                .buttonStyle(.glassProminent)
                .tint(AppColors.primaryBlue)
                .disabled(isAuthenticating)
                .padding(.horizontal, 32)
                .padding(.top, 8)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.arial(size: 13))
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            }
            .padding(.horizontal, 24)
        }
        .onAppear {
            unlock()
        }
    }

    private func unlock() {
        guard !isAuthenticating else { return }
        isAuthenticating = true
        errorMessage = nil

        Task {
            defer { isAuthenticating = false }
            do {
                try await authManager.unlockWithBiometrics()
            } catch BiometricAuthError.canceled {
                errorMessage = nil
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
    }
}

#Preview {
    BiometricLockView()
}
