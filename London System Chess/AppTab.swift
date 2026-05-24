//
//  AppTab.swift
//  London System Chess
//

import SwiftUI

/// The app's five permanent top-level sections, surfaced as a flat tab bar.
/// Identity, label, icon, and content all live here so the tab set has a single
/// source of truth (see CONTEXT.md for what each section means).
enum AppTab: Hashable, CaseIterable, Identifiable {
    case lines
    case daily
    case spar
    case stats
    case me

    var id: Self { self }

    var title: String {
        switch self {
        case .lines: "Lines"
        case .daily: "Daily"
        case .spar: "Spar"
        case .stats: "Stats"
        case .me: "Me"
        }
    }

    var systemImage: String {
        switch self {
        case .lines: "point.3.connected.trianglepath.dotted"
        case .daily: "sun.max"
        case .spar: "bolt"
        case .stats: "chart.bar"
        case .me: "person.crop.circle"
        }
    }

    @ViewBuilder
    var content: some View {
        switch self {
        case .lines: LinesView()
        case .daily: DailyView()
        case .spar: SparView()
        case .stats: StatsView()
        case .me: MeView()
        }
    }
}
