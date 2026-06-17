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
import CloudKit
import CryptoKit
import Security
import OSLog

// MARK: - Authentication State
enum AuthState: Equatable {
    case signedOut
    case signedIn(User)
    case loading
}

// MARK: - User Model
struct User: Codable, Identifiable, Equatable {
    /// For the Apple provider this is the stable `ASAuthorizationAppleIDCredential.user`
    /// string (never a random UUID). It is the login identity.
    let id: String
    var email: String?
    var phoneNumber: String?
    var displayName: String?
    var photoURL: String?
    var provider: AuthProvider
    /// Stable CloudKit user record name (`CKRecord.ID.recordName`) for this iCloud account.
    /// This is the identity used to own/share CloudKit records and attribute couple edits.
    /// Resolved asynchronously after sign-in / on launch; `nil` until CloudKit is available.
    var cloudKitUserRecordName: String?
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
    
    init(id: String, email: String? = nil, phoneNumber: String? = nil, displayName: String? = nil, photoURL: String? = nil, provider: AuthProvider, cloudKitUserRecordName: String? = nil, createdAt: Date = Date(), lastLoginAt: Date = Date()) {
        self.id = id
        self.email = email
        self.phoneNumber = phoneNumber
        self.displayName = displayName
        self.photoURL = photoURL
        self.provider = provider
        self.cloudKitUserRecordName = cloudKitUserRecordName
        self.createdAt = createdAt
        self.lastLoginAt = lastLoginAt
    }

    // Resilient decoding: older cached users won't have `cloudKitUserRecordName`.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(String.self, forKey: .id)
        self.email = try c.decodeIfPresent(String.self, forKey: .email)
        self.phoneNumber = try c.decodeIfPresent(String.self, forKey: .phoneNumber)
        self.displayName = try c.decodeIfPresent(String.self, forKey: .displayName)
        self.photoURL = try c.decodeIfPresent(String.self, forKey: .photoURL)
        self.provider = try c.decodeIfPresent(AuthProvider.self, forKey: .provider) ?? .apple
        self.cloudKitUserRecordName = try c.decodeIfPresent(String.self, forKey: .cloudKitUserRecordName)
        self.createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        self.lastLoginAt = try c.decodeIfPresent(Date.self, forKey: .lastLoginAt) ?? Date()
    }
}

// MARK: - Auth Manager
class AuthManager: ObservableObject {
    static let shared = AuthManager()

    /// v1 ships **Apple Sign In only**. Email/phone/social entry points stay in the codebase
    /// (the methods below are intact) but are hidden in the UI while this is `false`.
    /// Flip to `true` to restore the email/phone sign-in UI (note: those paths still mint a
    /// local UUID identity and are NOT compatible with CloudKit couples).
    static let allowsNonAppleProviders = false

    /// The CloudKit container backing the couples feature. Must match the container selected
    /// in Xcode's Signing & Capabilities ▸ iCloud (see COUPLES_MATCH_SETUP_STEPS.md).
    static let cloudKitContainerID = "iCloud.com.matchly.Matchly"

    /// Keychain identifiers for the persisted Apple login id.
    private static let keychainService = "com.matchly.auth"
    private static let keychainAppleUserAccount = "apple_user_id"

    @Published var authState: AuthState = .loading
    @Published var currentUser: User?

    /// Latest known CloudKit account status. Couples/CloudKit-dependent state should gate on
    /// `isCloudKitAvailable`. Defaults to `.couldNotDetermine` until the first check resolves.
    @Published var cloudAccountStatus: CKAccountStatus = .couldNotDetermine

    /// Resolved CloudKit user record name, even before it is copied onto `currentUser`.
    @Published private(set) var resolvedCloudKitRecordName: String?

    /// `true` only when CloudKit is usable (user signed into iCloud + capability enabled).
    var isCloudKitAvailable: Bool { cloudAccountStatus == .available }

