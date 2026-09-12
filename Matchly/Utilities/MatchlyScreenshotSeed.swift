//
//  MatchlyScreenshotSeed.swift
//  Matchly
//
//  Loads polished demo data for App Store screenshots and marketing captures.
//

import Foundation

enum MatchlyScreenshotSeed {
    static let launchArgument = "-MatchlyScreenshotSeed"

    /// Call on launch (launch argument) or from Settings in DEBUG builds.
    @MainActor
    static func applyIfRequested() {
        guard ProcessInfo.processInfo.arguments.contains(launchArgument) else { return }
        apply()
    }

    @MainActor
    static func apply() {
        let manager = DataManager.shared
        var preferences = manager.preferences
        preferences.hasCompletedOnboarding = true
        preferences.hasCompletedFeatureTour = true
        preferences.hasCompletedCoupleFeatureTour = true
        preferences.shouldPromptFirstProgramAdd = false
        preferences.appearanceMode = .light
        preferences.specialties = ["Internal Medicine"]
        preferences.specialty = "Internal Medicine"
        preferences.applyingTrack = ProgramTrainingLevelFilter.residency.rawValue
        preferences.enableCalendarSync = true
        preferences.profile.firstName = "Alex"
        preferences.profile.lastName = "Chen"
        manager.preferences = preferences

        manager.programs = demoPrograms()
        manager.recalculateAllScores()
        manager.savePreferences()
        manager.saveProgramsImmediately()
    }

    private static func demoPrograms() -> [Program] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        struct Seed {
            let hospital: String
            let city: String
            let state: String
            let type: String
            let acgme: String
            let score: Double
            let rating: Double
            let daysUntilInterview: Int?
            let interviewHour: Int?
            let interviewMinute: Int?
            let signal: SignalType
            let redFlag: Bool
            let imgFriendly: Bool
            let emr: String?
            let notes: String
        }

        let seeds: [Seed] = [
            Seed(hospital: "Johns Hopkins Hospital", city: "Baltimore", state: "MD", type: "Academic", acgme: "1400121010", score: 92, rating: 4.8, daysUntilInterview: 4, interviewHour: 9, interviewMinute: 30, signal: .gold, redFlag: false, imgFriendly: true, emr: EMRSystem.epic.rawValue, notes: "Strong research mentorship; ask about Osler residency culture."),
            Seed(hospital: "Massachusetts General Hospital", city: "Boston", state: "MA", type: "Academic", acgme: "1400121020", score: 89, rating: 4.6, daysUntilInterview: 9, interviewHour: 14, interviewMinute: 0, signal: .gold, redFlag: false, imgFriendly: false, emr: EMRSystem.epic.rawValue, notes: "Harvard affiliation; clarify night-float structure."),
            Seed(hospital: "Brigham and Women's Hospital", city: "Boston", state: "MA", type: "Academic", acgme: "1400121030", score: 87, rating: 4.5, daysUntilInterview: 14, interviewHour: 10, interviewMinute: 15, signal: .none, redFlag: false, imgFriendly: true, emr: EMRSystem.epic.rawValue, notes: "Women's health focus; friendly resident panel."),
            Seed(hospital: "Mayo Clinic", city: "Rochester", state: "MN", type: "Academic", acgme: "1400121040", score: 85, rating: 4.4, daysUntilInterview: 21, interviewHour: 13, interviewMinute: 45, signal: .none, redFlag: false, imgFriendly: true, emr: EMRSystem.epic.rawValue, notes: "Team-based learning model; ask about elective time."),
            Seed(hospital: "Cleveland Clinic", city: "Cleveland", state: "OH", type: "Academic", acgme: "1400121050", score: 83, rating: 4.2, daysUntilInterview: -6, interviewHour: 8, interviewMinute: 0, signal: .none, redFlag: false, imgFriendly: true, emr: EMRSystem.epic.rawValue, notes: "Cardiology exposure; completed interview — great PD conversation."),
            Seed(hospital: "UCSF Medical Center", city: "San Francisco", state: "CA", type: "Academic", acgme: "1400121060", score: 81, rating: 4.1, daysUntilInterview: -12, interviewHour: 15, interviewMinute: 30, signal: .none, redFlag: false, imgFriendly: false, emr: EMRSystem.epic.rawValue, notes: "Mission-driven culture; high cost of living."),
            Seed(hospital: "Duke University Hospital", city: "Durham", state: "NC", type: "Academic", acgme: "1400121070", score: 78, rating: 3.9, daysUntilInterview: nil, interviewHour: nil, interviewMinute: nil, signal: .none, redFlag: false, imgFriendly: true, emr: EMRSystem.epic.rawValue, notes: "Schedule interview — interested in research track."),
            Seed(hospital: "Northwestern Memorial Hospital", city: "Chicago", state: "IL", type: "Academic", acgme: "1400121080", score: 76, rating: 3.8, daysUntilInterview: nil, interviewHour: nil, interviewMinute: nil, signal: .none, redFlag: false, imgFriendly: true, emr: EMRSystem.epic.rawValue, notes: "Urban training; compare with UChicago."),
            Seed(hospital: "NYU Langone Health", city: "New York", state: "NY", type: "Academic", acgme: "1400121090", score: 74, rating: 3.7, daysUntilInterview: nil, interviewHour: nil, interviewMinute: nil, signal: .none, redFlag: true, imgFriendly: false, emr: EMRSystem.epic.rawValue, notes: "Red flag: residents mentioned heavy overnight burden."),
            Seed(hospital: "Stanford Health Care", city: "Stanford", state: "CA", type: "Academic", acgme: "1400121100", score: 72, rating: 3.5, daysUntilInterview: nil, interviewHour: nil, interviewMinute: nil, signal: .none, redFlag: false, imgFriendly: true, emr: EMRSystem.epic.rawValue, notes: "Still scoring questionnaire after virtual open house."),
            Seed(hospital: "University of Michigan", city: "Ann Arbor", state: "MI", type: "Academic", acgme: "1400121110", score: 68, rating: 3.2, daysUntilInterview: nil, interviewHour: nil, interviewMinute: nil, signal: .none, redFlag: false, imgFriendly: true, emr: EMRSystem.epic.rawValue, notes: "Incomplete questionnaire — finish after second look."),
            Seed(hospital: "Emory University School of Medicine", city: "Atlanta", state: "GA", type: "Academic", acgme: "1400121120", score: 0, rating: 0, daysUntilInterview: nil, interviewHour: nil, interviewMinute: nil, signal: .none, redFlag: false, imgFriendly: true, emr: nil, notes: "Added from ERAS — not yet scored.")
        ]

