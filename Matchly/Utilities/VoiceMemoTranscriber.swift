//
//  VoiceMemoTranscriber.swift
//  Matchly
//
//  On-device speech recognition for saved voice memos.
//

import Foundation
import Speech

enum VoiceMemoTranscriberError: LocalizedError {
    case notAuthorized
    case recognizerUnavailable
    case onDeviceRecognitionUnavailable
    case emptyResult

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Speech recognition access is required to create a transcript."
        case .recognizerUnavailable:
            return "Speech recognition is unavailable right now. Try again later."
        case .onDeviceRecognitionUnavailable:
            return "On-device transcription isn't available on this device. Your voice memo is still saved locally—you can play it back anytime."
        case .emptyResult:
            return "No speech was detected in this recording."
        }
    }
}

enum VoiceMemoTranscriber {
    /// Whether Matchly can transcribe using on-device speech recognition only.
    static var isOnDeviceTranscriptionAvailable: Bool {
        guard let recognizer = SFSpeechRecognizer(locale: Locale.current) else { return false }
        return recognizer.isAvailable && recognizer.supportsOnDeviceRecognition
    }

    static func authorizationStatus() -> SFSpeechRecognizerAuthorizationStatus {
        SFSpeechRecognizer.authorizationStatus()
    }

    static func requestAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }

    static func transcribe(audioAt url: URL) async throws -> String {
        let status = await requestAuthorization()
        guard status == .authorized else {
            throw VoiceMemoTranscriberError.notAuthorized
        }

        guard let recognizer = SFSpeechRecognizer(locale: Locale.current),
              recognizer.isAvailable else {
            throw VoiceMemoTranscriberError.recognizerUnavailable
        }

        guard recognizer.supportsOnDeviceRecognition else {
            throw VoiceMemoTranscriberError.onDeviceRecognitionUnavailable
        }

        return try await withCheckedThrowingContinuation { continuation in
            var hasResumed = false

            let request = SFSpeechURLRecognitionRequest(url: url)
            request.shouldReportPartialResults = false
            request.requiresOnDeviceRecognition = true

            recognizer.recognitionTask(with: request) { result, error in
                if hasResumed { return }

                if let error {
                    hasResumed = true
                    continuation.resume(throwing: error)
                    return
                }

                guard let result, result.isFinal else { return }

                let text = result.bestTranscription.formattedString
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                hasResumed = true
                if text.isEmpty {
                    continuation.resume(throwing: VoiceMemoTranscriberError.emptyResult)
                } else {
                    continuation.resume(returning: text)
                }
            }
        }
    }
}
