//
//  AuthManager.swift
//  Matchly
//
//  Created on 11/16/25.
//

import Foundation
import Combine
import SwiftUI
import AuthenticationServices
import OSLog

// MARK: - Authentication State
enum AuthState: Equatable {
    case signedOut
    case signedIn(User)
    case loading
}

// MARK: - User Model
struct User: Codable, Identifiable, Equatable {
    let id: String
    var email: String?
    var phoneNumber: String?
    var displayName: String?
    var photoURL: String?
    var provider: AuthProvider
    var createdAt: Date
    var lastLoginAt: Date
    
    enum AuthProvider: String, Codable {
        case email = "email"
        case phone = "phone"
        case google = "google"
        case apple = "apple"
        case facebook = "facebook"
        case reddit = "reddit"
    }
    
    init(id: String, email: String? = nil, phoneNumber: String? = nil, displayName: String? = nil, photoURL: String? = nil, provider: AuthProvider, createdAt: Date = Date(), lastLoginAt: Date = Date()) {
        self.id = id
        self.email = email
        self.phoneNumber = phoneNumber
        self.displayName = displayName
        self.photoURL = photoURL
        self.provider = provider
        self.createdAt = createdAt
        self.lastLoginAt = lastLoginAt
    }
}

// MARK: - Auth Manager
class AuthManager: ObservableObject {
    static let shared = AuthManager()
    
    @Published var authState: AuthState = .loading
    @Published var currentUser: User?
    
    private let authKey = "current_user_auth"
    static let logger = Logger(subsystem: "com.matchly", category: "AuthManager")
    
    init() {
        checkAuthState()
    }
    
    // MARK: - Auth State Management
    func checkAuthState() {
        // Check if user is already signed in
        if let userData = UserDefaults.standard.data(forKey: authKey),
           let user = try? JSONDecoder().decode(User.self, from: userData) {
            self.currentUser = user
            self.authState = .signedIn(user)
        } else {
            self.authState = .signedOut
        }
    }
    
    func signIn(user: User) {
        self.currentUser = user
        self.authState = .signedIn(user)
        
        // Save to UserDefaults
        if let encoded = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(encoded, forKey: authKey)
        }
        
        // Update last login - preserve all existing user data
        var updatedUser = user
        updatedUser.lastLoginAt = Date()
        
        // Ensure we preserve displayName if it exists
        if updatedUser.displayName == nil, let existing = self.currentUser {
            updatedUser.displayName = existing.displayName
        }
        
        if let encoded = try? JSONEncoder().encode(updatedUser) {
            UserDefaults.standard.set(encoded, forKey: authKey)
            self.currentUser = updatedUser
            Self.logger.info("Saved user to UserDefaults: displayName=\(updatedUser.displayName ?? "nil", privacy: .public)")
        }
    }
    
    func signOut() {
        self.currentUser = nil
        self.authState = .signedOut
        UserDefaults.standard.removeObject(forKey: authKey)
    }
    
    // MARK: - Email/Password Authentication
    func signUpWithEmail(email: String, password: String, displayName: String?) async throws {
        // TODO: Integrate with Firebase Auth
        // For now, create a local user
        let user = User(
            id: UUID().uuidString,
            email: email,
            displayName: displayName,
            provider: .email
        )
        
        await MainActor.run {
            signIn(user: user)
        }
    }
    
    func signInWithEmail(email: String, password: String) async throws {
        // TODO: Integrate with Firebase Auth
        // For now, check if user exists locally
        if let userData = UserDefaults.standard.data(forKey: authKey),
           let user = try? JSONDecoder().decode(User.self, from: userData),
           user.email == email {
            await MainActor.run {
                signIn(user: user)
            }
        } else {
            // In test mode: if no user exists, create one automatically for easier testing
            // This allows testing without needing to sign up first
            let user = User(
                id: UUID().uuidString,
                email: email,
                displayName: email.components(separatedBy: "@").first?.capitalized,
                provider: .email
            )
            await MainActor.run {
                signIn(user: user)
            }
        }
    }
    
    // MARK: - Phone Number Authentication
    func signInWithPhone(phoneNumber: String) async throws {
        // TODO: Integrate with Firebase Auth phone authentication
        let user = User(
            id: UUID().uuidString,
            phoneNumber: phoneNumber,
            provider: .phone
        )
        
        await MainActor.run {
            signIn(user: user)
        }
    }
    
    func verifyPhoneCode(code: String) async throws {
        // TODO: Verify phone code with Firebase
        // For now, just proceed
    }
    
    // MARK: - Social Authentication
    func signInWithGoogle() async throws {
        // TODO: Integrate with Google Sign-In
        // This requires Google Sign-In SDK
        throw AuthError.notImplemented
    }
    
    func signInWithApple() async throws {
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        
        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        
        // Handle authorization in a continuation
        let result = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<ASAuthorization, Error>) in
            let delegate = AppleSignInDelegate(continuation: continuation)
            authorizationController.delegate = delegate
            authorizationController.presentationContextProvider = delegate
            
            // Store delegate to prevent deallocation - both controller and delegate need to be retained
            delegate.retainController = authorizationController
            delegate.retainSelf = delegate // Retain self to prevent deallocation
            
            authorizationController.performRequests()
        }
        
        guard let appleIDCredential = result.credential as? ASAuthorizationAppleIDCredential else {
            Self.logger.error("Apple Sign In: Failed to get Apple ID credential")
            throw AuthError.networkError
        }
        
        // Extract user information
        let userID = appleIDCredential.user
        
        // Check if user already exists (Apple only provides email/name on first sign-in)
        var existingUser: User? = nil
        if let userData = UserDefaults.standard.data(forKey: authKey),
           let user = try? JSONDecoder().decode(User.self, from: userData),
           user.id == userID {
            existingUser = user
            Self.logger.info("Apple Sign In: Found existing user with ID: \(userID, privacy: .private)")
        }
        
        // Get email and displayName from credential (only available on first sign-in)
        // or use stored values if user already exists
        let email = appleIDCredential.email ?? existingUser?.email
        var displayName: String? = existingUser?.displayName
        
        // Format name if available from credential (only on first sign-in)
        if let givenName = appleIDCredential.fullName?.givenName,
           let familyName = appleIDCredential.fullName?.familyName {
            displayName = "\(givenName) \(familyName)"
        } else if let givenName = appleIDCredential.fullName?.givenName {
            displayName = givenName
        }
        
        Self.logger.info("Apple Sign In: Successfully authenticated user: \(userID, privacy: .private)")
        if let email = email {
            Self.logger.debug("Email: \(email, privacy: .private)")
        }
        if let displayName = displayName {
            Self.logger.debug("Display Name: \(displayName, privacy: .public)")
        }
        
        // Create or update user - always preserve existing displayName if we have one and new one is nil
        var finalDisplayName = displayName ?? existingUser?.displayName
        
        // Fallback: if no display name and we have an email, use the email's local part
        if (finalDisplayName == nil || finalDisplayName?.isEmpty == true),
           let email = email, !email.isEmpty {
            let emailLocalPart = email.components(separatedBy: "@").first ?? ""
            if !emailLocalPart.isEmpty {
                finalDisplayName = emailLocalPart.capitalized
                Self.logger.debug("Using email local part as display name: \(finalDisplayName ?? "", privacy: .public)")
            }
        }
        
        Self.logger.debug("Apple Sign In: Final user data - ID: \(userID, privacy: .private), Email: \(email ?? "nil", privacy: .private), Display Name: \(finalDisplayName ?? "nil", privacy: .public)")
        
        // Create or update user
        let user = User(
            id: userID,
            email: email,
            displayName: finalDisplayName,
            provider: .apple
        )
        
        await MainActor.run {
            signIn(user: user)
        }
    }
    
    func signInWithFacebook() async throws {
        // TODO: Integrate with Facebook Login SDK
        throw AuthError.notImplemented
    }
    
    func signInWithReddit() async throws {
        // TODO: Integrate with Reddit OAuth
        // Reddit doesn't have official SDK, need custom OAuth flow
        throw AuthError.notImplemented
    }
    
    // MARK: - Password Reset
    func resetPassword(email: String) async throws {
        // TODO: Integrate with Firebase Auth password reset
        throw AuthError.notImplemented
    }
}

