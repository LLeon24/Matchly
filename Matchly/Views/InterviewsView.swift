//
//  InterviewsView.swift
//  Matchly
//
//  Created on 11/14/25.
//

import SwiftUI
import EventKit

struct InterviewsView: View {
    @EnvironmentObject var dataManager: DataManager
    @ObservedObject private var calendarManager = CalendarManager.shared
    @State private var viewMode: ViewMode = .list
    @State private var selectedMonth: Date = Date()
    @State private var selectedDate: Date?
    @State private var showCalendarPermissionAlert = false
    @State private var showCalendarSuccessAlert = false
    @State private var showCalendarErrorAlert = false
    @State private var calendarErrorMessage = ""
    @State private var isCreatingEvents = false
    @State private var eventsCreatedCount = 0
    
    enum ViewMode {
        case list, calendar
    }
    
    var programsNeedingDates: [Program] {
        dataManager.programs.filter { $0.interviewDate == nil }
    }
    
    var allInterviews: [Program] {
        dataManager.programs.filter { $0.interviewDate != nil }
            .sorted { ($0.interviewDate ?? Date.distantPast) < ($1.interviewDate ?? Date.distantPast) }
    }
    
    var upcomingInterviews: [Program] {
        let now = Date()
        return allInterviews.filter { ($0.interviewDate ?? now) >= now }
    }
    
