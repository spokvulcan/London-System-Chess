//
//  LinesLayout.swift
//  London System Chess
//
//  Layered-DAG layout for the spatial graph-map (Renderer A). x is the ply
//  (left→right depth bands); y is assigned by a Reingold–Tilford-style pass —
//  a parent is centered over its children — with merge handling so a
//  transposition node is placed once (under its first parent) and the other
//  converging edges draw into it. Pure geometry, no SwiftUI, so it's testable.
//

import CoreGraphics

struct LinesLayout {
    static let nodeDiameter: CGFloat = 32
    static let columnSpacing: CGFloat = 132
    static let rowSpacing: CGFloat = 64
    static let margin: CGFloat = 70

    /// Center point of each node, in content coordinates.
    private(set) var nodePoints: [LinePosition.ID: CGPoint] = [:]
    /// Total laid-out size (for the scrollable/zoomable content frame).
    private(set) var contentSize: CGSize = .zero

    func point(_ id: LinePosition.ID) -> CGPoint? { nodePoints[id] }

    init(graph: LinesGraph) {
        let byID = graph.positionsByID

        // Adjacency, with a stable, pleasing child order: better-known lines first
        // (higher coverage), then by label for determinism.
        var childrenMap: [LinePosition.ID: [LinePosition.ID]] = [:]
        for move in graph.moves {
            childrenMap[move.from, default: []].append(move.to)
        }
        for (parent, kids) in childrenMap {
            childrenMap[parent] = kids.sorted { a, b in
                let ca = byID[a]?.mastery.coverage ?? 0
                let cb = byID[b]?.mastery.coverage ?? 0
                if ca != cb { return ca > cb }
                return (byID[a]?.label ?? "") < (byID[b]?.label ?? "")
            }
        }

        // DFS slot assignment: leaves take successive slots; an internal node sits
        // at the mean of its (first-visit) children. Already-placed merge nodes are
        // skipped so each node lands once.
        var slot: [LinePosition.ID: CGFloat] = [:]
        var visited = Set<LinePosition.ID>()
        var nextLeaf: CGFloat = 0

        func assign(_ id: LinePosition.ID) {
            guard !visited.contains(id) else { return }
            visited.insert(id)
            let freshChildren = (childrenMap[id] ?? []).filter { !visited.contains($0) }
            if freshChildren.isEmpty {
                slot[id] = nextLeaf
                nextLeaf += 1
            } else {
                for child in freshChildren { assign(child) }
                let childSlots = freshChildren.compactMap { slot[$0] }
                slot[id] = childSlots.reduce(0, +) / CGFloat(childSlots.count)
            }
        }

        if let root = graph.root { assign(root.id) }
        // Defensive: place anything unreached (shouldn't happen for a connected graph).
        for position in graph.positions where slot[position.id] == nil {
            slot[position.id] = nextLeaf
            nextLeaf += 1
        }

        var maxX: CGFloat = 0
        var maxY: CGFloat = 0
        for position in graph.positions {
            let x = Self.margin + CGFloat(position.ply) * Self.columnSpacing
            let y = Self.margin + (slot[position.id] ?? 0) * Self.rowSpacing
            nodePoints[position.id] = CGPoint(x: x, y: y)
            maxX = max(maxX, x)
            maxY = max(maxY, y)
        }
        contentSize = CGSize(width: maxX + Self.margin, height: maxY + Self.margin)
    }
}
