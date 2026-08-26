//
//  MatchlyCalendarSyncRow.swift
//  Matchly
//

import SwiftUI
import EventKit

struct MatchlyCalendarSyncRow: View {
    @EnvironmentObject private var dataManager: DataManager
    @ObservedObject private var calendarManager = CalendarManager.shared

    var syncOnAppearIfEnabled: Bool = false

    private static var didAutoSyncThisSession = false

    @State private var showCalendarPermissionAlert = false
    @State private var showCalendarSuccessAlert = false
    @State private var showCalendarErrorAlert = false
    @State private var calendarErrorMessage = ""
    @State private var isCreatingEvents = false
    @State private var eventsCreatedCount = 0

    private var interviewPrograms: [Program] {
        dataManager.programs.filter { $0.interviewDate != nil }
    }

    var body: some View {
        rowContent
            .alert("Calendar Access Required", isPresented: $showCalendarPermissionAlert) {
                Button("Settings") {
                    if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(settingsUrl)
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Matchly needs calendar access to create interview events. Please enable it in Settings.")
            }
            .alert("Calendar Events Created", isPresented: $showCalendarSuccessAlert) {
                Button("OK") { }
            } message: {
                Text("Successfully created \(eventsCreatedCount) interview event\(eventsCreatedCount == 1 ? "" : "s") in your calendar.")
            }
            .alert("Error", isPresented: $showCalendarErrorAlert) {
                Button("OK") { }
            } message: {
                Text(calendarErrorMessage)
            }
            .onAppear {
                calendarManager.checkAuthorizationStatus()
                guard syncOnAppearIfEnabled, !Self.didAutoSyncThisSession else { return }
                guard dataManager.preferences.enableCalendarSync,
                      calendarManager.calendarAccessGranted,
                      !interviewPrograms.isEmpty else { return }
                Self.didAutoSyncThisSession = true
                Task {
                    await createCalendarEvents(showSuccessAlert: false)
                }
            }
    }

    private var rowContent: some View {
        HStack(spacing: 12) {
            Image(systemName: calendarManager.calendarAccessGranted ? "calendar.badge.checkmark" : "calendar.badge.exclamationmark")
                .font(.arial(size: 18))
                .foregroundColor(calendarManager.calendarAccessGranted ? .green : .orange)

            VStack(alignment: .leading, spacing: 2) {
                Text("Calendar Sync")
                    .font(.arial(size: 15, weight: .medium))
                Text(calendarManager.calendarAccessGranted
                     ? "Interviews sync to \"\(calendarManager.matchlyCalendar?.title ?? "Matchly Interviews")\""
                     : "Enable to add interviews to your device calendar")
                    .font(.arial(size: 12))
                    .foregroundColor(.secondary)
            }

            Spacer(minLength: 8)

            if isCreatingEvents {
                ProgressView()
                    .scaleEffect(0.85)
            }

            Toggle("", isOn: calendarSyncBinding)
                .labelsHidden()
        }
        .padding(.vertical, 2)
    }

    private var calendarSyncBinding: Binding<Bool> {
        Binding(
            get: { dataManager.preferences.enableCalendarSync },
            set: { newValue in
                dataManager.preferences.enableCalendarSync = newValue
                dataManager.savePreferences()
                if newValue {
                    Task {
                        await createCalendarEvents(showSuccessAlert: false)
                    }
                }
            }
        )
    }

    private func createCalendarEvents(showSuccessAlert: Bool = true) async {
        guard !interviewPrograms.isEmpty else { return }

        if calendarManager.authorizationStatus == .notDetermined {
            let granted = await calendarManager.requestAccess()
            if !granted {
                await MainActor.run {
                    showCalendarPermissionAlert = true
                }
                return
            }
        } else {
            let hasAccess: Bool
            if #available(iOS 17.0, *) {
                hasAccess = (calendarManager.authorizationStatus == .fullAccess)
                    || (calendarManager.authorizationStatus == .writeOnly)
            } else {
                hasAccess = calendarManager.authorizationStatus == .authorized
            }

            if !hasAccess {
                await MainActor.run {
                    showCalendarPermissionAlert = true
                }
                return
            }
        }

        await MainActor.run {
            isCreatingEvents = true
        }

        do {
            try await calendarManager.createEventsForInterviews(interviewPrograms)
            await MainActor.run {
                isCreatingEvents = false
                eventsCreatedCount = interviewPrograms.count
                if showSuccessAlert {
                    showCalendarSuccessAlert = true
                }
            }
        } catch {
            await MainActor.run {
                isCreatingEvents = false
                calendarErrorMessage = error.localizedDescription
                showCalendarErrorAlert = true
            }
        }
    }
}
