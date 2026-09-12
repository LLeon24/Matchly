//
//  CouplesCloudManager.swift
//  Matchly
//
//  Cross-account CloudKit sync for linked couples (programs, rank list, preferences).
//

import CloudKit
import Foundation
import OSLog

struct CoupleRankListPayload {
    let pairs: [CouplesRankPair]
    let updatedAt: Date?
    let lastEditorRecordName: String?
}

enum CouplesCloudManager {
    private static let programBundleType = "CoupleProgramBundle"
    private static let rankListType = "CoupleRankList"
    private static let sharedPrefsType = "CoupleSharedPreferences"
    private static let profilePhotoType = "CoupleProfilePhoto"
    private static let logger = Logger(subsystem: "com.matchly", category: "CouplesCloud")
    private static let container = CKContainer(identifier: AuthManager.cloudKitContainerID)
    private static let encoder = JSONEncoder()
    private static let decoder = JSONDecoder()

    // MARK: - Programs

    static func publishOwnPrograms(
        coupleID: String,
        ownerRecordName: String,
        programs: [Program]
    ) async throws {
        let snapshots = Program.rankedSnapshots(from: programs)
        let data = try encoder.encode(snapshots)
        let recordID = CKRecord.ID(recordName: programBundleRecordName(coupleID: coupleID, owner: ownerRecordName))

        let record: CKRecord
        do {
            record = try await container.publicCloudDatabase.record(for: recordID)
        } catch let error as CKError where error.code == .unknownItem {
            record = CKRecord(recordType: programBundleType, recordID: recordID)
        }

        record["coupleID"] = coupleID as CKRecordValue
        record["ownerRecordName"] = ownerRecordName as CKRecordValue
        record["programsData"] = data as CKRecordValue
        record["updatedAt"] = Date() as CKRecordValue

        try await save(record)
        logger.info("Published \(snapshots.count, privacy: .public) programs for couple \(coupleID, privacy: .public)")
    }

    static func fetchPartnerPrograms(
        coupleID: String,
        partnerRecordName: String
    ) async throws -> [CoupleProgramSnapshot] {
        let recordID = CKRecord.ID(recordName: programBundleRecordName(coupleID: coupleID, owner: partnerRecordName))
        do {
            let record = try await container.publicCloudDatabase.record(for: recordID)
            guard let data = record["programsData"] as? Data else { return [] }
            return try decoder.decode([CoupleProgramSnapshot].self, from: data)
        } catch let error as CKError where error.code == .unknownItem {
            return []
        }
    }

    // MARK: - Rank list

    static func publishRankList(
        coupleID: String,
        pairs: [CouplesRankPair],
        editorRecordName: String
    ) async throws {
        let data = try encoder.encode(pairs)
        let recordID = CKRecord.ID(recordName: rankListRecordName(coupleID: coupleID))

        let record: CKRecord
        do {
            record = try await container.publicCloudDatabase.record(for: recordID)
        } catch let error as CKError where error.code == .unknownItem {
            record = CKRecord(recordType: rankListType, recordID: recordID)
        }

        record["coupleID"] = coupleID as CKRecordValue
        record["pairsData"] = data as CKRecordValue
        record["lastEditorRecordName"] = editorRecordName as CKRecordValue
        record["updatedAt"] = Date() as CKRecordValue

        try await save(record)
    }

    static func fetchRankList(coupleID: String) async throws -> CoupleRankListPayload? {
        let recordID = CKRecord.ID(recordName: rankListRecordName(coupleID: coupleID))
        do {
            let record = try await container.publicCloudDatabase.record(for: recordID)
            guard let data = record["pairsData"] as? Data else { return nil }
            let pairs = try decoder.decode([CouplesRankPair].self, from: data)
            return CoupleRankListPayload(
                pairs: pairs,
                updatedAt: record["updatedAt"] as? Date,
                lastEditorRecordName: record["lastEditorRecordName"] as? String
            )
        } catch let error as CKError where error.code == .unknownItem {
            return nil
        }
    }

