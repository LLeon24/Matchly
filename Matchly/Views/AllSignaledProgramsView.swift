//
//  AllSignaledProgramsView.swift
//  Matchly
//

import SwiftUI

struct AllSignaledProgramsView: View {
    @EnvironmentObject var dataManager: DataManager

    private var signaledPrograms: [Program] {
        dataManager.programs.filter { $0.signalType != .none }
    }

    private var groupedByBucket: [String: [Program]] {
        Dictionary(grouping: signaledPrograms) { program in
            SignalLimits.signalBucket(for: program.specialty, accreditationID: program.accreditationID)
        }
    }

    private var budgetSummaries: [DataManager.SignalBudgetSummary] {
        dataManager.signalBudgetSummaries()
    }

    private var orderedBucketNames: [String] {
        let names = Set(budgetSummaries.map(\.displayName)).union(groupedByBucket.keys)
        return names.sorted()
    }

    var body: some View {
        List {
            if !budgetSummaries.isEmpty {
                Section {
                    ForEach(budgetSummaries) { summary in
                        DashboardSignalBudgetRow(summary: summary, style: .standard)
                    }
                } header: {
                    Text("Signal Budget")
                } footer: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Limits follow ERAS / ResidencyCAS rules per specialty. Individual programs may opt out of accepting signals.")
                        if !signaledPrograms.isEmpty {
                            Text("Assigned programs are grouped by specialty and signal type below.")
                        }
                    }
                    .font(.arial(size: 12))
                }
            }

