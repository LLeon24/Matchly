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
    @Environment(\.matchlyLayout) private var layout

    @Namespace private var underlineNamespace

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            ForEach(titles.indices, id: \.self) { index in
                tab(index)
            }
        }
        .padding(.top, layout == .compactVertical ? 2 : 6)
        .padding(.bottom, layout == .compactVertical ? 2 : 4)
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
            VStack(spacing: layout.sectionTabSpacing) {
                Text(titles[index])
                    .font(.arial(size: layout.sectionTabFont, weight: isSelected ? .bold : .medium))
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
/// Pass `accentTint` for non-score metrics (program counts, completion, etc.).
struct DashboardRingHero: View {
    var score: Double = 0
    let progress: Double
    let bigNumber: String
    let unit: String
    let title: String
    let subtitle: String
    var accentTint: Color? = nil
    @Environment(\.matchlyLayout) private var layout

    private var gradientColors: [Color] {
        if let accentTint {
            return [accentTint, accentTint.opacity(0.65)]
        }
        return AppColors.scoreGradientColors(for: score)
    }

    private var tint: Color { accentTint ?? AppColors.scoreTint(for: score) }

    private var ringGradient: AngularGradient {
        if accentTint != nil {
            return AngularGradient(
                gradient: Gradient(colors: gradientColors),
                center: .center,
                startAngle: .degrees(-90),
                endAngle: .degrees(270)
            )
        }
        return AppColors.scoreRingGradient(for: score)
    }

    private var numberGradient: LinearGradient {
        if accentTint != nil {
            return LinearGradient(
                colors: gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        return AppColors.scoreLinearGradient(for: score)
    }

    var body: some View {
        VStack(spacing: layout == .compactVertical ? 8 : 14) {
            ZStack {
                // Soft, tinted track (a light wash of the accent) — never flat gray.
                Circle()
                    .stroke((gradientColors.first ?? AppColors.primaryBlue).opacity(0.16), lineWidth: layout.heroRingLineWidth)
                    .frame(width: layout.heroRingSize, height: layout.heroRingSize)

                // Vibrant Activity-ring style gradient arc with rounded caps.
                Circle()
                    .trim(from: 0, to: min(max(progress, 0), 1))
                    .stroke(
                        ringGradient,
                        style: StrokeStyle(lineWidth: layout.heroRingLineWidth, lineCap: .round)
                    )
                    .frame(width: layout.heroRingSize, height: layout.heroRingSize)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.7, dampingFraction: 0.85), value: progress)

                VStack(spacing: 0) {
                    Text(bigNumber)
                        .font(.arial(size: layout.heroBigNumberFont, weight: .bold))
                        .foregroundStyle(numberGradient)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                    if !unit.isEmpty {
                        Text(unit)
                            .font(.arial(size: layout.heroUnitFont, weight: .semibold))
                            .foregroundColor(tint.opacity(0.9))
                            .textCase(.uppercase)
                    }
                }
            }

            VStack(spacing: layout == .compactVertical ? 3 : 5) {
                Text(title)
                    .font(.arial(size: layout.heroTitleFont, weight: .bold))
                    .foregroundColor(.primary)
                Text(subtitle)
                    .font(.arial(size: layout.heroSubtitleFont))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 2)
    }
}

/// One metric in the Overview snapshot stat row.
struct DashboardSnapshotStat: Identifiable {
    let id: String
    let value: String
    let label: String
    let tint: Color
}

/// Overview hero: upcoming interviews front-and-center, ring shows season progress,
/// and a four-up stat row for programs, rank list, completed interviews, and scoring.
struct DashboardSnapshotHero: View {
    let progress: Double
    let progressCaption: String
    let bigNumber: String
    let unit: String
    let title: String
    let subtitle: String
    let stats: [DashboardSnapshotStat]
    var accentTint: Color = AppColors.accentGreen
    @Environment(\.matchlyLayout) private var layout

    private var gradientColors: [Color] {
        [accentTint, accentTint.opacity(0.65)]
    }

    private var ringGradient: AngularGradient {
        AngularGradient(
            gradient: Gradient(colors: gradientColors),
            center: .center,
            startAngle: .degrees(-90),
            endAngle: .degrees(270)
        )
    }

    var body: some View {
        Group {
            if layout == .compactVertical {
                compactBody
            } else {
                standardBody
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 2)
    }

    private var standardBody: some View {
        let heroMidSpacing: CGFloat = 12
        return VStack(spacing: 0) {
            heroRing

            Text(progressCaption)
                .font(.arial(size: layout.heroCaptionFont, weight: .medium))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .padding(.top, heroMidSpacing)
                .padding(.bottom, heroMidSpacing)

            VStack(spacing: 5) {
                Text(title)
                    .font(.arial(size: layout.heroTitleFont, weight: .bold))
                    .foregroundColor(.primary)
                Text(subtitle)
                    .font(.arial(size: layout.heroSubtitleFont))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            statsRow
        }
    }

    private var compactBody: some View {
        HStack(alignment: .center, spacing: 16) {
            ringBlock
                .frame(width: layout.heroRingSize + 8)

            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.arial(size: layout.heroTitleFont, weight: .bold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Text(subtitle)
                        .font(.arial(size: layout.heroSubtitleFont))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                statsGrid
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var ringBlock: some View {
        VStack(spacing: 8) {
            heroRing
            progressCaptionLabel
        }
    }

    private var heroRing: some View {
        ZStack {
            Circle()
                .stroke(gradientColors[0].opacity(0.16), lineWidth: layout.heroRingLineWidth)
                .frame(width: layout.heroRingSize, height: layout.heroRingSize)

            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(
                    ringGradient,
                    style: StrokeStyle(lineWidth: layout.heroRingLineWidth, lineCap: .round)
                )
                .frame(width: layout.heroRingSize, height: layout.heroRingSize)
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.7, dampingFraction: 0.85), value: progress)

            VStack(spacing: 0) {
                Text(bigNumber)
                    .font(.arial(size: layout.heroBigNumberFont, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: gradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.arial(size: layout.heroUnitFont, weight: .semibold))
                        .foregroundColor(accentTint.opacity(0.9))
                        .textCase(.uppercase)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            .padding(.horizontal, 4)
        }
    }

    private var progressCaptionLabel: some View {
        Text(progressCaption)
            .font(.arial(size: layout.heroCaptionFont, weight: .medium))
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .minimumScaleFactor(0.85)
    }

    @ViewBuilder
    private var statsRow: some View {
        if !stats.isEmpty {
            HStack(spacing: 0) {
                ForEach(stats) { stat in
                    statCell(stat)
                }
            }
            .padding(.top, 4)
        }
    }

    @ViewBuilder
    private var statsGrid: some View {
        if !stats.isEmpty {
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 8),
                    GridItem(.flexible(), spacing: 8)
                ],
                spacing: 8
            ) {
                ForEach(stats) { stat in
                    statCell(stat)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private func statCell(_ stat: DashboardSnapshotStat) -> some View {
        VStack(spacing: 2) {
            Text(stat.value)
                .font(.arial(size: layout.heroStatValueFont, weight: .bold))
                .foregroundColor(stat.tint)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(stat.label)
                .font(.arial(size: layout.heroStatLabelFont, weight: .medium))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
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
    var condensed: Bool = false
    @Environment(\.matchlyLayout) private var layout

    private var usesHorizontalLayout: Bool {
        condensed || layout == .compactVertical
    }

    private var iconSize: CGFloat {
        condensed ? 48 : layout.numberHeroIconSize
    }

    private var iconFont: CGFloat {
        condensed ? 20 : layout.numberHeroIconFont
    }

    private var numberFont: CGFloat {
        condensed ? 36 : layout.heroBigNumberFont
    }

    private var titleFont: CGFloat {
        condensed ? 16 : layout.heroTitleFont
    }

    private var subtitleFont: CGFloat {
        condensed ? 12 : layout.heroSubtitleFont
    }

    var body: some View {
        Group {
            if usesHorizontalLayout {
                HStack(alignment: .center, spacing: condensed ? 12 : 16) {
                    ZStack {
                        Circle()
                            .fill(tint.opacity(0.15))
                            .frame(width: iconSize, height: iconSize)
                        Image(systemName: icon)
                            .font(.arial(size: iconFont, weight: .semibold))
                            .foregroundColor(tint)
                            .symbolRenderingMode(.hierarchical)
                    }

                    VStack(alignment: .leading, spacing: condensed ? 2 : 4) {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(bigNumber)
                                .font(.arial(size: numberFont, weight: .bold))
                                .foregroundStyle(tint.gradient)
                                .minimumScaleFactor(0.5)
                                .lineLimit(1)
                            if !unit.isEmpty {
                                Text(unit)
                                    .font(.arial(size: titleFont, weight: .semibold))
                                    .foregroundColor(.secondary)
                            }
                        }
                        Text(title)
                            .font(.arial(size: titleFont, weight: .bold))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        Text(subtitle)
                            .font(.arial(size: subtitleFont))
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                VStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(tint.opacity(0.15))
                            .frame(width: iconSize, height: iconSize)
                        Image(systemName: icon)
                            .font(.arial(size: iconFont, weight: .semibold))
                            .foregroundColor(tint)
                            .symbolRenderingMode(.hierarchical)
                    }

                    HStack(alignment: .firstTextBaseline, spacing: 7) {
                        Text(bigNumber)
                            .font(.arial(size: numberFont, weight: .bold))
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
                            .font(.arial(size: titleFont, weight: .bold))
                            .foregroundColor(.primary)
                        Text(subtitle)
                            .font(.arial(size: subtitleFont))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, condensed ? 0 : 2)
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
    var chartHeight: CGFloat = 170

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
        .frame(height: chartHeight)
    }
}

// MARK: - Program Type Split (legacy — kept for reference if user data still has types)

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
