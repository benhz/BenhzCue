//
//  CalendarService.swift
//  ImageToCalendar
//
//  EventKit integration for Calendar events
//

import Foundation
import EventKit

class CalendarService {
    static let shared = CalendarService()

    private let eventStore = EKEventStore()

    private init() {}

    /// Request calendar access permission
    func requestAccess() async throws -> Bool {
        if #available(iOS 17.0, *) {
            return try await eventStore.requestFullAccessToEvents()
        } else {
            return try await withCheckedThrowingContinuation { continuation in
                eventStore.requestAccess(to: .event) { granted, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: granted)
                    }
                }
            }
        }
    }

    /// Check current authorization status
    func authorizationStatus() -> EKAuthorizationStatus {
        if #available(iOS 17.0, *) {
            return EKEventStore.authorizationStatus(for: .event)
        } else {
            return EKEventStore.authorizationStatus(for: .event)
        }
    }

    /// Create calendar event from editable event
    func createEvent(from editableEvent: EditableEvent) throws -> String {
        let event = EKEvent(eventStore: eventStore)

        event.title = editableEvent.editedTitle
        event.startDate = editableEvent.editedStart ?? Date()
        event.endDate = editableEvent.editedEnd ?? event.startDate.addingTimeInterval(3600)
        event.location = editableEvent.editedLocation.isEmpty ? nil : editableEvent.editedLocation
        event.notes = editableEvent.editedNotes.isEmpty ? nil : editableEvent.editedNotes
        event.calendar = eventStore.defaultCalendarForNewEvents
        event.timeZone = TimeZone.current

        // Add default alarm: 10 minutes before
        let alarm = EKAlarm(relativeOffset: -600) // -10 minutes
        event.addAlarm(alarm)

        try eventStore.save(event, span: .thisEvent)

        return event.eventIdentifier
    }

    /// Check for conflicts with existing events
    func checkConflicts(start: Date, end: Date) -> [EKEvent] {
        let predicate = eventStore.predicateForEvents(withStart: start, end: end, calendars: nil)
        let existingEvents = eventStore.events(matching: predicate)

        return existingEvents.filter { event in
            // Check for ≥15 min overlap
            let overlapStart = max(start, event.startDate)
            let overlapEnd = min(end, event.endDate)
            let overlap = overlapEnd.timeIntervalSince(overlapStart)
            return overlap >= 900 // 15 minutes
        }
    }

    /// Delete event by identifier
    func deleteEvent(identifier: String) throws {
        guard let event = eventStore.event(withIdentifier: identifier) else {
            throw CalendarError.eventNotFound
        }
        try eventStore.remove(event, span: .thisEvent)
    }

    /// Generate hash for duplicate detection
    static func generateHash(title: String, date: Date?, location: String?) -> String {
        var components = [title]
        if let date = date {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            components.append(formatter.string(from: date))
        }
        if let location = location, !location.isEmpty {
            components.append(location)
        }
        return components.joined(separator: "|").lowercased()
    }

    /// Check for duplicate events
    func checkDuplicates(title: String, start: Date?, location: String?) -> Bool {
        guard let start = start else { return false }

        let searchStart = Calendar.current.startOfDay(for: start)
        let searchEnd = Calendar.current.date(byAdding: .day, value: 1, to: searchStart)!

        let predicate = eventStore.predicateForEvents(withStart: searchStart, end: searchEnd, calendars: nil)
        let existingEvents = eventStore.events(matching: predicate)

        let newHash = CalendarService.generateHash(title: title, date: start, location: location)

        return existingEvents.contains { event in
            let existingHash = CalendarService.generateHash(
                title: event.title,
                date: event.startDate,
                location: event.location
            )
            return newHash == existingHash
        }
    }
}

enum CalendarError: LocalizedError {
    case eventNotFound
    case permissionDenied

    var errorDescription: String? {
        switch self {
        case .eventNotFound:
            return "Event not found"
        case .permissionDenied:
            return "Calendar access denied"
        }
    }
}
