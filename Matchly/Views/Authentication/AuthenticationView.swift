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
    
    var body: some View {
        ZStack {
            AppColors.dashboardCanvas
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    Spacer()
                        .frame(height: 40)
                    
                    // App Logo and Title
                    VStack(spacing: 16) {
                        // Matchly app icon
                        Image("MatchlyIcon")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 100, height: 100)
                            .cornerRadius(22) // iOS app icon corner radius
                            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                        
                        Text("Matchly")
                            .font(.arial(size: 32, weight: .bold))
                            .foregroundColor(.primary)
                        
                        Text("Residency Match Management")
                            .font(.arial(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .padding(.bottom, 20)
                    
                    // Sign In Options
                    VStack(spacing: 16) {
                        // v1 ships Apple Sign In ONLY. The email/phone entry points below are
                        // hidden (not deleted) behind `AuthManager.allowsNonAppleProviders` so
                        // they remain reversible. Couples Match requires iCloud, which Apple
                        // Sign In + CloudKit provide.
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

                            // Phone Number Sign In
                            Button(action: {
                                showPhoneLogin = true
                            }) {
                                HStack {
                                    Spacer()
                                    Image(systemName: "phone.fill")
                                        .font(.arial(size: 16))
                                        .frame(width: 24)
                                    Text("Continue with Phone")
                                        .font(.arial(size: 16, weight: .medium))
                                    Spacer()
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                            }
                            .buttonStyle(.glassProminent)
                            .tint(.green)

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
                        Text("Sign in with your Apple ID to get started.")
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
    }
}

#Preview {
    AuthenticationView()
}

