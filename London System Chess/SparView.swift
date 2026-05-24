//
//  SparView.swift
//  London System Chess
//

import SwiftUI

/// Practice play against a non-human opponent through London positions. Not yet built.
struct SparView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Spar",
                systemImage: AppTab.spar.systemImage,
                description: Text("Practice games against the engine are coming soon.")
            )
            .navigationTitle("Spar")
        }
    }
}

#Preview {
    SparView()
}
