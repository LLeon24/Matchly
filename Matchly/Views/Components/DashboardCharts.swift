//
//  DashboardCharts.swift
//  Matchly
//
//  Reusable, premium-feeling dashboard building blocks: a synced segmented
//  pill control, two hero stat layouts, and Swift Charts–based graphs
//  (application funnel + score distribution) plus a program-type split bar.
//
//  These views are intentionally decoupled from `DataManager`/`Program`: the
//  owning view computes plain values/arrays and hands them in. All colors are
//  semantic or `AppColors` so everything adapts to light & dark mode.
//

import SwiftUI
import Charts

// MARK: - Section Tab Bar (animated underline)

/// A clean, Monarch-style tab bar: three text labels with a short rounded
/// underline that slides between them via `matchedGeometryEffect`. The selected
/// label is bold + accent-colored. No boxed pill / heavy shadow. Stays in sync
/// with the paged `TabView` both ways (swipe animates the underline and taps
/// animate the page).
struct DashboardSectionTabBar: View {
    let titles: [String]
    @Binding var selection: Int
    var accent: Color = AppColors.primaryBlue

    @Namespace private var underlineNamespace

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            ForEach(titles.indices, id: \.self) { index in
                tab(index)
            }
        }
        .padding(.top, 6)
        .padding(.bottom, 4)
        // No full-width glass pill — `.regular` glass on a flat canvas reads as a
        // heavy gray slab. Keep this control airy: hairline + sliding underline only.
        .background(alignment: .bottom) {
            Rectangle()
                .fill(Color(.separator).opacity(0.25))
                .frame(height: 1)
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: selection)
    }

    @ViewBuilder
    private func tab(_ index: Int) -> some View {
        let isSelected = selection == index

        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                selection = index
            }
        } label: {
            VStack(spacing: 9) {
                Text(titles[index])
                    .font(.arial(size: 16, weight: isSelected ? .bold : .medium))
                    .foregroundColor(isSelected ? accent : .secondary)

                ZStack {
                    // Reserves height so the row doesn't jump between states.
                    Capsule()
                        .fill(Color.clear)
                        .frame(width: 28, height: 3)

                    if isSelected {
                        Capsule()
                            .fill(accent)
                            .frame(width: 28, height: 3)
                            .matchedGeometryEffect(id: "sectionUnderline", in: underlineNamespace)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Heroes

/// The Overview hero: a large number wrapped in a circular progress ring.
/// `progress` is 0...1; `bigNumber` is the formatted headline value.
struct DashboardRingHero: View {
    let score: Double
    let progress: Double
    let bigNumber: String
    let unit: String
    let title: String
    let subtitle: String

    private var gradientColors: [Color] { AppColors.scoreGradientColors(for: score) }
    private var tint: Color { AppColors.scoreTint(for: score) }

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                // Soft, tinted track (a light wash of the accent) — never flat gray.
                Circle()
                    .stroke((gradientColors.first ?? AppColors.primaryBlue).opacity(0.16), lineWidth: 16)
                    .frame(width: 210, height: 210)

                // Vibrant Activity-ring style gradient arc with rounded caps.
                Circle()
                    .trim(from: 0, to: min(max(progress, 0), 1))
                    .stroke(
                        AppColors.scoreRingGradient(for: score),
                        style: StrokeStyle(lineWidth: 16, lineCap: .round)
                    )
                    .frame(width: 210, height: 210)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.7, dampingFraction: 0.85), value: progress)

                VStack(spacing: 0) {
                    Text(bigNumber)
                        .font(.arial(size: 80, weight: .bold))
                        .foregroundStyle(AppColors.scoreLinearGradient(for: score))
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                    Text(unit)
                        .font(.arial(size: 13, weight: .semibold))
                        .foregroundColor(tint.opacity(0.9))
                        .textCase(.uppercase)
                }
            }

            VStack(spacing: 5) {
                Text(title)
                    .font(.arial(size: 24, weight: .bold))
                    .foregroundColor(.primary)
                Text(subtitle)
                    .font(.arial(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 2)
    }
}

/// A simple big-number hero (for counts that don't map to a 0...100 ring),
/// fronted by a soft tinted icon badge.
struct DashboardNumberHero: View {
    let bigNumber: String
    let unit: String
    let title: String
    let subtitle: String
    let icon: String
    let tint: Color

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.15))
                    .frame(width: 76, height: 76)
                Image(systemName: icon)
                    .font(.arial(size: 34, weight: .semibold))
                    .foregroundColor(tint)
                    .symbolRenderingMode(.hierarchical)
            }

            HStack(alignment: .firstTextBaseline, spacing: 7) {
                Text(bigNumber)
                    .font(.arial(size: 80, weight: .bold))
                    .foregroundStyle(tint.gradient)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.arial(size: 22, weight: .semibold))
                        .foregroundColor(.secondary)
                }
            }

            VStack(spacing: 5) {
                Text(title)
                    .font(.arial(size: 24, weight: .bold))
                    .foregroundColor(.primary)
                Text(subtitle)
                    .font(.arial(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 2)
    }
}

