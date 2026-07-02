//
//  London_System_ChessApp.swift
//  London System Chess
//
//  Created by Bohdan Ivanchenko on 25.05.2026.
//

import SwiftUI
import SwiftData

@main
struct London_System_ChessApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            ReviewCard.self,
            ReviewLogEntry.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            AppView()
        }
        .modelContainer(sharedModelContainer)
    }
}
