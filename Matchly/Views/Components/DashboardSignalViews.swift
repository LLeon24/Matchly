//
//  DashboardSignalViews.swift
//  Matchly
//
//  Per-specialty ERAS signal budget rows for dashboard Overview and Programs tabs.
//

import SwiftUI

// MARK: - Usage meter

struct DashboardSignalUsageMeter: View {
    let title: String
    let used: Int
    let limit: Int
    let color: Color

    private var remaining: Int { max(0, limit - used) }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.arial(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer(minLength: 0)
                Text("\(used)/\(limit)")
                    .font(.arial(size: 11, weight: .semibold))
                    .foregroundColor(used >= limit ? .red : .primary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(color.opacity(0.15))
                    Capsule()
                        .fill(used >= limit ? Color.red.opacity(0.75) : color)
                        .frame(width: limit > 0 ? geo.size.width * CGFloat(used) / CGFloat(limit) : 0)
                }
            }
            .frame(height: 5)

            Text(remaining == 0 ? "None left" : "\(remaining) left")
                .font(.arial(size: 10))
                .foregroundColor(remaining == 0 ? .red : .secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Per-specialty row

struct DashboardSignalBudgetRow: View {
    let summary: DataManager.SignalBudgetSummary
    var style: Style = .standard

    enum Style {
        case compact
        case standard
    }

    private var specialtyColor: Color {
        SpecialtyFormatter.color(for: summary.displayName)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: style == .compact ? 6 : 8) {
            HStack(spacing: 6) {
                Image(systemName: "stethoscope")
                    .font(.arial(size: 11, weight: .semibold))
                    .foregroundColor(specialtyColor)

                Text(SpecialtyFormatter.displayNameWithAbbreviation(summary.displayName))
                    .font(.arial(size: style == .compact ? 13 : 14, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Spacer(minLength: 4)

                if summary.usesResidencyCAS {
                    Text("CAS")
                        .font(.arial(size: 9, weight: .bold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.12))
                        .foregroundColor(.blue)
                        .clipShape(Capsule())
                }

                if style == .compact {
                    Text(compactUsageSummary)
                        .font(.arial(size: 11, weight: .semibold))
                        .foregroundColor(summary.totalRemaining == 0 ? .red : .secondary)
                }
            }

            if style == .standard {
                if summary.isTiered {
                    HStack(spacing: 12) {
                        DashboardSignalUsageMeter(
                            title: "Gold",
                            used: summary.goldUsed,
                            limit: summary.goldLimit,
                            color: .yellow
                        )
                        DashboardSignalUsageMeter(
                            title: "Silver",
                            used: summary.silverUsed,
                            limit: summary.silverLimit,
                            color: Color(white: 0.55)
                        )
                    }
                } else if summary.goldLimit > 0 {
                    DashboardSignalUsageMeter(
                        title: "Signals",
                        used: summary.goldUsed,
                        limit: summary.goldLimit,
                        color: AppColors.primaryBlue
                    )
                }

                if summary.requiresSignalStatement {
                    Label("Statement required", systemImage: "text.quote")
                        .font(.arial(size: 10))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, style == .compact ? 2 : 4)
    }

    private var compactUsageSummary: String {
        if summary.isTiered {
            return "\(summary.goldUsed)/\(summary.goldLimit)G · \(summary.silverUsed)/\(summary.silverLimit)S"
        }
        return "\(summary.goldUsed)/\(summary.goldLimit)"
    }
}

// MARK: - Overview condensed card

struct DashboardSignalsCondensedCard: View {
    let summaries: [DataManager.SignalBudgetSummary]
    var maxVisible: Int = 3

    var body: some View {
        NavigationLink(destination: AllSignaledProgramsView()) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    DashboardSectionHeader(
                        title: "Signal Budget",
                        icon: "star.circle.fill",
                        tint: AppColors.accentPurple
                    )
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.arial(size: 12))
                        .foregroundColor(.secondary.opacity(0.5))
                }

                VStack(spacing: 8) {
                    ForEach(Array(summaries.prefix(maxVisible).enumerated()), id: \.element.id) { index, summary in
                        DashboardSignalBudgetRow(summary: summary, style: .compact)
                        if index < min(summaries.count, maxVisible) - 1 {
                            Divider()
                        }
                    }
                }

                if summaries.count > maxVisible {
                    Text("+ \(summaries.count - maxVisible) more specialt\(summaries.count - maxVisible == 1 ? "y" : "ies")")
                        .font(.arial(size: 11, weight: .medium))
                        .foregroundColor(AppColors.primaryBlue)
                }

                let totalRemaining = summaries.map(\.totalRemaining).reduce(0, +)
                Text(totalRemaining == 0
                     ? "All signal slots used across your specialties"
                     : "\(totalRemaining) signal slot\(totalRemaining == 1 ? "" : "s") remaining total")
                    .font(.arial(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Programs tab detail block

struct DashboardSignalsDetailBlock: View {
    let summaries: [DataManager.SignalBudgetSummary]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            NavigationLink(destination: AllSignaledProgramsView()) {
                HStack {
                    Text("View all assigned signals")
                        .font(.arial(size: 13, weight: .semibold))
                        .foregroundColor(AppColors.primaryBlue)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.arial(size: 11))
                        .foregroundColor(.secondary.opacity(0.5))
                }
            }
            .buttonStyle(.plain)

            VStack(spacing: 14) {
                ForEach(Array(summaries.enumerated()), id: \.element.id) { index, summary in
                    DashboardSignalBudgetRow(summary: summary, style: .standard)
                    if index < summaries.count - 1 {
                        Divider()
                    }
                }
            }
        }
    }
}