        return seeds.enumerated().map { index, seed in
            var questionnaire = Questionnaire()
            if seed.rating > 0 {
                questionnaire = ratedQuestionnaire(stars: seed.rating)
            }
            if seed.redFlag {
                markFirstRedFlag(in: &questionnaire)
            }

            let interviewDate: Date? = seed.daysUntilInterview.map { offset in
                scheduledInterviewDate(
                    calendar: calendar,
                    from: today,
                    dayOffset: offset,
                    hour: seed.interviewHour ?? 9,
                    minute: seed.interviewMinute ?? 0
                )
            }

            return Program(
                id: "screenshot-\(index + 1)",
                specialty: "Internal Medicine",
                name: "\(seed.hospital) Internal Medicine",
                hospital: seed.hospital,
                city: seed.city,
                state: seed.state,
                type: seed.type,
                accreditationID: seed.acgme,
                questionnaire: questionnaire,
                notes: seed.notes,
                interviewDate: interviewDate,
                isIMGFriendly: seed.imgFriendly,
                emr: seed.emr,
                signalType: seed.signal,
                finalScore: seed.score
            )
        }
    }

    private static func ratedQuestionnaire(stars: Double) -> Questionnaire {
        var questionnaire = Questionnaire()
        for sectionIndex in questionnaire.sections.indices {
            for itemIndex in questionnaire.sections[sectionIndex].items.indices {
                questionnaire.sections[sectionIndex].items[itemIndex].programRating = stars
            }
        }
        return questionnaire
    }

    /// Marks the first red-flag section item as "Yes" so the badge appears in list shots.
    private static func markFirstRedFlag(in questionnaire: inout Questionnaire) {
        guard let redFlagSectionIndex = questionnaire.sections.firstIndex(where: { $0.title.localizedCaseInsensitiveContains("red flag") }) else {
            return
        }
        guard !questionnaire.sections[redFlagSectionIndex].items.isEmpty else { return }
        questionnaire.sections[redFlagSectionIndex].items[0].programRating = 1
    }

    private static func scheduledInterviewDate(
        calendar: Calendar,
        from baseDay: Date,
        dayOffset: Int,
        hour: Int,
        minute: Int
    ) -> Date {
        let day = calendar.date(byAdding: .day, value: dayOffset, to: baseDay) ?? baseDay
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
    }
}
