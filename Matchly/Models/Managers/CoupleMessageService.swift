//
//  CoupleMessageService.swift
//  Matchly
//
//  Lightweight partner notes synced via CloudKit public database.
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
    private static let recordType = "CoupleMessage"
    private static let container = CKContainer(identifier: AuthManager.cloudKitContainerID)

    static func fetchMessages(coupleID: String) async throws -> [CoupleMessage] {
        let predicate = NSPredicate(format: "coupleID == %@", coupleID)
        let query = CKQuery(recordType: recordType, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "sentAt", ascending: true)]

        let records = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[CKRecord], Error>) in
            var collected: [CKRecord] = []
            let operation = CKQueryOperation(query: query)
            operation.resultsLimit = 100

            operation.recordMatchedBlock = { _, result in
                if case .success(let record) = result {
                    collected.append(record)
                }
            }
            operation.queryResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume(returning: collected)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            container.publicCloudDatabase.add(operation)
        }

        return records.compactMap(parse).sorted { $0.sentAt < $1.sentAt }
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

        let record = CKRecord(recordType: recordType)
        record["coupleID"] = coupleID as CKRecordValue
        record["senderRecordName"] = senderRecordName as CKRecordValue
        record["senderName"] = senderName as CKRecordValue
        record["text"] = trimmed as CKRecordValue
        record["sentAt"] = Date() as CKRecordValue

        let saved = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CKRecord, Error>) in
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

        guard let message = parse(saved) else {
            throw CoupleMessageError.saveFailed
        }
        return message
    }

    private static func parse(_ record: CKRecord) -> CoupleMessage? {
        guard let coupleID = record["coupleID"] as? String,
              let senderRecordName = record["senderRecordName"] as? String,
              let senderName = record["senderName"] as? String,
              let text = record["text"] as? String else {
            return nil
        }

        return CoupleMessage(
            id: record.recordID.recordName,
            coupleID: coupleID,
            senderRecordName: senderRecordName,
            senderName: senderName,
            text: text,
            sentAt: record["sentAt"] as? Date ?? Date()
        )
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
