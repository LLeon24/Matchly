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
import FirebaseAuth
import FirebaseCore
import GoogleSignIn
import UIKit

// MARK: - Authentication State
enum AuthState: Equatable {
    case signedOut
    case signedIn(User)
    case loading
}

// MARK: - User Model
struct User: Codable, Identifiable, Equatable {
    /// Firebase Auth UID for the signed-in account (Apple / Google / email).
    /// The Apple provider's stable `ASAuthorizationAppleIDCredential.user` string is stored
    /// separately in the Keychain (`storedAppleUserID`) for credential revalidation.
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
@MainActor
class AuthManager: ObservableObject {
    static let shared = AuthManager()

    /// Email / Google entry points are enabled alongside Apple Sign In.
    /// Couples Match still requires iCloud (CloudKit), independent of auth provider.
    static let allowsNonAppleProviders = true

    /// The CloudKit container backing the couples feature. Must match the container selected
    /// in Xcode's Signing & Capabilities ▸ iCloud (see COUPLES_MATCH_SETUP_STEPS.md).
    static let cloudKitContainerID = "iCloud.com.matchly.Matchly"

    /// Keychain identifiers for the persisted Apple login id.
    private static let keychainService = "com.matchly.auth"
    private static let keychainAppleUserAccount = "apple_user_id"
    private static let keychainAppleDisplayNameAccount = "apple_display_name"
    private static let keychainCachedUserAccount = "cached_user_session"
    private static let biometricEnabledKey = "matchly_biometric_login_enabled"
    private static let biometricOfferDeclinedKey = "matchly_biometric_offer_declined"

    @Published var authState: AuthState = .loading
    @Published var currentUser: User?
    @Published private(set) var isAppLocked = false
    @Published var isBiometricLoginEnabled: Bool = UserDefaults.standard.bool(forKey: biometricEnabledKey)
    @Published var shouldOfferBiometricSetup = false
    @Published var biometricUnlockError: String?
    @Published private(set) var shouldShowBiometricRetry = false

    private var isBiometricUnlockInFlight = false

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

    /// Whether Face ID / Touch ID can restore a previous session on the login screen.
    var canUseBiometricLogin: Bool {
        guard isBiometricLoginEnabled,
              BiometricAuthManager.shared.canAuthenticate,
              let cached = cachedUserForBiometricLogin() else { return false }
        if cached.provider == .apple {
            return storedAppleUserID != nil
        }
        return true
    }

    var biometricDisplayName: String {
        BiometricAuthManager.shared.kind.displayName
    }

