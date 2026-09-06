//
//  CalendarManager.swift
//  Matchly
//
//  Created on 11/18/25.
//

import Foundation
import EventKit
import Combine
import UIKit
import CoreLocation
import OSLog

class CalendarManager: ObservableObject {
    static let shared = CalendarManager()
    
    @Published var authorizationStatus: EKAuthorizationStatus = .notDetermined
    @Published var calendarAccessGranted: Bool = false
    @Published var matchlyCalendar: EKCalendar?
    
    private let eventStore = EKEventStore()
    private let calendarTitle = "Matchly Interviews"
    private static let logger = Logger(subsystem: "com.matchly", category: "CalendarManager")
    
    private init() {
        checkAuthorizationStatus()
    }
    
    // MARK: - Authorization
    
    func requestAccess() async -> Bool {
        do {
            _ = try await eventStore.requestFullAccessToEvents()
            return await MainActor.run {
                authorizationStatus = EKEventStore.authorizationStatus(for: .event)
                calendarAccessGranted = authorizationStatus == .fullAccess
                if calendarAccessGranted {
                    findOrCreateMatchlyCalendar()
                }
                return calendarAccessGranted
            }
        } catch {
            Self.logger.error("Calendar access request failed: \(error.localizedDescription, privacy: .public)")
            await MainActor.run {
                authorizationStatus = EKEventStore.authorizationStatus(for: .event)
                calendarAccessGranted = false
            }
            return false
        }
    }
    
    @MainActor
    func checkAuthorizationStatus() {
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
        // Creating a dedicated calendar requires full read/write access (not write-only).
        calendarAccessGranted = authorizationStatus == .fullAccess
        
        if calendarAccessGranted {
            findOrCreateMatchlyCalendar()
        } else {
            matchlyCalendar = nil
        }
    }
    
    @MainActor
    func findOrCreateMatchlyCalendar() {
        if let storedIdentifier = UserDefaults.standard.string(forKey: Self.calendarIdentifierKey),
           let storedCalendar = eventStore.calendar(withIdentifier: storedIdentifier),
           storedCalendar.allowsContentModifications {
            matchlyCalendar = storedCalendar
            return
        }
        
        let calendars = eventStore.calendars(for: .event)
        if let existing = calendars.first(where: { $0.title == calendarTitle && $0.allowsContentModifications }) {
            matchlyCalendar = existing
            UserDefaults.standard.set(existing.calendarIdentifier, forKey: Self.calendarIdentifierKey)
            return
        }
        
        matchlyCalendar = createMatchlyCalendar()
        if let matchlyCalendar {
            UserDefaults.standard.set(matchlyCalendar.calendarIdentifier, forKey: Self.calendarIdentifierKey)
        }
    }
    
    private static let calendarIdentifierKey = "MatchlyCalendarIdentifier"
    
    /// Sources ordered by likelihood of supporting new calendar creation.
    private func orderedSourcesForCalendarCreation() -> [EKSource] {
        var ordered: [EKSource] = []
        var seen = Set<String>()
        
        func append(_ source: EKSource?) {
            guard let source, !seen.contains(source.sourceIdentifier) else { return }
            seen.insert(source.sourceIdentifier)
            ordered.append(source)
        }
        
        // On-device source is the most reliable for creating calendars.
        for source in eventStore.sources where source.sourceType == .local {
            append(source)
        }
        
        // iCloud (title may be localized, so match case-insensitively).
        for source in eventStore.sources where source.sourceType == .calDAV
            && source.title.localizedCaseInsensitiveContains("icloud") {
            append(source)
        }
        
        // Other CalDAV accounts (Exchange, etc.) — may reject creation; tried individually below.
        for source in eventStore.sources where source.sourceType == .calDAV {
            append(source)
        }
        
        // Last resort: default calendar's source, if that calendar is writable.
        if let defaultCalendar = eventStore.defaultCalendarForNewEvents,
           defaultCalendar.allowsContentModifications {
            append(defaultCalendar.source)
        }
        
        return ordered
    }
    
