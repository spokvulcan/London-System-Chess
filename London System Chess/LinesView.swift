//
//  LinesView.swift
//  London System Chess
//

import SwiftUI

/// Browsable reference of London System variations — a graph of positions where
/// transpositions converge to shared nodes (see ADR 0001). Not yet built.
struct LinesView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Lines",
                systemImage: AppTab.lines.systemImage,
                description: Text("The London System variation graph is coming soon.")
            )
            .navigationTitle("Lines")
        }
    }
}

#Preview {
    LinesView()
}
