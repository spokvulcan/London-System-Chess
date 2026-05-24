//
//  MeView.swift
//  London System Chess
//

import SwiftUI

/// The player's own profile and app settings. Not yet built.
struct MeView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Me",
                systemImage: AppTab.me.systemImage,
                description: Text("Your profile and settings will live here.")
            )
            .navigationTitle("Me")
        }
    }
}

#Preview {
    MeView()
}