    /// User-facing explanation when CloudKit isn't usable yet (mirrors CloudSyncManager style).
    var cloudUnavailableMessage: String? {
        switch cloudAccountStatus {
        case .available:
            return nil
        case .noAccount:
            return FeatureFlags.couplesMatchEnabled
                ? "iCloud is required for Couples Match. Sign in to iCloud in Settings, then reopen Matchly."
                : "Sign in to iCloud in Settings, then reopen Matchly."
        case .restricted:
            return FeatureFlags.couplesMatchEnabled
                ? "iCloud access is restricted on this device, so Couples Match is unavailable."
                : "iCloud access is restricted on this device."
        case .temporarilyUnavailable:
            return "iCloud is temporarily unavailable. Please try again in a moment."
        case .couldNotDetermine:
            return "Couldn't determine iCloud status. Make sure you're signed in to iCloud and the iCloud capability is enabled."
        @unknown default:
            return FeatureFlags.couplesMatchEnabled
                ? "iCloud is currently unavailable for Couples Match."
                : "iCloud is currently unavailable."
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

    /// Align local session with Firebase Auth after `FirebaseApp.configure()`.
    /// Never clears a valid local session on launch — that caused a flash of the login
    /// screen before Face ID / cached session restored the user.
    func syncWithFirebaseSession() {
        guard let firebaseUser = Auth.auth().currentUser else { return }
        let user = makeUser(from: firebaseUser, existing: currentUser)
        signIn(user: user)
        repairStoredDisplayNames()
    }
    
    // MARK: - Auth State Management
    func checkAuthState() {
        isBiometricLoginEnabled = UserDefaults.standard.bool(forKey: Self.biometricEnabledKey)

        // Check if user is already signed in. We do NOT wipe legacy stub users here; if a
        // previously "signed in" email/phone stub exists we keep them signed in and let the
        // next Apple sign-in map them onto a real Apple identity.
        if let userData = UserDefaults.standard.data(forKey: authKey),
           let user = try? JSONDecoder().decode(User.self, from: userData) {
            self.currentUser = user
            self.authState = .signedIn(user)
            if isBiometricLoginEnabled && BiometricAuthManager.shared.canAuthenticate {
                self.isAppLocked = true
            }
            repairStoredDisplayNames()
        } else {
            self.authState = .signedOut
            self.isAppLocked = false
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

        updatedUser.displayName = Self.sanitizedDisplayName(
            updatedUser.displayName,
            email: updatedUser.email
        )
        
        if let encoded = try? JSONEncoder().encode(updatedUser) {
            UserDefaults.standard.set(encoded, forKey: authKey)
            self.currentUser = updatedUser
            Self.logger.info("Saved user to UserDefaults: displayName=\(updatedUser.displayName ?? "nil", privacy: .public)")
        }

        if isBiometricLoginEnabled {
            cacheUserForBiometricLogin(updatedUser)
        } else if BiometricAuthManager.shared.canAuthenticate,
                  !UserDefaults.standard.bool(forKey: Self.biometricOfferDeclinedKey) {
            shouldOfferBiometricSetup = true
        }

        Task {
            _ = await DataManager.shared.mergeWithAccountCloudIfNeeded(trigger: "signIn")
            let profileName = DataManager.shared.preferences.profile.name
            if let resolvedName = resolvedAuthDisplayName(
                stored: updatedUser.displayName,
                profileName: profileName,
                email: updatedUser.email
            ) {
                DataManager.shared.applyAuthDisplayNameToProfileIfNeeded(resolvedName)
            }
            DataManager.shared.clearEmailDerivedProfileNameIfNeeded(email: updatedUser.email)
        }
    }

    func enableBiometricLogin() {
        isBiometricLoginEnabled = true
        UserDefaults.standard.set(true, forKey: Self.biometricEnabledKey)
        if let user = currentUser {
            cacheUserForBiometricLogin(user)
        }
        shouldOfferBiometricSetup = false
    }

    func disableBiometricLogin() {
        isBiometricLoginEnabled = false
        UserDefaults.standard.set(false, forKey: Self.biometricEnabledKey)
        Self.keychainDelete(account: Self.keychainCachedUserAccount)
        isAppLocked = false
    }

    func declineBiometricSetup() {
        UserDefaults.standard.set(true, forKey: Self.biometricOfferDeclinedKey)
        shouldOfferBiometricSetup = false
    }

    func lockAppIfNeeded() {
        guard isBiometricLoginEnabled,
              BiometricAuthManager.shared.canAuthenticate,
              case .signedIn = authState else { return }
        isAppLocked = true
    }

    func attemptAutomaticBiometricUnlock() {
        guard isAppLocked else { return }
        guard !isBiometricUnlockInFlight else { return }
        guard isBiometricLoginEnabled, BiometricAuthManager.shared.canAuthenticate else { return }

        isBiometricUnlockInFlight = true
        biometricUnlockError = nil
        shouldShowBiometricRetry = false

        Task { @MainActor in
            defer { isBiometricUnlockInFlight = false }
            // Let splash / transition animations finish so Face ID can present.
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard isAppLocked else { return }

            do {
                try await unlockWithBiometrics()
            } catch BiometricAuthError.canceled {
                biometricUnlockError = nil
                shouldShowBiometricRetry = true
            } catch {
                biometricUnlockError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                shouldShowBiometricRetry = true
            }
        }
    }

    func unlockWithBiometrics() async throws {
        guard isAppLocked else { return }
        let success = try await BiometricAuthManager.shared.authenticate(
            reason: "Unlock Matchly",
            policy: .biometricsOnly
        )
        guard success else { throw BiometricAuthError.failed }
        isAppLocked = false
        biometricUnlockError = nil
    }

    func signInWithBiometrics() async throws {
        guard canUseBiometricLogin else { throw BiometricAuthError.notAvailable }
        guard let cachedUser = cachedUserForBiometricLogin() else { throw AuthError.userNotFound }

        let success = try await BiometricAuthManager.shared.authenticate(
            reason: "Sign in to Matchly",
            policy: .biometricsOnly
        )
        guard success else { throw BiometricAuthError.failed }

        // Only Apple-provider sessions need Apple credential revalidation.
        if cachedUser.provider == .apple {
            guard let appleUserID = storedAppleUserID else { throw AuthError.invalidCredentials }
            let provider = ASAuthorizationAppleIDProvider()
            let state: ASAuthorizationAppleIDProvider.CredentialState = await withCheckedContinuation { continuation in
                provider.getCredentialState(forUserID: appleUserID) { state, _ in
                    continuation.resume(returning: state)
                }
            }

            switch state {
            case .authorized:
                break
            case .revoked, .notFound:
                await MainActor.run {
                    disableBiometricLogin()
                    Self.keychainDelete(account: Self.keychainAppleUserAccount)
                }
                throw AuthError.invalidCredentials
            case .transferred:
                throw AuthError.invalidCredentials
            @unknown default:
                throw AuthError.invalidCredentials
            }
        }

        await MainActor.run {
            signIn(user: cachedUser)
        }
        await refreshCloudKitIdentity()
    }
    
    func signOut() {
        do {
            try Auth.auth().signOut()
        } catch {
            Self.logger.error("Firebase signOut failed: \(error.localizedDescription, privacy: .public)")
        }
        GIDSignIn.sharedInstance.signOut()

        self.currentUser = nil
        self.resolvedCloudKitRecordName = nil
        self.authState = .signedOut
        self.cloudAccountStatus = .couldNotDetermine
        self.currentAppleNonce = nil
        self.isAppLocked = false
        self.isBiometricUnlockInFlight = false
        self.shouldShowBiometricRetry = false
        self.biometricUnlockError = nil
        UserDefaults.standard.removeObject(forKey: authKey)

        if !isBiometricLoginEnabled {
            Self.keychainDelete(account: Self.keychainAppleUserAccount)
            Self.keychainDelete(account: Self.keychainAppleDisplayNameAccount)
            Self.keychainDelete(account: Self.keychainCachedUserAccount)
        }
    }

    /// Best available name for UI: profile name, auth display name, cached Apple name — never the email prefix.
    func preferredDisplayName(profileName: String = "") -> String {
        let trimmedProfile = profileName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedProfile.isEmpty,
           !Self.isEmailDerivedDisplayName(trimmedProfile, email: currentUser?.email) {
            return trimmedProfile
        }

        if let displayName = currentUser?.displayName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !displayName.isEmpty,
           !Self.isEmailDerivedDisplayName(displayName, email: currentUser?.email) {
            return displayName
        }

        if let cachedAppleName = Self.keychainRead(account: Self.keychainAppleDisplayNameAccount)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !cachedAppleName.isEmpty {
            return cachedAppleName
        }

        if let firebaseName = Auth.auth().currentUser?.displayName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !firebaseName.isEmpty,
           !Self.isEmailDerivedDisplayName(firebaseName, email: currentUser?.email) {
            return firebaseName
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
    func signUpWithEmail(email: String, password: String, displayName: String?) async throws {
        guard Self.allowsNonAppleProviders else { throw AuthError.notImplemented }
        let normalizedEmail = Self.normalizedEmail(email)
        do {
            let result = try await Auth.auth().createUser(withEmail: normalizedEmail, password: password)
            if let displayName, !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let changeRequest = result.user.createProfileChangeRequest()
                changeRequest.displayName = displayName
                try await changeRequest.commitChanges()
            }
            let user = makeUser(from: result.user, provider: .email, displayName: displayName, existing: currentUser)
            await MainActor.run { signIn(user: user) }
            await refreshCloudKitIdentity()
        } catch {
            throw mapFirebaseAuthError(error)
        }
    }

    func signInWithEmail(email: String, password: String) async throws {
        guard Self.allowsNonAppleProviders else { throw AuthError.notImplemented }
        let normalizedEmail = Self.normalizedEmail(email)
        do {
            let result = try await Auth.auth().signIn(withEmail: normalizedEmail, password: password)
            let user = makeUser(from: result.user, provider: .email, existing: currentUser)
            await MainActor.run { signIn(user: user) }
            await refreshCloudKitIdentity()
        } catch {
            throw mapFirebaseAuthError(error)
        }
    }

    // MARK: - Phone Number Authentication
    func signInWithPhone(phoneNumber: String) async throws {
        guard Self.allowsNonAppleProviders else { throw AuthError.notImplemented }
        throw AuthError.notImplemented
    }

    func verifyPhoneCode(code: String) async throws {
        throw AuthError.notImplemented
    }

    // MARK: - Social Authentication
    func signInWithGoogle() async throws {
        guard Self.allowsNonAppleProviders else { throw AuthError.notImplemented }

        guard let clientID = FirebaseApp.app()?.options.clientID else {
            throw AuthError.networkError
        }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)

        guard let presenting = Self.topViewController() else {
            throw AuthError.networkError
        }

        do {
            let gidResult = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenting)
            guard let idToken = gidResult.user.idToken?.tokenString else {
                throw AuthError.invalidCredentials
            }
            let accessToken = gidResult.user.accessToken.tokenString
            let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)
            let authResult = try await Auth.auth().signIn(with: credential)
            let googleName = gidResult.user.profile?.name
            let user = makeUser(from: authResult.user, provider: .google, displayName: googleName, existing: currentUser)
            await MainActor.run { signIn(user: user) }
            await refreshCloudKitIdentity()
        } catch let error as AuthError {
            throw error
        } catch {
            let nsError = error as NSError
            if nsError.domain == "com.google.GIDSignIn", nsError.code == GIDSignInError.canceled.rawValue {
                throw AuthError.canceled
            }
            throw mapFirebaseAuthError(error)
        }
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

        let result = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<ASAuthorization, Error>) in
            let delegate = AppleSignInDelegate(continuation: continuation)
            authorizationController.delegate = delegate
            authorizationController.presentationContextProvider = delegate
            delegate.retainController = authorizationController
            delegate.retainSelf = delegate
            authorizationController.performRequests()
        }

