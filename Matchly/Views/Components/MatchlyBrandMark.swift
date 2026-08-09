//
//  MatchlyBrandMark.swift
//  Matchly
//

import SwiftUI

/// Transparent Matchly mark for in-app branding (splash, auth, lock, exports).
struct MatchlyBrandMark: View {
    enum Size {
        case inline
        case lock
        case auth
        case splash
        case onboarding

        var dimension: CGFloat {
            switch self {
            case .inline: return 44
            case .lock: return 72
            case .auth: return 100
            case .splash: return 120
            case .onboarding: return 140
            }
        }

        var cornerRadius: CGFloat {
            switch self {
            case .inline: return 10
            case .lock: return 16
            case .auth: return 22
            case .splash: return 26
            case .onboarding: return 30
            }
        }
    }

    var size: Size = .auth

    var body: some View {
        Image("MatchlyGlyph")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: size.dimension, height: size.dimension)
            .clipShape(RoundedRectangle(cornerRadius: size.cornerRadius, style: .continuous))
            .shadow(color: .black.opacity(size == .inline ? 0 : 0.1), radius: size == .inline ? 0 : 8, x: 0, y: size == .inline ? 0 : 4)
    }
}

#Preview {
    VStack(spacing: 24) {
        MatchlyBrandMark(size: .auth)
        MatchlyBrandMark(size: .inline)
    }
    .padding()
    .appCanvasBackground()
}
