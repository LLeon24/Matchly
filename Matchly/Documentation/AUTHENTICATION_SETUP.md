# Authentication Setup Guide

This guide explains how to set up authentication for Matchly with multiple sign-in providers.

## Overview

Matchly supports the following authentication methods:
- **Email/Password** - Traditional email and password authentication
- **Phone Number** - SMS-based verification
- **Apple ID** - Sign in with Apple
- **Google** - Google Sign-In
- **Facebook** - Facebook Login
- **Reddit** - Reddit OAuth (custom implementation)

## Current Implementation

The authentication system is currently set up with a local implementation that stores user data in UserDefaults. To enable full functionality with social providers, you'll need to integrate Firebase Authentication.

## Firebase Authentication Setup

### 1. Install Firebase SDK

Add Firebase to your project using Swift Package Manager:

1. In Xcode, go to **File > Add Packages...**
2. Enter: `https://github.com/firebase/firebase-ios-sdk`
3. Select **FirebaseAuth** and **FirebaseCore**

### 2. Configure Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Create a new project or select an existing one
3. Add an iOS app to your project
4. Download `GoogleService-Info.plist`
5. Add `GoogleService-Info.plist` to your Xcode project

### 3. Initialize Firebase

Update `MatchlyApp.swift`:

```swift
import SwiftUI
import FirebaseCore

@main
struct MatchlyApp: App {
    init() {
        FirebaseApp.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            SplashView()
        }
    }
}
```

### 4. Enable Authentication Providers

In Firebase Console:
1. Go to **Authentication > Sign-in method**
2. Enable the following providers:
   - **Email/Password**
   - **Phone**
   - **Google** (requires OAuth client IDs)
   - **Apple** (requires Apple Developer setup)
   - **Facebook** (requires Facebook App ID)

### 5. Update AuthManager

Replace the placeholder methods in `AuthManager.swift` with Firebase Auth implementations:

#### Email/Password

```swift
import FirebaseAuth

func signUpWithEmail(email: String, password: String, displayName: String?) async throws {
    let result = try await Auth.auth().createUser(withEmail: email, password: password)
    
    // Update display name
    if let displayName = displayName {
        let changeRequest = result.user.createProfileChangeRequest()
        changeRequest.displayName = displayName
        try await changeRequest.commitChanges()
    }
    
    let user = User(
        id: result.user.uid,
        email: result.user.email,
        displayName: result.user.displayName,
        provider: .email
    )
    
    await MainActor.run {
        signIn(user: user)
    }
}

func signInWithEmail(email: String, password: String) async throws {
    let result = try await Auth.auth().signIn(withEmail: email, password: password)
    
    let user = User(
        id: result.user.uid,
        email: result.user.email,
        displayName: result.user.displayName,
        provider: .email
    )
    
    await MainActor.run {
        signIn(user: user)
    }
}
```

#### Phone Authentication

```swift
func signInWithPhone(phoneNumber: String) async throws {
    PhoneAuthProvider.provider().verifyPhoneNumber(phoneNumber, uiDelegate: nil) { verificationID, error in
        if let error = error {
            // Handle error
            return
        }
        // Store verificationID for later use
        UserDefaults.standard.set(verificationID, forKey: "authVerificationID")
    }
}

func verifyPhoneCode(code: String) async throws {
    guard let verificationID = UserDefaults.standard.string(forKey: "authVerificationID") else {
        throw AuthError.networkError
    }
    
    let credential = PhoneAuthProvider.provider().credential(
        withVerificationID: verificationID,
        verificationCode: code
    )
    
    let result = try await Auth.auth().signIn(with: credential)
    
    let user = User(
        id: result.user.uid,
        phoneNumber: result.user.phoneNumber,
        provider: .phone
    )
    
    await MainActor.run {
        signIn(user: user)
    }
}
```

#### Google Sign-In

1. Install Google Sign-In SDK:
   - Add package: `https://github.com/google/GoogleSignIn-iOS`

2. Update `AuthManager.swift`:

