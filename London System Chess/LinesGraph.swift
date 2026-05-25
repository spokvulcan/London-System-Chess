//
//  LinesGraph.swift
//  London System Chess
//
//  The shared data model behind the Lines tab. Both planned renderers — the
//  spatial graph-map and the depth columns — consume this one model so the A/B
//  comparison only varies the visualization, never the data (see ADR 0002).
//
//  This is a plain value model with no persistence yet: the prototype is about
//  how the visuals feel, so `LinesGraph.sample` (in LinesSampleData.swift) holds
//  a hand-authored slice of real London theory. SwiftData can back this later.
//

import Foundation

/// Who is to move at a position, and equivalently who *made* a given move.
enum SideToMove: String, Codable, Hashable, CaseIterable {
    case white
    case black
}

/// How well the player knows a spot, as the two independent axes defined in
/// CONTEXT.md. `coverage` drives node fill (how much it's been studied);
/// `reliability` drives color (how correctly it's handled). A `nil` reliability
/// means *unknown* — no reps yet — which is deliberately distinct from a low
/// reliability (studied but error-prone).
struct Mastery: Hashable, Codable {
    /// 0 = never seen … 1 = thoroughly drilled.
    var coverage: Double
    /// `nil` = unknown (no reps yet); otherwise 0 = always wrong … 1 = always right.
    var reliability: Double?

    /// A spot the player has never encountered.
    static let unseen = Mastery(coverage: 0, reliability: nil)

    /// True when the spot has never been studied and has no reliability signal.
    var isUnseen: Bool { coverage == 0 && reliability == nil }

    /// True once the spot has been studied at all.
    var isCovered: Bool { coverage > 0 }
}

/// A position in the London variation graph — the node. Transpositions share a
/// single node, so `id` is the position's identity (EPD: piece placement, side
/// to move, castling rights, en-passant target), independent of move order.
struct LinePosition: Identifiable, Hashable, Codable {
    /// Position identity (EPD). Two move orders that transpose share this id.
    let id: String
    /// Full FEN, for rendering the actual board.
    let fen: String
    /// Half-moves from the start position (root = 0). The layered-DAG depth band
    /// and the depth-columns column index both come from this.
    let ply: Int
    /// Whose turn it is in this position.
    let sideToMove: SideToMove
    /// Short human label, e.g. "Start", "1.d4", "3...e6".
    let label: String
    /// SAN of a representative move reaching this position (nil at the root).
    let san: String?
    /// True when more than one distinct parent reaches here — a transposition /
    /// merge node, the spatial map's signature advantage over duplicating columns.
    let isTransposition: Bool
    /// The node-level aggregate mastery (the zoomed-out / collapsed level of detail).
    var mastery: Mastery
}

/// A move connecting two positions — the edge. Carries the per-move (edge-level)
/// reliability that the renderers reveal when zoomed in / expanded, distinct from
/// the node aggregate (see ADR 0002 and the "Both, layered" mastery decision).
struct LineMove: Identifiable, Hashable, Codable {
    let from: LinePosition.ID
    let to: LinePosition.ID
    /// Standard algebraic notation, e.g. "Bf4".
    let san: String
    /// The side that played this move.
    let side: SideToMove
    /// Per-move reliability (nil = unknown), the expanded level of detail.
    var reliability: Double?
    /// Per-move coverage.
    var coverage: Double

    var id: String { "\(from)|\(san)|\(to)" }
}

/// The London variation graph: positions (nodes) linked by moves (edges), where
/// transpositions converge to shared nodes rather than duplicating (ADR 0001).
struct LinesGraph: Hashable {
    var positions: [LinePosition]
    var moves: [LineMove]
}

// MARK: - Derived structure

extension LinesGraph {
    /// Positions keyed by id, for O(1) lookup.
    var positionsByID: [LinePosition.ID: LinePosition] {
        Dictionary(uniqueKeysWithValues: positions.map { ($0.id, $0) })
    }

    /// The start position (ply 0).
    var root: LinePosition? {
        positions.first { $0.ply == 0 }
    }

    /// Deepest ply present — the number of layered-DAG bands / depth columns.
    var maxPly: Int {
        positions.map(\.ply).max() ?? 0
    }

    /// Positions grouped by ply, ascending — the spatial map's vertical bands and
    /// the depth-columns columns share this grouping.
    var positionsByPly: [Int: [LinePosition]] {
        Dictionary(grouping: positions, by: \.ply)
    }

    /// Outbound moves from a position (its replies / continuations).
    func moves(from id: LinePosition.ID) -> [LineMove] {
        moves.filter { $0.from == id }
    }

    /// Inbound moves into a position (every move order that reaches it).
    func moves(into id: LinePosition.ID) -> [LineMove] {
        moves.filter { $0.to == id }
    }

    /// Child positions reachable from a position.
    func children(of id: LinePosition.ID) -> [LinePosition] {
        let byID = positionsByID
        return moves(from: id).compactMap { byID[$0.to] }
    }

    /// The transposition / merge nodes (reached by more than one distinct parent).
    var transpositions: [LinePosition] {
        positions.filter(\.isTransposition)
    }

    /// The active focus affordance's target: the single most-urgent weak spot.
    /// Derived only from Mastery (not Trends' probability — that boundary is in
    /// CONTEXT.md): among studied positions with a known reliability, the lowest
    /// reliability wins, breaking ties toward higher coverage then shallower ply.
    var focusSuggestion: LinePosition.ID? {
        positions
            .filter { $0.mastery.isCovered && $0.mastery.reliability != nil }
            .min { a, b in
                let ra = a.mastery.reliability ?? 1, rb = b.mastery.reliability ?? 1
                if ra != rb { return ra < rb }
                if a.mastery.coverage != b.mastery.coverage {
                    return a.mastery.coverage > b.mastery.coverage
                }
                return a.ply < b.ply
            }?
            .id
    }
}
