//
//  AuthenticationView.swift
//  Matchly
//
//  Created on 11/16/25.
//

import SwiftUI
import AuthenticationServices

struct AuthenticationView: View {
    @StateObject private var authManager = AuthManager.shared
    @State private var showSignUp = false
    @State private var showEmailLogin = false
    @State private var showPhoneLogin = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        ZStack {
            // Background
            Color(.systemBackground)
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
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.primary)
                        
                        Text("Residency Match Management")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .padding(.bottom, 20)
                    
                    // Sign In Options
                    VStack(spacing: 16) {
                        // Email/Password Sign In
                        Button(action: {
                            showEmailLogin = true
                        }) {
                            HStack {
                                Spacer()
                                Image(systemName: "envelope.fill")
                                    .font(.system(size: 16))
                                    .frame(width: 24)
                                Text("Continue with Email")
                                    .font(.system(size: 16, weight: .medium))
                                Spacer()
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                            .background(Color.blue)
                            .cornerRadius(12)
                        }
                        
                        // Phone Number Sign In
                        Button(action: {
                            showPhoneLogin = true
                        }) {
                            HStack {
                                Spacer()
                                Image(systemName: "phone.fill")
                                    .font(.system(size: 16))
                                    .frame(width: 24)
                                Text("Continue with Phone")
                                    .font(.system(size: 16, weight: .medium))
                                Spacer()
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                            .background(Color.green)
                            .cornerRadius(12)
                        }
                        
                        // Divider
                        HStack {
                            Rectangle()
                                .fill(Color.secondary.opacity(0.3))
                                .frame(height: 1)
                            Text("OR")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 12)
                            Rectangle()
                                .fill(Color.secondary.opacity(0.3))
                                .frame(height: 1)
                        }
                        .padding(.vertical, 8)
                        
                        // Apple Sign In
                        Button(action: {
                            Task { @MainActor in
                                do {
                                    print("🍎 Starting Apple Sign In...")
                                    try await authManager.signInWithApple()
                                    print("🍎 Apple Sign In completed successfully")
                                } catch {
                                    print("🍎 Apple Sign In error: \(error)")
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
                                    .font(.system(size: 16))
                                    .frame(width: 24)
                                Text("Continue with Apple")
                                    .font(.system(size: 16, weight: .medium))
                                Spacer()
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                            .background(Color.black)
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    // Sign Up Link
                    HStack(spacing: 4) {
                        Text("Don't have an account?")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                        Button(action: {
                            showSignUp = true
                        }) {
                            Text("Sign Up")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.top, 8)
                    
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