        guard let appleIDCredential = result.credential as? ASAuthorizationAppleIDCredential else {
            Self.logger.error("Apple Sign In: Failed to get Apple ID credential")
            throw AuthError.networkError
        }

        guard let identityTokenData = appleIDCredential.identityToken,
              let idTokenString = String(data: identityTokenData, encoding: .utf8),
              !idTokenString.isEmpty else {
            Self.logger.error("Apple Sign In: Missing identity token")
            currentAppleNonce = nil
            throw AuthError.invalidCredentials
        }

        let nonce = currentAppleNonce
        currentAppleNonce = nil
        guard let nonce else {
            Self.logger.error("Apple Sign In: nonce missing for Firebase exchange")
            throw AuthError.invalidCredentials
        }

        // Persist the stable Apple login id (not the Firebase UID) for biometric / credential checks.
        Self.keychainSave(appleIDCredential.user, account: Self.keychainAppleUserAccount)

        let existingUser: User? = {
            if let userData = UserDefaults.standard.data(forKey: authKey),
               let user = try? JSONDecoder().decode(User.self, from: userData) {
                return user
            }
            return currentUser
        }()

        var displayName: String? = existingUser?.displayName
        if let appleName = Self.formattedDisplayName(from: appleIDCredential.fullName) {
            displayName = appleName
            Self.keychainSave(appleName, account: Self.keychainAppleDisplayNameAccount)
        } else if displayName == nil || displayName?.isEmpty == true {
            displayName = Self.keychainRead(account: Self.keychainAppleDisplayNameAccount)
        }

