//
//  BoardTests.swift
//  London System ChessTests
//
//  The board's pure logic: FEN parsing, orientation ↔ square-name mapping (both
//  ways, both orientations — the flipped path has no default call site yet, so
//  these tests are what exercise it), and BoardTransition's identity tracking
//  across moves, captures, castling, en passant, and promotion.
//

import Testing
@testable import London_System_Chess

private let startFEN = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"

struct OrientationMappingTests {
    @Test func whiteAtBottomCorners() {
        #expect(ChessBoardView.squareName(displayRow: 7, displayCol: 0, orientation: .white) == "a1")
        #expect(ChessBoardView.squareName(displayRow: 0, displayCol: 7, orientation: .white) == "h8")
        #expect(ChessBoardView.squareName(displayRow: 4, displayCol: 4, orientation: .white) == "e4")
    }

    @Test func blackAtBottomCorners() {
        #expect(ChessBoardView.squareName(displayRow: 7, displayCol: 0, orientation: .black) == "h8")
        #expect(ChessBoardView.squareName(displayRow: 0, displayCol: 7, orientation: .black) == "a1")
        #expect(ChessBoardView.squareName(displayRow: 3, displayCol: 3, orientation: .black) == "e4")
    }

    @Test(arguments: [BoardOrientation.white, .black])
    func displayCellInvertsSquareName(orientation: BoardOrientation) {
        for row in 0..<8 {
            for col in 0..<8 {
                let name = ChessBoardView.squareName(displayRow: row, displayCol: col, orientation: orientation)
                let cell = ChessBoardView.displayCell(of: name, orientation: orientation)
                #expect(cell.row == row)
                #expect(cell.col == col)
            }
        }
    }

    /// a1 must be a dark square in both orientations — the renderer colors by
    /// display parity, which only works because flipping preserves it.
    @Test(arguments: [BoardOrientation.white, .black])
    func flipPreservesSquareColorParity(orientation: BoardOrientation) {
        let cell = ChessBoardView.displayCell(of: "a1", orientation: orientation)
        #expect(!(cell.row + cell.col).isMultiple(of: 2))
    }
}

struct FENTests {
    @Test func placementParsesStartPosition() {
        let ranks = ChessBoardView.placement(from: startFEN)
        #expect(ranks.count == 8)
        #expect(ranks[0][0] == "r")
        #expect(ranks[7][4] == "K")
        #expect(ranks[4].allSatisfy { $0 == nil })
    }

    @Test func pieceAtSquare() {
        #expect(ChessBoardView.piece(at: "e1", in: startFEN) == "K")
        #expect(ChessBoardView.piece(at: "d8", in: startFEN) == "q")
        #expect(ChessBoardView.piece(at: "e4", in: startFEN) == nil)
        #expect(ChessBoardView.piece(at: "z9", in: startFEN) == nil)
    }

    @Test func assetNames() {
        #expect(ChessBoardView.assetName(for: "N") == "wN")
        #expect(ChessBoardView.assetName(for: "q") == "bQ")
        #expect(ChessBoardView.assetName(for: "p") == "bP")
    }
}

struct BoardTransitionTests {
    private func pieces(_ fen: String) -> [BoardPiece] {
        BoardTransition.pieces(from: ChessBoardView.placement(from: fen))
    }

    private func apply(_ old: [BoardPiece], _ fen: String) -> [BoardPiece] {
        BoardTransition.pieces(old, movedTo: ChessBoardView.placement(from: fen))
    }

    private func piece(on square: String, in pieces: [BoardPiece]) -> BoardPiece? {
        pieces.first { $0.square == square }
    }

    @Test func startPositionHas32Pieces() {
        #expect(pieces(startFEN).count == 32)
    }

    @Test func simpleMoveKeepsIdentity() {
        let before = pieces(startFEN)
        let mover = piece(on: "e2", in: before)!
        let after = apply(before, "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1")
        #expect(after.count == 32)
        #expect(piece(on: "e4", in: after)?.id == mover.id)
        #expect(piece(on: "e2", in: after) == nil)
    }

    @Test func captureRemovesVictimAndSlidesAttacker() {
        let fen = "rnbqkbnr/ppp1pppp/8/3p4/4P3/8/PPPP1PPP/RNBQKBNR w KQkq - 0 2"
        let before = pieces(fen)
        let attacker = piece(on: "e4", in: before)!
        let victim = piece(on: "d5", in: before)!
        let after = apply(before, "rnbqkbnr/ppp1pppp/8/3P4/8/8/PPPP1PPP/RNBQKBNR b KQkq - 0 2")
        #expect(after.count == 31)
        #expect(piece(on: "d5", in: after)?.id == attacker.id)
        #expect(!after.contains { $0.id == victim.id })
    }

    @Test func castlingSlidesKingAndRook() {
        let fen = "r1bqkbnr/pppp1ppp/2n5/4p3/2B1P3/5N2/PPPP1PPP/RNBQK2R w KQkq - 4 4"
        let before = pieces(fen)
        let king = piece(on: "e1", in: before)!
        let rook = piece(on: "h1", in: before)!
        let after = apply(before, "r1bqkbnr/pppp1ppp/2n5/4p3/2B1P3/5N2/PPPP1PPP/RNBQ1RK1 b kq - 5 4")
        #expect(piece(on: "g1", in: after)?.id == king.id)
        #expect(piece(on: "f1", in: after)?.id == rook.id)
    }

    @Test func enPassantRemovesTheBypassedPawn() {
        let fen = "rnbqkbnr/ppp1pppp/8/3pP3/8/8/PPPP1PPP/RNBQKBNR w KQkq d6 0 3"
        let before = pieces(fen)
        let attacker = piece(on: "e5", in: before)!
        let victim = piece(on: "d5", in: before)!
        let after = apply(before, "rnbqkbnr/ppp1pppp/3P4/8/8/8/PPPP1PPP/RNBQKBNR b KQkq - 0 3")
        #expect(after.count == 31)
        #expect(piece(on: "d6", in: after)?.id == attacker.id)
        #expect(!after.contains { $0.id == victim.id })
    }

    @Test func promotionCarriesThePawnIdentityIntoTheQueen() {
        let fen = "8/P6k/8/8/8/8/8/K7 w - - 0 1"
        let before = pieces(fen)
        let pawn = piece(on: "a7", in: before)!
        let after = apply(before, "Q7/7k/8/8/8/8/8/K7 b - - 0 1")
        #expect(after.count == 3)
        let queen = piece(on: "a8", in: after)
        #expect(queen?.id == pawn.id)
        #expect(queen?.kind == "Q")
    }

    @Test func unrelatedPositionJumpStillYieldsValidPieces() {
        let before = pieces(startFEN)
        let after = apply(before, "r1bqkbnr/pppp1ppp/2n5/4p3/2B1P3/5N2/PPPP1PPP/RNBQK2R w KQkq - 4 4")
        #expect(after.count == 32)
        #expect(Set(after.map(\.id)).count == 32)
        #expect(Set(after.map(\.square)).count == 32)
    }
}
