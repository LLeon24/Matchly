//
//  BiometricAuthManager.swift
//  Matchly
//

import Foundation
import LocalAuthentication

enum BiometricAuthError: LocalizedError {
    case notAvailable
    case failed
    case canceled

    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "Biometric authentication isn't available on this device."
        case .failed:
            return "Authentication failed. Please try again."
        case .canceled:
            return "Authentication was canceled."
        }
    }
}

enum BiometricKind {
    case none
    case touchID
    case faceID
    case opticID

    var displayName: String {
        switch self {
        case .none:
            return "Biometrics"
        case .touchID:
            return "Touch ID"
        case .faceID:
            return "Face ID"
        case .opticID:
            return "Optic ID"
        }
    }

    var systemImageName: String {
        switch self {
        case .touchID:
            return "touchid"
        case .faceID, .opticID:
            return "faceid"
        case .none:
            return "lock.fill"
        }
    }
}

final class BiometricAuthManager {
    static let shared = BiometricAuthManager()

    private init() {}

    var kind: BiometricKind {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return .none
        }
        switch context.biometryType {
        case .touchID:
            return .touchID
        case .faceID:
            return .faceID
        case .opticID:
            return .opticID
        default:
            return .none
        }
    }

    var canAuthenticate: Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    func authenticate(reason: String) async throws -> Bool {
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"
        context.localizedFallbackTitle = "Use Passcode"

        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            throw BiometricAuthError.notAvailable
        }

        return try await withCheckedThrowingContinuation { continuation in
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, evaluateError in
                if success {
                    continuation.resume(returning: true)
                    return
                }

                if let laError = evaluateError as? LAError, laError.code == .userCancel {
                    continuation.resume(throwing: BiometricAuthError.canceled)
                    return
                }

                if let evaluateError {
                    continuation.resume(throwing: evaluateError)
                } else {
                    continuation.resume(throwing: BiometricAuthError.failed)
                }
            }
        }
    }
}
