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

    static func registerPendingCouple(
        couple: Couple,
        inviterRecordName: String,
        inviterName: String,
        inviterEmail: String?
    ) async throws {
        let code = couple.coupleCode.uppercased()
        let recordID = CKRecord.ID(recordName: code)
        let record = CKRecord(recordType: recordType, recordID: recordID)
        record["code"] = code as CKRecordValue
        record["coupleID"] = couple.id as CKRecordValue
        record["inviterRecordName"] = inviterRecordName as CKRecordValue
        record["inviterName"] = inviterName as CKRecordValue
        if let inviterEmail, !inviterEmail.isEmpty {
            record["inviterEmail"] = inviterEmail as CKRecordValue
        }
        record["status"] = "pending" as CKRecordValue
        record["createdAt"] = Date() as CKRecordValue

        try await save(record)
        logger.info("Registered couple code \(code, privacy: .public)")
    }

    static func deleteRegistration(for code: String) async {
        let recordID = CKRecord.ID(recordName: code.uppercased())
        do {
            try await container.publicCloudDatabase.deleteRecord(withID: recordID)
        } catch {
            logger.debug("Could not delete couple code record: \(error.localizedDescription, privacy: .public)")
        }
    }

    static func fetchRegistration(for code: String) async throws -> CoupleCodeRegistration? {
        let recordID = CKRecord.ID(recordName: code.uppercased())
        do {
            let record = try await container.publicCloudDatabase.record(for: recordID)
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

        let recordID = CKRecord.ID(recordName: normalizedCode)
        let record = try await container.publicCloudDatabase.record(for: recordID)
        record["status"] = "linked" as CKRecordValue
        record["partnerRecordName"] = partnerRecordName as CKRecordValue
        record["partnerName"] = partnerName as CKRecordValue
        if let partnerEmail, !partnerEmail.isEmpty {
            record["partnerEmail"] = partnerEmail as CKRecordValue
        }
        record["linkedAt"] = Date() as CKRecordValue

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
    case unexpectedResponse

    var errorDescription: String? {
        switch self {
        case .codeNotFound:
            return "No partner found with that code. Ask them to show their QR code in Matchly first."
        case .cannotLinkOwnCode:
            return "You cannot link with your own code. Share your QR code with your partner instead."
        case .codeAlreadyClaimed:
            return "This code has already been linked by another partner."
        case .iCloudRequired:
            return "Sign in to iCloud on this device to link with your partner."
        case .identityUnavailable:
            return "Could not verify your iCloud identity. Please sign in with Apple and try again."
        case .unexpectedResponse:
            return "Could not complete partner linking. Please try again."
        }
    }
}