        do {
            let credential = OAuthProvider.appleCredential(
                withIDToken: idTokenString,
                rawNonce: nonce,
                fullName: appleIDCredential.fullName
            )
            let authResult = try await Auth.auth().signIn(with: credential)
            try? await authResult.user.reload()

            var finalDisplayName = Self.firstNonEmpty([
                displayName,
                authResult.user.displayName,
                existingUser?.displayName,
                Self.keychainRead(account: Self.keychainAppleDisplayNameAccount)
            ])
            finalDisplayName = Self.sanitizedDisplayName(finalDisplayName, email: appleIDCredential.email ?? authResult.user.email ?? existingUser?.email)

            if let finalDisplayName,
               authResult.user.displayName == nil || authResult.user.displayName?.isEmpty == true {
                let changeRequest = authResult.user.createProfileChangeRequest()
                changeRequest.displayName = finalDisplayName
                try? await changeRequest.commitChanges()
            }

            let user = makeUser(
                from: authResult.user,
                provider: .apple,
                displayName: finalDisplayName,
                existing: existingUser
            )

            Self.logger.info("Apple Sign In: Firebase UID authenticated")
            await MainActor.run { signIn(user: user) }
            await refreshCloudKitIdentity()
        } catch {
            throw mapFirebaseAuthError(error)
        }
    }

