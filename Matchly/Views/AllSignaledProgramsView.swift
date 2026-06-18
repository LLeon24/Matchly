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

    private var sortedBuckets: [String] {
        groupedByBucket.keys.sorted()
    }

    private var budgetSummaries: [DataManager.SignalBudgetSummary] {
        dataManager.signalBudgetSummaries()
    }

    var body: some View {
        List {
            if !budgetSummaries.isEmpty {
                Section {
                    ForEach(budgetSummaries) { summary in
                        SignalBudgetCard(summary: summary)
                    }
                } header: {
                    Text("Signal Budget")
                } footer: {
                    Text("Limits follow ERAS / ResidencyCAS rules per specialty. Individual programs may opt out of accepting signals.")
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
                ForEach(sortedBuckets, id: \.self) { bucket in
                    let programs = groupedByBucket[bucket] ?? []
                    let sampleAccreditationID = programs.first?.accreditationID
                    let config = SignalLimits.configuration(for: bucket, accreditationID: sampleAccreditationID)
                    let usage = dataManager.getSignalUsage(for: bucket, accreditationID: sampleAccreditationID)

                    Section(header: bucketSectionHeader(bucket: bucket, usage: usage, config: config)) {
                        ForEach(programs.sorted { $0.finalScore > $1.finalScore }) { program in
                            NavigationLink(destination: ProgramEntryView(program: program)) {
                                signaledProgramRow(program)
                            }
                        }
                    }
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
    private func bucketSectionHeader(
        bucket: String,
        usage: (goldUsed: Int, goldLimit: Int, silverUsed: Int, silverLimit: Int),
        config: SignalConfiguration
    ) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "star.fill")
                .font(.arial(size: 12))
                .foregroundColor(.purple)
            Text(bucket)
                .font(.arial(size: 13, weight: .semibold))
            Spacer()
            if config.isTiered {
                Text("\(usage.goldUsed)/\(usage.goldLimit)G · \(usage.silverUsed)/\(usage.silverLimit)S")
                    .font(.arial(size: 10, weight: .medium))
            } else if usage.goldLimit > 0 {
                Text("\(usage.goldUsed)/\(usage.goldLimit)")
                    .font(.arial(size: 10, weight: .medium))
            }
        }
        .foregroundColor(.secondary)
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
                    signalBadge(for: program)
                    ProgramVoiceMemoBadge(program: program)
                    if let note = program.signalNote, !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Label("Statement", systemImage: "text.quote")
                            .font(.arial(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }

                if !program.city.isEmpty, !program.state.isEmpty {
                    Text("\(program.city), \(program.state)")
                        .font(.arial(size: 12))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func signalBadge(for program: Program) -> some View {
        let isTiered = SignalLimits.isTiered(for: program.specialty, accreditationID: program.accreditationID)
        let signalText = isTiered
            ? (program.signalType == .gold ? "Gold" : "Silver")
            : "Signal"
        let signalColor: Color = isTiered
            ? (program.signalType == .gold ? .yellow : Color(white: 0.55))
            : .blue

        HStack(spacing: 3) {
            Image(systemName: program.signalType == .gold ? "star.fill" : "star")
                .font(.arial(size: 8))
            Text(signalText)
                .font(.arial(size: 10, weight: .medium))
        }
        .foregroundColor(signalColor)
    }
}

private struct SignalBudgetCard: View {
    let summary: DataManager.SignalBudgetSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(summary.displayName)
                    .font(.arial(size: 15, weight: .semibold))
                Spacer()
                if summary.usesResidencyCAS {
                    Text("ResidencyCAS")
                        .font(.arial(size: 10, weight: .semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.12))
                        .foregroundColor(.blue)
                        .clipShape(Capsule())
                }
            }

            if summary.isTiered {
                HStack(spacing: 16) {
                    budgetPill(
                        title: "Gold left",
                        remaining: summary.goldRemaining,
                        total: summary.goldLimit,
                        color: .yellow
                    )
                    budgetPill(
                        title: "Silver left",
                        remaining: summary.silverRemaining,
                        total: summary.silverLimit,
                        color: .gray
                    )
                }
            } else if summary.goldLimit > 0 {
                budgetPill(
                    title: "Signals left",
                    remaining: summary.goldRemaining,
                    total: summary.goldLimit,
                    color: .blue
                )
            }

            if summary.requiresSignalStatement {
                Label("Signal statement required in application", systemImage: "text.quote")
                    .font(.arial(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 6)
    }

    private func budgetPill(title: String, remaining: Int, total: Int, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.arial(size: 11))
                .foregroundColor(.secondary)
            Text("\(remaining) of \(total)")
                .font(.arial(size: 16, weight: .bold))
                .foregroundColor(remaining == 0 ? .red : color)
        }
    }
}

#Preview {
    MatchlyNavigationView {
        AllSignaledProgramsView()
            .environmentObject(DataManager.shared)
    }
}
