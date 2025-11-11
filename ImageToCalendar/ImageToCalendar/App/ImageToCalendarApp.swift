//
//  ImageToCalendarApp.swift
//  ImageToCalendar
//
//  Created by Claude
//

import SwiftUI

@main
struct ImageToCalendarApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            if appState.isAuthenticated {
                ContentView()
                    .environmentObject(appState)
            } else {
                LoginView()
                    .environmentObject(appState)
            }
        }
    }
}

/// Global app state
class AppState: ObservableObject {
    @Published var isAuthenticated: Bool
    @Published var recentlyAddedEvents: [String] = []
    @Published var showingSettings = false

    init() {
        // Check if user requires authentication on launch
        let requireAuth = UserDefaults.standard.bool(forKey: "requireAuthentication")

        if requireAuth {
            // Check if authenticated recently (within last 5 minutes)
            if let lastAuth = UserDefaults.standard.object(forKey: "lastAuthenticationDate") as? Date {
                let timeSinceAuth = Date().timeIntervalSince(lastAuth)
                isAuthenticated = timeSinceAuth < 300 // 5 minutes
            } else {
                isAuthenticated = false
            }
        } else {
            // First time users - require authentication by default for security
            isAuthenticated = false
            UserDefaults.standard.set(true, forKey: "requireAuthentication")
        }
    }

    func recordAddedEvent(identifier: String) {
        recentlyAddedEvents.insert(identifier, at: 0)
        if recentlyAddedEvents.count > 10 {
            recentlyAddedEvents.removeLast()
        }
    }

    func logout() {
        isAuthenticated = false
        UserDefaults.standard.removeObject(forKey: "lastAuthenticationDate")
    }
}
