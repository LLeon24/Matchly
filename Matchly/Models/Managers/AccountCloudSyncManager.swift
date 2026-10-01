//
//  AccountCloudSyncManager.swift
//  Matchly
//
//  Firestore-backed account backup for signed-in users.
//  Path: users/{uid}/backup/primary
//

import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore
import OSLog

struct AccountCloudBackup: Equatable {
    var programsJSON: Data?
    var preferencesJSON: Data?
    var manualRankOrder: [String]?
    var programsUpdatedAt: Date?
    var preferencesUpdatedAt: Date?
    var updatedAt: Date?
}

final class AccountCloudSyncManager: ObservableObject {
    static let shared = AccountCloudSyncManager()

    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var syncError: String?

    private lazy var db = Firestore.firestore()
    private static let logger = Logger(subsystem: "com.matchly", category: "AccountCloudSync")

    private init() {}

    var isSignedIn: Bool {
        Auth.auth().currentUser != nil
    }

    private var backupDocument: DocumentReference? {
        guard let uid = Auth.auth().currentUser?.uid else { return nil }
        return db.collection("users").document(uid).collection("backup").document("primary")
    }

    func push(
        programsJSON: Data?,
        preferencesJSON: Data?,
        manualRankOrder: [String]?,
        programsUpdatedAt: Date?,
        preferencesUpdatedAt: Date?
    ) async {
        guard let doc = backupDocument else {
            await MainActor.run {
                self.syncError = "Sign in to sync account backup."
            }
            return
        }

        await MainActor.run {
            self.isSyncing = true
            self.syncError = nil
        }

        var payload: [String: Any] = [
            "updatedAt": FieldValue.serverTimestamp()
        ]
        if let programsJSON {
            payload["programsJSON"] = programsJSON
        }
        if let preferencesJSON {
            payload["preferencesJSON"] = preferencesJSON
        }
        if let manualRankOrder {
            payload["manualRankOrder"] = manualRankOrder
        }
        if let programsUpdatedAt {
            payload["programsUpdatedAt"] = Timestamp(date: programsUpdatedAt)
        }
        if let preferencesUpdatedAt {
            payload["preferencesUpdatedAt"] = Timestamp(date: preferencesUpdatedAt)
        }

        do {
            try await doc.setData(payload, merge: true)
            await MainActor.run {
                self.lastSyncDate = Date()
                self.isSyncing = false
            }
            Self.logger.info("Pushed account cloud backup")
        } catch {
            await MainActor.run {
                self.syncError = error.localizedDescription
                self.isSyncing = false
            }
            Self.logger.error("Account cloud push failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Permanently removes this account's Firestore backup.
    /// Must run while the user is still authenticated — security rules require it.
    func deleteBackup() async throws {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let backupDoc = db.collection("users").document(uid).collection("backup").document("primary")
        do {
            try await backupDoc.delete()
        } catch {
            let nsError = error as NSError
            // Not found is fine — nothing to delete.
            if nsError.domain == FirestoreErrorDomain, nsError.code == FirestoreErrorCode.notFound.rawValue {
                return
            }
            throw error
        }
        Self.logger.info("Deleted account cloud backup")
    }

    func pull() async -> AccountCloudBackup? {
        guard let doc = backupDocument else {
            await MainActor.run {
                self.syncError = "Sign in to sync account backup."
            }
            return nil
        }

        await MainActor.run {
            self.isSyncing = true
            self.syncError = nil
        }

        do {
            let snapshot = try await doc.getDocument()
            guard snapshot.exists, let data = snapshot.data() else {
                await MainActor.run { self.isSyncing = false }
                return AccountCloudBackup()
            }

            let backup = AccountCloudBackup(
                programsJSON: Self.dataValue(data["programsJSON"]),
                preferencesJSON: Self.dataValue(data["preferencesJSON"]),
                manualRankOrder: data["manualRankOrder"] as? [String],
                programsUpdatedAt: (data["programsUpdatedAt"] as? Timestamp)?.dateValue(),
                preferencesUpdatedAt: (data["preferencesUpdatedAt"] as? Timestamp)?.dateValue(),
                updatedAt: (data["updatedAt"] as? Timestamp)?.dateValue()
            )
            await MainActor.run {
                self.lastSyncDate = Date()
                self.isSyncing = false
            }
            Self.logger.info("Pulled account cloud backup")
            return backup
        } catch {
            await MainActor.run {
                self.syncError = error.localizedDescription
                self.isSyncing = false
            }
            Self.logger.error("Account cloud pull failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    private static func dataValue(_ value: Any?) -> Data? {
        if let data = value as? Data { return data }
        // Firestore may decode JSON payloads as UTF-8 strings on some clients.
        if let string = value as? String { return Data(string.utf8) }
        return nil
    }
}
