//
//  MasteryPainting.swift
//  London System Chess
//
//  Turns persisted ReviewCards into the Mastery the Lines renderers paint —
//  the real-data replacement for the sample's mock numbers. Coverage saturates
//  with reps; Reliability is the demonstrated-accuracy EWMA (nil until the
//  first rep, per CONTEXT.md's unknown ≠ low rule). Black-to-move positions
//  carry no cards, so they inherit their best-covered White parent — you reach
//  one exactly by playing that parent's move. Edge-level mastery stays unknown
//  this milestone (ADR 0004 keeps the card grain at positions).
//

import Foundation

enum MasteryPainting {
    /// The slice of a ReviewCard the painting needs.
    struct CardSnapshot {
        var reps: Int
        var reliabilityEWMA: Double?

        init(reps: Int, reliabilityEWMA: Double?) {
            self.reps = reps
            self.reliabilityEWMA = reliabilityEWMA
        }

        init(_ card: ReviewCard) {
            self.init(reps: card.reps, reliabilityEWMA: card.reliabilityEWMA)
        }
    }

    /// Learning alone shows (0.2); five reps saturate.
    static func coverage(reps: Int) -> Double {
        min(1.0, 0.2 + 0.16 * Double(reps))
    }

    static func mastery(for snapshot: CardSnapshot) -> Mastery {
        Mastery(coverage: coverage(reps: snapshot.reps), reliability: snapshot.reliabilityEWMA)
    }

    /// The graph with every mock Mastery replaced by real record data. White
    /// positions map straight from their card (unseen without one); Black
    /// positions inherit the best-covered White parent; edges go unknown.
    static func painted(
        _ graph: LinesGraph,
        records: [LinePosition.ID: CardSnapshot]
    ) -> LinesGraph {
        var nodeMastery: [LinePosition.ID: Mastery] = [:]
        for position in graph.positions where position.sideToMove == .white {
            nodeMastery[position.id] = records[position.id].map(mastery(for:)) ?? .unseen
        }
        let inbound = Dictionary(grouping: graph.moves, by: \.to)
        for position in graph.positions where position.sideToMove == .black {
            let parentMasteries = (inbound[position.id] ?? [])
                .compactMap { nodeMastery[$0.from] }
            nodeMastery[position.id] = parentMasteries
                .max { $0.coverage < $1.coverage } ?? .unseen
        }

        var painted = graph
        for index in painted.positions.indices {
            painted.positions[index].mastery =
                nodeMastery[painted.positions[index].id] ?? .unseen
        }
        for index in painted.moves.indices {
            // Edge reliability is unknown at this grain; coverage follows the
            // destination node so painted lines stay visually connected.
            painted.moves[index].reliability = nil
            painted.moves[index].coverage =
                nodeMastery[painted.moves[index].to]?.coverage ?? 0
        }
        return painted
    }
}
