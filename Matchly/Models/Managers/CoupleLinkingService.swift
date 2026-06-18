//
//  CoupleLinkingService.swift
//  Matchly
//
//  Registers couple invite codes in CloudKit's public database so a partner on
//  another device can look up and claim the code. Full CKShare sync is still
//  planned; this unblocks real two-device linking for couple status.
//

import CloudKit
import Foundation
import OSLog

struct CoupleCodeRegistration {
    let code: String
    let coupleID: String
    let inviterRecordName: String
    let inviterName: String
    let inviterEmail: String?
    let partnerRecordName: String?
    let partnerName: String?
    let partnerEmail: String?
    let isClaimed: Bool
}

enum CoupleLinkingService {
    private static let recordType = "CoupleCodeInvite"
    private static let logger = Logger(subsystem: "com.matchly", category: "CoupleLinking")
    private static let container = CKContainer(identifier: AuthManager.cloudKitContainerID)
    private static let timestampFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static func recordID(for code: String) -> CKRecord.ID {
        CKRecord.ID(recordName: code.uppercased())
    }

    private static func timestampString(from date: Date = Date()) -> String {
        timestampFormatter.string(from: date)
    }

    private static func setString(_ value: String, forKey key: String, on record: CKRecord) {
        record[key] = value as CKRecordValue
    }

    static func registerPendingCouple(
        couple: Couple,
        inviterRecordName: String,
        inviterName: String,
        inviterEmail: String?
    ) async throws {
        let code = couple.coupleCode.uppercased()

        // Required before writing to the public database.
        _ = try await container.userRecordID()

        if let existing = try? await fetchRegistration(for: code) {
            if existing.isClaimed {
                throw CoupleLinkingError.codeAlreadyClaimed
            }
            if existing.inviterRecordName != inviterRecordName {
                throw CoupleLinkingError.codeAlreadyClaimed
            }
        }

        // Replace any stale/partial record so schema changes can take effect.
        await deleteRegistration(for: code)

        let record = CKRecord(recordType: recordType, recordID: recordID(for: code))
        setString(code, forKey: "code", on: record)
        setString(couple.id, forKey: "coupleID", on: record)
        setString(inviterRecordName, forKey: "inviterRecordName", on: record)
        setString(inviterName, forKey: "inviterName", on: record)
        if let inviterEmail, !inviterEmail.isEmpty {
            setString(inviterEmail, forKey: "inviterEmail", on: record)
        }
        setString("pending", forKey: "status", on: record)
        setString(timestampString(), forKey: "createdAt", on: record)

        do {
            _ = try await save(record)
        } catch {
            throw mapError(error)
        }

        logger.info("Registered couple code \(code, privacy: .public)")
    }

    /// Maps CloudKit and other infrastructure errors into user-facing linking errors.
    static func mapError(_ error: Error) -> CoupleLinkingError {
        if let linking = error as? CoupleLinkingError { return linking }

        if let ckError = error as? CKError {
            if ckError.code == .partialFailure,
               let partial = ckError.partialErrorsByItemID?.values.first {
                return mapError(partial)
            }

            switch ckError.code {
            case .notAuthenticated:
                return .iCloudRequired
            case .permissionFailure:
                return .cloudKitPermissionDenied
            case .invalidArguments, .serverRejectedRequest:
                let detail = ckError.userInfo[NSLocalizedDescriptionKey] as? String ?? ckError.localizedDescription
                return .cloudKitFailed(
                    "CloudKit schema error (12): \(detail). In Dashboard → CoupleCodeInvite, every custom field must be String (including createdAt). Save schema, rebuild the app, Generate New Code, then Retry."
                )
            case .networkUnavailable, .networkFailure, .serviceUnavailable, .requestRateLimited, .zoneBusy:
                return .cloudKitFailed("Network or iCloud service issue. Check your connection and try again.")
            case .managedAccountRestricted:
                return .cloudKitFailed("This iCloud account is restricted from using CloudKit.")
            case .badContainer, .missingEntitlement:
                return .cloudKitFailed("CloudKit container misconfigured. Confirm iCloud.com.matchly.Matchly is enabled in Xcode Signing & Capabilities.")
            default:
                return .cloudKitFailed("\(ckError.localizedDescription) (CK \(ckError.code.rawValue))")
            }
        }

        return .cloudKitFailed(error.localizedDescription)
    }

    /// Waits for CloudKit identity when needed, then publishes the invite code to the public database.
    static func registerInviteIfNeeded(
        couple: Couple,
        authManager: AuthManager
    ) async throws {
        guard !couple.isLinked else { return }

        guard authManager.isCloudKitAvailable else {
            throw CoupleLinkingError.iCloudRequired
        }

        await authManager.refreshCloudKitIdentity()

        var inviterRecordName = authManager.cloudKitUserRecordName
        if inviterRecordName == nil {
            for _ in 0..<10 {
                await authManager.refreshCloudKitIdentity()
                inviterRecordName = authManager.cloudKitUserRecordName
                if inviterRecordName != nil { break }
                try await Task.sleep(nanoseconds: 400_000_000)
            }
        }

        guard let inviterRecordName else {
            throw CoupleLinkingError.identityUnavailable
        }

        if let existing = try? await fetchRegistration(for: couple.coupleCode),
           existing.inviterRecordName == inviterRecordName {
            return
        }

        do {
            try await registerPendingCouple(
                couple: couple,
                inviterRecordName: inviterRecordName,
                inviterName: couple.user1Name,
                inviterEmail: couple.user1Email
            )
        } catch {
            throw mapError(error)
        }
    }

