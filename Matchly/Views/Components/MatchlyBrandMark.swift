//
//  MatchlyBrandMark.swift
//  Matchly
//

import SwiftUI

// MARK: - Glyph

/// Transparent Matchly mark for in-app surfaces.
struct MatchlyBrandMark: View {
    enum Size {
        case micro
        case inline
        case lock
        case auth
        case splash
        case onboarding

        var dimension: CGFloat {
            switch self {
            case .micro: return 28
            case .inline: return 40
            case .lock: return 56
            case .auth: return 76
            case .splash: return 108
            case .onboarding: return 104
            }
        }
    }

    var size: Size = .auth

    var body: some View {
        Image("MatchlyGlyph")
            .resizable()
            .renderingMode(.original)
            .aspectRatio(contentMode: .fit)
            .frame(width: size.dimension, height: size.dimension)
            .accessibilityHidden(true)
    }
}

// MARK: - Lockup

/// Luxury-style glyph + wordmark composition for splash, auth, and brand moments.
struct MatchlyBrandLockup: View {
    enum Style {
        case splash
        case auth
        case lock
        case onboarding
        case about
        case exportHeader
    }

    enum Palette {
        case canvas
        case onDark
    }

    var style: Style = .auth
    var palette: Palette = .canvas
    var showsTagline: Bool = true

    var body: some View {
        switch style {
        case .exportHeader:
            exportHeader
        default:
            verticalLockup
        }
    }

    private var verticalLockup: some View {
        VStack(spacing: stackSpacing) {
            MatchlyBrandMark(size: glyphSize)

            if showsDivider {
                MatchlyBrandHairline(width: hairlineWidth, color: hairlineColor)
                    .padding(.top, dividerTopPadding)
            }

            Text(MatchlyBrandCopy.wordmark)
                .font(.arial(size: wordmarkSize, weight: .light))
                .foregroundStyle(primaryTextColor)
                .kerning(wordmarkKerning)

            if showsTagline, let tagline = taglineText {
                Text(tagline)
                    .font(.arial(size: taglineSize, weight: .regular))
                    .foregroundStyle(secondaryTextColor)
                    .kerning(taglineKerning)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, taglineHorizontalPadding)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(MatchlyBrandCopy.accessibilityLabel)
    }

    private var exportHeader: some View {
        HStack(spacing: 14) {
            MatchlyBrandMark(size: .inline)

            VStack(alignment: .leading, spacing: 4) {
                Text(MatchlyBrandCopy.wordmark)
                    .font(.arial(size: 17, weight: .light))
                    .foregroundStyle(Color.white)
                    .kerning(3.5)

                Text(MatchlyBrandCopy.exportSubtitle.uppercased())
                    .font(.arial(size: 10, weight: .regular))
                    .foregroundStyle(Color.white.opacity(0.82))
                    .kerning(1.6)
            }
        }
    }

    private var glyphSize: MatchlyBrandMark.Size {
        switch style {
        case .splash: return .splash
        case .auth: return .auth
        case .lock: return .lock
        case .onboarding: return .onboarding
        case .about: return .inline
        case .exportHeader: return .inline
        }
    }

    private var stackSpacing: CGFloat {
        switch style {
        case .splash, .onboarding: return 24
        case .auth: return 20
        case .lock: return 18
        case .about: return 10
        case .exportHeader: return 0
        }
    }

    private var showsDivider: Bool {
        switch style {
        case .about: return false
        default: return true
        }
    }

    private var hairlineWidth: CGFloat {
        switch style {
        case .splash, .onboarding: return 52
        case .auth, .lock: return 44
        case .about: return 36
        case .exportHeader: return 0
        }
    }

    private var dividerTopPadding: CGFloat {
        style == .about ? 0 : 2
    }

    private var wordmarkSize: CGFloat {
        switch style {
        case .splash, .onboarding: return 26
        case .auth: return 24
        case .lock: return 22
        case .about: return 18
        case .exportHeader: return 17
        }
    }

    private var wordmarkKerning: CGFloat {
        switch style {
        case .splash, .onboarding: return 6
        case .auth, .lock: return 5.5
        case .about: return 4.5
        case .exportHeader: return 3.5
        }
    }

    private var taglineSize: CGFloat {
        switch style {
        case .splash, .onboarding: return 11
        case .auth: return 10.5
        case .lock: return 10
        case .about: return 9.5
        case .exportHeader: return 10
        }
    }

    private var taglineKerning: CGFloat {
        switch style {
        case .splash, .onboarding: return 2.4
        case .auth, .lock: return 2.2
        case .about: return 2
        case .exportHeader: return 1.6
        }
    }

    private var taglineHorizontalPadding: CGFloat {
        style == .auth ? 24 : 32
    }

    private var taglineText: String? {
        guard showsTagline else { return nil }
        switch style {
        case .lock: return MatchlyBrandCopy.lockSubtitle
        default: return MatchlyBrandCopy.tagline
        }
    }

    private var primaryTextColor: Color {
        palette == .onDark ? .white : AppColors.primaryText
    }

    private var secondaryTextColor: Color {
        palette == .onDark ? Color.white.opacity(0.78) : AppColors.secondaryText
    }

    private var hairlineColor: Color {
        palette == .onDark ? Color.white.opacity(0.35) : AppColors.secondaryText.opacity(0.35)
    }
}

// MARK: - Shared copy & chrome

private enum MatchlyBrandCopy {
    static let wordmark = "MATCHLY"
    static let tagline = "RESIDENCY MATCH MANAGEMENT"
    static let lockSubtitle = "UNLOCK TO CONTINUE"
    static let exportSubtitle = "Residency Rank List"
    static let accessibilityLabel = "Matchly, Residency Match Management"
}

struct MatchlyBrandHairline: View {
    var width: CGFloat = 48
    var color: Color = AppColors.secondaryText.opacity(0.35)

    var body: some View {
        Rectangle()
            .fill(color)
            .frame(width: width, height: 0.5)
    }
}

#Preview("Splash") {
    VStack {
        MatchlyBrandLockup(style: .splash)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .appCanvasBackground()
}

#Preview("Auth") {
    MatchlyBrandLockup(style: .auth)
        .padding()
        .appCanvasBackground()
}
