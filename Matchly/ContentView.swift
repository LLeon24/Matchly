//
//  ContentView.swift
//  Matchly
//
//  Created by Leoh Leon on 11/14/25.
//
//  Preview helper for development - use this to preview views while making changes

import SwiftUI

struct ContentView: View {
    // Use @ObservedObject for singleton instances
    @ObservedObject private var dataManager = DataManager.shared
    @ObservedObject private var authManager = AuthManager.shared
    
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
//     MatchlyNavigationView {
//         DashboardView()
//             .environmentObject(DataManager.shared)
//     }
// }

// #Preview("Programs List") {
//     ProgramsListView()
//         .environmentObject(DataManager.shared)
// }

// #Preview("Settings") {
//     MatchlyNavigationView {
//         SettingsView()
//             .environmentObject(DataManager.shared)
//     }
// }

