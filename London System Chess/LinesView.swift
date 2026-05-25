//
//  LinesView.swift
//  London System Chess
//
//  The Lines tab shell: the variation graph rendered two interchangeable ways
//  (ADR 0002), switched by a toolbar segmented toggle, over one shared LinesGraph.
//  Selecting any node/move presents a floating board card; the focus affordance
//  jumps to the single most-urgent weak spot (derived from Mastery only — the
//  Lines/Trends boundary in CONTEXT.md).
//

import SwiftUI

struct LinesView: View {
    private let graph = LinesGraph.sample

    @State private var renderer: LinesRenderer = .map
    @State private var selectedID: LinePosition.ID?
    /// Bumped by the Focus button. The active renderer watches this and navigates
    /// to `focusID` in context (map pans to it, columns reveal it) and pulses it —
    /// rather than popping a modal over wherever you happen to be.
    @State private var focusTick = 0

    private var focusID: LinePosition.ID? { graph.focusSuggestion }

    var body: some View {
        NavigationStack {
            ZStack {
                renderedGraph
                    .overlay(alignment: .bottomLeading) {
                        MasteryLegend().padding(16)
                    }
                    .navigationTitle("Lines")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { toolbarContent }

                BoardCard(graph: graph, selectedID: $selectedID)
            }
        }
    }

    @ViewBuilder
    private var renderedGraph: some View {
        switch renderer {
        case .map:
            LinesMapView(graph: graph, selectedID: $selectedID, focusID: focusID, focusTick: focusTick)
        case .columns:
            LinesColumnsView(graph: graph, selectedID: $selectedID, focusID: focusID, focusTick: focusTick)
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            Picker("Renderer", selection: $renderer) {
                ForEach(LinesRenderer.allCases) { renderer in
                    Text(renderer.title)
                        .tag(renderer)
                        .accessibilityIdentifier("renderer-\(renderer.title)")
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 280)
            .accessibilityIdentifier("renderer-picker")
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                focusTick &+= 1
            } label: {
                Label("Focus", systemImage: "scope")
            }
            .disabled(focusID == nil)
            .accessibilityIdentifier("focus-button")
        }
    }
}

#Preview {
    LinesView()
}
