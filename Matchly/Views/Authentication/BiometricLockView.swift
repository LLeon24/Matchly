//
//  BiometricLockView.swift
//  Matchly
//

import SwiftUI

struct BiometricLockView: View {
    @ObservedObject private var authManager = AuthManager.shared

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

                HStack(spacing: 10) {
                    Image(systemName: biometric.systemImageName)
                        .font(.arial(size: 20, weight: .semibold))
                        .foregroundColor(AppColors.primaryBlue)
                    Text(
                        authManager.shouldShowBiometricRetry
                            ? "Confirm \(biometric.displayName) to continue"
                            : "Waiting for \(biometric.displayName)…"
                    )
                    .font(.arial(size: 15))
                    .foregroundColor(.secondary)
                }
                .multilineTextAlignment(.center)

                if let errorMessage = authManager.biometricUnlockError {
                    Text(errorMessage)
                        .font(.arial(size: 13))
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                if authManager.shouldShowBiometricRetry {
                    Button(action: retryUnlock) {
                        HStack(spacing: 10) {
                            Image(systemName: biometric.systemImageName)
                                .font(.arial(size: 18, weight: .semibold))
                            Text("Try \(biometric.displayName) Again")
                                .font(.arial(size: 16, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(AppColors.primaryBlue)
                    .padding(.horizontal, 32)
                }
            }
            .padding(.horizontal, 24)
        }
        .onAppear {
            authManager.attemptAutomaticBiometricUnlock()
        }
    }

    private func retryUnlock() {
        authManager.attemptAutomaticBiometricUnlock()
    }
}

#Preview {
    BiometricLockView()
}
