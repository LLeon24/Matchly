//
//  AuthenticationView.swift
//  Matchly
//
//  Created on 11/16/25.
//

import SwiftUI
import AuthenticationServices
import OSLog

private let authViewLogger = Logger(subsystem: "com.matchly", category: "AuthenticationView")

struct AuthenticationView: View {
    @ObservedObject private var authManager = AuthManager.shared
    @State private var showSignUp = false
    @State private var showEmailLogin = false
    @State private var showPhoneLogin = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isBiometricSigningIn = false

    private var biometricKind: BiometricKind {
        BiometricAuthManager.shared.kind
    }
    
    var body: some View {
        ZStack {
            AppColors.dashboardCanvas
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    Spacer()
                        .frame(height: 40)
                    
                    // Brand lockup
                    VStack(spacing: 16) {
                        MatchlyBrandLockup(style: .auth)
                    }
                    .padding(.bottom, 28)
                    
                    // Sign In Options
                    VStack(spacing: 16) {
                        if authManager.canUseBiometricLogin {
                            Button(action: signInWithBiometrics) {
                                HStack {
                                    Spacer()
                                    Image(systemName: biometricKind.systemImageName)
                                        .font(.arial(size: 16))
                                        .frame(width: 24)
                                    Text("Sign in with \(biometricKind.displayName)")
                                        .font(.arial(size: 16, weight: .medium))
                                    Spacer()
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                            }
                            .buttonStyle(.glassProminent)
                            .tint(AppColors.primaryBlue)
                            .disabled(isBiometricSigningIn)

                            HStack(spacing: 14) {
                                Rectangle()
                                    .fill(AppColors.secondaryText.opacity(0.35))
                                    .frame(height: 0.5)
                                    .frame(maxWidth: .infinity)
                                Text("OR")
                                    .font(.arial(size: 11, weight: .regular))
                                    .foregroundColor(.secondary)
                                    .kerning(1.8)
                                Rectangle()
                                    .fill(AppColors.secondaryText.opacity(0.35))
                                    .frame(height: 0.5)
                                    .frame(maxWidth: .infinity)
                            }
                            .padding(.vertical, 6)
                        }

                        // Email + Google when `allowsNonAppleProviders` is true; Apple always shown.
                        if AuthManager.allowsNonAppleProviders {
                            // Email/Password Sign In
                            Button(action: {
                                showEmailLogin = true
                            }) {
                                HStack {
                                    Spacer()
                                    Image(systemName: "envelope.fill")
                                        .font(.arial(size: 16))
                                        .frame(width: 24)
                                    Text("Continue with Email")
                                        .font(.arial(size: 16, weight: .medium))
                                    Spacer()
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                            }
                            .buttonStyle(.glassProminent)
                            .tint(.blue)

                            // Google Sign In
                            Button(action: {
                                Task { @MainActor in
                                    do {
                                        authViewLogger.info("Starting Google Sign In")
                                        try await authManager.signInWithGoogle()
                                        authViewLogger.info("Google Sign In completed successfully")
                                    } catch AuthError.canceled {
                                        return
                                    } catch {
                                        authViewLogger.error("Google Sign In error: \(error.localizedDescription, privacy: .public)")
                                        if let authError = error as? AuthError {
                                            errorMessage = authError.errorDescription ?? "Sign in failed"
                                        } else {
                                            errorMessage = error.localizedDescription
                                        }
                                        showError = true
                                    }
                                }
                            }) {
                                HStack {
                                    Spacer()
                                    Image(systemName: "g.circle.fill")
                                        .font(.arial(size: 16))
                                        .frame(width: 24)
                                    Text("Continue with Google")
                                        .font(.arial(size: 16, weight: .medium))
                                    Spacer()
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                            }
                            .buttonStyle(.glassProminent)
                            .tint(Color(red: 0.86, green: 0.28, blue: 0.22))

                            // Divider
                            HStack {
                                Rectangle()
                                    .fill(Color.secondary.opacity(0.3))
                                    .frame(height: 1)
                                Text("OR")
                                    .font(.arial(size: 12, weight: .medium))
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 12)
                                Rectangle()
                                    .fill(Color.secondary.opacity(0.3))
                                    .frame(height: 1)
                            }
                            .padding(.vertical, 8)
                        }

                        // Apple Sign In
                        Button(action: {
                            Task { @MainActor in
                                do {
                                    authViewLogger.info("Starting Apple Sign In")
                                    try await authManager.signInWithApple()
                                    authViewLogger.info("Apple Sign In completed successfully")
                                } catch {
                                    authViewLogger.error("Apple Sign In error: \(error.localizedDescription, privacy: .public)")
                                    // Provide helpful error message for Apple Sign In
                                    if let authError = error as? AuthError {
                                        errorMessage = authError.errorDescription ?? "Sign in failed"
                                    } else if let asError = error as? ASAuthorizationError {
                                        switch asError.code {
                                        case .canceled:
                                            errorMessage = "Apple Sign In was canceled."
                                        case .failed:
                                            errorMessage = "Apple Sign In failed. Please try again."
                                        case .invalidResponse:
                                            errorMessage = "Invalid response from Apple. Please try again."
                                        case .notHandled:
                                            errorMessage = "Apple Sign In not handled. Make sure the capability is enabled in Xcode."
                                        case .unknown:
                                            errorMessage = "Unknown error occurred. Please try again."
                                        default:
                                            errorMessage = "Apple Sign In failed: \(error.localizedDescription)"
                                        }
                                    } else {
                                        errorMessage = "Apple Sign In failed: \(error.localizedDescription)\n\nMake sure:\n1. Sign in with Apple capability is enabled in Xcode\n2. You're signed in to an Apple ID on this device\n3. The app is properly configured in Apple Developer"
                                    }
                                    showError = true
                                }
                            }
                        }) {
                            HStack {
                                Spacer()
                                Image(systemName: "applelogo")
                                    .font(.arial(size: 16))
                                    .frame(width: 24)
                                Text("Continue with Apple")
                                    .font(.arial(size: 16, weight: .medium))
                                Spacer()
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                        }
                        .buttonStyle(.glassProminent)
                        .tint(.black)
                    }
                    .padding(.horizontal, 24)
                    
                    // Sign Up Link (email-based; hidden in the Apple-only v1)
                    if AuthManager.allowsNonAppleProviders {
                        HStack(spacing: 4) {
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
                        }
                        .padding(.top, 8)
                    } else {
                        Text("Sign in with Apple, Google, or email to get started.")
                            .font(.arial(size: 13))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.top, 8)
                    }
                    
                    Spacer()
                        .frame(height: 40)
                }
            }
        }
        // Note: No need to dismiss - SplashView will automatically transition when authState changes
        .sheet(isPresented: $showSignUp) {
            SignUpView()
        }
        .sheet(isPresented: $showEmailLogin) {
            EmailLoginView()
        }
        .sheet(isPresented: $showPhoneLogin) {
            PhoneLoginView()
        }
        .alert("Sign In Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .matchlyKeyboardDismissToolbar()
    }

    private func signInWithBiometrics() {
        guard !isBiometricSigningIn else { return }
        isBiometricSigningIn = true

        Task { @MainActor in
            defer { isBiometricSigningIn = false }
            do {
                try await authManager.signInWithBiometrics()
            } catch BiometricAuthError.canceled {
                return
            } catch {
                if let authError = error as? LocalizedError, let description = authError.errorDescription {
                    errorMessage = description
                } else {
                    errorMessage = error.localizedDescription
                }
                showError = true
            }
        }
    }
}

#Preview {
    AuthenticationView()
}

