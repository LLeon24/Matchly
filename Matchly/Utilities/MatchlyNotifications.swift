//
//  MatchlyNotifications.swift
//  Matchly
//

import Foundation

extension Notification.Name {
    /// Posted when Interview Prep should return to the program editor and focus the questionnaire.
    static let matchlyFocusProgramQuestionnaire = Notification.Name("matchlyFocusProgramQuestionnaire")
}

enum MatchlyNotificationKey {
    static let programId = "programId"
}