    func signInWithFacebook() async throws {
        throw AuthError.notImplemented
    }

    func signInWithReddit() async throws {
        throw AuthError.notImplemented
    }

    // MARK: - Password Reset
    func resetPassword(email: String) async throws {
        let normalizedEmail = Self.normalizedEmail(email)
        guard !normalizedEmail.isEmpty else { throw AuthError.invalidCredentials }
        do {
            try await Auth.auth().sendPasswordReset(withEmail: normalizedEmail)
        } catch {
            throw mapFirebaseAuthError(error)
        }
    }

    /// Whether the signed-in Firebase user already has Email/Password linked.
    var hasPasswordProvider: Bool {
        Auth.auth().currentUser?.providerData.contains(where: { $0.providerID == "password" }) == true
    }

    /// Show Add Email & Password for any signed-in account that doesn't already have a password.
    /// (Apple / Google users; also covers Email users who somehow lack a password provider.)
    var canLinkEmailPassword: Bool {
        guard currentUser != nil else { return false }
        return !hasPasswordProvider
    }

    /// Link Email/Password to the currently signed-in account (same Firebase UID).
    func linkEmailPassword(email: String, password: String) async throws {
        guard let firebaseUser = Auth.auth().currentUser else {
            throw AuthError.notImplemented
        }
        let normalizedEmail = Self.normalizedEmail(email)
        guard !normalizedEmail.isEmpty else { throw AuthError.invalidCredentials }
        guard password.count >= 6 else { throw AuthError.weakPassword }

        do {
            let credential = EmailAuthProvider.credential(withEmail: normalizedEmail, password: password)
            let result = try await firebaseUser.link(with: credential)
            let linked = makeUser(
                from: result.user,
                provider: currentUser?.provider,
                displayName: currentUser?.displayName,
                existing: currentUser
            )
            await MainActor.run { signIn(user: linked) }
        } catch {
            throw mapFirebaseAuthError(error)
        }
    }

