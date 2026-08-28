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
            let granted = try await eventStore.requestFullAccessToEvents()
            await MainActor.run {
                authorizationStatus = EKEventStore.authorizationStatus(for: .event)
                calendarAccessGranted = granted
                if granted {
                    findOrCreateMatchlyCalendar()
                }
            }
            return granted
        } catch {
            Self.logger.error("Calendar access request failed: \(error.localizedDescription, privacy: .public)")
            await MainActor.run {
                authorizationStatus = EKEventStore.authorizationStatus(for: .event)
                calendarAccessGranted = false
            }
            return false
        }
    }
    
    func checkAuthorizationStatus() {
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
        calendarAccessGranted = (authorizationStatus == .fullAccess) || (authorizationStatus == .writeOnly)
        
        if calendarAccessGranted {
            findOrCreateMatchlyCalendar()
        }
    }
    
    private func findOrCreateMatchlyCalendar() {
        // Try to find existing Matchly calendar
        let calendars = eventStore.calendars(for: .event)
        matchlyCalendar = calendars.first { $0.title == calendarTitle }
        
        // If not found, create it
        if matchlyCalendar == nil {
            matchlyCalendar = createMatchlyCalendar()
        }
    }
    
    private func createMatchlyCalendar() -> EKCalendar? {
        let calendar = EKCalendar(for: .event, eventStore: eventStore)
        
        calendar.title = calendarTitle
        calendar.cgColor = UIColor.systemBlue.cgColor
        
        // Try to save to iCloud calendar first, then local
        if let iCloudSource = eventStore.sources.first(where: { $0.sourceType == .calDAV && $0.title.contains("iCloud") }) {
            calendar.source = iCloudSource
        } else if let localSource = eventStore.sources.first(where: { $0.sourceType == .local }) {
            calendar.source = localSource
        } else {
            calendar.source = eventStore.defaultCalendarForNewEvents?.source
        }
        
        do {
            try eventStore.saveCalendar(calendar, commit: true)
            Self.logger.info("Created Matchly calendar: \(self.calendarTitle, privacy: .public)")
            return calendar
        } catch {
            Self.logger.error("Failed to create Matchly calendar: \(error.localizedDescription, privacy: .public)")
            return nil
        }
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
            findOrCreateMatchlyCalendar()
        }

        guard let calendar = matchlyCalendar else {
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
            return "Could not find or create the Matchly calendar."
        case .eventCreationFailed:
            return "Failed to create calendar events. Please try again."
        }
    }
}

