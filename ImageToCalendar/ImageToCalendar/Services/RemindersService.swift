//
//  RemindersService.swift
//  ImageToCalendar
//
//  Reminders framework integration
//

import Foundation
import EventKit

class RemindersService {
    static let shared = RemindersService()

    private let eventStore = EKEventStore()

    private init() {}

    /// Request reminders access permission
    func requestAccess() async throws -> Bool {
        if #available(iOS 17.0, *) {
            return try await eventStore.requestFullAccessToReminders()
        } else {
            return try await withCheckedThrowingContinuation { continuation in
                eventStore.requestAccess(to: .reminder) { granted, error in
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
            return EKEventStore.authorizationStatus(for: .reminder)
        } else {
            return EKEventStore.authorizationStatus(for: .reminder)
        }
    }

    /// Create reminder from editable event
    func createReminder(from editableEvent: EditableEvent) throws -> String {
        let reminder = EKReminder(eventStore: eventStore)

        reminder.title = editableEvent.editedTitle
        reminder.notes = editableEvent.editedNotes.isEmpty ? nil : editableEvent.editedNotes
        reminder.calendar = eventStore.defaultCalendarForNewReminders()

        // Set due date if available
        if let dueDate = editableEvent.editedDue {
            let dueDateComponents = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: dueDate
            )
            reminder.dueDateComponents = dueDateComponents

            // Add default alarm: 10 minutes before due date
            let alarm = EKAlarm(relativeOffset: -600)
            reminder.addAlarm(alarm)
        }

        try eventStore.save(reminder, commit: true)

        // Add subtasks if available
        if !editableEvent.editedSubtasks.isEmpty {
            try addSubtasks(to: reminder, subtasks: editableEvent.editedSubtasks)
        }

        return reminder.calendarItemIdentifier
    }

    /// Add subtasks to a reminder
    private func addSubtasks(to parent: EKReminder, subtasks: [String]) throws {
        for subtaskTitle in subtasks {
            let subtask = EKReminder(eventStore: eventStore)
            subtask.title = subtaskTitle
            subtask.calendar = parent.calendar

            // Note: EKReminder doesn't have direct parent-child relationship in API
            // But we can add them to the same list and reference parent in notes
            subtask.notes = "Subtask of: \(parent.title ?? "")"

            try eventStore.save(subtask, commit: false)
        }
        try eventStore.commit()
    }

    /// Delete reminder by identifier
    func deleteReminder(identifier: String) throws {
        guard let reminder = eventStore.calendarItem(withIdentifier: identifier) as? EKReminder else {
            throw ReminderError.reminderNotFound
        }
        try eventStore.remove(reminder, commit: true)
    }

    /// Check for duplicate reminders
    func checkDuplicates(title: String, dueDate: Date?) -> Bool {
        guard let calendar = eventStore.defaultCalendarForNewReminders() else {
            return false
        }

        let predicate = eventStore.predicateForReminders(in: [calendar])

        var foundDuplicate = false
        let semaphore = DispatchSemaphore(value: 0)

        eventStore.fetchReminders(matching: predicate) { reminders in
            defer { semaphore.signal() }

            guard let reminders = reminders else { return }

            let newHash = self.generateHash(title: title, dueDate: dueDate)

            foundDuplicate = reminders.contains { reminder in
                let existingHash = self.generateHash(
                    title: reminder.title ?? "",
                    dueDate: reminder.dueDateComponents?.date
                )
                return newHash == existingHash
            }
        }

        semaphore.wait()
        return foundDuplicate
    }

    /// Generate hash for duplicate detection
    private func generateHash(title: String, dueDate: Date?) -> String {
        var components = [title]
        if let date = dueDate {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            components.append(formatter.string(from: date))
        }
        return components.joined(separator: "|").lowercased()
    }
}

enum ReminderError: LocalizedError {
    case reminderNotFound
    case permissionDenied

    var errorDescription: String? {
        switch self {
        case .reminderNotFound:
            return "Reminder not found"
        case .permissionDenied:
            return "Reminders access denied"
        }
    }
}