```swift
import GoogleSignIn

func signInWithGoogle() async throws {
    guard let clientID = FirebaseApp.app()?.options.clientID else {
        throw AuthError.networkError
    }
    
    let config = GIDConfiguration(clientID: clientID)
    GIDSignIn.sharedInstance.configuration = config
    
    guard let windowScene = await UIApplication.shared.connectedScenes.first as? UIWindowScene,
          let window = await windowScene.windows.first,
          let rootViewController = await window.rootViewController else {
        throw AuthError.networkError
    }
    
    let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
    
    guard let idToken = result.user.idToken?.tokenString else {
        throw AuthError.networkError
    }
    
    let credential = GoogleAuthProvider.credential(withIDToken: idToken,
                                                   accessToken: result.user.accessToken.tokenString)
    
    let authResult = try await Auth.auth().signIn(with: credential)
    
    let user = User(
        id: authResult.user.uid,
        email: authResult.user.email,
        displayName: authResult.user.displayName,
        photoURL: authResult.user.photoURL?.absoluteString,
        provider: .google
    )
    
    await MainActor.run {
        signIn(user: user)
    }
}
```

#### Sign in with Apple

1. Add Sign in with Apple capability in Xcode
2. Update `AuthManager.swift`:

```swift
import AuthenticationServices

func signInWithApple() async throws {
    let appleIDProvider = ASAuthorizationAppleIDProvider()
    let request = appleIDProvider.createRequest()
    request.requestedScopes = [.fullName, .email]
    
    let authorizationController = ASAuthorizationController(authorizationRequests: [request])
    
    // Handle authorization in a continuation
    let result = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<ASAuthorization, Error>) in
        authorizationController.delegate = AuthDelegate(continuation: continuation)
        authorizationController.presentationContextProvider = AuthPresentationContextProvider()
        authorizationController.performRequests()
    }
    
    guard let appleIDCredential = result.credential as? ASAuthorizationAppleIDCredential,
          let identityToken = appleIDCredential.identityToken,
          let idTokenString = String(data: identityToken, encoding: .utf8) else {
        throw AuthError.networkError
    }
    
    let credential = OAuthProvider.credential(withProviderID: "apple.com",
                                              idToken: idTokenString,
                                              rawNonce: nil)
    
    let authResult = try await Auth.auth().signIn(with: credential)
    
    let user = User(
        id: authResult.user.uid,
        email: authResult.user.email,
        displayName: authResult.user.displayName ?? appleIDCredential.fullName?.formatted(),
        provider: .apple
    )
    
    await MainActor.run {
        signIn(user: user)
    }
}
```

#### Facebook Login

1. Install Facebook SDK:
   - Add package: `https://github.com/facebook/facebook-ios-sdk`

2. Update `AuthManager.swift`:

```swift
import FacebookLogin

func signInWithFacebook() async throws {
    let loginManager = LoginManager()
    
    let result = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<LoginResult, Error>) in
        loginManager.logIn(permissions: ["email", "public_profile"], from: nil) { result, error in
            if let error = error {
                continuation.resume(throwing: error)
            } else if let result = result {
                continuation.resume(returning: result)
            }
        }
    }
    
    guard let token = result.token?.tokenString else {
        throw AuthError.networkError
    }
    
    let credential = FacebookAuthProvider.credential(withAccessToken: token)
    let authResult = try await Auth.auth().signIn(with: credential)
    
    let user = User(
        id: authResult.user.uid,
        email: authResult.user.email,
        displayName: authResult.user.displayName,
        photoURL: authResult.user.photoURL?.absoluteString,
        provider: .facebook
    )
    
    await MainActor.run {
        signIn(user: user)
    }
}
```

#### Reddit OAuth

Reddit doesn't have an official SDK. You'll need to implement a custom OAuth 2.0 flow:

1. Register your app at [Reddit Apps](https://www.reddit.com/prefs/apps)
2. Implement OAuth 2.0 authorization code flow
3. Use the access token with Firebase Custom Auth (if needed)

## Testing

After implementing Firebase Auth:

1. Test each authentication method
2. Verify user data is saved correctly
3. Test sign-out functionality
4. Test authentication persistence (app restart)

## Security Notes

- Never commit `GoogleService-Info.plist` to version control
- Store sensitive API keys securely
- Use Firebase Security Rules to protect user data
- Implement proper error handling for all auth methods

## Next Steps

1. Complete Firebase setup
2. Implement each authentication provider
3. Test thoroughly
4. Add error handling and user feedback
5. Consider adding biometric authentication (Face ID/Touch ID) for returning users


