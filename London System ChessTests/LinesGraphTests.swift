//
//  LinesGraphTests.swift
//  London System ChessTests
//
//  Integrity checks for the shared Lines data model and the sample repertoire.
//  These assert structural invariants (a connected, well-formed graph with real
//  transpositions and a resolvable focus spot) rather than brittle exact counts.
//

import Testing
@testable import London_System_Chess

struct LinesGraphTests {
    let graph = LinesGraph.sample

    @Test func hasASingleRootAtPlyZero() {
        let roots = graph.positions.filter { $0.ply == 0 }
        #expect(roots.count == 1)
        #expect(graph.root?.sideToMove == .white)
        #expect(graph.root?.san == nil)
        #expect(graph.root?.label == "Start")
    }

    @Test func positionIDsAreUnique() {
        let ids = graph.positions.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test func everyMoveConnectsExistingPositions() {
        let ids = Set(graph.positions.map(\.id))
        for move in graph.moves {
            #expect(ids.contains(move.from), "dangling from: \(move.from)")
            #expect(ids.contains(move.to), "dangling to: \(move.to)")
        }
    }

    @Test func everyMoveAdvancesExactlyOnePly() {
        let byID = graph.positionsByID
        for move in graph.moves {
            guard let from = byID[move.from], let to = byID[move.to] else { continue }
            #expect(to.ply == from.ply + 1)
            // The side that played the move is the side that was to move beforehand.
            #expect(move.side == from.sideToMove)
        }
    }

    @Test func everyNonRootPositionIsReachable() {
        for position in graph.positions where position.ply > 0 {
            #expect(!graph.moves(into: position.id).isEmpty,
                    "unreachable: \(position.label)")
        }
    }

    @Test func transpositionsAreExactlyTheMergeNodes() {
        // A transposition is flagged iff more than one distinct parent reaches it.
        for position in graph.positions {
            let distinctParents = Set(graph.moves(into: position.id).map(\.from))
            #expect(position.isTransposition == (distinctParents.count > 1),
                    "flag mismatch at \(position.label)")
        }
        // The repertoire is meant to demonstrate convergence — there must be some.
        #expect(!graph.transpositions.isEmpty)
    }

    @Test func masteryAxesAreInRange() {
        for position in graph.positions {
            #expect((0...1).contains(position.mastery.coverage))
            if let reliability = position.mastery.reliability {
                #expect((0...1).contains(reliability))
            }
            // The "unknown" reliability is reserved for never-seen spots.
            if position.mastery.coverage == 0 {
                #expect(position.mastery.reliability == nil)
            }
        }
    }

    @Test func focusSuggestionIsTheWeakestStudiedSpot() throws {
        let focusID = try #require(graph.focusSuggestion)
        let focus = try #require(graph.positionsByID[focusID])
        #expect(focus.mastery.isCovered)
        let focusReliability = try #require(focus.mastery.reliability)
        // Nothing studied is weaker than the focus spot.
        for position in graph.positions
        where position.mastery.isCovered {
            if let reliability = position.mastery.reliability {
                #expect(reliability >= focusReliability)
            }
        }
    }
}
