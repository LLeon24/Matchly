//
//  ProgramInterviewScheduleLine.swift
//  Matchly
//
//  Shared interview schedule/status chips for My Programs and Interviews.
//

import SwiftUI

enum ProgramInterviewSchedulePhase: Equatable {
    case needsDate
    case today(Date)
    case upcoming(Date, daysUntil: Int)
    case past(Date, daysAgo: Int)

    static func resolve(for program: Program, now: Date = Date()) -> ProgramInterviewSchedulePhase {
        guard let date = program.interviewDate else { return .needsDate }

        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: now)
        let startOfInterviewDay = calendar.startOfDay(for: date)

        if calendar.isDate(date, inSameDayAs: now) {
            return .today(date)
        }
        if date >= now {
            let daysUntil = max(
                calendar.dateComponents([.day], from: startOfToday, to: startOfInterviewDay).day ?? 0,
                0
            )
            return .upcoming(date, daysUntil: daysUntil)
        }
        let daysAgo = max(
            calendar.dateComponents([.day], from: startOfInterviewDay, to: startOfToday).day ?? 0,
            0
        )
        return .past(date, daysAgo: daysAgo)
    }
}

struct ProgramInterviewScheduleLine: View {
    enum Style {
        /// Single-line summary for My Programs rows.
        case compact
        /// Date/time chip + status pill for Interviews list and calendar cards.
        case chips
    }

    let program: Program
    var style: Style = .compact
    var now: Date = Date()

    private var phase: ProgramInterviewSchedulePhase {
        ProgramInterviewSchedulePhase.resolve(for: program, now: now)
    }

    var body: some View {
        switch style {
        case .compact:
            compactLine
        case .chips:
            chipsLine
        }
    }

    @ViewBuilder
    private var compactLine: some View {
        switch phase {
        case .needsDate:
            needsDateLabel
        case .today(let date):
            compactText("\(Self.todayLabel) · \(Self.timeFormatter.string(from: date))", tint: AppColors.pipelineUpcoming)
        case .upcoming(let date, let daysUntil):
            compactText(
                "\(Self.shortDateFormatter.string(from: date)) · \(Self.timeFormatter.string(from: date)) · \(countdownLabel(daysUntil: daysUntil, prefixIn: true))",
                tint: AppColors.pipelineUpcoming
            )
        case .past(let date, let daysAgo):
            compactText(
                "\(Self.shortDateFormatter.string(from: date)) · \(elapsedLabel(daysAgo: daysAgo, includeCompletedPrefix: true))",
                tint: .secondary
            )
        }
    }

    @ViewBuilder
    private var chipsLine: some View {
        switch phase {
        case .needsDate:
            needsDateLabel
        case .today(let date):
            HStack(spacing: 6) {
                dateTimeChip(for: date, tint: AppColors.pipelineUpcoming)
                statusPill(text: Self.todayLabel, tint: AppColors.pipelineUpcoming)
            }
        case .upcoming(let date, let daysUntil):
            HStack(spacing: 6) {
                dateTimeChip(for: date, tint: AppColors.accentTeal)
                statusPill(text: countdownLabel(daysUntil: daysUntil), tint: AppColors.pipelineUpcoming)
            }
        case .past(let date, let daysAgo):
            HStack(spacing: 6) {
                dateTimeChip(for: date, tint: .secondary)
                statusPill(text: elapsedLabel(daysAgo: daysAgo, includeCompletedPrefix: false), tint: AppColors.pipelineScored)
            }
        }
    }

    private var needsDateLabel: some View {
        HStack(spacing: 4) {
            Image(systemName: "calendar.badge.plus")
                .font(.arial(size: 9, weight: .semibold))
            Text("Needs interview date")
                .font(.arial(size: 11, weight: .semibold))
        }
        .foregroundColor(AppColors.pipelineNeedDate)
    }

    private func compactText(_ text: String, tint: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "calendar")
                .font(.arial(size: 9, weight: .semibold))
            Text(text)
                .font(.arial(size: 11, weight: .medium))
                .lineLimit(2)
        }
        .foregroundColor(tint)
    }

    private func dateTimeChip(for date: Date, tint: Color) -> some View {
        HStack(spacing: 4) {
            Text(Self.shortDateFormatter.string(from: date))
            Text("·")
                .foregroundColor(tint.opacity(0.55))
            Text(Self.timeFormatter.string(from: date))
        }
        .font(.arial(size: 12, weight: .semibold))
        .foregroundColor(tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(tint.opacity(0.12))
        .clipShape(Capsule())
    }

    private func statusPill(text: String, tint: Color) -> some View {
        Text(text)
            .font(.arial(size: 10, weight: .bold))
            .foregroundColor(tint)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(tint.opacity(0.12))
            .clipShape(Capsule())
    }

    private func countdownLabel(daysUntil: Int, prefixIn: Bool = false) -> String {
        switch daysUntil {
        case 0: return Self.todayLabel
        case 1: return prefixIn ? "in 1 day" : "1 day"
        default: return prefixIn ? "in \(daysUntil) days" : "\(daysUntil) days"
        }
    }

    private func elapsedLabel(daysAgo: Int, includeCompletedPrefix: Bool) -> String {
        switch daysAgo {
        case 0:
            return includeCompletedPrefix ? "Completed today" : "Today"
        case 1:
            return includeCompletedPrefix ? "Completed yesterday" : "1 day ago"
        default:
            return includeCompletedPrefix ? "Completed \(daysAgo) days ago" : "\(daysAgo) days ago"
        }
    }

    private static let todayLabel = "Today"

    private static let shortDateFormatter: DateFormatter = {
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
