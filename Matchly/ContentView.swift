//
//  ContentView.swift
//  Matchly
//
//  Created by Leoh Leon on 11/14/25.
//
//  Preview helper for development - use this to preview views while making changes

import SwiftUI

struct ContentView: View {
    // Use @StateObject to create fresh instances for previews
    @StateObject private var dataManager = DataManager.shared
    @StateObject private var authManager = AuthManager.shared
    
    var body: some View {
        // Show the full interactive app
        MainTabView()
            .environmentObject(dataManager)
            .environmentObject(authManager)
    }
}

// Preview for the full app
#Preview("Matchly App") {
    ContentView()
}

// Alternative previews for specific views - uncomment to test individual views
// #Preview("Dashboard") {
//     NavigationView {
//         DashboardView()
//             .environmentObject(DataManager.shared)
//     }
// }

// #Preview("Programs List") {
//     ProgramsListView()
//         .environmentObject(DataManager.shared)
// }

// #Preview("Settings") {
//     NavigationView {
//         SettingsView()
//             .environmentObject(DataManager.shared)
//     }
// }