    var pastInterviews: [Program] {
        let now = Date()
        return allInterviews.filter { ($0.interviewDate ?? now) < now }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            MatchlyListPageTitleRow(title: "Interviews") {
                if !programsNeedingDates.isEmpty {
                    NavigationLink(destination: SetInterviewDatesView()) {
                        MatchlyToolbarAddInterviewDateButton()
                    }
                    .buttonStyle(.plain)
                }
            }

            // View Mode Picker
            Picker("View Mode", selection: $viewMode) {
                Label("List", systemImage: "list.bullet").tag(ViewMode.list)
                Label("Calendar", systemImage: "calendar").tag(ViewMode.calendar)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            
            if viewMode == .list {
                listView
            } else {
                calendarView
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .matchlyScrollTabBarClearance()
        .appCanvasBackground()
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
        }
    }
    
    private func createCalendarEvents() async {
        guard !allInterviews.isEmpty else { return }
        
        // Check authorization
        if calendarManager.authorizationStatus == .notDetermined {
            let granted = await calendarManager.requestAccess()
            if !granted {
                await MainActor.run {
                    showCalendarPermissionAlert = true
                }
                return
            }
        } else {
            // Check for appropriate access level (iOS 17+ uses .fullAccess or .writeOnly, iOS < 17 uses .authorized)
            let hasAccess: Bool
            if #available(iOS 17.0, *) {
                hasAccess = (calendarManager.authorizationStatus == .fullAccess) || (calendarManager.authorizationStatus == .writeOnly)
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
            try await calendarManager.createEventsForInterviews(allInterviews)
            await MainActor.run {
                isCreatingEvents = false
                eventsCreatedCount = allInterviews.count
                showCalendarSuccessAlert = true
            }
        } catch {
            await MainActor.run {
                isCreatingEvents = false
                calendarErrorMessage = error.localizedDescription
                showCalendarErrorAlert = true
            }
        }
    }
    
    private var listView: some View {
        List {
            // Calendar sync section - always show if enabled in preferences
            if dataManager.preferences.enableCalendarSync {
                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Image(systemName: calendarManager.calendarAccessGranted ? "calendar.badge.checkmark" : "calendar.badge.exclamationmark")
                                    .foregroundColor(calendarManager.calendarAccessGranted ? .green : .orange)
                                Text("Calendar Sync")
                                    .font(.arial(size: 15, weight: .medium))
                            }
                            
                            if calendarManager.calendarAccessGranted {
                                Text("Interviews will be added to \"\(calendarManager.matchlyCalendar?.title ?? "Matchly Interviews")\" calendar")
                                    .font(.arial(size: 13))
                                    .foregroundColor(.secondary)
                            } else {
                                Text("Enable calendar access to create interview events")
                                    .font(.arial(size: 13))
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            Task {
                                await createCalendarEvents()
                            }
                        }) {
                            if isCreatingEvents {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Text(calendarManager.calendarAccessGranted ? "Sync Now" : "Enable")
                                    .font(.arial(size: 14, weight: .medium))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                            }
                        }
                        .buttonStyle(.glassProminent)
                        .tint(calendarManager.calendarAccessGranted ? AppColors.primaryBlue : .orange)
                        .disabled(isCreatingEvents || allInterviews.isEmpty)
                    }
                    .padding(.vertical, 4)
                    .listRowBackground(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(.clear)
                            .glassEffect(.regular, in: .rect(cornerRadius: 16))
                            .padding(.vertical, 4)
                    )
                } header: {
                    Text("Calendar")
                } footer: {
                    if calendarManager.calendarAccessGranted {
                        Text("Your interviews are synced to your device calendar. Events will update automatically when you modify interview dates.")
                    } else {
                        Text("Add your interviews to your device calendar to get reminders and see them in your calendar app.")
                    }
                }
            }
            
            if !programsNeedingDates.isEmpty {
                Section {
                    ForEach(programsNeedingDates) { program in
                        NavigationLink(destination: ProgramEntryView(program: program)) {
                            ProgramNeedingInterviewDateRow(program: program)
                        }
                    }
                } header: {
                    Text("Needs a Date (\(programsNeedingDates.count))")
                        .font(.arial(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)
                } footer: {
                    Text("Tap a program to add its interview date and time.")
                }
            }
            
            if upcomingInterviews.isEmpty && pastInterviews.isEmpty {
                if programsNeedingDates.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "calendar.badge.exclamationmark")
                        .font(.arial(size: 60))
                        .foregroundColor(.secondary)
                    
                    Text("No Interviews Scheduled")
                        .font(.arial(size: 20, weight: .bold))
                    
                    Text("Add interview dates to your programs to track them here")
                        .font(.arial(size: 15))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .listRowSeparator(.hidden)
                }
            } else {
                
                // Upcoming Interviews
                if !upcomingInterviews.isEmpty {
                    Section {
                        ForEach(upcomingInterviews) { program in
                            NavigationLink(destination: ProgramEntryView(program: program)) {
                                InterviewRow(program: program, isUpcoming: true)
                            }
                        }
                    } header: {
                        Text("Upcoming (\(upcomingInterviews.count))")
                            .font(.arial(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                }
                
                // Past Interviews
                if !pastInterviews.isEmpty {
                    Section {
                        ForEach(pastInterviews) { program in
                            NavigationLink(destination: ProgramEntryView(program: program)) {
                                InterviewRow(program: program, isUpcoming: false)
                            }
                        }
                    } header: {
                        Text("Past (\(pastInterviews.count))")
                            .font(.arial(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .matchlyScrollTabBarClearance()
    }
    
    private var calendarView: some View {
        VStack(spacing: 0) {
            // Month Navigation Header
            HStack {
                Button(action: {
                    withAnimation {
                        selectedMonth = Calendar.current.date(byAdding: .month, value: -1, to: selectedMonth) ?? selectedMonth
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .font(.arial(size: 16, weight: .semibold))
                        .foregroundColor(.blue)
                        .padding(8)
                }
                .accessibilityLabel("Previous month")
                
                Spacer()
                
                Text(Self.monthYearFormatter.string(from: selectedMonth))
                    .font(.arial(size: 20, weight: .bold))
                
                Spacer()
                
                Button(action: {
                    withAnimation {
                        selectedMonth = Calendar.current.date(byAdding: .month, value: 1, to: selectedMonth) ?? selectedMonth
                    }
                }) {
                    Image(systemName: "chevron.right")
                        .font(.arial(size: 16, weight: .semibold))
                        .foregroundColor(.blue)
                        .padding(8)
                }
                .accessibilityLabel("Next month")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .glassEffect(.regular, in: .rect(cornerRadius: 12))
            .padding(.horizontal, 16)
            
            // Calendar Grid
            CalendarGridView(
                month: selectedMonth,
                interviews: allInterviews,
                selectedDate: $selectedDate
            )
            
            // Selected Date Details
            if let selectedDate = selectedDate {
                let interviewsOnDate = interviewsOnDate(selectedDate)
                if !interviewsOnDate.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Divider()
                        
                        Text("Interviews on \(Self.dayDateFormatter.string(from: selectedDate))")
                            .font(.arial(size: 16, weight: .semibold))
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(interviewsOnDate) { program in
                                    NavigationLink(destination: ProgramEntryView(program: program)) {
                                        CompactInterviewCard(program: program)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                        .padding(.bottom, 8)
                    }
                    .glassEffect(.regular, in: .rect(cornerRadius: 12))
                }
            }
        }
    }
    
    private func interviewsOnDate(_ date: Date) -> [Program] {
        let calendar = Calendar.current
        return allInterviews.filter { program in
            guard let interviewDate = program.interviewDate else { return false }
            return calendar.isDate(interviewDate, inSameDayAs: date)
        }
    }
    
    private static let monthYearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()
    
    private static let dayDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter
    }()
}

// MARK: - Calendar Grid View
struct CalendarGridView: View {
    let month: Date
    let interviews: [Program]
    @Binding var selectedDate: Date?
    
    private let calendar = Calendar.current
    private let weekdays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    
    private var monthStart: Date {
        calendar.dateInterval(of: .month, for: month)?.start ?? month
    }
    
    private var monthEnd: Date {
        calendar.dateInterval(of: .month, for: month)?.end ?? month
    }
    
    private var firstWeekday: Int {
        calendar.component(.weekday, from: monthStart) - 1
    }
    
    private var daysInMonth: Int {
        calendar.range(of: .day, in: .month, for: month)?.count ?? 30
    }
    
    private var daysToShow: [Date?] {
        var days: [Date?] = []
        
        // Add empty cells for days before month starts
        for _ in 0..<firstWeekday {
            days.append(nil)
        }
        
        // Add days in month
        for day in 1...daysInMonth {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: monthStart) {
                days.append(date)
            }
        }
        
        return days
    }
    
    private func hasInterview(on date: Date) -> Bool {
        return interviews.contains { program in
            guard let interviewDate = program.interviewDate else { return false }
            return calendar.isDate(interviewDate, inSameDayAs: date)
        }
    }
    
    private func interviewsCount(on date: Date) -> Int {
        return interviews.filter { program in
            guard let interviewDate = program.interviewDate else { return false }
            return calendar.isDate(interviewDate, inSameDayAs: date)
        }.count
    }
    
    private func isToday(_ date: Date) -> Bool {
        calendar.isDateInToday(date)
    }
    
    private func isSelected(_ date: Date) -> Bool {
        if let selected = selectedDate {
            return calendar.isDate(date, inSameDayAs: selected)
        }
        return false
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Weekday headers
            HStack(spacing: 0) {
                ForEach(weekdays, id: \.self) { weekday in
                    Text(weekday)
                        .font(.arial(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, 8)
            .glassEffect(.regular, in: .rect(cornerRadius: 12))
            
            // Calendar grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 0) {
                ForEach(Array(daysToShow.enumerated()), id: \.offset) { index, date in
                    if let date = date {
                        CalendarDayView(
                            date: date,
                            hasInterview: hasInterview(on: date),
                            interviewCount: interviewsCount(on: date),
                            isToday: isToday(date),
                            isSelected: isSelected(date)
                        )
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3)) {
                                if isSelected(date) {
                                    selectedDate = nil
                                } else {
                                    selectedDate = date
                                }
                            }
                        }
                    } else {
                        // Empty cell
                        Color.clear
                            .frame(height: 44)
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
        }
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
        .padding(.horizontal, 16)
        .padding(.bottom, 90) // Space for custom tab bar
    }
}

// MARK: - Calendar Day View
struct CalendarDayView: View {
    let date: Date
    let hasInterview: Bool
    let interviewCount: Int
    let isToday: Bool
    let isSelected: Bool
    
    private var dayNumber: Int {
        Calendar.current.component(.day, from: date)
    }
    
    var body: some View {
        VStack(spacing: 2) {
            Text("\(dayNumber)")
                .font(.arial(size: 16, weight: isToday || isSelected ? .bold : .regular))
                .foregroundColor(textColor)
            
            if hasInterview {
                Circle()
                    .fill(hasInterview ? Color.blue : Color.clear)
                    .frame(width: 6, height: 6)
            } else {
                Spacer()
                    .frame(height: 6)
            }
        }
        .frame(height: 44)
        .frame(maxWidth: .infinity)
        .background(backgroundColor)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isToday ? Color.blue : Color.clear, lineWidth: 2)
        )
    }
    
    private var textColor: Color {
        if isSelected {
            return .white
        } else if isToday {
            return .blue
        } else if hasInterview {
            return .primary
        } else {
            return .primary
        }
    }
    
    private var backgroundColor: Color {
        if isSelected {
            return Color.blue
        } else if isToday {
            return Color.blue.opacity(0.1)
        } else {
            return Color.clear
        }
    }
}

// MARK: - Compact Interview Card
struct CompactInterviewCard: View {
    let program: Program
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let date = program.interviewDate {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.arial(size: 10))
                    Text(Self.timeFormatter.string(from: date))
                        .font(.arial(size: 11, weight: .medium))
                }
                .foregroundColor(.blue)
            }
            
            Text(HospitalNameFormatter.format(program.hospital.isEmpty ? program.name : program.hospital))
                .font(.arial(size: 14, weight: .semibold))
                .lineLimit(2)
            
            if !program.city.isEmpty && !program.state.isEmpty {
                Text("\(program.city), \(program.state)")
                    .font(.arial(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(12)
        .frame(width: 160)
        .glassEffect(
            .regular.tint(Color.blue.opacity(0.12)),
            in: .rect(cornerRadius: 10)
        )
    }
    
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }()
}

struct InterviewRow: View {
    enum Style {
        case standard
        /// Dashboard hero — schedule column left of program details.
        case featured
    }

    let program: Program
    let isUpcoming: Bool
    var style: Style = .standard

    private var badgeColor: Color {
        isUpcoming ? AppColors.accentTeal : Color.secondary
    }

    var body: some View {
        HStack(alignment: style == .featured ? .center : .top, spacing: style == .featured ? 14 : 12) {
            if style == .featured {
                featuredScheduleColumn
            } else {
                dateBadge
            }

            programDetailsColumn

            Spacer(minLength: 0)
        }
        .padding(.vertical, style == .featured ? 4 : 6)
    }

    private var dateBadge: some View {
        ZStack {
            Circle()
                .fill(badgeColor.opacity(0.15))
                .frame(width: 42, height: 42)

            if let date = program.interviewDate {
                VStack(spacing: 0) {
                    Text(Self.dayFormatter.string(from: date))
                        .font(.arial(size: 15, weight: .bold))
                        .foregroundColor(badgeColor)
                    Text(Self.monthFormatter.string(from: date))
                        .font(.arial(size: 9, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var featuredScheduleColumn: some View {
        VStack(spacing: 6) {
            dateBadge

            if let date = program.interviewDate {
                Text(Self.timeFormatter.string(from: date))
                    .font(.arial(size: 13, weight: .semibold))
                    .foregroundStyle(AppColors.primaryText)
                    .multilineTextAlignment(.center)

                if isUpcoming {
                    let daysUntil = max(Calendar.current.dateComponents([.day], from: Date(), to: date).day ?? 0, 0)
                    Text(daysUntil == 1 ? "1 day" : "\(daysUntil) days")
                        .font(.arial(size: 11, weight: .bold))
                        .foregroundColor(AppColors.accentTeal)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppColors.accentTeal.opacity(0.14))
                        .clipShape(Capsule())
                }
            }
        }
        .frame(width: 56)
    }

    @ViewBuilder
    private var programDetailsColumn: some View {
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

            if style == .standard, let date = program.interviewDate {
                HStack(spacing: 8) {
                    HStack(spacing: 3) {
                        Image(systemName: "clock")
                            .font(.arial(size: 9))
                        Text(Self.timeFormatter.string(from: date))
                            .font(.arial(size: 11, weight: .medium))
                    }
                    .foregroundColor(.secondary)

                    if isUpcoming {
                        let daysUntil = Calendar.current.dateComponents([.day], from: Date(), to: date).day ?? 0
                        Text("\(daysUntil)d")
                            .font(.arial(size: 10, weight: .semibold))
                            .foregroundColor(AppColors.accentTeal)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppColors.accentTeal.opacity(0.12))
                            .cornerRadius(4)
                    }
                }
            }

            ProgramVoiceMemoBadge(program: program, iconSize: 9, textSize: 11)
        }
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter
    }()

    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }()
}

#Preview {
    MatchlyNavigationView {
        InterviewsView()
            .environmentObject(DataManager.shared)
    }
}

