//
//  AudioSessionManager.swift
//  Matchly
//

import AVFoundation

enum AudioSessionError: Error {
    case recordFailed
    case playbackFailed
    case permissionDenied
}

/// All AVAudioSession, AVAudioRecorder, and AVAudioPlayer work runs on this queue.
enum AudioSessionManager {
    static let queue = DispatchQueue(label: "com.matchly.audio-session", qos: .userInitiated)

    private static var activeRecorder: AVAudioRecorder?
    private static var activePlayer: AVAudioPlayer?

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

    static func requestRecordPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            if #available(iOS 17.0, *) {
                AVAudioApplication.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            } else {
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    private static var recordingCategoryOptions: AVAudioSession.CategoryOptions {
        var options: AVAudioSession.CategoryOptions = [.defaultToSpeaker, .allowBluetoothHFP]
        if #available(iOS 26.0, *) {
            options.insert(.bluetoothHighQualityRecording)
        }
        return options
    }

    static func prepareForRecording() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: recordingCategoryOptions)
        try session.setActive(true)
    }

    static func prepareForPlayback() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default)
        try session.setActive(true)
    }

    static func deactivateSession() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    static func startRecording(at url: URL, deleteExisting: Bool) throws {
        if deleteExisting, FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }

        try prepareForRecording()

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 22_050,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
        ]

        let recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder.isMeteringEnabled = true
        recorder.prepareToRecord()

        guard recorder.record() else {
            throw AudioSessionError.recordFailed
        }

        activeRecorder = recorder
    }

    static func recordingMeterLevel() -> Float {
        guard let recorder = activeRecorder else { return -55 }
        recorder.updateMeters()
        return recorder.averagePower(forChannel: 0)
    }

    static func stopRecording() {
        activeRecorder?.stop()
        activeRecorder = nil
        deactivateSession()
    }

    static func makePlayer(for url: URL, rate: Float = 1.0) throws -> AVAudioPlayer {
        try prepareForPlayback()
        let player = try AVAudioPlayer(contentsOf: url)
        player.enableRate = true
        player.rate = rate
        player.prepareToPlay()
        activePlayer = player
        return player
    }

    static func setPlaybackRate(_ rate: Float) {
        guard let player = activePlayer else { return }
        player.enableRate = true
        player.rate = rate
    }

    static func clearPlayer() {
        activePlayer?.stop()
        activePlayer = nil
        deactivateSession()
    }

    static func currentPlayer() -> AVAudioPlayer? {
        activePlayer
    }
}
