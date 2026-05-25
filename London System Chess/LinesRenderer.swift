//
//  LinesRenderer.swift
//  London System Chess
//
//  The two interchangeable ways to visualize the same LinesGraph (ADR 0002),
//  selected by the grouped glass toolbar toggle. Built to be compared head-to-head
//  for which one teaches the London better.
//

import SwiftUI

enum LinesRenderer: String, CaseIterable, Identifiable {
    /// Zoomable layered-DAG graph; transpositions merge into shared nodes.
    case map
    /// Chessable-style depth columns; transpositions necessarily duplicate.
    case columns

    var id: Self { self }

    var title: String {
        switch self {
        case .map: "Map"
        case .columns: "Columns"
        }
    }

    var systemImage: String {
        switch self {
        case .map: "point.3.connected.trianglepath.dotted"
        case .columns: "rectangle.split.3x1"
        }
    }
}
