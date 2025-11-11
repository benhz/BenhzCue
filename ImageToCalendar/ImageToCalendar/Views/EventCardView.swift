//
//  EventCardView.swift
//  ImageToCalendar
//
//  Individual event card with editing capabilities
//

import SwiftUI

struct EventCardView: View {
    @Binding var event: EditableEvent
    @State private var showingDetail = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with type toggle
            HStack {
                Picker("Type", selection: $event.selectedType) {
                    Text("Calendar").tag(ParsedEvent.EventType.calendar)
                    Text("Reminder").tag(ParsedEvent.EventType.reminder)
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(maxWidth: 200)

                Spacer()

                // Confidence indicator
                confidenceIndicator
            }

            // Title
            TextField("Event Title", text: $event.editedTitle)
                .font(.headline)
                .textFieldStyle(RoundedBorderTextFieldStyle())

            // Date/Time information
            if event.selectedType == .calendar {
                calendarDetails
            } else {
                reminderDetails
            }

            // Location (for calendar events)
            if event.selectedType == .calendar {
                HStack {
                    Image(systemName: "location")
                        .foregroundColor(.secondary)
                    TextField("Location (optional)", text: $event.editedLocation)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
            }

            // Notes
            HStack(alignment: .top) {
                Image(systemName: "note.text")
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
                TextEditor(text: $event.editedNotes)
                    .frame(minHeight: 60)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                    )
            }

            // Subtasks (for reminders)
            if event.selectedType == .reminder && !event.editedSubtasks.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Subtasks:")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    ForEach(event.editedSubtasks, id: \.self) { subtask in
                        HStack {
                            Image(systemName: "circle")
                                .font(.caption)
                            Text(subtask)
                                .font(.caption)
                        }
                    }
                }
            }

            // Warnings
            if event.hasConflict || event.isDuplicate {
                warningsSection
            }

            // Pending fields indicator
            if let pending = event.parsedEvent.pendingFields, !pending.isEmpty {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Missing: \(pending.joined(separator: ", "))")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }

    private var confidenceIndicator: some View {
        HStack(spacing: 4) {
            Image(systemName: confidenceIcon)
                .foregroundColor(confidenceColor)
            Text("\(Int(event.parsedEvent.confidence * 100))%")
                .font(.caption)
                .foregroundColor(confidenceColor)
        }
    }

    private var confidenceIcon: String {
        if event.parsedEvent.confidence >= 0.8 {
            return "checkmark.circle.fill"
        } else if event.parsedEvent.confidence >= 0.6 {
            return "exclamationmark.circle.fill"
        } else {
            return "questionmark.circle.fill"
        }
    }

    private var confidenceColor: Color {
        if event.parsedEvent.confidence >= 0.8 {
            return .green
        } else if event.parsedEvent.confidence >= 0.6 {
            return .orange
        } else {
            return .red
        }
    }

    private var calendarDetails: some View {
        VStack(alignment: .leading, spacing: 8) {
            DatePicker(
                "Start",
                selection: Binding(
                    get: { event.editedStart ?? Date() },
                    set: { event.editedStart = $0 }
                ),
                displayedComponents: [.date, .hourAndMinute]
            )

            DatePicker(
                "End",
                selection: Binding(
                    get: { event.editedEnd ?? Date().addingTimeInterval(3600) },
                    set: { event.editedEnd = $0 }
                ),
                displayedComponents: [.date, .hourAndMinute]
            )
        }
        .font(.subheadline)
    }

    private var reminderDetails: some View {
        DatePicker(
            "Due Date",
            selection: Binding(
                get: { event.editedDue ?? Date() },
                set: { event.editedDue = $0 }
            ),
            displayedComponents: [.date, .hourAndMinute]
        )
        .font(.subheadline)
    }

    private var warningsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            if event.hasConflict {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Time conflict detected")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }

            if event.isDuplicate {
                HStack {
                    Image(systemName: "doc.on.doc.fill")
                        .foregroundColor(.yellow)
                    Text("Possible duplicate")
                        .font(.caption)
                        .foregroundColor(.yellow)
                }
            }
        }
        .padding(8)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
    }
}
