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
    
    // Card backgrounds - semantic colors that adapt automatically
    static let cardBackground = Color(.systemBackground)
    static let cardBackgroundAccent = Color(.secondarySystemBackground)
    
    // Text colors - semantic
    static let primaryText = Color(.label)
    static let secondaryText = Color(.secondaryLabel)
    static let tertiaryText = Color(.tertiaryLabel)
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

