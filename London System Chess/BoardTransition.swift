//
//  BoardTransition.swift
//  London System Chess
//
//  Identity tracking for board pieces across FEN changes, so the board can
//  animate: a piece that persists keeps its id (and slides to its new square),
//  a captured piece drops out (fades), a new piece appears. Pure logic, no UI —
//  the view feeds it placements; tests feed it moves.
//

import Foundation

/// A piece with an identity that survives across positions. `square` is always
/// canonical algebraic ("e4"), independent of how the board is displayed.
struct BoardPiece: Identifiable, Equatable {
    let id: Int
    var kind: Character
    var square: String
}

enum BoardTransition {
    /// Fresh pieces for a placement, ids assigned in scan order.
    static func pieces(from placement: [[Character?]]) -> [BoardPiece] {
        var pieces: [BoardPiece] = []
        forEachPiece(in: placement) { square, kind in
            pieces.append(BoardPiece(id: pieces.count, kind: kind, square: square))
        }
        return pieces
    }

    /// Carries `old` into `placement`, preserving ids where a piece plausibly
    /// persisted. Matching, in order:
    /// 1. same square + same kind — untouched piece
    /// 2. same kind, nearest first — the moved piece(s); castling pairs K and R
    ///    independently since kinds differ
    /// 3. same color — promotion: the vanished pawn becomes the new queen and
    ///    slides into it rather than blinking
    /// Unmatched old pieces are dropped (captures); unmatched new squares get
    /// fresh ids (appearances).
    static func pieces(_ old: [BoardPiece], movedTo placement: [[Character?]]) -> [BoardPiece] {
        var nextID = (old.map(\.id).max() ?? -1) + 1
        var incoming: [String: Character] = [:]
        forEachPiece(in: placement) { square, kind in incoming[square] = kind }

        var result: [BoardPiece] = []
        var displaced: [BoardPiece] = []
        for piece in old {
            if incoming[piece.square] == piece.kind {
                result.append(piece)
                incoming.removeValue(forKey: piece.square)
            } else {
                displaced.append(piece)
            }
        }

        var added = incoming.map { (square: $0.key, kind: $0.value) }
            .sorted { $0.square < $1.square }

        // Pass 2: same kind, nearest destination first.
        for piece in displaced {
            guard let index = nearest(in: added, to: piece.square, where: { $0.kind == piece.kind })
            else { continue }
            result.append(BoardPiece(id: piece.id, kind: piece.kind, square: added[index].square))
            added.remove(at: index)
        }
        let unmatched = displaced.filter { piece in !result.contains { $0.id == piece.id } }

        // Pass 3: same color (promotion). Anything still unmatched was captured
        // and simply leaves the array.
        for piece in unmatched {
            guard let index = nearest(in: added, to: piece.square, where: {
                $0.kind.isUppercase == piece.kind.isUppercase
            }) else { continue }
            result.append(BoardPiece(id: piece.id, kind: added[index].kind, square: added[index].square))
            added.remove(at: index)
        }

        for addition in added {
            result.append(BoardPiece(id: nextID, kind: addition.kind, square: addition.square))
            nextID += 1
        }
        return result.sorted { $0.id < $1.id }
    }

    // MARK: - Helpers

    private static func forEachPiece(
        in placement: [[Character?]], _ body: (String, Character) -> Void
    ) {
        for (row, rank) in placement.prefix(8).enumerated() {
            for (col, kind) in rank.prefix(8).enumerated() {
                guard let kind else { continue }
                let file = Character(UnicodeScalar(97 + col)!)
                body("\(file)\(8 - row)", kind)
            }
        }
    }

    private static func nearest(
        in candidates: [(square: String, kind: Character)],
        to square: String,
        where matches: ((square: String, kind: Character)) -> Bool
    ) -> Int? {
        candidates.indices
            .filter { matches(candidates[$0]) }
            .min { distance(square, candidates[$0].square) < distance(square, candidates[$1].square) }
    }

    private static func distance(_ a: String, _ b: String) -> Int {
        guard let af = a.first?.asciiValue, let ar = a.last?.wholeNumberValue,
              let bf = b.first?.asciiValue, let br = b.last?.wholeNumberValue
        else { return .max }
        return abs(Int(af) - Int(bf)) + abs(ar - br)
    }
}
