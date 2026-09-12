//
//  ProgramVoiceMemoBadge.swift
//  Matchly
//

import SwiftUI

struct ProgramVoiceMemoBadge: View {
    let program: Program
    var iconSize: CGFloat = 8
    var textSize: CGFloat = 10

    var body: some View {
        if program.hasVoiceMemo {
            HStack(spacing: 3) {
                Image(systemName: "waveform")
                    .font(.arial(size: iconSize))
                Text("Voice Memo")
                    .font(.arial(size: textSize, weight: .medium))
            }
            .foregroundColor(.purple)
            .accessibilityLabel("Has voice memo")
        }
    }
}

extension Program {
    var hasVoiceMemo: Bool {
        VoiceMemoStorage.programHasVoiceMemo(id: id, reference: voiceMemoURL)
    }
}
