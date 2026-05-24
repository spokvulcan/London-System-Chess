//
//  DailyView.swift
//  London System Chess
//

import SwiftUI

/// A day-scoped training item that refreshes each day. Not yet built.
struct DailyView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Daily",
                systemImage: AppTab.daily.systemImage,
                description: Text("Your daily training item will appear here.")
            )
            .navigationTitle("Daily")
        }
    }
}

#Preview {
    DailyView()
}
