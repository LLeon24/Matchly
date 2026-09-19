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
    var style: DashboardSignalBudgetRow.Style = .standard

    private var remaining: Int { max(0, limit - used) }

    var body: some View {
        if style == .compact {
            compactBody
        } else {
            standardBody
        }
    }

    private var standardBody: some View {
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

            progressBar(height: 5)

            Text(remaining == 0 ? "None left" : "\(remaining) left")
                .font(.arial(size: 10))
                .foregroundColor(remaining == 0 ? .red : .secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var compactBody: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                if !title.isEmpty {
                    Text(title)
                        .font(.arial(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                }
                Spacer(minLength: 0)
                Text("\(used)/\(limit)")
                    .font(.arial(size: 10, weight: .semibold))
                    .foregroundColor(used >= limit ? .red : .secondary)
            }
            progressBar(height: 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func progressBar(height: CGFloat) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(color.opacity(0.15))
                Capsule()
                    .fill(used >= limit ? Color.red.opacity(0.75) : color)
                    .frame(width: limit > 0 ? geo.size.width * CGFloat(used) / CGFloat(limit) : 0)
            }
        }
        .frame(height: height)
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
        VStack(alignment: .leading, spacing: style == .compact ? 4 : 8) {
            HStack(spacing: 6) {
                Image(systemName: "stethoscope")
                    .font(.arial(size: style == .compact ? 10 : 11, weight: .semibold))
                    .foregroundColor(specialtyColor)

                Text(SpecialtyFormatter.displayNameWithAbbreviation(summary.displayName))
                    .font(.arial(size: style == .compact ? 12 : 14, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Spacer(minLength: 4)

                if summary.usesResidencyCAS {
                    Text("CAS")
                        .font(.arial(size: 8, weight: .bold))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.blue.opacity(0.12))
                        .foregroundColor(.blue)
                        .clipShape(Capsule())
                }

                if style == .compact, !summary.isTiered, summary.goldLimit > 0 {
                    Text("\(summary.goldUsed)/\(summary.goldLimit)")
                        .font(.arial(size: 11, weight: .semibold))
                        .foregroundColor(summary.goldUsed >= summary.goldLimit ? .red : .secondary)
                } else if style == .compact {
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
            } else {
                if summary.isTiered {
                    HStack(spacing: 8) {
                        DashboardSignalUsageMeter(
                            title: "Gold",
                            used: summary.goldUsed,
                            limit: summary.goldLimit,
                            color: .yellow,
                            style: .compact
                        )
                        DashboardSignalUsageMeter(
                            title: "Silver",
                            used: summary.silverUsed,
                            limit: summary.silverLimit,
                            color: Color(white: 0.55),
                            style: .compact
                        )
                    }
                } else if summary.goldLimit > 0 {
                    progressBarOnly(used: summary.goldUsed, limit: summary.goldLimit, color: AppColors.primaryBlue)
                }
            }
        }
        .padding(.vertical, style == .compact ? 0 : 4)
    }

    private func progressBarOnly(used: Int, limit: Int, color: Color) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(color.opacity(0.15))
                Capsule()
                    .fill(used >= limit ? Color.red.opacity(0.75) : color)
                    .frame(width: limit > 0 ? geo.size.width * CGFloat(used) / CGFloat(limit) : 0)
            }
        }
        .frame(height: 4)
    }

    private var compactUsageSummary: String {
        if summary.isTiered {
            return "\(summary.goldUsed)/\(summary.goldLimit)G · \(summary.silverUsed)/\(summary.silverLimit)S"
        }
        return "\(summary.goldUsed)/\(summary.goldLimit)"
    }
}

// MARK: - Dashboard detail block

struct DashboardSignalsDetailBlock: View {
    let summaries: [DataManager.SignalBudgetSummary]
    var style: DashboardSignalBudgetRow.Style = .compact

    var body: some View {
        VStack(alignment: .leading, spacing: style == .compact ? 8 : 12) {
            NavigationLink(destination: AllSignaledProgramsView()) {
                HStack {
                    Text("View all assigned signals")
                        .font(.arial(size: style == .compact ? 12 : 13, weight: .semibold))
                        .foregroundColor(AppColors.primaryBlue)
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            VStack(spacing: style == .compact ? 8 : 14) {
                ForEach(Array(summaries.enumerated()), id: \.element.id) { index, summary in
                    DashboardSignalBudgetRow(summary: summary, style: style)
                    if index < summaries.count - 1 {
                        Divider()
                    }
                }
            }
        }
    }
}
