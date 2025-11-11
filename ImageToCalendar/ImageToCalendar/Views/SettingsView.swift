//
//  SettingsView.swift
//  ImageToCalendar
//
//  App settings and undo functionality
//

import SwiftUI
import Combine
import EventKit

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = SettingsViewModel()

    var body: some View {
        NavigationView {
            Form {
                // Backend Configuration
                Section(header: Text("Backend Configuration")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Backend URL")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        TextField("https://your-backend.vercel.app", text: $viewModel.backendURL)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.none)
                            .keyboardType(.URL)

                        Text("Configure your Dify workflow backend endpoint")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                // Privacy Settings
                Section(header: Text("Privacy")) {
                    Toggle("Delete images after parsing", isOn: $viewModel.deleteAfterParsing)

                    VStack(alignment: .leading) {
                        Text("When enabled, uploaded images are deleted from the backend immediately after parsing.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                // Permissions Status
                Section(header: Text("Permissions")) {
                    HStack {
                        Text("Calendar Access")
                        Spacer()
                        permissionStatus(viewModel.calendarStatus)
                    }

                    HStack {
                        Text("Reminders Access")
                        Spacer()
                        permissionStatus(viewModel.remindersStatus)
                    }

                    Button("Open System Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                }

                // Undo Recent Changes
                Section(header: Text("Recent Events")) {
                    if appState.recentlyAddedEvents.isEmpty {
                        Text("No recent events")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(appState.recentlyAddedEvents, id: \.self) { identifier in
                            HStack {
                                Text(identifier)
                                    .font(.caption)
                                    .lineLimit(1)
                                    .truncationMode(.middle)

                                Spacer()

                                Button("Undo") {
                                    viewModel.undoEvent(identifier: identifier)
                                }
                                .foregroundColor(.red)
                                .font(.caption)
                            }
                        }
                    }

                    if !appState.recentlyAddedEvents.isEmpty {
                        Button("Clear All") {
                            appState.recentlyAddedEvents.removeAll()
                        }
                        .foregroundColor(.red)
                    }
                }

                // Default Behaviors
                Section(header: Text("Default Behaviors")) {
                    Stepper("Event duration: \(viewModel.defaultDuration) min", value: $viewModel.defaultDuration, in: 15...240, step: 15)

                    Stepper("Alert before: \(viewModel.defaultAlert) min", value: $viewModel.defaultAlert, in: 0...60, step: 5)

                    Stepper("Conflict threshold: \(viewModel.conflictThreshold) min", value: $viewModel.conflictThreshold, in: 5...60, step: 5)
                }

                // App Info
                Section(header: Text("About")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Model")
                        Spacer()
                        Text("Dify Workflow")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Success", isPresented: $viewModel.showingSuccess) {
                Button("OK") { viewModel.successMessage = nil }
            } message: {
                Text(viewModel.successMessage ?? "")
            }
            .alert("Error", isPresented: $viewModel.showingError) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "Unknown error")
            }
        }
        .onAppear {
            viewModel.loadPermissionStatus()
        }
    }

    private func permissionStatus(_ status: String) -> some View {
        Text(status)
            .font(.caption)
            .padding(4)
            .background(statusColor(status).opacity(0.2))
            .foregroundColor(statusColor(status))
            .cornerRadius(4)
    }

    private func statusColor(_ status: String) -> Color {
        switch status {
        case "Authorized":
            return .green
        case "Denied":
            return .red
        case "Not Determined":
            return .orange
        default:
            return .gray
        }
    }
}

@MainActor
class SettingsViewModel: ObservableObject {
    @Published var backendURL = ""
    @Published var deleteAfterParsing = true
    @Published var defaultDuration = 60
    @Published var defaultAlert = 10
    @Published var conflictThreshold = 15

    @Published var calendarStatus = "Not Determined"
    @Published var remindersStatus = "Not Determined"

    @Published var showingSuccess = false
    @Published var showingError = false
    @Published var successMessage: String?
    @Published var errorMessage: String?

    init() {
        loadSettings()
    }

    func loadSettings() {
        // Load from UserDefaults
        backendURL = UserDefaults.standard.string(forKey: "backendURL") ?? ""
        deleteAfterParsing = UserDefaults.standard.bool(forKey: "deleteAfterParsing")
        defaultDuration = UserDefaults.standard.integer(forKey: "defaultDuration")
        defaultAlert = UserDefaults.standard.integer(forKey: "defaultAlert")
        conflictThreshold = UserDefaults.standard.integer(forKey: "conflictThreshold")

        // Set defaults if not configured
        if defaultDuration == 0 { defaultDuration = 60 }
        if defaultAlert == 0 { defaultAlert = 10 }
        if conflictThreshold == 0 { conflictThreshold = 15 }
    }

    func saveSettings() {
        UserDefaults.standard.set(backendURL, forKey: "backendURL")
        UserDefaults.standard.set(deleteAfterParsing, forKey: "deleteAfterParsing")
        UserDefaults.standard.set(defaultDuration, forKey: "defaultDuration")
        UserDefaults.standard.set(defaultAlert, forKey: "defaultAlert")
        UserDefaults.standard.set(conflictThreshold, forKey: "conflictThreshold")
    }

    func loadPermissionStatus() {
        let calendarAuth = CalendarService.shared.authorizationStatus()
        calendarStatus = authStatusString(calendarAuth)

        let remindersAuth = RemindersService.shared.authorizationStatus()
        remindersStatus = authStatusString(remindersAuth)
    }

    private func authStatusString(_ status: EKAuthorizationStatus) -> String {
        switch status {
        case .notDetermined:
            return "Not Determined"
        case .restricted:
            return "Restricted"
        case .denied:
            return "Denied"
        case .authorized:
            return "Authorized"
        case .fullAccess:
            return "Authorized"
        case .writeOnly:
            return "Write Only"
        @unknown default:
            return "Unknown"
        }
    }

    func undoEvent(identifier: String) {
        Task {
            do {
                // Try to delete as calendar event first
                try CalendarService.shared.deleteEvent(identifier: identifier)
                successMessage = "Event deleted successfully"
                showingSuccess = true
            } catch {
                // Try as reminder
                do {
                    try RemindersService.shared.deleteReminder(identifier: identifier)
                    successMessage = "Reminder deleted successfully"
                    showingSuccess = true
                } catch {
                    errorMessage = "Unable to delete: \(error.localizedDescription)"
                    showingError = true
                }
            }
        }
    }
}
