//
//  ProgramCloudSyncCodec.swift
//  Matchly
//
//  Firestore/iCloud program payloads omit device-local voice memo references.
//

import Foundation

enum ProgramCloudSyncCodec {
    static func encodeProgramsForCloudSync(_ programs: [Program]) throws -> Data {
        try JSONEncoder().encode(programs.map { $0.strippingVoiceMemoURLForCloudSync() })
    }

    static func decodeProgramsFromCloudSync(
        _ data: Data,
        preservingLocalVoiceMemosFrom existing: [Program]
    ) throws -> [Program] {
        let remote = try JSONDecoder().decode([Program].self, from: data)
        let localVoiceMemos = Dictionary(
            uniqueKeysWithValues: existing.compactMap { program -> (String, String)? in
                guard let reference = program.voiceMemoURL,
                      !reference.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    return nil
                }
                return (program.id, reference)
            }
        )

        return mergingLocalVoiceMemos(into: remote, localVoiceMemos: localVoiceMemos)
    }

    static func mergingLocalVoiceMemos(into remotePrograms: [Program], from existingPrograms: [Program]) -> [Program] {
        let localVoiceMemos = Dictionary(
            uniqueKeysWithValues: existingPrograms.compactMap { program -> (String, String)? in
                guard let reference = program.voiceMemoURL,
                      !reference.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    return nil
                }
                return (program.id, reference)
            }
        )
        return mergingLocalVoiceMemos(into: remotePrograms, localVoiceMemos: localVoiceMemos)
    }

    private static func mergingLocalVoiceMemos(
        into remotePrograms: [Program],
        localVoiceMemos: [String: String]
    ) -> [Program] {
        remotePrograms.map { program in
            var merged = program
            merged.voiceMemoURL = localVoiceMemos[program.id]
            return merged
        }
    }
}

private extension Program {
    func strippingVoiceMemoURLForCloudSync() -> Program {
        var copy = self
        copy.voiceMemoURL = nil
        return copy
    }
}
