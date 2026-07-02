//
//  TrendsView.swift
//  London System Chess
//

import SwiftUI

/// The player's performance trends over time. Not yet built.
struct TrendsView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "No Trends Yet",
                systemImage: AppTab.trends.systemImage,
                description: Text("Trends over your real games will appear here.")
            )
            .navigationTitle("Trends")
        }
    }
}

#Preview {
    TrendsView()
}
