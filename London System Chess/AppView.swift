//
//  AppView.swift
//  London System Chess
//

import SwiftUI
import SwiftData

/// Root of the app. Owns the native iOS 26 Liquid Glass `TabView`; the selected
/// item is tinted by the app's accent color (AccentColor asset). Launches on Daily.
struct AppView: View {
    @State private var selection: AppTab = .daily

    var body: some View {
        TabView(selection: $selection) {
            ForEach(AppTab.allCases) { tab in
                Tab(tab.title, systemImage: tab.systemImage, value: tab) {
                    tab.content
                }
            }
        }
    }
}

#Preview {
    AppView()
        .modelContainer(for: Item.self, inMemory: true)
}
