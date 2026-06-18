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
    case emptyResult

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Speech recognition access is required to create a transcript."
        case .recognizerUnavailable:
            return "Speech recognition is unavailable right now. Try again later."
        case .emptyResult:
            return "No speech was detected in this recording."
        }
    }
}

enum VoiceMemoTranscriber {
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

        return try await withCheckedThrowingContinuation { continuation in
            var hasResumed = false

            let request = SFSpeechURLRecognitionRequest(url: url)
            request.shouldReportPartialResults = false
            if recognizer.supportsOnDeviceRecognition {
                request.requiresOnDeviceRecognition = true
            }

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
