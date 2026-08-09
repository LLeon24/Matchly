//
//  MatchlyBrandMark.swift
//  Matchly
//

import SwiftUI

// MARK: - Glyph

/// Transparent Matchly mark for in-app surfaces.
struct MatchlyBrandMark: View {
    enum Size {
        case statusBar
        case micro
        case ribbon
        case inline
        case feature
        case lock
        case auth
        case splash
        case onboarding

        var dimension: CGFloat {
            switch self {
            case .statusBar: return 22
            case .micro: return 28
            case .ribbon: return 36
            case .inline: return 40
            case .feature: return 56
            case .lock: return 56
            case .auth: return 76
            case .splash: return 108
            case .onboarding: return 104
            }
        }
    }

    var size: Size = .auth
    /// Nudges the glyph for optical centering when the artwork’s visual weight is uneven.
    var opticalOffsetX: CGFloat = 0

    var body: some View {
        Image("MatchlyGlyph")
            .resizable()
            .renderingMode(.original)
            .aspectRatio(contentMode: .fit)
            .frame(width: size.dimension, height: size.dimension)
            .offset(x: opticalOffsetX)
            .accessibilityHidden(true)
    }

    /// Compensates for the glyph’s visual weight sitting slightly left of geometric center.
    static func opticalCenterOffset(for size: Size) -> CGFloat {
        0.033 * size.dimension
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
            MatchlyBrandMark(size: glyphSize, opticalOffsetX: glyphOpticalOffsetX)

            if showsDivider {
                MatchlyBrandHairline(width: hairlineWidth, color: hairlineColor)
                    .padding(.top, dividerTopPadding)
            }

            Text(MatchlyBrandCopy.wordmark)
                .font(.arial(size: wordmarkSize, weight: .light))
                .foregroundStyle(primaryTextColor)
                .kerning(wordmarkKerning)
                .frame(maxWidth: .infinity)

            if showsTagline, let tagline = taglineText {
                Text(tagline)
                    .font(.arial(size: taglineSize, weight: .regular))
                    .foregroundStyle(secondaryTextColor)
                    .kerning(taglineKerning)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, taglineHorizontalPadding)
            }
        }
        .frame(maxWidth: .infinity)
        .multilineTextAlignment(.center)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(MatchlyBrandCopy.accessibilityLabel)
    }

    private var exportHeader: some View {
        HStack(spacing: 14) {
            MatchlyBrandMark(size: .inline)

            VStack(alignment: .leading, spacing: 4) {
                Text(MatchlyBrandCopy.wordmark)
                    .font(.arial(size: 17, weight: .light))
                    .foregroundStyle(primaryTextColor)
                    .kerning(3.5)

                Text(MatchlyBrandCopy.exportSubtitle.uppercased())
                    .font(.arial(size: 10, weight: .regular))
                    .foregroundStyle(secondaryTextColor)
                    .kerning(1.6)
            }
        }
    }

    private var glyphOpticalOffsetX: CGFloat {
        switch style {
        case .splash, .onboarding, .auth:
            return MatchlyBrandMark.opticalCenterOffset(for: glyphSize)
        default:
            return 0
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

/// Compact horizontal brand mark for dashboard and nav chrome.
struct MatchlyBrandRibbon: View {
    enum Prominence {
        case compact
        case dashboard

        var glyphSize: MatchlyBrandMark.Size {
            switch self {
            case .compact: return .micro
            case .dashboard: return .ribbon
            }
        }

        var wordmarkSize: CGFloat {
            switch self {
            case .compact: return 10
            case .dashboard: return 12
            }
        }

        var wordmarkKerning: CGFloat {
            switch self {
            case .compact: return 2.6
            case .dashboard: return 3.8
            }
        }

        var spacing: CGFloat {
            switch self {
            case .compact: return 7
            case .dashboard: return 9
            }
        }
    }

    var prominence: Prominence = .dashboard

    var body: some View {
        HStack(spacing: prominence.spacing) {
            MatchlyBrandMark(
                size: prominence.glyphSize,
                opticalOffsetX: MatchlyBrandMark.opticalCenterOffset(for: prominence.glyphSize)
            )
            Text(MatchlyBrandCopy.wordmark)
                .font(.arial(size: prominence.wordmarkSize, weight: .light))
                .foregroundStyle(AppColors.secondaryText.opacity(prominence == .dashboard ? 0.92 : 0.88))
                .kerning(prominence.wordmarkKerning)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(MatchlyBrandCopy.accessibilityLabel)
    }
}

/// Top-left status-bar wordmark: the glyph reads as “M”, followed by “ATCHLY”.
struct MatchlyBrandInlineWordmark: View {
    var glyphSize: MatchlyBrandMark.Size = .statusBar
    /// Use primary text on splash / light canvases; secondary on in-card chrome.
    var emphasis: Bool = false

    private var wordmarkSize: CGFloat {
        switch glyphSize {
        case .statusBar: return 11
        case .micro: return 13
        case .ribbon: return 15
        case .inline: return 16
        case .feature: return 20
        case .lock, .auth: return 22
        case .splash, .onboarding: return 24
        }
    }

    private var wordmarkKerning: CGFloat {
        switch glyphSize {
        case .statusBar: return 2.8
        case .micro: return 3.4
        case .ribbon: return 3.8
        case .inline: return 4.0
        case .feature: return 4.4
        case .lock, .auth: return 4.8
        case .splash, .onboarding: return 5.2
        }
    }

    private var spacing: CGFloat {
        switch glyphSize {
        case .statusBar: return 1
        case .micro, .ribbon: return 2
        case .inline, .feature: return 3
        default: return 4
        }
    }

    private var wordmarkColor: Color {
        emphasis ? AppColors.primaryText : AppColors.secondaryText.opacity(0.82)
    }

    var body: some View {
        HStack(spacing: spacing) {
            MatchlyBrandMark(
                size: glyphSize,
                opticalOffsetX: MatchlyBrandMark.opticalCenterOffset(for: glyphSize)
            )
            Text("ATCHLY")
                .font(.arial(size: wordmarkSize, weight: .light))
                .foregroundStyle(wordmarkColor)
                .kerning(wordmarkKerning)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(MatchlyBrandCopy.accessibilityLabel)
    }
}

/// Inline M + ATCHLY with hairline and tagline — splash-style brand moment.
struct MatchlyBrandInlineLockup: View {
    var glyphSize: MatchlyBrandMark.Size = .feature
    var hairlineWidth: CGFloat = 56
    var showsTagline: Bool = true
    var tagline: String? = nil

    private var resolvedTagline: String {
        tagline ?? MatchlyBrandCopy.tagline
    }

    var body: some View {
        VStack(spacing: glyphSize == .feature ? 20 : 24) {
            MatchlyBrandInlineWordmark(glyphSize: glyphSize, emphasis: true)

            MatchlyBrandHairline(width: hairlineWidth)

            if showsTagline {
                Text(resolvedTagline)
                    .font(.arial(size: 11, weight: .regular))
                    .foregroundStyle(AppColors.secondaryText)
                    .kerning(2.4)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(MatchlyBrandCopy.accessibilityLabel)
    }
}

/// Pins the inline wordmark in the system status bar, left of the Dynamic Island.
private struct MatchlyStatusBarBrandPlacement: ViewModifier {
    func body(content: Content) -> some View {
        content.overlay(alignment: .topLeading) {
            GeometryReader { geo in
                MatchlyBrandInlineWordmark()
                    .padding(.leading, 16)
                    .padding(.top, Self.brandTopPadding(safeAreaTop: geo.safeAreaInsets.top))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .ignoresSafeArea(edges: .top)
            .allowsHitTesting(false)
        }
    }

    /// Vertically centers the wordmark with the Dynamic Island / notch pill.
    private static func brandTopPadding(safeAreaTop: CGFloat) -> CGFloat {
        let wordmarkHeight = MatchlyBrandMark.Size.statusBar.dimension
        if safeAreaTop >= 51 {
            // Dynamic Island pill: ~11pt from top, ~37pt tall → center ≈ 29.5pt
            let islandCenterY: CGFloat = 11 + 18.5
            return islandCenterY - wordmarkHeight / 2
        }
        if safeAreaTop >= 44 {
            return (safeAreaTop - wordmarkHeight) / 2
        }
        return max(6, safeAreaTop * 0.35)
    }
}

extension View {
    /// Dashboard status-bar brand — glyph + “ATCHLY” left of the Dynamic Island.
    func matchlyStatusBarBrand() -> some View {
        modifier(MatchlyStatusBarBrandPlacement())
    }
}

struct MatchlyBrandHairline: View {
    var width: CGFloat = 48
    var fullWidth: Bool = false
    var color: Color = AppColors.secondaryText.opacity(0.35)

    var body: some View {
        Rectangle()
            .fill(color)
            .frame(height: 0.5)
            .frame(maxWidth: fullWidth ? .infinity : width)
            .frame(width: fullWidth ? nil : width)
    }
}

#Preview("Inline lockup") {
    VStack(spacing: 32) {
        MatchlyBrandInlineLockup(glyphSize: .feature)
        MatchlyBrandInlineWordmark(glyphSize: .micro)
    }
    .frame(maxWidth: .infinity)
    .padding()
    .appCanvasBackground()
}

#Preview("Inline wordmark") {
    VStack(alignment: .leading) {
        MatchlyBrandInlineWordmark()
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding()
    .appCanvasBackground()
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
