//
//  LinesLayoutTests.swift
//  London System ChessTests
//
//  Geometry invariants for the spatial graph-map's layered-DAG layout.
//

import Testing
import CoreGraphics
@testable import London_System_Chess

struct LinesLayoutTests {
    let graph = LinesGraph.sample
    var layout: LinesLayout { LinesLayout(graph: graph) }

    @Test func everyPositionGetsAPoint() {
        let layout = layout
        for position in graph.positions {
            #expect(layout.point(position.id) != nil, "no point for \(position.label)")
        }
    }

    @Test func xIsDeterminedByPly() {
        let layout = layout
        // x encodes depth: a deeper ply is always strictly further right.
        for position in graph.positions {
            guard let point = layout.point(position.id) else { continue }
            let expectedX = LinesLayout.margin + CGFloat(position.ply) * LinesLayout.columnSpacing
            #expect(point.x == expectedX)
        }
    }

    @Test func everyEdgeFlowsRightwardByOneColumn() {
        let layout = layout
        for move in graph.moves {
            guard let from = layout.point(move.from), let to = layout.point(move.to) else { continue }
            #expect(to.x - from.x == LinesLayout.columnSpacing)
        }
    }

    @Test func contentSizeEnclosesAllNodes() {
        let layout = layout
        #expect(layout.contentSize.width > 0)
        #expect(layout.contentSize.height > 0)
        for position in graph.positions {
            guard let point = layout.point(position.id) else { continue }
            #expect(point.x <= layout.contentSize.width)
            #expect(point.y <= layout.contentSize.height)
        }
    }
}
