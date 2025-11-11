//
//  EventModels.swift
//  ImageToCalendar
//
//  Data models for parsed events from Dify
//

import Foundation

/// Response from Dify workflow
struct DifyResponse: Codable {
    let events: [ParsedEvent]
}

/// Individual parsed event
struct ParsedEvent: Codable, Identifiable {
    let id = UUID()
    let type: EventType
    let title: String
    let start: String? // ISO8601 for calendar
    let end: String? // ISO8601 for calendar
    let due: String? // ISO8601 for reminder
    let location: String?
    let notes: String?
    let subtasks: [String]?
    let confidence: Double
    let pendingFields: [String]?

    enum CodingKeys: String, CodingKey {
        case type, title, start, end, due, location, notes, subtasks, confidence
        case pendingFields = "pending_fields"
    }

    enum EventType: String, Codable {
        case calendar
        case reminder
    }
}

/// User-editable event for confirmation UI
struct EditableEvent: Identifiable {
    let id = UUID()
    var parsedEvent: ParsedEvent
    var selectedType: ParsedEvent.EventType
    var editedTitle: String
    var editedStart: Date?
    var editedEnd: Date?
    var editedDue: Date?
    var editedLocation: String
    var editedNotes: String
    var editedSubtasks: [String]
    var hasConflict: Bool = false
    var isDuplicate: Bool = false

    init(from parsed: ParsedEvent) {
        self.parsedEvent = parsed
        self.selectedType = parsed.type
        self.editedTitle = parsed.title

        // Parse ISO8601 dates
        let isoFormatter = ISO8601DateFormatter()
        if let start = parsed.start {
            self.editedStart = isoFormatter.date(from: start)
        }
        if let end = parsed.end {
            self.editedEnd = isoFormatter.date(from: end)
        }
        if let due = parsed.due {
            self.editedDue = isoFormatter.date(from: due)
        }

        self.editedLocation = parsed.location ?? ""
        self.editedNotes = parsed.notes ?? ""
        self.editedSubtasks = parsed.subtasks ?? []
    }

    /// Apply default behaviors
    mutating func applyDefaults() {
        // Default duration: 60 min if no end time
        if selectedType == .calendar && editedStart != nil && editedEnd == nil {
            editedEnd = editedStart?.addingTimeInterval(3600)
        }
    }
}
