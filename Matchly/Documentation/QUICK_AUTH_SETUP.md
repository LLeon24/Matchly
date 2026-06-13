# Quick Authentication Setup Guide

## Current Status

- ✅ **Email/Password**: Working (local implementation)
- ✅ **Phone**: Working (local implementation)
- ⚠️ **Apple Sign In**: Code implemented, needs configuration
- ❌ **Google**: Not implemented (needs Firebase + SDK)
- ❌ **Facebook**: Not implemented (needs Firebase + SDK)
- ❌ **Reddit**: Not implemented (needs custom OAuth)

## Quick Fix: Enable Apple Sign In

Apple Sign In is already implemented in code but needs to be configured:

### Step 1: Enable Capability in Xcode

1. Open your project in Xcode
2. Select your project in the navigator
3. Select your app target
4. Go to **Signing & Capabilities** tab
5. Click **+ Capability**
6. Add **Sign in with Apple**

### Step 2: Configure in Apple Developer

1. Go to [Apple Developer Portal](https://developer.apple.com/account/)
2. Navigate to **Certificates, Identifiers & Profiles**
3. Select your App ID
4. Enable **Sign in with Apple** capability
5. Save and regenerate provisioning profiles if needed

### Step 3: Test

After enabling the capability, Apple Sign In should work on:
- Real iOS devices (with Apple ID signed in)
- Simulator (iOS 13+ with Apple ID signed in)

## Full Setup: Enable All Social Logins

To enable Google, Facebook, and Reddit, you need to set up Firebase Authentication:

### Option 1: Full Firebase Setup (Recommended for Production)

See `AUTHENTICATION_SETUP.md` for complete instructions.

**Quick Steps:**
1. Install Firebase SDK via Swift Package Manager
2. Create Firebase project and add iOS app
3. Download `GoogleService-Info.plist`
4. Enable providers in Firebase Console
5. Update `AuthManager.swift` with Firebase implementations

### Option 2: Test Mode (For Development)

If you want to test the UI without full Firebase setup, you can temporarily modify `AuthManager.swift` to create mock users:

```swift
func signInWithGoogle() async throws {
    // Temporary test implementation
    let user = User(
        id: UUID().uuidString,
        email: "test@gmail.com",
        displayName: "Test Google User",
        provider: .google
    )
    await MainActor.run {
        signIn(user: user)
    }
}
```

**Note:** This is for testing only. For production, use proper Firebase implementation.

## Troubleshooting

### Apple Sign In Not Working

1. **Check capability**: Ensure "Sign in with Apple" is enabled in Xcode
2. **Check device**: Must be on real device or simulator with Apple ID
3. **Check entitlements**: Verify `.entitlements` file includes `com.apple.developer.applesignin`
4. **Check bundle ID**: Must match your Apple Developer App ID

### Error Messages

The app now shows helpful error messages when social logins aren't configured. These will guide you to the setup steps needed.

## Next Steps

1. **For Apple**: Enable the capability (5 minutes)
2. **For others**: Choose between Firebase setup (30+ minutes) or test mode (5 minutes)


