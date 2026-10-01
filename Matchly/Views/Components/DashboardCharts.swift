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

/// Text-only section tabs with a tinted rounded box on the selected label.
/// Stays in sync with the paged `TabView` (swipe or tap).
struct DashboardSectionTabBar: View {
    let titles: [String]
    @Binding var selection: Int
    var accent: Color = AppColors.primaryBlue
    var tabAccents: [Color]? = nil
    @Environment(\.matchlyLayout) private var layout

    @Namespace private var selectionNamespace

    var body: some View {
        HStack(spacing: 6) {
            ForEach(titles.indices, id: \.self) { index in
                tab(index)
            }
        }
        .padding(.horizontal, layout == .compactVertical ? 6 : 8)
        .padding(.vertical, layout == .compactVertical ? 6 : 8)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground).opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color(.separator).opacity(0.35), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: selection)
    }

    private func tabAccent(for index: Int) -> Color {
        if let tabAccents, index < tabAccents.count {
            return tabAccents[index]
        }
        return accent
    }

    @ViewBuilder
    private func tab(_ index: Int) -> some View {
        let isSelected = selection == index
        let tabColor = tabAccent(for: index)

        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                selection = index
            }
        } label: {
            Text(titles[index])
                .font(.arial(size: layout.sectionTabFont, weight: isSelected ? .regular : .light))
                .foregroundColor(isSelected ? tabColor.opacity(0.82) : Color.primary.opacity(0.45))
                .kerning(isSelected ? 0.5 : 0.3)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .padding(.vertical, layout == .compactVertical ? 10 : 12)
                .padding(.horizontal, layout == .compactVertical ? 6 : 8)
                .frame(maxWidth: .infinity)
                .background {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(tabColor.opacity(0.09))
                            .matchedGeometryEffect(id: "sectionTabFill", in: selectionNamespace)
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// iPhone-style page dots for the dashboard section pager. Sits below the
/// Overview / Programs / Interviews tabs and above the scrolling page content.
struct DashboardSectionPageIndicator: View {
    let count: Int
    @Binding var selection: Int
    var tabAccents: [Color]? = nil
    var accent: Color = AppColors.primaryBlue

    var body: some View {
        HStack(spacing: 7) {
            ForEach(0..<count, id: \.self) { index in
                Circle()
                    .fill(fillColor(for: index))
                    .frame(
                        width: index == selection ? 8 : 6,
                        height: index == selection ? 8 : 6
                    )
                    .animation(.spring(response: 0.32, dampingFraction: 0.82), value: selection)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Section \(selection + 1) of \(count)")
        .accessibilityValue(accessibilitySectionName)
    }

    private var accessibilitySectionName: String {
        switch selection {
        case 0: return "Overview"
        case 1: return "Programs"
        case 2: return "Interviews"
        default: return ""
        }
    }

    private func fillColor(for index: Int) -> Color {
        let sectionColor: Color
        if let tabAccents, index < tabAccents.count {
            sectionColor = tabAccents[index]
        } else {
            sectionColor = accent
        }

        if index == selection {
            return sectionColor.opacity(0.55)
        }
        return Color.primary.opacity(0.18)
    }
}

/// Refined section summary: obvious headline stat without the full-page hero footprint.
struct DashboardSectionSummaryHero: View {
    let icon: String
    let tint: Color
    let bigNumber: String
    var unit: String = ""
    let title: String
    let subtitle: String
    var metrics: [DashboardSummaryMetric] = []
    @Environment(\.matchlyLayout) private var layout

    private var iconSize: CGFloat { layout == .compactVertical ? 50 : 56 }
    private var iconFont: CGFloat { layout == .compactVertical ? 20 : 24 }
    private var numberFont: CGFloat { layout == .compactVertical ? 34 : 40 }
    private var titleFont: CGFloat { layout == .compactVertical ? 15 : 17 }
    private var subtitleFont: CGFloat { layout == .compactVertical ? 12 : 13 }
    private var metricValueFont: CGFloat { layout == .compactVertical ? 16 : 18 }

    var body: some View {
        VStack(spacing: layout == .compactVertical ? 10 : 12) {
            HStack(alignment: .center, spacing: 14) {
                ZStack {
                    Circle()
                        .fill(tint.opacity(0.14))
                        .frame(width: iconSize, height: iconSize)
                    Image(systemName: icon)
                        .font(.arial(size: iconFont, weight: .semibold))
                        .foregroundColor(tint)
                        .symbolRenderingMode(.hierarchical)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        Text(bigNumber)
                            .font(.arial(size: numberFont, weight: .bold))
                            .foregroundStyle(tint.gradient)
                            .minimumScaleFactor(0.6)
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

                    Text(subtitle)
                        .font(.arial(size: subtitleFont))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)
            }

            if !metrics.isEmpty {
                Divider()
                    .overlay(Color(.separator).opacity(0.35))

                HStack(spacing: 0) {
                    ForEach(Array(metrics.enumerated()), id: \.element.id) { index, metric in
                        if index > 0 {
                            Spacer(minLength: 8)
                        }
                        summaryMetric(metric)
                        if index < metrics.count - 1 {
                            Spacer(minLength: 8)
                        }
                    }
                }
            }
        }
        .padding(.vertical, layout == .compactVertical ? 12 : 14)
        .padding(.horizontal, 4)
    }

    private func summaryMetric(_ metric: DashboardSummaryMetric) -> some View {
        VStack(spacing: 2) {
            Text(metric.value)
                .font(.arial(size: metricValueFont, weight: .bold))
                .foregroundColor(metric.tint)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(metric.label)
                .font(.arial(size: 11, weight: .medium))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }
}

struct DashboardSummaryMetric: Identifiable {
    let id = UUID()
    let value: String
    let label: String
    let tint: Color
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
            return [accentTint, accentTint]
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
                MatchlyHeroTitle(title: title, size: layout.heroTitleFont)
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

/// One slice of the season hero ring — sized as a fraction of the full circle (0...1).
struct DashboardSnapshotRingSegment: Identifiable {
    let id: String
    let fraction: Double
    let color: Color
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
    var nextInterviewProgram: Program? = nil
    var ringSegments: [DashboardSnapshotRingSegment] = []
    let stats: [DashboardSnapshotStat]
    var accentTint: Color = AppColors.accentGreen
    var onStatTap: ((InterviewSeasonStage) -> Void)? = nil
    @Environment(\.matchlyLayout) private var layout

    /// Editorial card rhythm — left-aligned, action-first.
    private enum HeroSpacing {
        static let contentToStats: CGFloat = 16
        static let inset: CGFloat = 14
        static let labelToRow: CGFloat = 10
        static let headerText: CGFloat = 6

        /// Card top→logo and season row→next interview.
        static func sectionGap(for layout: MatchlyLayoutStyle) -> CGFloat {
            layout == .compactVertical ? 10 : 12
        }

        /// Logo bottom→season title.
        static func logoToSeasonGap(for layout: MatchlyLayoutStyle) -> CGFloat {
            -5
        }
    }

    private var compactRingSize: CGFloat { layout == .compactVertical ? 56 : 76 }
    private var compactRingLineWidth: CGFloat { layout == .compactVertical ? 6 : 8 }
    private var compactRingNumberFont: CGFloat { layout == .compactVertical ? 22 : 28 }
    private var compactRingUnitFont: CGFloat { layout == .compactVertical ? 8 : 9 }

    private var usesSegmentedRing: Bool { !ringSegments.isEmpty }

    private var gradientColors: [Color] {
        [accentTint, accentTint]
    }

    private var ringGradient: AngularGradient {
        AngularGradient(
            gradient: Gradient(colors: gradientColors),
            center: .center,
            startAngle: .degrees(-90),
            endAngle: .degrees(270)
        )
    }

    private var segmentedRingFill: Double {
        min(max(ringSegments.reduce(0) { $0 + $1.fraction }, 0), 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            heroBrandBlock

            statsRow
                .padding(.top, HeroSpacing.contentToStats)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var heroBrandBlock: some View {
        let gap = HeroSpacing.sectionGap(for: layout)
        let logoGap = HeroSpacing.logoToSeasonGap(for: layout)

        return VStack(alignment: .leading, spacing: 0) {
            MatchlyBrandInlineWordmark(glyphSize: .hero)
                .padding(.top, gap - layout.cardVerticalPadding)

            ZStack(alignment: .bottomTrailing) {
                seasonTitleBlock
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.trailing, compactRingSize + 12)

                compactSeasonRing
            }
            .padding(.top, logoGap)

            if nextInterviewProgram != nil {
                nextInterviewCard
                    .padding(.top, gap)
            }
        }
    }

    private var seasonTitleBlock: some View {
        VStack(alignment: .leading, spacing: HeroSpacing.headerText) {
            MatchlyContentSectionTitle(title: title)

            Text(progressCaption)
                .font(.arial(size: layout.heroCaptionFont, weight: .regular))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var nextInterviewCard: some View {
        if let program = nextInterviewProgram {
            VStack(alignment: .leading, spacing: HeroSpacing.labelToRow) {
                MatchlySectionHeaderText(title: "Next Interview")

                NavigationLink(destination: ProgramEntryView(program: program)) {
                    InterviewRow(program: program, isUpcoming: true, style: .featured)
                }
                .buttonStyle(.plain)
            }
            .padding(HeroSpacing.inset)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.secondary.opacity(0.06))
            )
        }
    }

    private var compactSeasonRing: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.14), lineWidth: compactRingLineWidth)
                .frame(width: compactRingSize, height: compactRingSize)

            if usesSegmentedRing {
                segmentedRingArcs
            } else {
                Circle()
                    .trim(from: 0, to: min(max(progress, 0), 1))
                    .stroke(
                        ringGradient,
                        style: StrokeStyle(lineWidth: compactRingLineWidth, lineCap: .round)
                    )
                    .frame(width: compactRingSize, height: compactRingSize)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.7, dampingFraction: 0.85), value: progress)
            }

            VStack(spacing: 0) {
                Text(bigNumber)
                    .font(.arial(size: compactRingNumberFont, weight: .bold))
                    .foregroundStyle(centerNumberStyle)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.arial(size: compactRingUnitFont, weight: .semibold))
                        .foregroundColor(usesSegmentedRing ? .secondary : accentTint)
                        .textCase(.uppercase)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            .padding(.horizontal, 2)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(bigNumber) \(unit). \(progressCaption)")
    }

    private var centerNumberStyle: AnyShapeStyle {
        if usesSegmentedRing {
            return AnyShapeStyle(Color.primary)
        }
        return AnyShapeStyle(
            LinearGradient(
                colors: gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    private var segmentedRingArcs: some View {
        Circle()
            .trim(from: 0, to: segmentedRingFill)
            .stroke(
                blendedSegmentGradient(),
                style: StrokeStyle(lineWidth: compactRingLineWidth, lineCap: .round)
            )
            .frame(width: compactRingSize, height: compactRingSize)
            .rotationEffect(.degrees(-90))
            .animation(.spring(response: 0.7, dampingFraction: 0.85), value: segmentedRingFill)
    }

    private func blendedSegmentGradient() -> AngularGradient {
        let segments = ringSegments
        guard !segments.isEmpty else {
            return AngularGradient(
                gradient: Gradient(colors: [accentTint]),
                center: .center,
                startAngle: .degrees(-90),
                endAngle: .degrees(270)
            )
        }

        var stops: [Gradient.Stop] = []
        var cursor: Double = 0

        for segment in segments {
            let end = min(cursor + segment.fraction, 1)
            stops.append(.init(color: segment.color, location: cursor))
            stops.append(.init(color: segment.color, location: end))
            cursor = end
        }

        let sorted = stops.sorted { $0.location < $1.location }
        return AngularGradient(
            gradient: Gradient(stops: sorted),
            center: .center,
            startAngle: .degrees(-90),
            endAngle: .degrees(270)
        )
    }

    @ViewBuilder
    private var statsRow: some View {
        if !stats.isEmpty {
            HStack(spacing: 0) {
                ForEach(stats) { stat in
                    statCell(stat)
                }
            }
        }
    }

    @ViewBuilder
    private func statCell(_ stat: DashboardSnapshotStat) -> some View {
        let content = VStack(spacing: 2) {
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

        if let stage = InterviewSeasonStage(rawValue: stat.id), let onStatTap {
            Button {
                onStatTap(stage)
            } label: {
                content
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
        } else {
            content
        }
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
                            .font(MatchlyEditorialTypography.displayFont(size: titleFont))
                            .foregroundColor(.primary)
                            .kerning(MatchlyEditorialTypography.heroTitleKerning(for: titleFont))
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
                        MatchlyHeroTitle(title: title, size: titleFont)
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
