//
//  ProgramComparisonView.swift
//  Matchly
//
//  Created on 11/14/25.
//

import SwiftUI

struct ProgramComparisonView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var selectedPrograms: Set<String> = []
    @State private var showProgramPicker = false

    private static let programAccentColors: [Color] = [
        AppColors.primaryBlue,
        AppColors.accentOrange,
        .purple,
        .green
    ]

    var comparisonPrograms: [Program] {
        dataManager.programs.filter { selectedPrograms.contains($0.id) }
    }

    var body: some View {
        MatchlyNavigationView {
            VStack(spacing: 0) {
                if selectedPrograms.isEmpty {
                    emptyState
                } else {
                    comparisonContent
                }
            }
            .navigationTitle("Compare Programs")
            .appCanvasBackground()
            .onAppear {
                dataManager.recalculateAllScores()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !selectedPrograms.isEmpty {
                        Menu {
                            Button(action: {
                                showProgramPicker = true
                            }) {
                                Label("Add Program", systemImage: "plus")
                            }

                            Button(role: .destructive, action: {
                                selectedPrograms.removeAll()
                            }) {
                                Label("Clear All", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
            .sheet(isPresented: $showProgramPicker) {
                ProgramComparisonPickerView(
                    selectedPrograms: $selectedPrograms,
                    currentSelections: selectedPrograms
                )
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "square.grid.2x2")
                .font(.arial(size: 60))
                .foregroundColor(.secondary)

            Text("Compare Programs")
                .font(.arial(size: 24, weight: .semibold))

            Text("Select 2–4 programs to compare scores and details side by side")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button(action: {
                showProgramPicker = true
            }) {
                Text("Select Programs")
                    .font(.arial(size: 18, weight: .semibold))
                    .padding(.horizontal, 30)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.glassProminent)
            .tint(AppColors.primaryBlue)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private let metricLabelWidth: CGFloat = 104

    private var comparisonContent: some View {
        ScrollView {
            VStack(spacing: 12) {
                programsHeaderSection
                scoreMatrixSection

                if comparisonPrograms.count < 4 {
                    addProgramButton
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 12)
        }
        .matchlyScrollTabBarClearance()
    }

    private var programsHeaderSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Selected Programs")
                .font(.arial(size: 13, weight: .semibold))
                .foregroundColor(.secondary)

            ForEach(Array(comparisonPrograms.enumerated()), id: \.element.id) { index, program in
                ComparisonProgramHeaderRow(
                    program: program,
                    index: index,
                    accentColor: accentColor(for: index),
                    onRemove: {
                        selectedPrograms.remove(program.id)
                    }
                )

                if index < comparisonPrograms.count - 1 {
                    Divider()
                }
            }
        }
        .dashboardCardStyle()
    }

    private var scoreMatrixSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Score Comparison")
                .font(.arial(size: 13, weight: .semibold))
                .foregroundColor(.secondary)

            if comparisonPrograms.count >= 3 {
                columnKeyRow
            }

            scoreMatrixHeaderRow

            ForEach(Array(metrics.enumerated()), id: \.element.id) { rowIndex, metric in
                scoreMatrixRow(metric, shaded: rowIndex.isMultiple(of: 2))

                if rowIndex < metrics.count - 1 {
                    Divider()
                        .padding(.leading, metricLabelWidth + 8)
                }
            }
        }
        .dashboardCardStyle()
    }

    private var columnKeyRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(comparisonPrograms.enumerated()), id: \.element.id) { index, program in
                    ComparisonColumnKeyPill(
                        index: index,
                        label: ComparisonProgramLabel.shortLabel(for: program, among: comparisonPrograms),
                        accentColor: accentColor(for: index)
                    )
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var scoreMatrixHeaderRow: some View {
        HStack(spacing: 8) {
            Text("Metric")
                .font(.arial(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .frame(width: metricLabelWidth, alignment: .leading)

            ForEach(Array(comparisonPrograms.enumerated()), id: \.element.id) { index, program in
                ComparisonColorColumnHeader(
                    index: index,
                    shortLabel: ComparisonProgramLabel.shortLabel(for: program, among: comparisonPrograms),
                    accentColor: accentColor(for: index)
                )
                .frame(maxWidth: .infinity)
            }

            if comparisonPrograms.count < 4 {
                Button(action: {
                    showProgramPicker = true
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.arial(size: 22))
                        .foregroundColor(AppColors.primaryBlue)
                        .frame(width: 36)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.bottom, 4)
    }

    private func scoreMatrixRow(_ metric: ComparisonMetric, shaded: Bool) -> some View {
        let standings = metric.standings(for: comparisonPrograms)

        return HStack(spacing: 8) {
            Text(metric.shortTitle)
                .font(.arial(size: 12, weight: .medium))
                .foregroundColor(.secondary)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .frame(width: metricLabelWidth, alignment: .leading)

            ForEach(Array(comparisonPrograms.enumerated()), id: \.element.id) { index, program in
                ComparisonScoreCell(
                    value: metric.value(program),
                    emrRawValue: metric.id == "emr" ? program.emr : nil,
                    isEMRMetric: metric.id == "emr",
                    valueColor: metric.color(program),
                    accentColor: accentColor(for: index),
                    isLeader: standings.leadingProgramIDs.contains(program.id) && comparisonPrograms.count > 1,
                    shaded: shaded
                )
                .frame(maxWidth: .infinity)
            }

            if comparisonPrograms.count < 4 {
                Color.clear.frame(width: 36)
            }
        }
        .padding(.vertical, metric.id == "emr" ? 6 : 4)
    }

    private var addProgramButton: some View {
        Button(action: {
            showProgramPicker = true
        }) {
            HStack(spacing: 10) {
                Image(systemName: "plus.circle.fill")
                    .font(.arial(size: 22))
                Text("Add Another Program")
                    .font(.arial(size: 15, weight: .semibold))
            }
            .foregroundColor(AppColors.primaryBlue)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
        .dashboardCardStyle()
    }

    private func accentColor(for index: Int) -> Color {
        Self.programAccentColors[index % Self.programAccentColors.count]
    }

    private var metrics: [ComparisonMetric] {
        let prefs = dataManager.preferences

        func sectionMetric(
            id: String,
            title: String,
            shortTitle: String,
            sectionPrefix: String,
            color: Color
        ) -> ComparisonMetric {
            ComparisonMetric(
                id: id,
                title: title,
                shortTitle: shortTitle,
                value: { program in
                    guard let average = program.questionnaire.standardSectionAverage(sectionPrefix, preferences: prefs) else {
                        return "—"
                    }
                    return String(format: "%.1f", average)
                },
                numericValue: { program in
                    program.questionnaire.standardSectionAverage(sectionPrefix, preferences: prefs)
                },
                color: { _ in color },
                prefersLower: false
            )
        }

        var list: [ComparisonMetric] = [
            ComparisonMetric(
                id: "overall",
                title: "Overall Score",
                shortTitle: "Overall",
                value: { program in
                    guard program.finalScore > 0 else { return "—" }
                    return String(format: "%.1f", program.finalScore)
                },
                numericValue: { program in
                    program.finalScore > 0 ? program.finalScore : nil
                },
                color: { scoreColor($0.finalScore) },
                prefersLower: false
            ),
            sectionMetric(id: "quality", title: "Program Quality", shortTitle: "Quality", sectionPrefix: "Section B", color: .blue),
            sectionMetric(id: "culture", title: "Culture Fit", shortTitle: "Culture", sectionPrefix: "Section D", color: .purple),
            sectionMetric(id: "location", title: "Location & Lifestyle", shortTitle: "Location", sectionPrefix: "Section C", color: .green),
            sectionMetric(id: "logistics", title: "Logistics", shortTitle: "Logistics", sectionPrefix: "Section E", color: .orange),
            sectionMetric(id: "career", title: "Career Alignment", shortTitle: "Career", sectionPrefix: "Section A", color: .pink),
            ComparisonMetric(
                id: "emr",
                title: "EMR",
                shortTitle: "EMR",
                value: { $0.emr ?? "Not set" },
                numericValue: nil,
                color: { $0.emr == nil ? .secondary : .primary },
                prefersLower: false
            )
        ]

        if comparisonPrograms.contains(where: { $0.redFlags.total() > 0 }) {
            list.append(
                ComparisonMetric(
                    id: "redflags",
                    title: "Red Flags",
                    shortTitle: "Red Flags",
                    value: { String(format: "%.1f", $0.redFlags.total()) },
                    numericValue: { $0.redFlags.total() },
                    color: { _ in .red },
                    prefersLower: true
                )
            )
        }

        list.append(
            ComparisonMetric(
                id: "interview",
                title: "Interview Date",
                shortTitle: "Interview",
                value: { program in
                    guard let date = program.interviewDate else { return "Not set" }
                    return ComparisonMetric.compactInterviewDateFormatter.string(from: date)
                },
                numericValue: nil,
                color: { $0.interviewDate == nil ? .secondary : .primary },
                prefersLower: false
            )
        )

        return list
    }
}

// MARK: - Comparison components

private enum ComparisonProgramLabel {
    static func displayName(for program: Program) -> String {
        HospitalNameFormatter.format(program.hospital.isEmpty ? program.name : program.hospital)
    }

    static func shortLabel(for program: Program, among programs: [Program]) -> String {
        let city = program.city.trimmingCharacters(in: .whitespaces)
        let name = displayName(for: program)
        let primarySegment = name
            .split(separator: "/")
            .first
            .map { String($0).trimmingCharacters(in: .whitespaces) } ?? name

        if !city.isEmpty {
            let peersWithSameCity = programs.filter {
                $0.city.trimmingCharacters(in: .whitespaces).caseInsensitiveCompare(city) == .orderedSame
            }

            if peersWithSameCity.count == 1 {
                return city
            }

            let state = program.state.trimmingCharacters(in: .whitespaces)
            let cityStateLabel: String = {
                guard !state.isEmpty else { return city }
                let abbrev = StateMapping.abbreviation(for: state) ?? state
                return "\(city), \(abbrev)"
            }()

            let peersWithSameCityState = programs.filter {
                $0.city.trimmingCharacters(in: .whitespaces).caseInsensitiveCompare(city) == .orderedSame
                    && $0.state.trimmingCharacters(in: .whitespaces).caseInsensitiveCompare(state) == .orderedSame
            }

            if peersWithSameCityState.count == 1 {
                return cityStateLabel
            }

            if let parenthetical = parentheticalHint(in: name) {
                return parenthetical
            }

            return truncate(primarySegment, limit: 16)
        }

        return truncate(primarySegment, limit: 18)
    }

    private static func parentheticalHint(in name: String) -> String? {
        guard let start = name.firstIndex(of: "("),
              let end = name[start...].firstIndex(of: ")") else {
            return nil
        }
        let hint = String(name[name.index(after: start)..<end]).trimmingCharacters(in: .whitespaces)
        guard !hint.isEmpty else { return nil }
        return truncate(hint, limit: 16)
    }

    private static func truncate(_ text: String, limit: Int) -> String {
        guard text.count > limit else { return text }
        return String(text.prefix(limit - 1)).trimmingCharacters(in: .whitespaces) + "…"
    }
}

private struct ComparisonIndexBadge: View {
    let index: Int
    let accentColor: Color
    var size: CGFloat = 20

    var body: some View {
        Text("\(index + 1)")
            .font(.arial(size: size * 0.55, weight: .bold))
            .foregroundColor(.white)
            .frame(width: size, height: size)
            .background(
                Circle()
                    .fill(accentColor)
            )
    }
}

private struct ComparisonColumnKeyPill: View {
    let index: Int
    let label: String
    let accentColor: Color

    var body: some View {
        HStack(spacing: 6) {
            ComparisonIndexBadge(index: index, accentColor: accentColor, size: 18)

            Text(label)
                .font(.arial(size: 11, weight: .semibold))
                .foregroundColor(.primary)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule(style: .continuous)
                .fill(accentColor.opacity(0.12))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(accentColor.opacity(0.28), lineWidth: 1)
        )
    }
}

private struct ComparisonMetric: Identifiable {
    static let compactInterviewDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }()

    let id: String
    let title: String
    let shortTitle: String
    let value: (Program) -> String
    let numericValue: ((Program) -> Double?)?
    let color: (Program) -> Color
    let prefersLower: Bool

    struct Standings {
        let leadingProgramIDs: Set<String>
    }

    func standings(for programs: [Program]) -> Standings {
        guard programs.count > 1, let numericValue else {
            return Standings(leadingProgramIDs: [])
        }

        let scored = programs.compactMap { program -> (id: String, score: Double)? in
            guard let score = numericValue(program) else { return nil }
            return (id: program.id, score: score)
        }
        guard !scored.isEmpty else {
            return Standings(leadingProgramIDs: [])
        }

        let target = prefersLower
            ? scored.map(\.score).min()
            : scored.map(\.score).max()

        guard let target else {
            return Standings(leadingProgramIDs: [])
        }

        let leaders = scored.filter { $0.score == target }.map(\.id)
        return Standings(leadingProgramIDs: Set(leaders))
    }
}

private struct ComparisonProgramHeaderRow: View {
    let program: Program
    let index: Int
    let accentColor: Color
    let onRemove: () -> Void

    private var displayName: String {
        ComparisonProgramLabel.displayName(for: program)
    }

    private var locationLine: String {
        if program.hasDisplayLocation {
            return program.displayCityState
        }
        if !program.state.isEmpty { return program.state }
        return program.specialty
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            ComparisonIndexBadge(index: index, accentColor: accentColor)

            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(accentColor)
                .frame(width: 4)
                .padding(.vertical, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(displayName)
                    .font(.arial(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(locationLine)
                    .font(.arial(size: 12))
                    .foregroundColor(.secondary)
            }

            Spacer(minLength: 8)

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.arial(size: 18))
                    .foregroundColor(.secondary.opacity(0.75))
            }
            .buttonStyle(.plain)
        }
    }
}

private struct ComparisonColorColumnHeader: View {
    let index: Int
    let shortLabel: String
    let accentColor: Color

    var body: some View {
        VStack(spacing: 4) {
            ComparisonIndexBadge(index: index, accentColor: accentColor, size: 18)

            Text(shortLabel)
                .font(.arial(size: 9, weight: .semibold))
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity)

            Capsule(style: .continuous)
                .fill(accentColor)
                .frame(maxWidth: .infinity)
                .frame(height: 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 2)
    }
}

private struct ComparisonScoreCell: View {
    let value: String
    var emrRawValue: String? = nil
    var isEMRMetric: Bool = false
    let valueColor: Color
    let accentColor: Color
    let isLeader: Bool
    let shaded: Bool

    var body: some View {
        Group {
            if isEMRMetric {
                EMRValueView(rawValue: emrRawValue, style: .compact)
                    .frame(maxWidth: .infinity)
            } else {
                Text(value)
                    .font(.arial(size: 14, weight: .semibold))
                    .foregroundColor(valueColor)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, isEMRMetric ? 8 : 10)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(cellBackground)
        )
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(accentColor)
                .frame(width: 3)
                .padding(.vertical, 6)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isLeader ? accentColor.opacity(0.45) : accentColor.opacity(0.12), lineWidth: isLeader ? 1.5 : 1)
        )
    }

    private var cellBackground: Color {
        if isLeader {
            return accentColor.opacity(0.14)
        }
        return shaded ? Color(.systemGray6).opacity(0.45) : Color(.systemGray6).opacity(0.22)
    }
}

struct ProgramComparisonPickerView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var dataManager: DataManager
    @Binding var selectedPrograms: Set<String>
    let currentSelections: Set<String>
    @State private var tempSelections: Set<String>

    private let maxSelections = 4
    private let minSelections = 2

    init(selectedPrograms: Binding<Set<String>>, currentSelections: Set<String>) {
        self._selectedPrograms = selectedPrograms
        self.currentSelections = currentSelections
        self._tempSelections = State(initialValue: currentSelections)
    }

    var body: some View {
        MatchlyNavigationView {
            VStack(spacing: 0) {
                selectionSummaryBar

                List {
                    ForEach(dataManager.programs) { program in
                        Button(action: {
                            if tempSelections.contains(program.id) {
                                tempSelections.remove(program.id)
                            } else if tempSelections.count < maxSelections {
                                tempSelections.insert(program.id)
                            }
                        }) {
                            HStack {
                                Image(systemName: tempSelections.contains(program.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(tempSelections.contains(program.id) ? .blue : .gray)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(HospitalNameFormatter.format(program.hospital))
                                        .font(.arial(size: 16, weight: .semibold))
                                        .foregroundColor(.primary)
                                    if program.hasDisplayLocation {
                                        Text(program.displayCityState)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }

                                Spacer()

                                if tempSelections.count >= maxSelections && !tempSelections.contains(program.id) {
                                    Text("Max 4")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Programs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        selectedPrograms = tempSelections
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(tempSelections.count < minSelections)
                }
            }
        }
    }

    private var selectionSummaryBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(tempSelections.count)/\(maxSelections)")
                    .font(.arial(size: 32, weight: .bold))
                    .foregroundColor(selectionCountColor)
                    .monospacedDigit()

                Text("selected")
                    .font(.arial(size: 15, weight: .medium))
                    .foregroundColor(.secondary)

                Spacer()
            }

            HStack(spacing: 6) {
                ForEach(0..<maxSelections, id: \.self) { index in
                    Capsule(style: .continuous)
                        .fill(index < tempSelections.count ? AppColors.primaryBlue : Color(.systemGray4))
                        .frame(height: 5)
                }
            }

            Text(selectionHelperText)
                .font(.arial(size: 12))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGroupedBackground))
    }

    private var selectionCountColor: Color {
        if tempSelections.count < minSelections {
            return AppColors.accentOrange
        }
        if tempSelections.count == maxSelections {
            return AppColors.primaryBlue
        }
        return .primary
    }

    private var selectionHelperText: String {
        switch tempSelections.count {
        case 0:
            return "Select 2–4 programs to compare"
        case 1:
            return "Select at least 1 more program"
        case 2, 3:
            return "You can add up to \(maxSelections - tempSelections.count) more"
        default:
            return "Maximum of \(maxSelections) programs selected"
        }
    }
}

#Preview {
    ProgramComparisonView()
        .environmentObject(DataManager.shared)
}