    static func deleteRegistration(for code: String) async {
        let recordID = recordID(for: code)
        do {
            try await container.publicCloudDatabase.deleteRecord(withID: recordID)
        } catch {
            logger.debug("Could not delete couple code record: \(error.localizedDescription, privacy: .public)")
        }
    }

    static func fetchRegistration(for code: String) async throws -> CoupleCodeRegistration? {
        do {
            let record = try await container.publicCloudDatabase.record(for: recordID(for: code))
            return parse(record)
        } catch let error as CKError where error.code == .unknownItem {
            return nil
        }
    }

    static func claimCouple(
        code: String,
        partnerRecordName: String,
        partnerName: String,
        partnerEmail: String?
    ) async throws -> CoupleCodeRegistration {
        let normalizedCode = code.uppercased()
        guard let existing = try await fetchRegistration(for: normalizedCode) else {
            throw CoupleLinkingError.codeNotFound
        }

        if existing.inviterRecordName == partnerRecordName {
            throw CoupleLinkingError.cannotLinkOwnCode
        }

        if existing.isClaimed, existing.partnerRecordName != partnerRecordName {
            throw CoupleLinkingError.codeAlreadyClaimed
        }

        if existing.isClaimed, existing.partnerRecordName == partnerRecordName {
            return existing
        }

        let record = try await container.publicCloudDatabase.record(for: recordID(for: normalizedCode))
        setString("linked", forKey: "status", on: record)
        setString(partnerRecordName, forKey: "partnerRecordName", on: record)
        setString(partnerName, forKey: "partnerName", on: record)
        if let partnerEmail, !partnerEmail.isEmpty {
            setString(partnerEmail, forKey: "partnerEmail", on: record)
        }
        setString(timestampString(), forKey: "linkedAt", on: record)

        let saved = try await save(record)
        guard let parsed = parse(saved) else {
            throw CoupleLinkingError.unexpectedResponse
        }
        return parsed
    }

    private static func save(_ record: CKRecord) async throws -> CKRecord {
        try await withCheckedThrowingContinuation { continuation in
            container.publicCloudDatabase.save(record) { saved, error in
                if let error {
                    if let ckError = error as? CKError {
                        let serverMessage = ckError.userInfo[NSLocalizedDescriptionKey] as? String ?? ckError.localizedDescription
                        logger.error("CloudKit save failed: \(serverMessage, privacy: .public) code=\(ckError.code.rawValue, privacy: .public)")
                    } else {
                        logger.error("CloudKit save failed: \(error.localizedDescription, privacy: .public)")
                    }
                    continuation.resume(throwing: error)
                } else if let saved {
                    continuation.resume(returning: saved)
                } else {
                    continuation.resume(throwing: CoupleLinkingError.unexpectedResponse)
                }
            }
        }
    }

    private static func parse(_ record: CKRecord) -> CoupleCodeRegistration? {
        guard let code = record["code"] as? String,
              let coupleID = record["coupleID"] as? String,
              let inviterRecordName = record["inviterRecordName"] as? String,
              let inviterName = record["inviterName"] as? String else {
            return nil
        }

        let status = record["status"] as? String ?? "pending"
        return CoupleCodeRegistration(
            code: code,
            coupleID: coupleID,
            inviterRecordName: inviterRecordName,
            inviterName: inviterName,
            inviterEmail: record["inviterEmail"] as? String,
            partnerRecordName: record["partnerRecordName"] as? String,
            partnerName: record["partnerName"] as? String,
            partnerEmail: record["partnerEmail"] as? String,
            isClaimed: status == "linked"
        )
    }
}

enum CoupleLinkingError: LocalizedError {
    case codeNotFound
    case cannotLinkOwnCode
    case codeAlreadyClaimed
    case iCloudRequired
    case identityUnavailable
    case inviteNotPublished
    case cloudKitPermissionDenied
    case cloudKitFailed(String)
    case unexpectedResponse

    var errorDescription: String? {
        switch self {
        case .codeNotFound:
            return """
            No partner found with that code. Ask them to open Couples Matching and wait until \
            their invite is ready, then try again. Both phones must be signed into iCloud and \
            running the same app build (both from Xcode, or both from TestFlight).
            """
        case .cannotLinkOwnCode:
            return "You cannot link with your own code. Share your QR code with your partner instead."
        case .codeAlreadyClaimed:
            return "This code has already been linked by another partner."
        case .iCloudRequired:
            return "Sign in to iCloud on this device to link with your partner."
        case .identityUnavailable:
            return "Could not verify your iCloud identity. Sign in with Apple, confirm iCloud is enabled in Settings, then try again."
        case .inviteNotPublished:
            return "Could not publish your invite to iCloud. Confirm iCloud is enabled and try again in a moment."
        case .cloudKitPermissionDenied:
            return """
            CloudKit denied creating your invite. In CloudKit Dashboard → Schema → Security Roles → \
            _icloud → CoupleCodeInvite, check Create (Read and Write alone are not enough). Also set \
            _world to Read. Save, tap Generate New Code, then Retry Publishing Invite.
            """
        case .cloudKitFailed(let message):
            return message
        case .unexpectedResponse:
            return "Could not complete partner linking. Please try again."
        }
    }
}
