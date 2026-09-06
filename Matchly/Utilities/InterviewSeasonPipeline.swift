//
//  InterviewSeasonPipeline.swift
//  Matchly
//
//  Mutually exclusive per-program pipeline stage for the dashboard hero ring and stats.
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
        case .toReview: return "To Review"
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

    /// One stage per program — priority: to review → scored → upcoming → need date.
    ///
    /// - **To Review:** questionnaire still incomplete (matches Programs Needing Review).
    /// - **Scored:** questionnaire complete with a rank-list score (matches Rank List).
    /// - **Upcoming:** interview scheduled in the future but not scored yet.
    /// - **Need Date:** tracked invite with no interview date and not scored yet.
    static func stage(
        for program: Program,
        preferences: UserPreferences,
        now: Date = Date()
    ) -> InterviewSeasonStage {
        if program.needsScoring(preferences: preferences) {
            return .toReview
        }
        if isRankReady(program, preferences: preferences) {
            return .scored
        }
        if let date = program.interviewDate, date >= now {
            return .upcoming
        }
        if program.interviewDate == nil {
            return .needDate
        }
        // Past interview with a complete questionnaire but no score yet.
        return .toReview
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
        var result: [InterviewSeasonStage: Int] = [:]
        for stage in InterviewSeasonStage.allCases {
            result[stage] = 0
        }
        for program in programs {
            let stage = stage(for: program, preferences: preferences, now: now)
            result[stage, default: 0] += 1
        }
        return result
    }
}
