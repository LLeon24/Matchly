//
//  EMRBadgeView.swift
//  Matchly
//
//  Compact EMR badges for tables and detail views.
//  Uses monograms and brand-inspired colors — not vendor logo artwork.
//

import SwiftUI

extension EMRSystem {
    /// Short label for narrow compare-table cells.
    var compactDisplayName: String {
        switch self {
        case .epic: return "Epic"
        case .oracleCerner: return "Cerner"
        case .meditech: return "MEDITECH"
        case .veradigmAllscripts: return "Veradigm"
        case .athenahealth: return "athena"
        case .eClinicalWorks: return "eCW"
        case .nextGen: return "NextGen"
        case .cpsiEvident: return "CPSI"
        case .other: return "Other"
        case .notSure: return "Not sure"
        }
    }

    /// Single-letter monogram for badge circles (not an official logo).
    var monogram: String {
        switch self {
        case .epic: return "E"
        case .oracleCerner: return "C"
        case .meditech: return "M"
        case .veradigmAllscripts: return "V"
        case .athenahealth: return "A"
        case .eClinicalWorks: return "e"
        case .nextGen: return "N"
        case .cpsiEvident: return "P"
        case .other: return "?"
        case .notSure: return "?"
        }
    }

    /// Brand-inspired accent colors for badges. Not official brand assets.
    var brandAccentColor: Color {
        switch self {
        case .epic: return Color(red: 0.89, green: 0.10, blue: 0.22)
        case .oracleCerner: return Color(red: 0.98, green: 0.45, blue: 0.09)
        case .meditech: return Color(red: 0.00, green: 0.45, blue: 0.74)
        case .veradigmAllscripts: return Color(red: 0.18, green: 0.55, blue: 0.34)
        case .athenahealth: return Color(red: 0.55, green: 0.24, blue: 0.68)
        case .eClinicalWorks: return Color(red: 0.10, green: 0.55, blue: 0.45)
        case .nextGen: return Color(red: 0.00, green: 0.35, blue: 0.65)
        case .cpsiEvident: return Color(red: 0.20, green: 0.40, blue: 0.70)
        case .other, .notSure: return .secondary
        }
    }
}

struct EMRBadgeView: View {
    enum Style {
        case compact
        case regular
    }

    let system: EMRSystem
    var style: Style = .regular

    private var badgeSize: CGFloat {
        style == .compact ? 24 : 30
    }

    private var nameFontSize: CGFloat {
        style == .compact ? 9 : 13
    }

    var body: some View {
        VStack(spacing: style == .compact ? 3 : 5) {
            ZStack {
                Circle()
                    .fill(system.brandAccentColor.opacity(0.16))
                    .frame(width: badgeSize, height: badgeSize)

                Text(system.monogram)
                    .font(.arial(size: badgeSize * 0.46, weight: .bold))
                    .foregroundColor(system.brandAccentColor)
            }

            Text(system.compactDisplayName)
                .font(.arial(size: nameFontSize, weight: .semibold))
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.65)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityLabel(system.displayName)
    }
}

struct EMRValueView: View {
    let rawValue: String?
    var style: EMRBadgeView.Style = .regular

    var body: some View {
        if let rawValue, let system = EMRSystem(rawValue: rawValue), system != .other {
            EMRBadgeView(system: system, style: style)
        } else if let rawValue, !rawValue.isEmpty {
            // Custom typed name (or bare "Other") — show as text, with Other badge styling when empty custom.
            if rawValue == EMRSystem.other.rawValue {
                EMRBadgeView(system: .other, style: style)
            } else {
                VStack(spacing: style == .compact ? 3 : 5) {
                    ZStack {
                        Circle()
                            .fill(Color.secondary.opacity(0.16))
                            .frame(width: style == .compact ? 24 : 30, height: style == .compact ? 24 : 30)
                        Text("?")
                            .font(.arial(size: (style == .compact ? 24 : 30) * 0.46, weight: .bold))
                            .foregroundColor(.secondary)
                    }
                    Text(rawValue)
                        .font(.arial(size: style == .compact ? 9 : 13, weight: .semibold))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.65)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityLabel(rawValue)
            }
        } else {
            Text("Not set")
                .font(.arial(size: style == .compact ? 11 : 14, weight: .semibold))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}