// MARK: - Application Funnel

struct FunnelStage: Identifiable {
    let id = UUID()
    let label: String
    let count: Int
    let color: Color
}

/// Horizontal Swift Charts bar "funnel": Total → Reviewed → Interviews → Ranked.
/// Stage order is preserved top-to-bottom regardless of Charts' default sorting.
struct ApplicationFunnelChart: View {
    let stages: [FunnelStage]

    private var maxCount: Int {
        max(stages.map(\.count).max() ?? 0, 1)
    }

    var body: some View {
        Chart(stages) { stage in
            BarMark(
                x: .value("Count", Double(stage.count)),
                y: .value("Stage", stage.label)
            )
            .foregroundStyle(stage.color.gradient)
            .cornerRadius(7)
            .annotation(position: .trailing, alignment: .leading, spacing: 6) {
                Text("\(stage.count)")
                    .font(.arial(size: 13, weight: .bold))
                    .foregroundColor(stage.color)
            }
        }
        // First domain entry sits at the bottom, so reverse to keep "Total" on top.
        .chartYScale(domain: Array(stages.map(\.label).reversed()))
        // Pad the x range so the trailing count annotations aren't clipped.
        .chartXScale(domain: 0...(Double(maxCount) * 1.15))
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisValueLabel()
                    .font(.arial(size: 12, weight: .medium))
            }
        }
        .frame(height: CGFloat(stages.count) * 40 + 12)
    }
}

// MARK: - Score Distribution

struct ScoreBucket: Identifiable {
    let id = UUID()
    let range: String
    let count: Int
    let color: Color
}

/// Vertical Swift Charts histogram of program `finalScore` buckets.
struct ScoreDistributionChart: View {
    let buckets: [ScoreBucket]

    private var maxCount: Int {
        max(buckets.map(\.count).max() ?? 0, 1)
    }

    var body: some View {
        Chart(buckets) { bucket in
            BarMark(
                x: .value("Range", bucket.range),
                y: .value("Programs", Double(bucket.count)),
                width: .ratio(0.62)
            )
            .foregroundStyle(bucket.color.gradient)
            .cornerRadius(6)
            .annotation(position: .top, spacing: 4) {
                if bucket.count > 0 {
                    Text("\(bucket.count)")
                        .font(.arial(size: 11, weight: .bold))
                        .foregroundColor(bucket.color)
                }
            }
        }
        .chartXScale(domain: buckets.map(\.range))
        .chartYScale(domain: 0...(Double(maxCount) + 0.6))
        .chartYAxis(.hidden)
        .chartXAxis {
            AxisMarks { _ in
                AxisValueLabel()
                    .font(.arial(size: 11, weight: .medium))
            }
        }
        .frame(height: 170)
    }
}

// MARK: - Program Type Split

/// A slim stacked bar comparing Academic / Community / Hybrid program counts,
/// with a compact legend below. Zero-count segments collapse gracefully.
struct ProgramTypeSplit: View {
    let academic: Int
    let community: Int
    let hybrid: Int

    private var total: Int { max(academic + community + hybrid, 1) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            GeometryReader { geo in
                HStack(spacing: 2) {
                    segment(count: academic, width: geo.size.width, color: AppColors.primaryBlue)
                    segment(count: community, width: geo.size.width, color: AppColors.accentTeal)
                    segment(count: hybrid, width: geo.size.width, color: AppColors.accentPurple)
                }
            }
            .frame(height: 16)

            HStack(spacing: 18) {
                legend(label: "Academic", count: academic, color: AppColors.primaryBlue)
                legend(label: "Community", count: community, color: AppColors.accentTeal)
                if hybrid > 0 {
                    legend(label: "Hybrid", count: hybrid, color: AppColors.accentPurple)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func segment(count: Int, width: CGFloat, color: Color) -> some View {
        Capsule()
            .fill(color.gradient)
            .frame(width: max(width * CGFloat(count) / CGFloat(total), count > 0 ? 6 : 0))
    }

    private func legend(label: String, count: Int, color: Color) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 9, height: 9)
            Text("\(label) \(count)")
                .font(.arial(size: 12, weight: .medium))
                .foregroundColor(.secondary)
        }
    }
}