    /// The resolved CloudKit user record name for the signed-in account, if available.
    var cloudKitUserRecordName: String? {
        currentUser?.cloudKitUserRecordName ?? resolvedCloudKitRecordName
    }

    /// The stable Apple login id persisted in the Keychain (survives UserDefaults clears).
    var storedAppleUserID: String? { Self.keychainRead(account: Self.keychainAppleUserAccount) }

    /// User-facing explanation when CloudKit isn't usable yet (mirrors CloudSyncManager style).
    var cloudUnavailableMessage: String? {
        switch cloudAccountStatus {
        case .available:
            return nil
        case .noAccount:
            return "iCloud is required for Couples Match. Sign in to iCloud in Settings, then reopen Matchly."
        case .restricted:
            return "iCloud access is restricted on this device, so Couples Match is unavailable."
        case .temporarilyUnavailable:
            return "iCloud is temporarily unavailable. Please try again in a moment."
        case .couldNotDetermine:
            return "Couldn't determine iCloud status. Make sure you're signed in to iCloud and the iCloud capability is enabled."
        @unknown default:
            return "iCloud is currently unavailable for Couples Match."
        }
    }

    /// Nonce used for the in-flight Apple Sign In request (SHA256 of this is sent to Apple).
    private var currentAppleNonce: String?

    private let authKey = "current_user_auth"
    static let logger = Logger(subsystem: "com.matchly", category: "AuthManager")
    
    init() {
        checkAuthState()
        // Revalidate Apple credential + resolve CloudKit identity off the launch path.
        Task { [weak self] in
            await self?.revalidateAppleCredentialState()
            await self?.refreshCloudKitIdentity()
        }
    }
    
    // MARK: - Auth State Management
    func checkAuthState() {
        // Check if user is already signed in. We do NOT wipe legacy stub users here; if a
        // previously "signed in" email/phone stub exists we keep them signed in and let the
        // next Apple sign-in map them onto a real Apple identity.
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
        self.resolvedCloudKitRecordName = nil
        self.authState = .signedOut
        self.cloudAccountStatus = .couldNotDetermine
        self.currentAppleNonce = nil
        UserDefaults.standard.removeObject(forKey: authKey)
        Self.keychainDelete(account: Self.keychainAppleUserAccount)
    }

    /// Best available name for UI: auth display name, profile name, email local-part, then fallback.
    func preferredDisplayName(profileName: String = "") -> String {
        if let displayName = currentUser?.displayName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !displayName.isEmpty {
            return displayName
        }
        let trimmedProfile = profileName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedProfile.isEmpty {
            return trimmedProfile
        }
        if let email = currentUser?.email?.trimmingCharacters(in: .whitespacesAndNewlines), !email.isEmpty {
            let localPart = email.components(separatedBy: "@").first ?? ""
            if !localPart.isEmpty {
                return localPart.capitalized
            }
            return email
        }
        if let phone = currentUser?.phoneNumber, !phone.isEmpty {
            return phone
        }
        return "User"
    }

    /// Persist a display name when Apple Sign In did not return one on repeat logins.
    func updateDisplayName(_ name: String) {
        guard var user = currentUser else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        user.displayName = trimmed
        persist(user)
    }

