//
//  ConfirmationView.swift
//  ImageToCalendar
//
//  Event confirmation and editing UI
//

import SwiftUI

struct ConfirmationView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel: ConfirmationViewModel
    @Environment(\.dismiss) var dismiss

    let onDismiss: () -> Void

    init(events: [EditableEvent], onDismiss: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: ConfirmationViewModel(events: events))
        self.onDismiss = onDismiss
    }

    var body: some View {
        NavigationView {
            VStack {
                if viewModel.events.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            ForEach(viewModel.events) { event in
                                EventCardView(event: binding(for: event))
                            }
                        }
                        .padding()
                    }

                    // Add All button
                    Button(action: { viewModel.addAllEvents() }) {
                        HStack {
                            if viewModel.isSaving {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                            }
                            Text("Add All to System Apps")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(viewModel.isSaving ? Color.gray : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(viewModel.isSaving)
                    .padding()
                }
            }
            .navigationTitle("Confirm Events")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                        onDismiss()
                    }
                }
            }
            .alert("Success", isPresented: $viewModel.showingSuccess) {
                Button("Done") {
                    dismiss()
                    onDismiss()
                }
            } message: {
                Text("Successfully added \(viewModel.successCount) event(s)")
            }
            .alert("Error", isPresented: $viewModel.showingError) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "Unknown error")
            }
            .alert("Permission Required", isPresented: $viewModel.showingPermissionDenied) {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Please enable Calendar and Reminders access in Settings to add events.")
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("No Events Found")
                .font(.title2)
                .fontWeight(.semibold)

            Text("We couldn't extract any events from the image. Try a clearer photo or add more context.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }

    private func binding(for event: EditableEvent) -> Binding<EditableEvent> {
        guard let index = viewModel.events.firstIndex(where: { $0.id == event.id }) else {
            fatalError("Event not found")
        }
        return $viewModel.events[index]
    }
}

@MainActor
class ConfirmationViewModel: ObservableObject {
    @Published var events: [EditableEvent]
    @Published var isSaving = false
    @Published var showingSuccess = false
    @Published var showingError = false
    @Published var showingPermissionDenied = false
    @Published var errorMessage: String?
    @Published var successCount = 0

    init(events: [EditableEvent]) {
        self.events = events
    }

    func addAllEvents() {
        isSaving = true
        successCount = 0
        errorMessage = nil

        Task {
            for event in events {
                do {
                    let identifier = try await addEvent(event)
                    successCount += 1

                    // Record for undo functionality
                    if let appState = AppStateHolder.shared.appState {
                        appState.recordAddedEvent(identifier: identifier)
                    }
                } catch {
                    errorMessage = error.localizedDescription
                    showingError = true
                    isSaving = false
                    return
                }
            }

            isSaving = false
            showingSuccess = true
        }
    }

    private func addEvent(_ event: EditableEvent) async throws -> String {
        switch event.selectedType {
        case .calendar:
            // Request permission if needed
            let status = CalendarService.shared.authorizationStatus()
            if status == .notDetermined {
                let granted = try await CalendarService.shared.requestAccess()
                if !granted {
                    showingPermissionDenied = true
                    throw CalendarError.permissionDenied
                }
            } else if status == .denied || status == .restricted {
                showingPermissionDenied = true
                throw CalendarError.permissionDenied
            }

            return try CalendarService.shared.createEvent(from: event)

        case .reminder:
            // Request permission if needed
            let status = RemindersService.shared.authorizationStatus()
            if status == .notDetermined {
                let granted = try await RemindersService.shared.requestAccess()
                if !granted {
                    showingPermissionDenied = true
                    throw ReminderError.permissionDenied
                }
            } else if status == .denied || status == .restricted {
                showingPermissionDenied = true
                throw ReminderError.permissionDenied
            }

            return try RemindersService.shared.createReminder(from: event)
        }
    }
}

/// Helper to access AppState from view model
class AppStateHolder {
    static let shared = AppStateHolder()
    weak var appState: AppState?
}
