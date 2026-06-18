//
//  VoiceMemoStorage.swift
//  Matchly
//
//  Local voice memo files keyed by program ID (Phase 1 — device storage only).
//

import Foundation
import AVFoundation

enum VoiceMemoStorageError: Error {
    case mergeFailed
}

enum VoiceMemoStorage {
    static let subdirectory = "VoiceMemos"
    nonisolated static let maxDurationSeconds: TimeInterval = 300
    static let playbackRateOptions: [Float] = [0.75, 1.0, 1.25, 1.5, 2.0]
    private static let playbackRateDefaultsKey = "voiceMemoPlaybackRate"

    static var preferredPlaybackRate: Float {
        get {
            let stored = UserDefaults.standard.object(forKey: playbackRateDefaultsKey) as? Float
            return playbackRateOptions.contains(stored ?? 1.0) ? (stored ?? 1.0) : 1.0
        }
        set {
            UserDefaults.standard.set(newValue, forKey: playbackRateDefaultsKey)
        }
    }

    static func transcriptURL(forProgramId id: String) -> URL {
        baseDirectory().appendingPathComponent("\(id).txt")
    }

    static func loadTranscript(forProgramId id: String) -> String? {
        let url = transcriptURL(forProgramId: id)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try? String(contentsOf: url, encoding: .utf8)
    }

    static func saveTranscript(_ text: String, forProgramId id: String) throws {
        let directory = baseDirectory()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try text.write(to: transcriptURL(forProgramId: id), atomically: true, encoding: .utf8)
    }

    static func deleteTranscript(forProgramId id: String) {
        try? FileManager.default.removeItem(at: transcriptURL(forProgramId: id))
    }

    static func fileURL(forProgramId id: String) -> URL {
        let directory = baseDirectory()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("\(id).m4a")
    }

    static func baseDirectory() -> URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(subdirectory, isDirectory: true)
    }

    static func storedReference(forProgramId id: String) -> String {
        "\(subdirectory)/\(id).m4a"
    }

    static func hasMemo(forProgramId id: String) -> Bool {
        FileManager.default.fileExists(atPath: fileURL(forProgramId: id).path)
    }

    static func referenceIfMemoExists(forProgramId id: String) -> String? {
        hasMemo(forProgramId: id) ? storedReference(forProgramId: id) : nil
    }

    static func programHasVoiceMemo(id: String, reference: String?) -> Bool {
        if hasMemo(forProgramId: id) { return true }
        if let reference, resolveURL(from: reference) != nil { return true }
        return false
    }

    static func resolveURL(from reference: String?) -> URL? {
        guard let reference, !reference.isEmpty else { return nil }

        if reference.hasPrefix("file://"), let url = URL(string: reference) {
            return FileManager.default.fileExists(atPath: url.path) ? url : nil
        }

        if reference.hasPrefix("/") {
            let url = URL(fileURLWithPath: reference)
            return FileManager.default.fileExists(atPath: url.path) ? url : nil
        }

        let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(reference)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    static func deleteMemo(forProgramId id: String) {
        let url = fileURL(forProgramId: id)
        try? FileManager.default.removeItem(at: url)
        deleteTranscript(forProgramId: id)
    }

    static func invalidateTranscript(forProgramId id: String) {
        deleteTranscript(forProgramId: id)
    }

    static func deleteMemo(reference: String?) {
        guard let reference else { return }
        if reference.contains("/"), let url = resolveURL(from: reference) {
            try? FileManager.default.removeItem(at: url)
            return
        }
        let programId = (reference as NSString).lastPathComponent
            .replacingOccurrences(of: ".m4a", with: "")
        if !programId.isEmpty {
            deleteMemo(forProgramId: programId)
        }
    }

    /// Copies a legacy absolute-path memo into Application Support, if needed.
    static func normalizedReference(from stored: String?, programId: String) -> String? {
        if hasMemo(forProgramId: programId) {
            return storedReference(forProgramId: programId)
        }

        guard let stored, let legacyURL = resolveURL(from: stored) else { return nil }

        let destination = fileURL(forProgramId: programId)
        do {
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.copyItem(at: legacyURL, to: destination)
            return storedReference(forProgramId: programId)
        } catch {
            return stored
        }
    }

    static func duration(of url: URL) async -> TimeInterval {
        let asset = AVURLAsset(url: url)
        do {
            let loadedDuration = try await asset.load(.duration)
            let seconds = CMTimeGetSeconds(loadedDuration)
            return seconds.isFinite && seconds > 0 ? seconds : 0
        } catch {
            return 0
        }
    }

    nonisolated static func remainingDuration(givenExistingDuration existing: TimeInterval) -> TimeInterval {
        max(0, maxDurationSeconds - existing)
    }

    static func remainingDuration(for url: URL) async -> TimeInterval {
        remainingDuration(givenExistingDuration: await duration(of: url))
    }

    static func mergeAudio(existing: URL, appendSegment: URL, into destination: URL) async throws {
        let composition = AVMutableComposition()
        guard let compositionTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw VoiceMemoStorageError.mergeFailed
        }

        let existingAsset = AVURLAsset(url: existing)
        let appendAsset = AVURLAsset(url: appendSegment)

        guard let existingTrack = try await existingAsset.loadTracks(withMediaType: .audio).first,
              let appendTrack = try await appendAsset.loadTracks(withMediaType: .audio).first else {
            throw VoiceMemoStorageError.mergeFailed
        }

        let existingDuration = try await existingAsset.load(.duration)
        let appendDuration = try await appendAsset.load(.duration)

        try compositionTrack.insertTimeRange(
            CMTimeRange(start: .zero, duration: existingDuration),
            of: existingTrack,
            at: .zero
        )
        try compositionTrack.insertTimeRange(
            CMTimeRange(start: .zero, duration: appendDuration),
            of: appendTrack,
            at: existingDuration
        )

        let exportURL = destination.deletingLastPathComponent()
            .appendingPathComponent("merge-\(UUID().uuidString).m4a")

        guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetAppleM4A) else {
            throw VoiceMemoStorageError.mergeFailed
        }

        try await exportSession.export(to: exportURL, as: .m4a)

        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.moveItem(at: exportURL, to: destination)
    }
}
