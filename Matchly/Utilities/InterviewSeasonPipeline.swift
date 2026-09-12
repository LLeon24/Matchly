//
//  InterviewSeasonPipeline.swift
//  Matchly
//
//  Dashboard hero stats and ring segments for interview season tracking.
//

import SwiftUI

enum InterviewSeasonStage: String, CaseIterable, Identifiable {
    case needDate
    case upcoming
    case toReview
    case scored

    var id: String { rawValue }

    var label: String {
        switch self {
        case .needDate: return "Need Date"
        case .upcoming: return "Upcoming"
        case .scored: return "Scored"
        case .toReview: return "Incomplete"
        }
    }

    var color: Color {
        switch self {
        case .needDate: return AppColors.pipelineNeedDate
        case .upcoming: return AppColors.pipelineUpcoming
        case .scored: return AppColors.pipelineScored
        case .toReview: return AppColors.pipelineToReview
        }
    }

    /// Independent stat count for the dashboard hero row. Categories may overlap —
    /// e.g. a program can be both Upcoming and Scored.
    ///
    /// - **Incomplete:** incomplete questionnaire (My Programs → Incomplete).
    /// - **Upcoming:** interview scheduled in the future (`InterviewsView` upcoming section).
    /// - **Need Date:** no interview date yet (Interviews list “Needs a Date” section).
    /// - **Scored:** rank-list ready — questionnaire complete with a score (`RankListView`).
    static func statCount(
        _ stage: InterviewSeasonStage,
        for programs: [Program],
        preferences: UserPreferences,
        now: Date = Date()
    ) -> Int {
        switch stage {
        case .toReview:
            return programs.filter { $0.needsScoring(preferences: preferences) }.count
        case .upcoming:
            return programs.filter { program in
                guard let date = program.interviewDate else { return false }
                return date >= now
            }.count
        case .needDate:
            return programs.filter { $0.interviewDate == nil }.count
        case .scored:
            return programs.filter { isRankReady($0, preferences: preferences) }.count
        }
    }

    static func statCounts(
        for programs: [Program],
        preferences: UserPreferences,
        now: Date = Date()
    ) -> [InterviewSeasonStage: Int] {
        Dictionary(
            uniqueKeysWithValues: InterviewSeasonStage.allCases.map { stage in
                (stage, statCount(stage, for: programs, preferences: preferences, now: now))
            }
        )
    }

    /// One stage per program for the hero ring — mutually exclusive, priority:
    /// to review → upcoming → need date → scored.
    static func ringStage(
        for program: Program,
        preferences: UserPreferences,
        now: Date = Date()
    ) -> InterviewSeasonStage {
        if program.needsScoring(preferences: preferences) {
            return .toReview
        }
        if let date = program.interviewDate, date >= now {
            return .upcoming
        }
        if program.interviewDate == nil {
            return .needDate
        }
        if isRankReady(program, preferences: preferences) {
            return .scored
        }
        return .toReview
    }

    /// Backward-compatible alias used by tests and call sites.
    static func stage(
        for program: Program,
        preferences: UserPreferences,
        now: Date = Date()
    ) -> InterviewSeasonStage {
        ringStage(for: program, preferences: preferences, now: now)
    }

    static func ringStageCounts(
        for programs: [Program],
        preferences: UserPreferences,
        now: Date = Date()
    ) -> [InterviewSeasonStage: Int] {
        var result: [InterviewSeasonStage: Int] = [:]
        for stage in InterviewSeasonStage.allCases {
            result[stage] = 0
        }
        for program in programs {
            let stage = ringStage(for: program, preferences: preferences, now: now)
            result[stage, default: 0] += 1
        }
        return result
    }

    /// Matches Rank List eligibility: questionnaire complete and has a computed score.
    static func isRankReady(_ program: Program, preferences: UserPreferences) -> Bool {
        !program.needsScoring(preferences: preferences) && program.finalScore > 0
    }

    static func counts(
        for programs: [Program],
        preferences: UserPreferences,
        now: Date = Date()
    ) -> [InterviewSeasonStage: Int] {
        ringStageCounts(for: programs, preferences: preferences, now: now)
    }
}