    private static func normalizedEmail(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    // MARK: - Firebase Helpers

    private func makeUser(
        from firebaseUser: FirebaseAuth.User,
        provider: User.AuthProvider? = nil,
        displayName: String? = nil,
        existing: User?
    ) -> User {
        let resolvedProvider = provider ?? Self.provider(for: firebaseUser) ?? existing?.provider ?? .email
        let email = firebaseUser.email ?? existing?.email
        let resolvedName = Self.sanitizedDisplayName(
            Self.firstNonEmpty([
                displayName,
                firebaseUser.displayName,
                existing?.displayName,
                Self.keychainRead(account: Self.keychainAppleDisplayNameAccount)
            ]),
            email: email
        )
        return User(
            id: firebaseUser.uid,
            email: email,
            phoneNumber: firebaseUser.phoneNumber ?? existing?.phoneNumber,
            displayName: resolvedName,
            photoURL: firebaseUser.photoURL?.absoluteString ?? existing?.photoURL,
            provider: resolvedProvider,
            cloudKitUserRecordName: existing?.cloudKitUserRecordName,
            createdAt: existing?.createdAt ?? (firebaseUser.metadata.creationDate ?? Date()),
            lastLoginAt: Date()
        )
    }

    private static func provider(for firebaseUser: FirebaseAuth.User) -> User.AuthProvider? {
        let ids = firebaseUser.providerData.map(\.providerID)
        if ids.contains("apple.com") { return .apple }
        if ids.contains("google.com") { return .google }
        if ids.contains("password") { return .email }
        if ids.contains("phone") { return .phone }
        return nil
    }

    private func mapFirebaseAuthError(_ error: Error) -> AuthError {
        let nsError = error as NSError
        // Firebase Auth error codes (FIRAuthErrorCode).
        switch nsError.code {
        case 17011: // userNotFound
            return .userNotFound
        case 17009, 17004, 17008, 17094: // wrongPassword / invalidCredential / invalidEmail
            return .invalidCredentials
        case 17007, 17025, 17015: // emailAlreadyInUse / credentialAlreadyInUse
            return .emailAlreadyInUse
        case 17026: // weakPassword
            return .weakPassword
        case 17014: // requiresRecentLogin
            return .requiresRecentLogin
        case 17020: // networkError
            return .networkError
        default:
            return .networkError
        }
    }

    private static func topViewController(base: UIViewController? = nil) -> UIViewController? {
        let resolvedBase = base ?? activeRootViewController()
        if let nav = resolvedBase as? UINavigationController {
            return topViewController(base: nav.visibleViewController)
        }
        if let tab = resolvedBase as? UITabBarController {
            return topViewController(base: tab.selectedViewController)
        }
        if let presented = resolvedBase?.presentedViewController {
            return topViewController(base: presented)
        }
        return resolvedBase
    }

    private static func activeRootViewController() -> UIViewController? {
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            if let keyWindow = windowScene.windows.first(where: { $0.isKeyWindow }) {
                return keyWindow.rootViewController
            }
            if let window = windowScene.windows.first {
                return window.rootViewController
            }
        }
        return nil
    }

    static func presentationAnchorForAppleSignIn() -> ASPresentationAnchor {
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            if let keyWindow = windowScene.windows.first(where: { $0.isKeyWindow }) {
                return keyWindow
            }
            if let window = windowScene.windows.first {
                return window
            }
        }

        Self.logger.error("Apple Sign In: No key window available")
        let windowScenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        if let windowScene = windowScenes.first(where: { $0.activationState == .foregroundActive }) ?? windowScenes.first {
            return UIWindow(windowScene: windowScene)
        }

        Self.logger.error("Apple Sign In: No window scene available")
        preconditionFailure("Apple Sign In requires an active window scene")
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

        guard let appleUserID = await MainActor.run(body: { self.storedAppleUserID }) else {
            Self.logger.notice("Apple credential: missing stored Apple user id — signing out")
            await MainActor.run { self.signOut() }
            return
        }

