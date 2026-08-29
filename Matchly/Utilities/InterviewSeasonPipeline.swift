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

    /// One stage per program — priority: upcoming → to review → need date → scored.
    ///
    /// - **Upcoming:** interview scheduled in the future.
    /// - **To Review:** questionnaire still incomplete (matches Programs Needing Review).
    /// - **Need Date:** questionnaire complete but no interview date yet.
    /// - **Scored:** past interview and questionnaire complete.
    static func stage(
        for program: Program,
        preferences: UserPreferences,
        now: Date = Date()
    ) -> InterviewSeasonStage {
        if let date = program.interviewDate, date >= now {
            return .upcoming
        }
        if program.needsScoring(preferences: preferences) {
            return .toReview
        }
        if program.interviewDate == nil {
            return .needDate
        }
        return .scored
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
