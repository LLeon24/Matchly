//
//  AudioSessionManager.swift
//  Matchly
//

import AVFoundation

enum AudioSessionError: Error {
    case recordFailed
    case playbackFailed
}

/// All AVAudioSession and AVAudioRecorder/AVAudioPlayer work runs on this queue.
enum AudioSessionManager {
    static let queue = DispatchQueue(label: "com.matchly.audio-session", qos: .userInitiated)

    static func run<T>(_ work: @escaping () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    continuation.resume(returning: try work())
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    static func runVoid(_ work: @escaping () -> Void) async {
        await withCheckedContinuation { continuation in
            queue.async {
                work()
                continuation.resume()
            }
        }
    }
}