    /// Persist `user` to UserDefaults and publish it without re-running the
    /// last-login/display-name preservation in `signIn(user:)`. Safe to call when already
    /// signed in (e.g. when filling in the CloudKit record name after it resolves).
    @MainActor
    private func persist(_ user: User) {
        self.currentUser = user
        self.authState = .signedIn(user)
        if let encoded = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(encoded, forKey: authKey)
        }
    }
    
    // MARK: - Email/Password Authentication
    /// Sign up with email and password
    /// NOTE: Currently uses local storage. To enable Firebase Auth:
    /// 1. Add Firebase SDK to project
    /// 2. Initialize Firebase in MatchlyApp.swift
    /// 3. Replace this implementation with Firebase Auth calls
    /// See Documentation/AUTHENTICATION_SETUP.md for details
    func signUpWithEmail(email: String, password: String, displayName: String?) async throws {
        // v1 is Apple Sign In only. This path is kept intact but gated off so it can't mint a
        // local UUID identity. Flip `allowsNonAppleProviders` to re-enable.
        guard Self.allowsNonAppleProviders else { throw AuthError.notImplemented }
        // Local implementation - replace with Firebase Auth when ready
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
    
    /// Sign in with email and password
    /// NOTE: Currently uses local storage. See signUpWithEmail for Firebase integration notes.
    func signInWithEmail(email: String, password: String) async throws {
        // v1 is Apple Sign In only. Gated off so it can't mint a local UUID identity.
        guard Self.allowsNonAppleProviders else { throw AuthError.notImplemented }
        // Local implementation - replace with Firebase Auth when ready
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
    /// Sign in with phone number
    /// NOTE: Requires Firebase Auth phone authentication setup
    /// See Documentation/AUTHENTICATION_SETUP.md for configuration
    func signInWithPhone(phoneNumber: String) async throws {
        // v1 is Apple Sign In only. Gated off so it can't mint a local UUID identity.
        guard Self.allowsNonAppleProviders else { throw AuthError.notImplemented }
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
    
    /// Verify phone authentication code
    /// NOTE: Requires Firebase Auth phone authentication setup
    func verifyPhoneCode(code: String) async throws {
        // TODO: Verify phone code with Firebase
        // For now, just proceed
    }
    
    // MARK: - Social Authentication
    /// Sign in with Google
    /// NOTE: Requires Google Sign-In SDK and Firebase configuration
    /// See Documentation/AUTHENTICATION_SETUP.md
    func signInWithGoogle() async throws {
        // TODO: Integrate with Google Sign-In SDK
        throw AuthError.notImplemented
    }
    
    func signInWithApple() async throws {
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]

        // Generate a fresh nonce and send its SHA256 to Apple. The raw nonce is retained so it
        // round-trips (it is embedded in the returned identity token's JWT claims).
        let rawNonce = Self.randomNonceString()
        currentAppleNonce = rawNonce
        request.nonce = Self.sha256(rawNonce)

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

        // Verify the identity token is present. Without a backend we don't do full server-side
        // JWT verification, but a missing token means the authorization is not usable.
        guard let identityTokenData = appleIDCredential.identityToken,
              !identityTokenData.isEmpty,
              String(data: identityTokenData, encoding: .utf8)?.isEmpty == false else {
            Self.logger.error("Apple Sign In: Missing identity token")
            currentAppleNonce = nil
            throw AuthError.invalidCredentials
        }
        // Confirm the nonce round-tripped (request had a nonce set).
        if currentAppleNonce == nil {
            Self.logger.warning("Apple Sign In: nonce was not set for this request")
        }
        currentAppleNonce = nil
        
        // Extract user information
        let userID = appleIDCredential.user

        // Persist the stable Apple login id to the Keychain (preferred secure storage).
        Self.keychainSave(userID, account: Self.keychainAppleUserAccount)
        
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
        
        // Create or update user, preserving an already-resolved CloudKit record name if any.
        let user = User(
            id: userID,
            email: email,
            displayName: finalDisplayName,
            provider: .apple,
            cloudKitUserRecordName: existingUser?.cloudKitUserRecordName
        )
        
        await MainActor.run {
            signIn(user: user)
        }

        // Resolve (or refresh) the CloudKit identity now that we're signed in. This is
        // best-effort: if CloudKit/iCloud isn't available the app still works, gated.
        await refreshCloudKitIdentity()
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

    // MARK: - CloudKit Identity

    /// Checks `CKContainer.accountStatus` and, when available, resolves and caches the stable
    /// CloudKit user record name on the current user. Degrades gracefully (logs + updates
    /// `cloudAccountStatus`) when CloudKit/iCloud isn't available so the app keeps running
    /// before the user finishes the Xcode capability setup.
    func refreshCloudKitIdentity() async {
        let container = CKContainer(identifier: Self.cloudKitContainerID)

        let status: CKAccountStatus
        do {
            status = try await container.accountStatus()
        } catch {
            Self.logger.error("CloudKit accountStatus failed: \(error.localizedDescription, privacy: .public)")
            await MainActor.run { self.cloudAccountStatus = .couldNotDetermine }
            return
        }

        await MainActor.run { self.cloudAccountStatus = status }

        guard status == .available else {
            Self.logger.notice("CloudKit account not available (status raw: \(status.rawValue, privacy: .public)) — iCloud required for couples identity")
            return
        }

        do {
            let recordID = try await container.userRecordID()
            let recordName = recordID.recordName
            await MainActor.run {
                self.resolvedCloudKitRecordName = recordName
                if var user = self.currentUser {
                    if user.cloudKitUserRecordName != recordName {
                        user.cloudKitUserRecordName = recordName
                        self.persist(user)
                    }
                }
            }
            Self.logger.info("Resolved CloudKit user record id")
        } catch {
            Self.logger.error("CloudKit fetchUserRecordID failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Apple Credential Revalidation

    /// Re-checks the Apple credential state on launch. If revoked/notFound, signs the user out
    /// and clears the cached identity. Only applies to Apple-provider users.
    func revalidateAppleCredentialState() async {
        guard let user = await MainActor.run(body: { self.currentUser }),
              user.provider == .apple else { return }

        let provider = ASAuthorizationAppleIDProvider()
        let state: ASAuthorizationAppleIDProvider.CredentialState = await withCheckedContinuation { continuation in
            provider.getCredentialState(forUserID: user.id) { state, _ in
                continuation.resume(returning: state)
            }
        }

        switch state {
        case .authorized:
            Self.logger.debug("Apple credential still authorized")
        case .revoked, .notFound:
            Self.logger.notice("Apple credential \(String(describing: state), privacy: .public) — signing out")
            await MainActor.run { self.signOut() }
        case .transferred:
            Self.logger.notice("Apple credential transferred")
        @unknown default:
            Self.logger.notice("Apple credential unknown state")
        }
    }

    // MARK: - Nonce / Hashing (Apple Sign In)

    private static func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            var randoms = [UInt8](repeating: 0, count: 16)
            let status = SecRandomCopyBytes(kSecRandomDefault, randoms.count, &randoms)
            if status != errSecSuccess {
                // Fallback to a non-crypto source rather than crashing; nonce is defense in depth.
                randoms = (0..<16).map { _ in UInt8.random(in: 0...255) }
            }
            for random in randoms where remainingLength > 0 {
                if Int(random) < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        return result
    }

    private static func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashed = SHA256.hash(data: inputData)
        return hashed.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Keychain

    private static func keychainSave(_ value: String, account: String) {
        guard let data = value.data(using: .utf8) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account
        ]
        // Replace any existing item.
        SecItemDelete(query as CFDictionary)
        var addQuery = query
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        if status != errSecSuccess {
            logger.error("Keychain save failed (status: \(status, privacy: .public))")
        }
    }

    private static func keychainRead(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func keychainDelete(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
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
        AuthManager.logger.error("Apple Sign In: No key window available")
        // Return a window created from a window scene found through context to
        // prevent a crash. The sign-in will fail gracefully and the delegate will
        // surface the error. Prefer the foreground-active scene.
        let windowScenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        if let windowScene = windowScenes.first(where: { $0.activationState == .foregroundActive }) ?? windowScenes.first {
            return UIWindow(windowScene: windowScene)
        }
        // Last resort: no window scene exists (should not happen during active sign-in).
        AuthManager.logger.error("Apple Sign In: No window scene available")
        preconditionFailure("Apple Sign In requires an active window scene")
    }
}

