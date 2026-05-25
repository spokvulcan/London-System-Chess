//
//  LinesMapView.swift
//  London System Chess
//
//  Renderer A — the spatial graph-map: a zoomable layered DAG (left→right by ply)
//  where transpositions merge into shared nodes (the map's signature advantage
//  over duplicating columns). Nodes are tinted by Mastery; merge-edges are drawn
//  in the accent color so convergence reads at a glance; the focus spot pulses.
//

import SwiftUI

struct LinesMapView: View {
    let graph: LinesGraph
    @Binding var selectedID: LinePosition.ID?
    let focusID: LinePosition.ID?
    /// Bumped by the toolbar Focus button — pans the weak spot into view in context.
    let focusTick: Int

    private let layout: LinesLayout
    private let byID: [LinePosition.ID: LinePosition]

    init(graph: LinesGraph, selectedID: Binding<LinePosition.ID?>, focusID: LinePosition.ID?, focusTick: Int) {
        self.graph = graph
        self._selectedID = selectedID
        self.focusID = focusID
        self.focusTick = focusTick
        self.layout = LinesLayout(graph: graph)
        self.byID = graph.positionsByID
    }

    // Transform: screen = contentPoint * scale + offset (scaleEffect anchored top-leading).
    @State private var scale: CGFloat = 0.75
    @State private var lastScale: CGFloat = 0.75
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var viewSize: CGSize = .zero
    @State private var didCenter = false
    @State private var pulse = false

    private let minScale: CGFloat = 0.3
    private let maxScale: CGFloat = 2.5

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                edgeCanvas
                nodeLayer
            }
            .frame(width: layout.contentSize.width, height: layout.contentSize.height, alignment: .topLeading)
            .scaleEffect(scale, anchor: .topLeading)
            .offset(offset)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .contentShape(Rectangle())
            .gesture(panGesture.simultaneously(with: zoomGesture))
            .overlay(alignment: .bottomTrailing) { controls }
            .onAppear {
                viewSize = geo.size
                if !didCenter { centerOnRoot(); didCenter = true }
                pulse = true
            }
            .onChange(of: geo.size) { _, newValue in viewSize = newValue }
            // Focus affordance: bring the weak spot into view rather than popping a card.
            .onChange(of: focusTick) { _, _ in
                if let focusID { withAnimation(.snappy) { center(on: focusID) } }
            }
        }
        .clipped()
    }

    // MARK: Edges

    private var edgeCanvas: some View {
        Canvas { context, _ in
            for move in graph.moves {
                guard let a = layout.point(move.from), let b = layout.point(move.to) else { continue }
                var path = Path()
                path.move(to: a)
                let midX = (a.x + b.x) / 2
                path.addCurve(
                    to: b,
                    control1: CGPoint(x: midX, y: a.y),
                    control2: CGPoint(x: midX, y: b.y)
                )
                let isMerge = byID[move.to]?.isTransposition ?? false
                if isMerge {
                    context.stroke(
                        path,
                        with: .color(.accentColor.opacity(0.8)),
                        style: StrokeStyle(lineWidth: 2, dash: [5, 4])
                    )
                } else {
                    context.stroke(
                        path,
                        with: .color(MasteryStyle.reliabilityColor(move.reliability).opacity(0.4)),
                        style: StrokeStyle(lineWidth: 1.5)
                    )
                }
            }
        }
        .frame(width: layout.contentSize.width, height: layout.contentSize.height)
    }

    // MARK: Nodes

    private var nodeLayer: some View {
        ForEach(graph.positions) { position in
            node(position)
                .position(layout.point(position.id) ?? .zero)
        }
    }

    private func node(_ position: LinePosition) -> some View {
        let diameter = LinesLayout.nodeDiameter
        let isSelected = position.id == selectedID
        let isFocus = position.id == focusID
        return Button {
            withAnimation(.snappy) { selectedID = position.id }
        } label: {
            VStack(spacing: 3) {
                ZStack {
                    if isFocus {
                        Circle()
                            .stroke(MasteryStyle.focusAccent, lineWidth: 3)
                            .frame(width: diameter + 12, height: diameter + 12)
                            .scaleEffect(pulse ? 1.2 : 1)
                            .opacity(pulse ? 0.25 : 0.85)
                            .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: pulse)
                    }
                    Circle()
                        .fill(MasteryStyle.tint(for: position.mastery))
                        .frame(width: diameter, height: diameter)
                        .overlay(
                            // Never-studied spots get a dashed grey "frontier" ring so the
                            // edge of what you've learned reads at a glance; selection wins.
                            Circle().stroke(
                                isSelected ? Color.primary
                                    : (position.mastery.isUnseen ? Color.secondary : .white.opacity(0.55)),
                                style: StrokeStyle(
                                    lineWidth: isSelected ? 2.5 : (position.mastery.isUnseen ? 1.5 : 0.5),
                                    dash: (position.mastery.isUnseen && !isSelected) ? [3, 3] : []
                                )
                            )
                        )
                    if position.isTransposition {
                        Image(systemName: "arrow.triangle.merge")
                            .font(.system(size: diameter * 0.42, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                Text(position.label)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .lineLimit(1)
                    .fixedSize()
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(.ultraThinMaterial, in: Capsule())
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: Controls

    private var controls: some View {
        Button {
            withAnimation(.snappy) { centerOnRoot() }
        } label: {
            Image(systemName: "arrow.counterclockwise")
                .font(.body.weight(.semibold))
                .padding(10)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .padding(16)
    }

    // MARK: Gestures & framing

    private var panGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                offset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
            }
            .onEnded { _ in lastOffset = offset }
    }

    private var zoomGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                let newScale = min(max(lastScale * value.magnification, minScale), maxScale)
                // Keep the viewport center stable while zooming.
                let center = CGPoint(x: viewSize.width / 2, y: viewSize.height / 2)
                let factor = newScale / lastScale
                offset = CGSize(
                    width: center.x - (center.x - lastOffset.width) * factor,
                    height: center.y - (center.y - lastOffset.height) * factor
                )
                scale = newScale
            }
            .onEnded { _ in
                lastScale = scale
                lastOffset = offset
            }
    }

    private func centerOnRoot() {
        guard let root = graph.root, let point = layout.point(root.id), viewSize != .zero else { return }
        scale = 0.75
        lastScale = scale
        let target = CGPoint(x: viewSize.width * 0.12, y: viewSize.height * 0.5)
        offset = CGSize(width: target.x - point.x * scale, height: target.y - point.y * scale)
        lastOffset = offset
    }

    /// Pans (keeping the current zoom) so `id` sits at the viewport center.
    private func center(on id: LinePosition.ID) {
        guard let point = layout.point(id), viewSize != .zero else { return }
        let target = CGPoint(x: viewSize.width * 0.5, y: viewSize.height * 0.5)
        offset = CGSize(width: target.x - point.x * scale, height: target.y - point.y * scale)
        lastOffset = offset
    }
}
