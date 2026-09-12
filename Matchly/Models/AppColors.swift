//
//  AppColors.swift
//  Matchly
//
//  Created on 11/16/25.
//

import SwiftUI

struct AppColors {
    // Primary brand color - vibrant medical blue (matches icon)
    // Light: vibrant blue, Dark: slightly brighter for visibility
    static let primaryBlue = Color(
        light: Color(red: 0.0, green: 0.48, blue: 0.65),
        dark: Color(red: 0.2, green: 0.6, blue: 0.8)
    )
    
    // Accent teal-green (matches icon chest piece)
    // Light: teal-green, Dark: brighter teal
    static let accentTeal = Color(
        light: Color(red: 0.2, green: 0.7, blue: 0.8),
        dark: Color(red: 0.3, green: 0.8, blue: 0.9)
    )
    
    // Happy, vibrant accent colors - adjusted for dark mode
    static let accentPink = Color(
        light: Color(red: 1.0, green: 0.4, blue: 0.6),
        dark: Color(red: 1.0, green: 0.5, blue: 0.7)
    )
    static let accentPurple = Color(
        light: Color(red: 0.6, green: 0.4, blue: 1.0),
        dark: Color(red: 0.7, green: 0.5, blue: 1.0)
    )
    static let accentOrange = Color(
        light: Color(red: 1.0, green: 0.6, blue: 0.2),
        dark: Color(red: 1.0, green: 0.7, blue: 0.3)
    )
    static let accentGreen = Color(
        light: Color(red: 0.2, green: 0.8, blue: 0.4),
        dark: Color(red: 0.3, green: 0.9, blue: 0.5)
    )
    static let accentYellow = Color(
        light: Color(red: 1.0, green: 0.85, blue: 0.2),
        dark: Color(red: 1.0, green: 0.9, blue: 0.3)
    )
    /// Darker yellow for stat labels on light backgrounds.
    static let accentAmber = Color(
        light: Color(red: 0.80, green: 0.58, blue: 0.04),
        dark: Color(red: 1.0, green: 0.82, blue: 0.28)
    )
    static let accentRed = Color(
        light: Color(red: 0.90, green: 0.28, blue: 0.30),
        dark: Color(red: 1.0, green: 0.38, blue: 0.40)
    )

    // MARK: - Interview season pipeline (hero ring + stat row share these exactly)

    /// Warm orange — program still needs an interview date.
    static let pipelineNeedDate = accentOrange
    /// Soft purple — scheduled upcoming interview.
    static let pipelineUpcoming = Color(
        light: Color(red: 0.55, green: 0.42, blue: 0.88),
        dark: Color(red: 0.68, green: 0.55, blue: 0.96)
    )
    /// Brand-success green — questionnaire scored and ready.
    static let pipelineScored = accentGreen
    /// Magenta-rose — interview done; questionnaire still needs review.
    static let pipelineToReview = Color(
        light: Color(red: 0.84, green: 0.24, blue: 0.52),
        dark: Color(red: 0.94, green: 0.38, blue: 0.62)
    )
    
    // Gradient combinations - adapt to dark mode
    static var primaryGradient: LinearGradient {
        LinearGradient(
            colors: [primaryBlue, accentTeal],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    static var happyGradient: LinearGradient {
        LinearGradient(
            colors: [accentPink, accentPurple],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    static var successGradient: LinearGradient {
        LinearGradient(
            colors: [accentGreen, accentTeal],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Score-driven gradients (Apple Activity-ring style)

    /// A vibrant 2-stop gradient whose hue family reflects the score quality.
    /// Empty/zero scores fall back to a calm brand sweep so the hero still
    /// reads as intentional and colorful (never empty/gloomy).
    static func scoreGradientColors(for score: Double) -> [Color] {
        if score >= 80 { return [accentTeal, accentGreen] }
        if score >= 60 { return [primaryBlue, accentTeal] }
        if score >= 40 { return [accentYellow, accentOrange] }
        if score > 0   { return [accentOrange, accentPink] }
        return [primaryBlue, accentTeal] // 0 / no data: calm brand sweep
    }

    /// Angular gradient for an Activity-ring style progress arc.
    static func scoreRingGradient(for score: Double) -> AngularGradient {
        AngularGradient(
            gradient: Gradient(colors: scoreGradientColors(for: score)),
            center: .center,
            startAngle: .degrees(-90),
            endAngle: .degrees(270)
        )
    }

    /// Linear gradient (top-leading → bottom-trailing) for tinting hero numbers.
    static func scoreLinearGradient(for score: Double) -> LinearGradient {
        LinearGradient(
            colors: scoreGradientColors(for: score),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// The representative solid tint for a score (the gradient's end color).
    static func scoreTint(for score: Double) -> Color {
        scoreGradientColors(for: score).last ?? primaryBlue
    }
    
    // Card backgrounds - semantic colors that adapt automatically
    static let cardBackground = Color(.systemBackground)
    static let cardBackgroundAccent = Color(.secondarySystemBackground)

    // Bright, clean dashboard canvas (Monarch-style).
    // Light: crisp near-white with only a whisper of coolness (no yellow/cream
    // cast) so it reads light & happy; white cards still separate via shadow.
    // Dark: a proper near-black so elevated cards stand out clearly.
    static let dashboardCanvas = Color(
        light: Color(red: 1.0, green: 1.0, blue: 1.0),
        dark: Color(red: 0.071, green: 0.071, blue: 0.078)
    )

    // Elevated card surface that floats on `dashboardCanvas`.
    // Light: pure white. Dark: elevated dark gray (matches grouped surfaces).
    static let dashboardCard = Color(
        light: Color(red: 1.0, green: 1.0, blue: 1.0),
        dark: Color(red: 0.110, green: 0.110, blue: 0.118)
    )
    
    // Text colors - semantic
    static let primaryText = Color(.label)
    static let secondaryText = Color(.secondaryLabel)
    static let tertiaryText = Color(.tertiaryLabel)

    /// Magenta-pink — distinct from red-flag section F.
    static let sectionDMagenta = Color(
        light: Color(red: 0.82, green: 0.22, blue: 0.62),
        dark: Color(red: 0.92, green: 0.38, blue: 0.72)
    )

    /// Deep red reserved for red-flag section F.
    static let sectionFRed = Color(
        light: Color(red: 0.62, green: 0.08, blue: 0.10),
        dark: Color(red: 0.92, green: 0.24, blue: 0.26)
    )
}

enum QuestionnaireSectionAccent {
    static func color(for sectionId: String, title: String) -> Color {
        switch sectionId {
        case "matchly.section.a": return .blue
        case "matchly.section.b": return AppColors.accentPurple
        case "matchly.section.c": return AppColors.accentOrange
        case "matchly.section.d": return AppColors.sectionDMagenta
        case "matchly.section.e": return AppColors.accentTeal
        case "matchly.section.f": return AppColors.sectionFRed
        default:
            guard let letter = QuestionnaireSectionNaming.letter(from: title) else {
                return AppColors.primaryBlue
            }
            switch letter {
            case "G": return .indigo
            case "H": return .mint
            case "I": return .cyan
            case "J": return .brown
            case "K": return .green
            default: return AppColors.primaryBlue
            }
        }
    }
}

// Extension to create Color with light/dark variants
extension Color {
    init(light: Color, dark: Color) {
        self.init(UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                return UIColor(dark)
            default:
                return UIColor(light)
            }
        })
    }
}

