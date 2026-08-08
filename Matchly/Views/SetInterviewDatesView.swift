//
//  SetInterviewDatesView.swift
//  Matchly
//
//  Lists programs missing an interview date so applicants can set date/time quickly.
//

import EventKit
import OSLog
import SwiftUI

private let setInterviewLogger = Logger(subsystem: "com.matchly", category: "SetInterviewDates")

struct SetInterviewDatesView: View {
    @EnvironmentObject var dataManager: DataManager

    @State private var programForDatePicker: Program?
    @State private var programForFullEdit: Program?

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
        .sheet(item: $programForDatePicker) { program in
            SetInterviewDateSheet(
                program: program,
                onOpenFullProgram: {
                    programForDatePicker = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        programForFullEdit = program
                    }
                }
            )
            .environmentObject(dataManager)
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $programForFullEdit) { program in
            ProgramEntryView(program: program)
                .environmentObject(dataManager)
        }
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
                Text("Tap a program to set its interview date and time.")
                    .font(.arial(size: 14))
                    .foregroundColor(.secondary)
                    .listRowBackground(Color.clear)
            }

            ForEach(sortedSpecialties, id: \.self) { specialty in
                Section {
                    ForEach(grouped[specialty] ?? []) { program in
                        Button {
                            programForDatePicker = program
                        } label: {
                            ProgramNeedingInterviewDateRow(program: program)
                        }
                        .buttonStyle(.plain)
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

struct SetInterviewDateSheet: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) private var dismiss

    let program: Program
    var onOpenFullProgram: () -> Void

    @State private var interviewDate: Date = Date()
    @State private var showEnableCalendarSyncAlert = false
    @State private var isSaving = false

    private var programTitle: String {
        HospitalNameFormatter.format(
            program.hospital.isEmpty
                ? (program.name.isEmpty ? "Unnamed Program" : program.name)
                : program.hospital
        )
    }

    var body: some View {
        MatchlyNavigationView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(programTitle)
                        .font(.arial(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(2)

                    if !program.city.isEmpty && !program.state.isEmpty {
                        Label("\(program.city), \(program.state)", systemImage: "mappin.circle.fill")
                            .font(.arial(size: 13))
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 8)

                DatePicker(
                    "Interview Date & Time",
                    selection: $interviewDate,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                .frame(maxWidth: .infinity)

                Button {
                    onOpenFullProgram()
                } label: {
                    Label("Open full program", systemImage: "doc.text")
                        .font(.arial(size: 14, weight: .medium))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .padding(.horizontal, 20)

                Spacer(minLength: 0)
            }
            .navigationTitle("Interview Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveInterviewDate()
                    }
                    .fontWeight(.semibold)
                    .disabled(isSaving)
                }
            }
            .alert("Add to Calendar?", isPresented: $showEnableCalendarSyncAlert) {
                Button("Not Now", role: .cancel) {
                    dismiss()
                }
                Button("Add Event") {
                    addCalendarEvent(for: interviewDate)
                    dismiss()
                }
            } message: {
                Text("Calendar sync is off. Add this interview to your calendar anyway?")
            }
        }
    }

    private func saveInterviewDate() {
        isSaving = true
        var updated = program
        updated.interviewDate = interviewDate
        dataManager.updateProgram(updated)

        if dataManager.preferences.enableCalendarSync {
            addCalendarEvent(for: interviewDate)
            dismiss()
        } else {
            isSaving = false
            showEnableCalendarSyncAlert = true
        }
    }

    private func addCalendarEvent(for date: Date) {
        Task {
            do {
                let calendarManager = CalendarManager.shared
                if calendarManager.authorizationStatus == .notDetermined {
                    let granted = await calendarManager.requestAccess()
                    guard granted else { return }
                } else {
                    calendarManager.checkAuthorizationStatus()
                }

                guard calendarManager.calendarAccessGranted else { return }

                var calendarProgram = program
                calendarProgram.interviewDate = date
                try await calendarManager.createEventsForInterviews([calendarProgram])
                setInterviewLogger.info("Created calendar event for interview date")
            } catch {
                setInterviewLogger.error("Failed to create calendar event: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}

struct ProgramNeedingInterviewDateRow: View {
    let program: Program

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(AppColors.accentOrange.opacity(0.15))
                    .frame(width: 42, height: 42)
                Image(systemName: "calendar.badge.plus")
                    .font(.arial(size: 16, weight: .semibold))
                    .foregroundColor(AppColors.accentOrange)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(HospitalNameFormatter.format(
                    program.hospital.isEmpty
                        ? (program.name.isEmpty ? "Unnamed Program" : program.name)
                        : program.hospital
                ))
                .font(.arial(size: 15, weight: .semibold))
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

                if !program.specialty.isEmpty {
                    MatchlyProgramSpecialtyBadge(specialty: program.specialty)
                }

                MatchlyProgramLocationAndIDRow(program: program)

                Text("No interview date")
                    .font(.arial(size: 11, weight: .semibold))
                    .foregroundColor(AppColors.accentOrange)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(AppColors.accentOrange.opacity(0.12))
                    .cornerRadius(4)

                ProgramVoiceMemoBadge(program: program, iconSize: 9, textSize: 11)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }
}

#Preview {
    MatchlyNavigationView {
        SetInterviewDatesView()
            .environmentObject(DataManager.shared)
    }
}
