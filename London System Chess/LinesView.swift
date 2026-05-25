//
//  LinesView.swift
//  London System Chess
//
//  The Lines tab shell: the variation graph rendered two interchangeable ways
//  (ADR 0002), switched by a grouped glass toolbar toggle, over one shared LinesGraph.
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
            // Host the canvas in a scroll view whose content underlaps the toolbar.
            // That's what drives iOS 26's *native* navigation-bar Liquid Glass (the
            // soft scroll-edge effect, same as the Trends list) — the bar isn't a flat
            // material we paint, it's the system frosting whatever canvas sits under it.
            // The map keeps its own pan/zoom gestures; the scroll view doesn't scroll
            // (content fills the viewport), it's purely the surface the glass reads.
            ScrollView([.horizontal, .vertical]) {
                LinesMapView(graph: graph, selectedID: $selectedID, focusID: focusID, focusTick: focusTick)
                    .containerRelativeFrame([.horizontal, .vertical])
            }
            .scrollDisabled(true)
            .scrollEdgeEffectStyle(.soft, for: .top)
            .ignoresSafeArea(.container, edges: .top)
        case .columns:
            // Columns keeps its content below the bar: its top edge is a breadcrumb
            // and column headers that shouldn't slide under the glass. The bar still
            // shows glass; it just doesn't get the full content-blur the map does.
            LinesColumnsView(graph: graph, selectedID: $selectedID, focusID: focusID, focusTick: focusTick)
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        // Grouped glass renderer toggle (ADR 0002): one shared Liquid Glass capsule
        // holding both icons, the active renderer filled with the accent. Leading, so
        // the inline "Lines" title centers and Focus stays trailing. A single shared
        // pill (not two independent glass buttons) keeps the inactive option visible
        // even over the empty/white parts of the canvas.
        ToolbarItem(placement: .topBarLeading) {
            HStack(spacing: 2) {
                ForEach(LinesRenderer.allCases) { option in
                    rendererButton(option)
                }
            }
            .padding(3)
            .glassEffect(.regular, in: .capsule)
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

    @ViewBuilder
    private func rendererButton(_ option: LinesRenderer) -> some View {
        let isActive = renderer == option
        Button {
            withAnimation(.snappy) { renderer = option }
        } label: {
            Image(systemName: option.systemImage)
                .font(.body)
                .frame(width: 42, height: 30)
                .foregroundStyle(isActive ? Color.white : Color.primary)
                .background {
                    if isActive {
                        Capsule().fill(Color.accentColor)
                    }
                }
                .accessibilityLabel(option.title)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("renderer-\(option.title)")
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }
}

#Preview {
    LinesView()
}