            if signaledPrograms.isEmpty {
                Section {
                    VStack(spacing: 16) {
                        Image(systemName: "star.circle")
                            .font(.arial(size: 48))
                            .foregroundColor(.secondary)

                        Text("No Signals Assigned")
                            .font(.arial(size: 18, weight: .semibold))

                        Text("Assign signals from any program page. Your remaining budget appears above.")
                            .font(.arial(size: 14))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                }
            } else {
                ForEach(orderedBucketNames, id: \.self) { bucket in
                    assignedProgramsSection(for: bucket)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .appCanvasBackground()
        .navigationTitle("Signals")
        .navigationBarTitleDisplayMode(.inline)
        .matchlyScrollTabBarClearance()
    }

    @ViewBuilder
    private func assignedProgramsSection(for bucket: String) -> some View {
        let programs = groupedByBucket[bucket] ?? []
        let sampleAccreditationID = programs.first?.accreditationID
        let config = SignalLimits.configuration(for: bucket, accreditationID: sampleAccreditationID)
        let usage = dataManager.getSignalUsage(for: bucket, accreditationID: sampleAccreditationID)
        let summary = budgetSummaries.first { $0.displayName == bucket }
        let goldPrograms = programs
            .filter { $0.signalType == .gold }
            .sorted { $0.finalScore > $1.finalScore }
        let silverPrograms = programs
            .filter { $0.signalType == .silver }
            .sorted { $0.finalScore > $1.finalScore }

        Section {
            if config.isTiered {
                signalTypeGroupHeader(
                    title: "Gold Signals",
                    used: summary?.goldUsed ?? usage.goldUsed,
                    limit: summary?.goldLimit ?? usage.goldLimit,
                    remaining: summary?.goldRemaining ?? max(0, usage.goldLimit - usage.goldUsed),
                    color: .yellow,
                    icon: "star.fill"
                )

                signalTypeProgramRows(
                    title: "Gold Signals",
                    remaining: summary?.goldRemaining ?? max(0, usage.goldLimit - usage.goldUsed),
                    limit: summary?.goldLimit ?? usage.goldLimit,
                    programs: goldPrograms
                )

                signalTypeGroupHeader(
                    title: "Silver Signals",
                    used: summary?.silverUsed ?? usage.silverUsed,
                    limit: summary?.silverLimit ?? usage.silverLimit,
                    remaining: summary?.silverRemaining ?? max(0, usage.silverLimit - usage.silverUsed),
                    color: Color(white: 0.55),
                    icon: "star"
                )

                signalTypeProgramRows(
                    title: "Silver Signals",
                    remaining: summary?.silverRemaining ?? max(0, usage.silverLimit - usage.silverUsed),
                    limit: summary?.silverLimit ?? usage.silverLimit,
                    programs: silverPrograms
                )
            } else if usage.goldLimit > 0 || !goldPrograms.isEmpty {
                signalTypeGroupHeader(
                    title: "Signals",
                    used: summary?.goldUsed ?? usage.goldUsed,
                    limit: summary?.goldLimit ?? usage.goldLimit,
                    remaining: summary?.goldRemaining ?? max(0, usage.goldLimit - usage.goldUsed),
                    color: AppColors.primaryBlue,
                    icon: "star.fill"
                )

                signalTypeProgramRows(
                    title: "Signals",
                    remaining: summary?.goldRemaining ?? max(0, usage.goldLimit - usage.goldUsed),
                    limit: summary?.goldLimit ?? usage.goldLimit,
                    programs: goldPrograms
                )
            }
        } header: {
            specialtySectionHeader(bucket: bucket, config: config)
        }
    }

    @ViewBuilder
    private func specialtySectionHeader(bucket: String, config: SignalConfiguration) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "stethoscope")
                .font(.arial(size: 12, weight: .semibold))
                .foregroundColor(SpecialtyFormatter.color(for: bucket))

            Text(SpecialtyFormatter.displayNameWithAbbreviation(bucket))
                .font(.arial(size: 14, weight: .semibold))
                .foregroundColor(.primary)

            Spacer(minLength: 4)

            if config.usesResidencyCAS {
                Text("ResidencyCAS")
                    .font(.arial(size: 9, weight: .semibold))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.12))
                    .foregroundColor(.blue)
                    .clipShape(Capsule())
            }
        }
        .textCase(nil)
    }

    @ViewBuilder
    private func signalTypeProgramRows(
        title: String,
        remaining: Int,
        limit: Int,
        programs: [Program]
    ) -> some View {
        if programs.isEmpty {
            Text(emptyGroupMessage(title: title, remaining: remaining, limit: limit))
                .font(.arial(size: 13))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
        } else {
            ForEach(programs) { program in
                NavigationLink(destination: ProgramEntryView(program: program)) {
                    signaledProgramRow(program)
                }
            }
        }
    }

    private func signalTypeGroupHeader(
        title: String,
        used: Int,
        limit: Int,
        remaining: Int,
        color: Color,
        icon: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.arial(size: 13, weight: .semibold))
                    .foregroundColor(color)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.arial(size: 14, weight: .semibold))
                        .foregroundColor(.primary)

                    Text(usageSummary(used: used, limit: limit, remaining: remaining))
                        .font(.arial(size: 12))
                        .foregroundColor(.secondary)
                }

                Spacer(minLength: 0)

                Text("\(used)/\(limit)")
                    .font(.arial(size: 13, weight: .bold))
                    .foregroundColor(used >= limit ? .red : color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(color.opacity(0.12))
                    .clipShape(Capsule())
            }

            if limit > 0 {
                DashboardSignalUsageMeter(
                    title: "",
                    used: used,
                    limit: limit,
                    color: color,
                    style: .compact
                )
            }
        }
        .padding(.vertical, 4)
    }

    private func usageSummary(used: Int, limit: Int, remaining: Int) -> String {
        if limit == 0 {
            return "Not available for this specialty"
        }
        if used == 0 {
            return remaining == 1 ? "None assigned · 1 available" : "None assigned · \(remaining) available"
        }
        if remaining == 0 {
            return "All \(limit) used"
        }
        return "\(used) assigned · \(remaining) remaining"
    }

    private func emptyGroupMessage(title: String, remaining: Int, limit: Int) -> String {
        if limit == 0 {
            return "This specialty does not use \(title.lowercased())."
        }
        if remaining == 0 {
            return "No slots remaining."
        }
        return "No programs assigned yet. \(remaining) \(remaining == 1 ? "slot" : "slots") available."
    }

    @ViewBuilder
    private func signaledProgramRow(_ program: Program) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(scoreColor(program.finalScore).opacity(0.15))
                    .frame(width: 42, height: 42)

                VStack(spacing: 0) {
                    Image(systemName: "star.fill")
                        .font(.arial(size: 9))
                        .foregroundColor(scoreColor(program.finalScore))
                    Text(String(format: "%.0f", program.finalScore))
                        .font(.arial(size: 15, weight: .bold))
                        .foregroundColor(scoreColor(program.finalScore))
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(HospitalNameFormatter.format(program.hospital.isEmpty ? program.name : program.hospital))
                    .font(.arial(size: 15, weight: .semibold))
                    .lineLimit(2)

                HStack(spacing: 8) {
                    ProgramVoiceMemoBadge(program: program)
                    if let note = program.signalNote, !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Label("Statement", systemImage: "text.quote")
                            .font(.arial(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }

                if program.hasDisplayLocation {
                    Text(program.displayCityState)
                        .font(.arial(size: 12))
                        .foregroundColor(.secondary)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    MatchlyNavigationView {
        AllSignaledProgramsView()
            .environmentObject(DataManager.shared)
    }
}
