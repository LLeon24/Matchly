//
//  MatchlyWidget.swift
//  MatchlyWidgetExtension
//
//  Home / lock screen widget showing upcoming residency interviews.
//  Data comes from the app via the App Group container (see
//  DataManager.publishWidgetSnapshot()).
//

import WidgetKit
import SwiftUI

// MARK: - Shared data

enum WidgetData {
    static let appGroupID = "group.com.lleonmd.Matchly"
    static let interviewsKey = "widget_upcoming_interviews"

    struct Interview: Identifiable {
        let id: String
        let title: String
        let subtitle: String
        let date: Date
    }

    /// Interviews from today onward, soonest first, relative to `referenceDate`.
    static func upcomingInterviews(asOf referenceDate: Date) -> [Interview] {
        guard let defaults = UserDefaults(suiteName: appGroupID),
              let raw = defaults.array(forKey: interviewsKey) as? [[String: Any]] else {
            return []
        }
        let dayStart = Calendar.current.startOfDay(for: referenceDate)
        return raw
            .compactMap { dict -> Interview? in
                guard let id = dict["id"] as? String,
                      let title = dict["title"] as? String,
                      let timestamp = dict["date"] as? TimeInterval else { return nil }
                return Interview(
                    id: id,
                    title: title,
                    subtitle: dict["subtitle"] as? String ?? "",
                    date: Date(timeIntervalSince1970: timestamp)
                )
            }
            .filter { $0.date >= dayStart }
            .sorted { $0.date < $1.date }
    }
}

// MARK: - Timeline

struct InterviewsEntry: TimelineEntry {
    let date: Date
    let interviews: [WidgetData.Interview]
}

struct InterviewsProvider: TimelineProvider {
    func placeholder(in context: Context) -> InterviewsEntry {
        InterviewsEntry(date: Date(), interviews: Self.sampleInterviews)
    }

    func getSnapshot(in context: Context, completion: @escaping (InterviewsEntry) -> Void) {
        let interviews = WidgetData.upcomingInterviews(asOf: Date())
        completion(InterviewsEntry(
            date: Date(),
            interviews: context.isPreview && interviews.isEmpty ? Self.sampleInterviews : interviews
        ))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<InterviewsEntry>) -> Void) {
        // One entry now plus one per upcoming midnight, so "in N days" stays
        // correct even if the app isn't opened for a week.
        let calendar = Calendar.current
        let now = Date()
        var entries: [InterviewsEntry] = [
            InterviewsEntry(date: now, interviews: WidgetData.upcomingInterviews(asOf: now))
        ]
        for dayOffset in 1...30 {
            guard let midnight = calendar.date(
                byAdding: .day,
                value: dayOffset,
                to: calendar.startOfDay(for: now)
            ) else { continue }
            entries.append(InterviewsEntry(
                date: midnight,
                interviews: WidgetData.upcomingInterviews(asOf: midnight)
            ))
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    static let sampleInterviews: [WidgetData.Interview] = [
        .init(
            id: "sample-1",
            title: "Orlando Regional Medical Center",
            subtitle: "EM • Orlando, FL",
            date: Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date()
        ),
        .init(
            id: "sample-2",
            title: "Mount Sinai Hospital",
            subtitle: "EM • New York, NY",
            date: Calendar.current.date(byAdding: .day, value: 9, to: Date()) ?? Date()
        )
    ]
}

// MARK: - Styling helpers

private enum WidgetStyle {
    static let brandBlue = Color(red: 0.0, green: 0.48, blue: 0.65)
    static let brandTeal = Color(red: 0.2, green: 0.7, blue: 0.8)

    static func countdownText(to date: Date, from referenceDate: Date) -> String {
        let calendar = Calendar.current
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: referenceDate),
            to: calendar.startOfDay(for: date)
        ).day ?? 0
        switch days {
        case 0: return "Today"
        case 1: return "Tomorrow"
        default: return "In \(days) days"
        }
    }

    static func shortDate(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }
}

// MARK: - Views

struct InterviewsWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    var entry: InterviewsEntry

    var body: some View {
        Group {
            switch family {
            case .accessoryRectangular:
                accessoryRectangular
            case .systemMedium:
                medium
            default:
                small
            }
        }
        .widgetURL(URL(string: "matchly://interviews"))
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 4) {
            header
            Spacer(minLength: 2)
            if let next = entry.interviews.first {
                Text(WidgetStyle.countdownText(to: next.date, from: entry.date))
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(WidgetStyle.brandBlue)
                    .minimumScaleFactor(0.7)
                Text(next.title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(2)
                Text(WidgetStyle.shortDate(next.date))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            } else {
                emptyState
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var medium: some View {
        VStack(alignment: .leading, spacing: 6) {
            header
            if entry.interviews.isEmpty {
                Spacer()
                emptyState
                Spacer()
            } else {
                ForEach(entry.interviews.prefix(3)) { interview in
                    HStack(alignment: .top, spacing: 8) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(interview.title)
                                .font(.system(size: 12, weight: .semibold))
                                .lineLimit(2)
                                .minimumScaleFactor(0.85)
                                .fixedSize(horizontal: false, vertical: true)
                            if !interview.subtitle.isEmpty {
                                Text(interview.subtitle)
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        Spacer(minLength: 8)
                        VStack(alignment: .trailing, spacing: 1) {
                            Text(WidgetStyle.countdownText(to: interview.date, from: entry.date))
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(WidgetStyle.brandBlue)
                            Text(WidgetStyle.shortDate(interview.date))
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var accessoryRectangular: some View {
        VStack(alignment: .leading, spacing: 1) {
            if let next = entry.interviews.first {
                Text("\(Image(systemName: "stethoscope")) \(WidgetStyle.countdownText(to: next.date, from: entry.date))")
                    .font(.headline)
                Text(next.title)
                    .font(.caption)
                    .lineLimit(2)
            } else {
                Text("\(Image(systemName: "stethoscope")) Matchly")
                    .font(.headline)
                Text("No upcoming interviews")
                    .font(.caption)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var header: some View {
        HStack(spacing: 4) {
            Image(systemName: "stethoscope")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(WidgetStyle.brandTeal)
            Text(entry.interviews.count > 1 ? "UPCOMING INTERVIEWS" : "NEXT INTERVIEW")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)
                .kerning(0.6)
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("No upcoming interviews")
                .font(.system(size: 13, weight: .semibold))
            Text("Add an interview date in Matchly")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Widget

struct MatchlyWidget: Widget {
    let kind: String = "MatchlyWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: InterviewsProvider()) { entry in
            InterviewsWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    Color(uiColor: .systemBackground)
                }
        }
        .configurationDisplayName("Upcoming Interviews")
        .description("See your next residency interviews at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

#Preview(as: .systemSmall) {
    MatchlyWidget()
} timeline: {
    InterviewsEntry(date: .now, interviews: InterviewsProvider.sampleInterviews)
}

#Preview(as: .systemMedium) {
    MatchlyWidget()
} timeline: {
    InterviewsEntry(date: .now, interviews: InterviewsProvider.sampleInterviews)
}
