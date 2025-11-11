//
//  ContentView.swift
//  ImageToCalendar
//
//  Main app view with image upload
//

import SwiftUI
import Combine

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = ContentViewModel()

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)

                    Text("Image to Calendar")
                        .font(.title)
                        .fontWeight(.bold)

                    Text("Upload an event poster or schedule")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 40)

                // Selected image preview
                if let image = viewModel.selectedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 200)
                        .cornerRadius(12)
                        .shadow(radius: 4)
                        .padding(.horizontal)
                }

                // Additional text input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Additional Context (Optional)")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    TextField("e.g., Add this to Wednesday afternoon", text: $viewModel.additionalText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                .padding(.horizontal)

                Spacer()

                // Action buttons
                VStack(spacing: 12) {
                    if viewModel.selectedImage == nil {
                        Button(action: { viewModel.showingImagePicker = true }) {
                            Label("Select Photo", systemImage: "photo.on.rectangle")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }

                        Button(action: { viewModel.showingCamera = true }) {
                            Label("Take Photo", systemImage: "camera")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                    } else {
                        Button(action: { viewModel.processImage() }) {
                            HStack {
                                if viewModel.isProcessing {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Image(systemName: "sparkles")
                                }
                                Text(viewModel.isProcessing ? "Processing..." : "Parse Events")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(viewModel.isProcessing ? Color.gray : Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(viewModel.isProcessing)

                        Button(action: { viewModel.selectedImage = nil }) {
                            Text("Choose Different Photo")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.secondary.opacity(0.2))
                                .foregroundColor(.primary)
                                .cornerRadius(12)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { appState.showingSettings = true }) {
                        Image(systemName: "gear")
                    }
                }
            }
            .sheet(isPresented: $viewModel.showingImagePicker) {
                ImagePicker(selectedImage: $viewModel.selectedImage, sourceType: .photoLibrary)
            }
            .sheet(isPresented: $viewModel.showingCamera) {
                ImagePicker(selectedImage: $viewModel.selectedImage, sourceType: .camera)
            }
            .sheet(isPresented: $viewModel.showingConfirmation) {
                if let events = viewModel.parsedEvents {
                    ConfirmationView(events: events, onDismiss: {
                        viewModel.showingConfirmation = false
                        viewModel.selectedImage = nil
                    })
                }
            }
            .sheet(isPresented: $appState.showingSettings) {
                SettingsView()
            }
            .alert("Error", isPresented: $viewModel.showingError) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "Unknown error")
            }
        }
    }
}

@MainActor
class ContentViewModel: ObservableObject {
    @Published var selectedImage: UIImage?
    @Published var additionalText = ""
    @Published var showingImagePicker = false
    @Published var showingCamera = false
    @Published var showingConfirmation = false
    @Published var isProcessing = false
    @Published var parsedEvents: [EditableEvent]?
    @Published var showingError = false
    @Published var errorMessage: String?

    func processImage() {
        guard let image = selectedImage else { return }

        isProcessing = true
        errorMessage = nil

        Task {
            do {
                let response = try await DifyService.shared.parseImageToEvents(
                    image: image,
                    additionalText: additionalText.isEmpty ? nil : additionalText
                )

                var editableEvents = response.events.map { EditableEvent(from: $0) }

                // Apply defaults
                for i in 0..<editableEvents.count {
                    editableEvents[i].applyDefaults()
                }

                // Check for conflicts and duplicates
                checkConflictsAndDuplicates(&editableEvents)

                parsedEvents = editableEvents
                showingConfirmation = true
            } catch {
                errorMessage = error.localizedDescription
                showingError = true
            }

            isProcessing = false
        }
    }

    private func checkConflictsAndDuplicates(_ events: inout [EditableEvent]) {
        for i in 0..<events.count {
            // Check conflicts for calendar events
            if events[i].selectedType == .calendar,
               let start = events[i].editedStart,
               let end = events[i].editedEnd {
                let conflicts = CalendarService.shared.checkConflicts(start: start, end: end)
                events[i].hasConflict = !conflicts.isEmpty
            }

            // Check duplicates
            if events[i].selectedType == .calendar {
                events[i].isDuplicate = CalendarService.shared.checkDuplicates(
                    title: events[i].editedTitle,
                    start: events[i].editedStart,
                    location: events[i].editedLocation
                )
            } else {
                events[i].isDuplicate = RemindersService.shared.checkDuplicates(
                    title: events[i].editedTitle,
                    dueDate: events[i].editedDue
                )
            }
        }
    }
}
