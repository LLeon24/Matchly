//
//  InterviewsView.swift
//  Matchly
//
//  Created on 11/14/25.
//

import SwiftUI

struct InterviewsView: View {
    @EnvironmentObject var dataManager: DataManager
    @EnvironmentObject private var deepLinkHandler: CoupleDeepLinkHandler
    @State private var viewMode: ViewMode = .list
    @State private var selectedMonth: Date = Date()
    @State private var selectedDate: Date?

    private enum ScrollAnchor {
        static let upcomingSection = "interviews-upcoming-section"
    }

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
            MatchlyListPageTitleRow(title: "Interviews")

            // View Mode Picker
            MatchlyColoredTabBar(
                options: [
                    MatchlyColoredTabOption(value: ViewMode.list, title: "List", tint: AppColors.accentTeal),
                    MatchlyColoredTabOption(value: ViewMode.calendar, title: "Calendar", tint: AppColors.pipelineUpcoming)
                ],
                selection: $viewMode
            )
            .padding(.bottom, 10)
            
            if viewMode == .list {
                listView
            } else {
                ScrollView {
                    calendarView
                }
                .scrollContentBackground(.hidden)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .matchlyScrollTabBarClearance()
        .appCanvasBackground()
    }
    
    private var listView: some View {
        ScrollViewReader { proxy in
            List {
                Section {
                    MatchlyCalendarSyncRow(syncOnAppearIfEnabled: true)
                        .listRowBackground(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(.clear)
                                .glassEffect(.regular, in: .rect(cornerRadius: 16))
                        )
                }

                if !programsNeedingDates.isEmpty {
                    Section {
                        ForEach(programsNeedingDates) { program in
                            NavigationLink(destination: ProgramEntryView(program: program)) {
                                ProgramNeedingInterviewDateRow(program: program)
                            }
                        }
                    } header: {
                        interviewsSectionHeader("Needs a Date (\(programsNeedingDates.count))")
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
                            Color.clear
                                .frame(height: 0)
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                                .id(ScrollAnchor.upcomingSection)

                            ForEach(upcomingInterviews) { program in
                                NavigationLink(destination: ProgramEntryView(program: program)) {
                                    InterviewRow(program: program, isUpcoming: true)
                                }
                            }
                        } header: {
                            interviewsSectionHeader("Upcoming (\(upcomingInterviews.count))")
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
                            interviewsSectionHeader("Past (\(pastInterviews.count))")
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .contentMargins(.top, 0, for: .scrollContent)
            .scrollContentBackground(.hidden)
            .matchlyScrollTabBarClearance()
            .onAppear {
                scrollToPendingFocus(using: proxy)
            }
            .onChange(of: deepLinkHandler.pendingInterviewsListFocus) { _, focus in
                guard focus == .upcoming else { return }
                scrollToPendingFocus(using: proxy)
            }
        }
    }

    private func scrollToPendingFocus(using proxy: ScrollViewProxy) {
        guard deepLinkHandler.consumeInterviewsListFocus() == .upcoming else { return }
        viewMode = .list
        guard !upcomingInterviews.isEmpty else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.easeInOut(duration: 0.25)) {
                proxy.scrollTo(ScrollAnchor.upcomingSection, anchor: .top)
            }
        }
    }
    
    private func interviewsSectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.arial(size: 14, weight: .bold))
            .foregroundColor(.primary)
            .textCase(nil)
    }

    private var calendarView: some View {
        VStack(spacing: 12) {
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
                        Text("Interviews on \(Self.dayDateFormatter.string(from: selectedDate))")
                            .font(.arial(size: 16, weight: .semibold))
                            .padding(.horizontal, 16)

                        VStack(spacing: 12) {
                            ForEach(interviewsOnDate) { program in
                                NavigationLink(destination: ProgramEntryView(program: program)) {
                                    InterviewRow(
                                        program: program,
                                        isUpcoming: (program.interviewDate ?? Date()) >= Date(),
                                        style: .featured
                                    )
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(AppColors.accentTeal.opacity(0.08))
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassEffect(.regular, in: .rect(cornerRadius: 12))
                    .padding(.horizontal, 16)
                }
            }
        }
        .padding(.top, 4)
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
            
            if program.hasDisplayLocation {
                Text(program.displayCityState)
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
        /// Dashboard hero — full-width program with inline schedule row.
        case featured
    }

    let program: Program
    let isUpcoming: Bool
    var style: Style = .standard

    private var badgeColor: Color {
        isUpcoming ? AppColors.accentTeal : Color.secondary
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if style == .standard {
                dateBadge
            }

            programDetailsColumn

            Spacer(minLength: 0)
        }
        .padding(.vertical, style == .featured ? 2 : 6)
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
    private var programDetailsColumn: some View {
        VStack(alignment: .leading, spacing: style == .featured ? 4 : 3) {
            Text(HospitalNameFormatter.format(
                program.hospital.isEmpty
                    ? (program.name.isEmpty ? "Unnamed Program" : program.name)
                    : program.hospital
            ))
            .font(.arial(size: 15, weight: .semibold))
            .lineLimit(style == .featured ? 2 : 3)
            .fixedSize(horizontal: false, vertical: true)

            if style == .featured, let date = program.interviewDate {
                featuredScheduleLine(for: date)
            }

            if style == .featured {
                featuredMetadataRow
            } else if !program.specialty.isEmpty {
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

    @ViewBuilder
    private var featuredMetadataRow: some View {
        HStack(spacing: 6) {
            if !program.specialty.isEmpty {
                MatchlyProgramSpecialtyBadge(
                    specialty: program.specialty,
                    useFullName: true
                )
            }

            if program.signalType != .none {
                featuredSignalBadge
            }
        }
    }

    @ViewBuilder
    private var featuredSignalBadge: some View {
        let isTiered = SignalLimits.isTiered(
            for: program.specialty,
            accreditationID: program.accreditationID
        )
        let signalText = isTiered
            ? (program.signalType == .gold ? "Gold Signal" : "Silver Signal")
            : "Signal"
        let signalColor: Color = isTiered
            ? (program.signalType == .gold ? Color.yellow : Color(white: 0.6))
            : AppColors.primaryBlue

        HStack(spacing: 3) {
            Image(systemName: program.signalType == .gold ? "star.fill" : "star")
                .font(.arial(size: 8))
            Text(signalText)
                .font(.arial(size: 10, weight: .semibold))
        }
        .foregroundColor(signalColor)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(signalColor.opacity(0.15))
        .cornerRadius(4)
    }

    private func featuredScheduleLine(for date: Date) -> some View {
        HStack(spacing: 6) {
            featuredDateTimeChip(for: date)

            if isUpcoming {
                scheduleSeparator

                let daysUntil = max(Calendar.current.dateComponents([.day], from: Date(), to: date).day ?? 0, 0)
                Text(daysUntil == 1 ? "1 day" : "\(daysUntil) days")
                    .font(.arial(size: 10, weight: .bold))
                    .foregroundColor(AppColors.pipelineUpcoming)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(AppColors.pipelineUpcoming.opacity(0.12))
                    .clipShape(Capsule())
            }
        }
    }

    private func featuredDateTimeChip(for date: Date) -> some View {
        HStack(spacing: 4) {
            Text(Self.featuredDateFormatter.string(from: date))
            Text("·")
                .foregroundColor(AppColors.accentTeal.opacity(0.55))
            Text(Self.timeFormatter.string(from: date))
        }
        .font(.arial(size: 12, weight: .semibold))
        .foregroundColor(AppColors.accentTeal)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(AppColors.accentTeal.opacity(0.12))
        .clipShape(Capsule())
    }

    private var scheduleSeparator: some View {
        Text("·")
            .font(.arial(size: 12, weight: .medium))
            .foregroundColor(.secondary)
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

    private static let featuredDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
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
            .environmentObject(CoupleDeepLinkHandler())
    }
}

