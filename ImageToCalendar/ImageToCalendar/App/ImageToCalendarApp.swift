//
//  ImageToCalendarApp.swift
//  ImageToCalendar
//
//  Created by Claude
//

import SwiftUI
import Combine

@main
struct ImageToCalendarApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
    }
}

/// Global app state
class AppState: ObservableObject {
    @Published var recentlyAddedEvents: [String] = []
    @Published var showingSettings = false

    func recordAddedEvent(identifier: String) {
        recentlyAddedEvents.insert(identifier, at: 0)
        if recentlyAddedEvents.count > 10 {
            recentlyAddedEvents.removeLast()
        }
    }
}