        let provider = ASAuthorizationAppleIDProvider()
        let state: ASAuthorizationAppleIDProvider.CredentialState = await withCheckedContinuation { continuation in
            provider.getCredentialState(forUserID: appleUserID) { state, _ in
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

    // MARK: - Display Name Helpers

    static func formattedDisplayName(from components: PersonNameComponents?) -> String? {
        guard let components else { return nil }
        let formatter = PersonNameComponentsFormatter()
        formatter.style = .default
        let formatted = formatter.string(from: components)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return formatted.isEmpty ? nil : formatted
    }

    static func isEmailDerivedDisplayName(_ name: String, email: String?) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let email else { return false }
        let localPart = email.components(separatedBy: "@").first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !localPart.isEmpty else { return false }
        return trimmed.caseInsensitiveCompare(localPart) == .orderedSame
            || trimmed.caseInsensitiveCompare(localPart.capitalized) == .orderedSame
    }

    static func sanitizedDisplayName(_ name: String?, email: String?) -> String? {
        guard let name = name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else {
            return nil
        }
        if isEmailDerivedDisplayName(name, email: email) {
            return nil
        }
        return name
    }

    private static func firstNonEmpty(_ values: [String?]) -> String? {
        for value in values {
            let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !trimmed.isEmpty {
                return trimmed
            }
        }
        return nil
    }

    private func resolvedAuthDisplayName(stored: String?, profileName: String, email: String?) -> String? {
        Self.sanitizedDisplayName(
            Self.firstNonEmpty([
                stored,
                profileName,
                Self.keychainRead(account: Self.keychainAppleDisplayNameAccount),
                Auth.auth().currentUser?.displayName
            ]),
            email: email
        )
    }

    @MainActor
    private func repairStoredDisplayNames() {
        guard var user = currentUser else { return }

        let repaired = Self.sanitizedDisplayName(
            Self.firstNonEmpty([
                user.displayName,
                Auth.auth().currentUser?.displayName,
                Self.keychainRead(account: Self.keychainAppleDisplayNameAccount),
                DataManager.shared.preferences.profile.name
            ]),
            email: user.email
        )

        if user.displayName != repaired {
            user.displayName = repaired
            persist(user)
            if isBiometricLoginEnabled {
                cacheUserForBiometricLogin(user)
            }
        }

        DataManager.shared.clearEmailDerivedProfileNameIfNeeded(email: user.email)

        if let repaired, !repaired.isEmpty {
            DataManager.shared.applyAuthDisplayNameToProfileIfNeeded(repaired)
        }
    }

    // MARK: - Keychain

    private func cacheUserForBiometricLogin(_ user: User) {
        guard let data = try? JSONEncoder().encode(user) else { return }
        Self.keychainSaveData(data, account: Self.keychainCachedUserAccount)
    }

    private func cachedUserForBiometricLogin() -> User? {
        guard let data = Self.keychainReadData(account: Self.keychainCachedUserAccount) else { return nil }
        return try? JSONDecoder().decode(User.self, from: data)
    }

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

    private static func keychainSaveData(_ data: Data, account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
        var addQuery = query
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        if status != errSecSuccess {
            logger.error("Keychain data save failed (status: \(status, privacy: .public))")
        }
    }

    private static func keychainReadData(account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess else { return nil }
        return item as? Data
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
    case canceled
    case requiresRecentLogin

    var errorDescription: String? {
        switch self {
        case .userNotFound:
            return "No account found with this email address."
        case .invalidCredentials:
            return "Invalid email or password."
        case .emailAlreadyInUse:
            return "An account with this email already exists. Sign in, use Forgot Password, or try Google/Apple if you used those before."
        case .weakPassword:
            return "Password must be at least 6 characters."
        case .networkError:
            return "Network error. Please check your connection."
        case .notImplemented:
            return "This feature is not yet implemented."
        case .canceled:
            return nil
        case .requiresRecentLogin:
            return "For security, sign out and sign back in, then try adding email login again."
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
    
    nonisolated func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        // ASAuthorizationController calls this on the main thread.
        MainActor.assumeIsolated {
            AuthManager.presentationAnchorForAppleSignIn()
        }
    }
}

