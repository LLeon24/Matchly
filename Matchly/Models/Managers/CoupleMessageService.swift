//
//  CoupleMessageService.swift
//  Matchly
//
//  Partner chat synced via one CloudKit record per couple (no query indexes required).
//

import CloudKit
import Foundation

struct CoupleMessage: Identifiable, Hashable {
    let id: String
    let coupleID: String
    let senderRecordName: String
    let senderName: String
    let text: String
    let sentAt: Date

    var isFromCurrentUser: Bool {
        senderRecordName == AuthManager.shared.cloudKitUserRecordName
    }
}

enum CoupleMessageService {
    /// One shared thread record per couple — fetched by record name, not query.
    private static let recordType = "CoupleMessageThread"
    private static let container = CKContainer(identifier: AuthManager.cloudKitContainerID)
    private static let encoder = JSONEncoder()
    private static let decoder = JSONDecoder()
    private static let timestampFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static func fetchMessages(coupleID: String) async throws -> [CoupleMessage] {
        let recordID = threadRecordID(for: coupleID)
        do {
            let record = try await container.publicCloudDatabase.record(for: recordID)
            return decodeMessages(from: record, coupleID: coupleID)
        } catch let error as CKError where error.code == .unknownItem {
            return []
        }
    }

    static func sendMessage(
        coupleID: String,
        senderRecordName: String,
        senderName: String,
        text: String
    ) async throws -> CoupleMessage {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw CoupleMessageError.emptyMessage
        }

        let stored = StoredCoupleMessage(
            id: UUID().uuidString,
            senderRecordName: senderRecordName,
            senderName: senderName,
            text: trimmed,
            sentAt: timestampString()
        )

        let saved = try await appendMessage(stored, coupleID: coupleID)
        guard let message = saved else {
            throw CoupleMessageError.saveFailed
        }
        return message
    }

    static func userFacingMessage(for error: Error) -> String {
        if let messageError = error as? CoupleMessageError {
            return messageError.localizedDescription
        }

        if let ckError = error as? CKError {
            if ckError.code == .partialFailure,
               let partial = ckError.partialErrorsByItemID?.values.first {
                return userFacingMessage(for: partial)
            }

            switch ckError.code {
            case .notAuthenticated:
                return "Sign in to iCloud to message your partner."
            case .permissionFailure:
                return "CloudKit permission denied for chat. In CloudKit Dashboard, allow Create and Read on CoupleMessageThread for signed-in users."
            case .invalidArguments, .serverRejectedRequest:
                return "CloudKit schema error for chat: add record type CoupleMessageThread with String fields coupleID and updatedAt, plus Bytes field messagesData. Deploy to Production for TestFlight."
            case .networkUnavailable, .networkFailure, .serviceUnavailable, .requestRateLimited, .zoneBusy:
                return "Network or iCloud issue. Check your connection and try again."
            default:
                return "\(ckError.localizedDescription) (CK \(ckError.code.rawValue))"
            }
        }

        return error.localizedDescription
    }

    // MARK: - Thread record

    private static func threadRecordID(for coupleID: String) -> CKRecord.ID {
        CKRecord.ID(recordName: "chat-\(coupleID)")
    }

    private static func appendMessage(
        _ message: StoredCoupleMessage,
        coupleID: String,
        attempt: Int = 0
    ) async throws -> CoupleMessage? {
        guard attempt < 4 else { throw CoupleMessageError.saveFailed }

        let recordID = threadRecordID(for: coupleID)
        let database = container.publicCloudDatabase

        let record: CKRecord
        do {
            record = try await database.record(for: recordID)
        } catch let error as CKError where error.code == .unknownItem {
            record = CKRecord(recordType: recordType, recordID: recordID)
            record["coupleID"] = coupleID as CKRecordValue
            record["messagesData"] = Data() as CKRecordValue
        }

        var stored = decodeStoredMessages(from: record)
        stored.append(message)
        record["messagesData"] = try encoder.encode(stored) as CKRecordValue
        record["updatedAt"] = timestampString() as CKRecordValue

        do {
            _ = try await save(record)
            return CoupleMessage(stored: message, coupleID: coupleID)
        } catch let error as CKError where error.code == .serverRecordChanged {
            return try await appendMessage(message, coupleID: coupleID, attempt: attempt + 1)
        }
    }

    private static func decodeMessages(from record: CKRecord, coupleID: String) -> [CoupleMessage] {
        decodeStoredMessages(from: record)
            .map { CoupleMessage(stored: $0, coupleID: coupleID) }
            .sorted { $0.sentAt < $1.sentAt }
    }

    private static func decodeStoredMessages(from record: CKRecord) -> [StoredCoupleMessage] {
        guard let data = record["messagesData"] as? Data, !data.isEmpty else { return [] }
        return (try? decoder.decode([StoredCoupleMessage].self, from: data)) ?? []
    }

    private static func save(_ record: CKRecord) async throws -> CKRecord {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CKRecord, Error>) in
            container.publicCloudDatabase.save(record) { saved, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let saved {
                    continuation.resume(returning: saved)
                } else {
                    continuation.resume(throwing: CoupleMessageError.saveFailed)
                }
            }
        }
    }

    private static func timestampString(from date: Date = Date()) -> String {
        timestampFormatter.string(from: date)
    }

    fileprivate static func parseTimestamp(_ string: String) -> Date {
        timestampFormatter.date(from: string) ?? Date()
    }
}

private struct StoredCoupleMessage: Codable {
    let id: String
    let senderRecordName: String
    let senderName: String
    let text: String
    let sentAt: String
}

private extension CoupleMessage {
    init(stored: StoredCoupleMessage, coupleID: String) {
        id = stored.id
        self.coupleID = coupleID
        senderRecordName = stored.senderRecordName
        senderName = stored.senderName
        text = stored.text
        sentAt = CoupleMessageService.parseTimestamp(stored.sentAt)
    }
}

enum CoupleMessageError: LocalizedError {
    case emptyMessage
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .emptyMessage:
            return "Enter a message before sending."
        case .saveFailed:
            return "Could not send your message. Please try again."
        }
    }
}
