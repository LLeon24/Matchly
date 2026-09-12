//
//  ProgramStyle.swift
//  Matchly
//
//  Shared styling helpers (score/rank colors, program type color & icon).
//  Previously these identical helpers were duplicated privately across ~10 views.
//

import SwiftUI
import UIKit

/// Color for a program's final score (0–100 scale).
func scoreColor(_ score: Double) -> Color {
    if score >= 80 { return .green }
    if score >= 60 { return .blue }
    if score >= 40 { return .orange }
    return .red
}

/// UIKit twin of `scoreColor` for PDF / share rendering.
func scoreUIColor(_ score: Double) -> UIColor {
    UIColor(scoreColor(score))
}

/// Color for a program's rank position in the rank list.
func rankColor(_ rank: Int) -> Color {
    if rank <= 3 { return .green }
    if rank <= 10 { return .blue }
    return .gray
}

/// UIKit twin of `rankColor` for PDF / share rendering.
func rankUIColor(_ rank: Int) -> UIColor {
    UIColor(rankColor(rank))
}

/// Specialty accent as UIKit color.
func specialtyUIColor(for specialty: String) -> UIColor {
    UIColor(SpecialtyFormatter.color(for: specialty))
}

/// Accent color for a program type (Academic / Community / Hybrid).
func programTypeColor(_ type: String) -> Color {
    switch type {
    case "Academic": return .blue
    case "Community": return .green
    case "Hybrid": return .orange
    default: return .secondary
    }
}

/// SF Symbol name for a program type (Academic / Community / Hybrid).
func programTypeIcon(_ type: String) -> String {
    switch type {
    case "Academic": return "graduationcap.fill"
    case "Community": return "house.fill"
    case "Hybrid": return "square.stack.3d.up.fill"
    default: return "building.2.fill"
    }
}

/// Consistent IMG badge for saved programs (`IMG` vs `IMG Likely`).
struct SavedProgramIMGBadge: View {
    let program: Program
    var iconSize: CGFloat = 8
    var textSize: CGFloat = 10

    var body: some View {
        let imgDisplay = IMGStatusDisplay.forSavedProgram(program)
        if imgDisplay != .none {
            HStack(spacing: 3) {
                Image(systemName: "globe.americas.fill")
                    .font(.arial(size: iconSize))
                Text(imgDisplay.label)
                    .font(.arial(size: textSize, weight: .medium))
            }
            .foregroundColor(imgDisplay.color)
        }
    }
}
