//
//  SetInterviewDatesView.swift
//  Matchly
//
//  Lists programs missing an interview date so applicants can tap in and set one.
//

import SwiftUI

struct SetInterviewDatesView: View {
    @EnvironmentObject var dataManager: DataManager

    private var programsNeedingDates: [Program] {
        dataManager.programs.filter { $0.interviewDate == nil }
    }

    var body: some View {
        Group {
            if programsNeedingDates.isEmpty {
                emptyState
            } else {
                programList
            }
        }
        .navigationTitle("Set Interview Dates")
        .navigationBarTitleDisplayMode(.large)
        .appCanvasBackground()
    }

    private var emptyState: some View {
        List {
            VStack(spacing: 16) {
                Image(systemName: "calendar.badge.checkmark")
                    .font(.arial(size: 60))
                    .foregroundColor(AppColors.accentGreen)

                Text("All Dates Set")
                    .font(.arial(size: 20, weight: .bold))

                Text("Every program has an interview date logged")
                    .font(.arial(size: 15))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
        }
        .padding(.bottom, 90)
    }

    private var programList: some View {
        let grouped = Dictionary(grouping: programsNeedingDates) { $0.specialty }
        let sortedSpecialties = grouped.keys.sorted()

        return List {
            Section {
                Text("Tap a program to add its interview date and time.")
                    .font(.arial(size: 14))
                    .foregroundColor(.secondary)
                    .listRowBackground(Color.clear)
            }

            ForEach(sortedSpecialties, id: \.self) { specialty in
                Section {
                    ForEach(grouped[specialty] ?? []) { program in
                        NavigationLink(destination: ProgramEntryView(program: program)) {
                            ProgramNeedingInterviewDateRow(program: program)
                        }
                    }
                } header: {
                    HStack(spacing: 6) {
                        Image(systemName: "stethoscope")
                            .font(.arial(size: 12))
                            .foregroundColor(SpecialtyFormatter.color(for: specialty))
                        Text("\(specialty) (\(SpecialtyFormatter.abbreviation(for: specialty)))")
                            .font(.arial(size: 13, weight: .semibold))
                    }
                    .foregroundColor(.secondary)
                }
            }
        }
        .padding(.bottom, 90)
    }
}

struct ProgramNeedingInterviewDateRow: View {
    let program: Program

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(AppColors.accentOrange.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: "calendar.badge.plus")
                    .font(.arial(size: 18, weight: .semibold))
                    .foregroundColor(AppColors.accentOrange)
                    .symbolRenderingMode(.hierarchical)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(HospitalNameFormatter.format(
                    program.hospital.isEmpty
                        ? (program.name.isEmpty ? "Unnamed Program" : program.name)
                        : program.hospital
                ))
                .font(.arial(size: 15, weight: .semibold))
                .lineLimit(2)
                .foregroundColor(.primary)

                if !program.city.isEmpty && !program.state.isEmpty {
                    HStack(spacing: 3) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.arial(size: 9))
                        Text("\(program.city), \(program.state)")
                            .font(.arial(size: 12))
                    }
                    .foregroundColor(.secondary)
                }

                Text("No interview date")
                    .font(.arial(size: 12, weight: .medium))
                    .foregroundColor(AppColors.accentOrange)

                ProgramVoiceMemoBadge(program: program, iconSize: 9, textSize: 11)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    MatchlyNavigationView {
        SetInterviewDatesView()
            .environmentObject(DataManager.shared)
    }
}