    // MARK: - Preferences

    static func publishSharedPreferences(
        coupleID: String,
        preferences: CouplesPreferences,
        editorRecordName: String
    ) async throws {
        let data = try encoder.encode(preferences)
        let recordID = CKRecord.ID(recordName: prefsRecordName(coupleID: coupleID))

        let record: CKRecord
        do {
            record = try await container.publicCloudDatabase.record(for: recordID)
        } catch let error as CKError where error.code == .unknownItem {
            record = CKRecord(recordType: sharedPrefsType, recordID: recordID)
        }

        record["coupleID"] = coupleID as CKRecordValue
        record["preferencesData"] = data as CKRecordValue
        record["lastEditorRecordName"] = editorRecordName as CKRecordValue
        record["updatedAt"] = Date() as CKRecordValue

        try await save(record)
    }

    static func fetchSharedPreferences(coupleID: String) async throws -> CouplesPreferences? {
        let recordID = CKRecord.ID(recordName: prefsRecordName(coupleID: coupleID))
        do {
            let record = try await container.publicCloudDatabase.record(for: recordID)
            guard let data = record["preferencesData"] as? Data else { return nil }
            return try decoder.decode(CouplesPreferences.self, from: data)
        } catch let error as CKError where error.code == .unknownItem {
            return nil
        }
    }

    // MARK: - Profile photos

    static func publishOwnProfilePhoto(
        coupleID: String,
        ownerRecordName: String,
        photoData: Data?
    ) async throws {
        let recordID = CKRecord.ID(recordName: profilePhotoRecordName(coupleID: coupleID, owner: ownerRecordName))

        let record: CKRecord
        do {
            record = try await container.publicCloudDatabase.record(for: recordID)
        } catch let error as CKError where error.code == .unknownItem {
            record = CKRecord(recordType: profilePhotoType, recordID: recordID)
        }

        record["coupleID"] = coupleID as CKRecordValue
        record["ownerRecordName"] = ownerRecordName as CKRecordValue
        record["photoData"] = photoData as CKRecordValue?
        record["updatedAt"] = Date() as CKRecordValue

        try await save(record)
    }

    static func fetchPartnerProfilePhoto(
        coupleID: String,
        partnerRecordName: String
    ) async throws -> Data? {
        let recordID = CKRecord.ID(recordName: profilePhotoRecordName(coupleID: coupleID, owner: partnerRecordName))
        do {
            let record = try await container.publicCloudDatabase.record(for: recordID)
            return record["photoData"] as? Data
        } catch let error as CKError where error.code == .unknownItem {
            return nil
        }
    }

    // MARK: - Record names

    private static func profilePhotoRecordName(coupleID: String, owner: String) -> String {
        "profile-\(coupleID)-\(owner)"
    }

    private static func programBundleRecordName(coupleID: String, owner: String) -> String {
        "programs-\(coupleID)-\(owner)"
    }

    private static func rankListRecordName(coupleID: String) -> String {
        "ranklist-\(coupleID)"
    }

    private static func prefsRecordName(coupleID: String) -> String {
        "prefs-\(coupleID)"
    }

    private static func save(_ record: CKRecord) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            container.publicCloudDatabase.save(record) { _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    static func userFacingMessage(for error: Error) -> String {
        if let ckError = error as? CKError {
            switch ckError.code {
            case .notAuthenticated:
                return "Sign in to iCloud to sync with your partner."
            case .permissionFailure:
                return "CloudKit permission denied. Check Security Roles for CoupleProgramBundle (Create, Read, Write for _icloud)."
            case .invalidArguments, .serverRejectedRequest:
                return "CloudKit schema error: add record types CoupleProgramBundle, CoupleRankList, CoupleSharedPreferences, and CoupleProfilePhoto in the dashboard (see setup docs)."
            default:
                return "\(ckError.localizedDescription) (CK \(ckError.code.rawValue))"
            }
        }
        return error.localizedDescription
    }
}