// MARK: - Auth Errors
enum AuthError: LocalizedError {
    case userNotFound
    case invalidCredentials
    case emailAlreadyInUse
    case weakPassword
    case networkError
    case notImplemented
    
    var errorDescription: String? {
        switch self {
        case .userNotFound:
            return "No account found with this email address."
        case .invalidCredentials:
            return "Invalid email or password."
        case .emailAlreadyInUse:
            return "An account with this email already exists."
        case .weakPassword:
            return "Password must be at least 6 characters."
        case .networkError:
            return "Network error. Please check your connection."
        case .notImplemented:
            return "This feature is not yet implemented."
        }
    }
}

// MARK: - Apple Sign In Delegate
class AppleSignInDelegate: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private let continuation: CheckedContinuation<ASAuthorization, Error>
    var retainController: ASAuthorizationController? // Retain the controller to prevent deallocation
    var retainSelf: AppleSignInDelegate? // Retain self to prevent deallocation
    
    init(continuation: CheckedContinuation<ASAuthorization, Error>) {
        self.continuation = continuation
        super.init()
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        AuthManager.logger.info("Apple Sign In: Authorization completed successfully")
        retainController = nil // Release after completion
        retainSelf = nil // Release self
        continuation.resume(returning: authorization)
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        AuthManager.logger.error("Apple Sign In: Authorization failed with error: \(error.localizedDescription, privacy: .public)")
        if let authError = error as? ASAuthorizationError {
            AuthManager.logger.error("Error code: \(authError.code.rawValue), description: \(authError.localizedDescription, privacy: .public)")
        }
        retainController = nil // Release after error
        retainSelf = nil // Release self
        continuation.resume(throwing: error)
    }
    
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        // Try to get window from connected scenes (iOS 13+)
        // First, try to find the key window
        for scene in UIApplication.shared.connectedScenes {
            if let windowScene = scene as? UIWindowScene {
                if let keyWindow = windowScene.windows.first(where: { $0.isKeyWindow }) {
                    return keyWindow
                }
                // Fallback to first window in scene
                if let window = windowScene.windows.first {
                    return window
                }
            }
        }
        
        // This should never happen in a properly initialized app
        // Log the error for debugging
        AuthManager.logger.error("Apple Sign In: No window available - this should not happen")
        // Return a dummy window to prevent crash - the sign-in will likely fail gracefully
        // The delegate will handle the error
        // Use the first available window scene to create a window (iOS 15+)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            return UIWindow(windowScene: windowScene)
        }
        // Last resort fallback - this should never be reached
        return UIWindow(frame: .zero)
    }
}