    @MainActor
    private func createMatchlyCalendar() -> EKCalendar? {
        let candidateSources = orderedSourcesForCalendarCreation()
        
        guard !candidateSources.isEmpty else {
            Self.logger.error("No calendar sources available for Matchly calendar creation")
            return nil
        }
        
        for source in candidateSources {
            let calendar = EKCalendar(for: .event, eventStore: eventStore)
            calendar.title = calendarTitle
            calendar.cgColor = UIColor.systemBlue.cgColor
            calendar.source = source
            
            do {
                try eventStore.saveCalendar(calendar, commit: true)
                Self.logger.info("Created Matchly calendar on source: \(source.title, privacy: .public)")
                return calendar
            } catch {
                Self.logger.error(
                    "Failed to create Matchly calendar on source \(source.title, privacy: .public): \(error.localizedDescription, privacy: .public)"
                )
            }
        }
        
        Self.logger.error("Exhausted all calendar sources; could not create Matchly calendar")
        return nil
    }
    
    func syncAllInterviewPrograms(_ programs: [Program]) async throws {
        try await createEventsForInterviews(programs.filter { $0.interviewDate != nil })
    }

    // MARK: - Calendar Events
    
    func createEventsForInterviews(_ programs: [Program]) async throws {
        guard calendarAccessGranted else {
            throw CalendarError.notAuthorized
        }

        if matchlyCalendar == nil {
            await MainActor.run {
                findOrCreateMatchlyCalendar()
            }
        }

        let calendar = await MainActor.run { matchlyCalendar }
        guard let calendar else {
            throw CalendarError.calendarNotFound
        }
        
        var createdCount = 0
        var updatedCount = 0
        var errorCount = 0
        
        for program in programs {
            guard let interviewDate = program.interviewDate else { continue }
            
            // Same cached geocoder as the in-app map, so the event pin matches Directions.
            let coordinate = await GeocodingHelper.coordinate(for: program)
            
            do {
                // Check if event already exists
                let existingEvent = try await findExistingEvent(for: program, in: calendar)
                
                if let event = existingEvent {
                    // Update existing event
                    applyEventDetails(to: event, program: program, interviewDate: interviewDate, coordinate: coordinate)
                    try eventStore.save(event, span: .thisEvent, commit: false)
                    updatedCount += 1
                } else {
                    // Create new event
                    let event = createEvent(for: program, interviewDate: interviewDate, in: calendar, coordinate: coordinate)
                    try eventStore.save(event, span: .thisEvent, commit: false)
                    createdCount += 1
                }
            } catch {
                Self.logger.error("Error processing interview for \(program.hospital, privacy: .public): \(error.localizedDescription, privacy: .public)")
                errorCount += 1
            }
        }
        
        // Commit all changes at once
        do {
            try eventStore.commit()
            Self.logger.info("Created \(createdCount) events, updated \(updatedCount) events")
            if errorCount > 0 {
                Self.logger.warning("\(errorCount) events had errors")
            }
        } catch {
            Self.logger.error("Failed to commit calendar changes: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }
    
    private func findExistingEvent(for program: Program, in calendar: EKCalendar) async throws -> EKEvent? {
        // Search for events in a date range around the interview date
        guard let interviewDate = program.interviewDate else { return nil }
        
        let startDate = Calendar.current.date(byAdding: .day, value: -1, to: interviewDate) ?? interviewDate
        let endDate = Calendar.current.date(byAdding: .day, value: 1, to: interviewDate) ?? interviewDate
        
        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: [calendar])
        let events = eventStore.events(matching: predicate)
        
        // Find event that matches this program (by hospital name or program ID in notes)
        return events.first { event in
            event.title.contains(program.hospital) || 
            event.title.contains(program.name) ||
            event.notes?.contains(program.id) == true
        }
    }
    
    private func createEvent(for program: Program, interviewDate: Date, in calendar: EKCalendar, coordinate: CLLocationCoordinate2D) -> EKEvent {
        let event = EKEvent(eventStore: eventStore)
        event.calendar = calendar
        event.isAllDay = false
        applyEventDetails(to: event, program: program, interviewDate: interviewDate, coordinate: coordinate)
        
        // Set alarm 1 day before
        let alarm = EKAlarm(relativeOffset: -86400) // 24 hours before
        event.addAlarm(alarm)
        
        return event
    }
    
    private func applyEventDetails(to event: EKEvent, program: Program, interviewDate: Date, coordinate: CLLocationCoordinate2D) {
        event.title = "Interview: \(HospitalNameFormatter.format(program.hospital.isEmpty ? program.name : program.hospital))"
        event.startDate = interviewDate
        event.endDate = Calendar.current.date(byAdding: .hour, value: 2, to: interviewDate) ?? interviewDate // Default 2-hour duration
        event.notes = eventNotes(for: program)
        
        // Same address string as the in-app Directions button, with a map pin so
        // Calendar shows the location and can offer travel time.
        let locationString = AddressFormatter.geocodingQuery(for: program)
        event.location = locationString
        let structuredLocation = EKStructuredLocation(title: locationString)
        structuredLocation.geoLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        event.structuredLocation = structuredLocation
    }
    
    private func eventNotes(for program: Program) -> String {
        var notes = "Residency Interview\n\n"
        if !program.specialty.isEmpty {
            notes += "Specialty: \(program.specialty)\n"
        }
        if program.hasDisplayLocation {
            notes += "Location: \(program.displayCityState)\n"
        }
        let resolved = program.resolvedAddress
        if !resolved.street.isEmpty {
            notes += "Address: \(resolved.street)\n"
        } else if let site = resolved.siteName, !site.isEmpty {
            notes += "Site: \(site)\n"
        }
        if let coordinator = program.programCoordinator, !coordinator.isEmpty {
            notes += "Coordinator: \(coordinator)\n"
        }
        if let email = program.contactEmail, !email.isEmpty {
            notes += "Email: \(email)\n"
        }
        if let website = program.websiteURL, !website.isEmpty {
            notes += "Website: \(website)\n"
        }
        if !program.notes.isEmpty {
            notes += "\nNotes: \(program.notes)\n"
        }
        notes += "\nProgram ID: \(program.id)"
        return notes
    }
    
    func removeEventsForProgram(_ program: Program) throws {
        guard calendarAccessGranted, let calendar = matchlyCalendar else {
            throw CalendarError.notAuthorized
        }
        
        guard let interviewDate = program.interviewDate else { return }
        
        let startDate = Calendar.current.date(byAdding: .day, value: -1, to: interviewDate) ?? interviewDate
        let endDate = Calendar.current.date(byAdding: .day, value: 1, to: interviewDate) ?? interviewDate
        
        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: [calendar])
        let events = eventStore.events(matching: predicate)
        
        for event in events {
            if event.notes?.contains(program.id) == true {
                try eventStore.remove(event, span: .thisEvent, commit: false)
            }
        }
        
        try eventStore.commit()
    }

    func removeAllMatchlyEvents() throws {
        guard calendarAccessGranted, let calendar = matchlyCalendar else {
            throw CalendarError.notAuthorized
        }
        
        // Get all events from the Matchly calendar
        let startDate = Date.distantPast
        let endDate = Date.distantFuture
        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: [calendar])
        let events = eventStore.events(matching: predicate)
        
        for event in events {
            try eventStore.remove(event, span: .thisEvent, commit: false)
        }
        
        try eventStore.commit()
        Self.logger.info("Removed all Matchly calendar events")
    }
}

enum CalendarError: LocalizedError {
    case notAuthorized
    case calendarNotFound
    case eventCreationFailed
    
    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Calendar access is required to create interview events. Please enable calendar access in Settings."
        case .calendarNotFound:
            return "Could not create the Matchly Interviews calendar. Make sure you grant Full Calendar Access (not Add Events Only) in Settings, then try again."
        case .eventCreationFailed:
            return "Failed to create calendar events. Please try again."
        }
    }
}

