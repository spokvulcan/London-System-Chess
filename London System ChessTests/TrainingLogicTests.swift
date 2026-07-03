//
//  TrainingLogicTests.swift
//  London System ChessTests
//
//  The training loop's pure rules (ADR 0004): what a Learn tap covers, how a
//  line-walk steers and where it stops, how answers match repertoire moves, how
//  sessions de-dup targets, and how records paint Mastery. All on the real
//  sample graph — no persistence, no FSRS.
//

import Foundation
import SwiftData
import Testing
@testable import London_System_Chess

@MainActor
struct RepertoireNavigatorTests {
    let graph = LinesGraph.sample
    var navigator: RepertoireNavigator { RepertoireNavigator(graph: graph) }

    var root: LinePosition { graph.root! }

    /// A deep known position: the 5...Qb6 spot (the sample's focus anchor) —
    /// White to move at ply 10, reached via 1.d4 d5 2.Bf4 Nf6 3.e3 c5 4.c3 Nc6 5.Nd2 Qb6.
    var qb6ID: LinePosition.ID {
        graph.positions.first { $0.san == "Qb6" && $0.ply == 10 }!.id
    }

    // MARK: - Card eligibility

    @Test func onlyWhiteToMovePositionsWithContinuationsAreCardEligible() {
        let navigator = navigator
        for position in graph.positions {
            let eligible = navigator.isCardEligible(position.id)
            if eligible {
                #expect(position.sideToMove == .white)
                #expect(!graph.moves(from: position.id).isEmpty)
            }
        }
        // The root is the canonical eligible spot.
        #expect(navigator.isCardEligible(root.id))
    }

    // MARK: - Learning

    @Test func learnPathRunsRootToTargetConnected() {
        let navigator = navigator
        let path = navigator.learnPath(to: qb6ID)
        #expect(path.first == root.id)
        #expect(path.last == qb6ID)
        // Consecutive path entries are connected by real moves.
        for (from, to) in zip(path, path.dropFirst()) {
            #expect(graph.moves(from: from).contains { $0.to == to })
        }
    }

    @Test func learnablePositionsAreEligibleUnlearnedAndOnPath() {
        let navigator = navigator
        let path = Set(navigator.learnPath(to: qb6ID))
        let all = navigator.learnablePositions(to: qb6ID, learned: [])
        #expect(!all.isEmpty)
        for id in all {
            #expect(path.contains(id))
            #expect(navigator.isCardEligible(id))
        }
        // Learning is idempotent: already-learned positions are skipped.
        let rest = navigator.learnablePositions(to: qb6ID, learned: Set(all.prefix(2)))
        #expect(rest.count == all.count - 2)
    }

    // MARK: - Answer matching

    @Test func answerMatchesAnyOutboundRepertoireMove() {
        let navigator = navigator
        for move in graph.moves(from: root.id) {
            let from = String(move.uci.prefix(2))
            let to = String(move.uci.dropFirst(2).prefix(2))
            #expect(navigator.move(from: root.id, matching: from, to)?.san == move.san)
        }
        #expect(navigator.move(from: root.id, matching: "a2", "a3") == nil)
    }

    // MARK: - Walks

    /// Learning the line to the target and walking it, always answering with the
    /// steering-preferred move, must prompt the target itself.
    @Test func steeredWalkReachesItsTarget() {
        let navigator = navigator
        let learned = Set(navigator.learnablePositions(to: qb6ID, learned: []))
        let distances = navigator.distances(to: qb6ID)
        var current = root.id
        var prompted: [LinePosition.ID] = []
        var steps = 0
        while navigator.isPromptable(current, learned: learned), steps < 50 {
            steps += 1
            prompted.append(current)
            if current == qb6ID { break }
            // The player plays the on-path move (what revealMove also picks).
            guard let move = navigator.revealMove(from: current, distancesToTarget: distances) else { break }
            current = move.to
            guard let reply = navigator.blackReply(
                from: current, learned: learned, distancesToTarget: distances
            ) else { break }
            current = reply.to
        }
        #expect(prompted.contains(qb6ID))
    }

    @Test func walkNeverEntersUnlearnedTerritory() {
        let navigator = navigator
        // Learn only the first few plies: path to some ply-3 position.
        let shallow = graph.positions.first { $0.ply == 3 }!.id
        let learned = Set(navigator.learnablePositions(to: shallow, learned: []))
        var current = root.id
        var steps = 0
        while navigator.isPromptable(current, learned: learned), steps < 50 {
            steps += 1
            guard let move = navigator.revealMove(from: current, distancesToTarget: nil) else { break }
            current = move.to
            guard let reply = navigator.blackReply(
                from: current, learned: learned, distancesToTarget: nil
            ) else { break }
            // Black only ever lands on learned, promptable positions.
            #expect(navigator.isPromptable(reply.to, learned: learned))
            current = reply.to
        }
        #expect(steps <= 3, "a shallow repertoire must end the walk early")
    }

    // MARK: - Session composition

    @Test func sessionTargetsSkipCardsCoveredByEarlierWalks() {
        let navigator = navigator
        // The path to the deep target passes through the root: with both due,
        // the root must not become its own walk.
        let due = [qb6ID, root.id]
        let targets = navigator.sessionTargets(dueIDs: due, limit: 5)
        #expect(targets == [qb6ID])
    }

    @Test func sessionTargetsRespectTheLimit() {
        let navigator = navigator
        let due = graph.positions
            .filter { navigator.isCardEligible($0.id) }
            .map(\.id)
        let targets = navigator.sessionTargets(dueIDs: due, limit: 5)
        #expect(targets.count <= 5)
        #expect(!targets.isEmpty)
    }
}

@MainActor
struct MasteryPaintingTests {
    let graph = LinesGraph.sample

    @Test func coverageSaturatesWithReps() {
        #expect(MasteryPainting.coverage(reps: 0) == 0.2)
        #expect(MasteryPainting.coverage(reps: 5) == 1.0)
        #expect(MasteryPainting.coverage(reps: 50) == 1.0)
    }

    @Test func unrecordedPositionsPaintUnseenAndMocksNeverLeakThrough() {
        let painted = MasteryPainting.painted(graph, records: [:])
        for position in painted.positions {
            #expect(position.mastery.isUnseen, "mock mastery leaked on \(position.label)")
        }
        for move in painted.moves {
            #expect(move.reliability == nil)
        }
    }

    @Test func whiteNodesPaintFromTheirRecord() {
        let rootID = graph.root!.id
        let painted = MasteryPainting.painted(
            graph,
            records: [rootID: .init(reps: 2, reliabilityEWMA: 0.8)]
        )
        let root = painted.positionsByID[rootID]!
        #expect(abs(root.mastery.coverage - 0.52) < 0.0001)
        #expect(root.mastery.reliability == 0.8)
    }

    @Test func blackNodesInheritTheirBestCoveredWhiteParent() {
        let rootID = graph.root!.id
        let d4 = graph.children(of: rootID).first { $0.san == "d4" }!
        #expect(d4.sideToMove == .black)
        let painted = MasteryPainting.painted(
            graph,
            records: [rootID: .init(reps: 3, reliabilityEWMA: 0.6)]
        )
        let paintedD4 = painted.positionsByID[d4.id]!
        #expect(paintedD4.mastery.coverage == painted.positionsByID[rootID]!.mastery.coverage)
        #expect(paintedD4.mastery.reliability == 0.6)
    }

    @Test func learnedButUntestedIsCoveredWithUnknownReliability() {
        let rootID = graph.root!.id
        let painted = MasteryPainting.painted(
            graph,
            records: [rootID: .init(reps: 0, reliabilityEWMA: nil)]
        )
        let root = painted.positionsByID[rootID]!
        #expect(root.mastery.isCovered)
        #expect(root.mastery.reliability == nil)
    }
}

@MainActor
struct ReviewGradingTests {
    @Test func ewmaInitializesFromFirstGradeThenBlends() {
        let first = ReviewScheduler.updatedEWMA(nil, grade: .good)
        #expect(first == 1.0)
        let after = ReviewScheduler.updatedEWMA(first, grade: .again)
        #expect(abs(after - 0.7) < 0.0001)
        let third = ReviewScheduler.updatedEWMA(after, grade: .hard)
        #expect(abs(third - (0.7 * 0.7 + 0.3 * 0.5)) < 0.0001)
    }

    @Test func applyingAReviewSchedulesTheCardIntoTheFuture() throws {
        let card = ReviewCard(positionID: "test-position")
        #expect(card.stateRaw == 0)
        let scheduler = ReviewScheduler()
        try scheduler.applyReview(to: card, grade: .good, at: .now)
        #expect(card.reps == 1)
        #expect(card.dueAt > .now)
        #expect(card.stateRaw != 0)
        #expect(card.reliabilityEWMA == 1.0)
        #expect(card.lastReviewedAt != nil)
    }

    @Test func snapshotRestoreRewindsAReviewExactly() throws {
        let card = ReviewCard(positionID: "test-position")
        let scheduler = ReviewScheduler()
        let before = scheduler.snapshot(of: card)
        try scheduler.applyReview(to: card, grade: .good, at: .now)
        scheduler.restore(before, to: card)
        #expect(card.reps == 0)
        #expect(card.stateRaw == 0)
        #expect(card.reliabilityEWMA == nil)
        // The shaky demote path: rewind + re-apply as hard.
        try scheduler.applyReview(to: card, grade: .hard, at: .now)
        #expect(card.reps == 1)
        #expect(card.reliabilityEWMA == 0.5)
    }
}

/// The whole training loop, end to end, against a real (in-memory) SwiftData
/// container and the real DailySession state machine: Learn a line in Lines →
/// the due cards compose a session → a line-walk is answered → FSRS reschedules
/// and the EWMA updates → Lines paints real coverage/reliability.
@MainActor
struct TrainingLoopIntegrationTests {
    @Test func learnReviewRepaintLoop() async throws {
        let container = try ModelContainer(
            for: ReviewCard.self, ReviewLogEntry.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        let graph = LinesGraph.sample
        let navigator = RepertoireNavigator(graph: graph)
        let target = graph.positions.first { $0.san == "Qb6" && $0.ply == 10 }!.id

        // Learn (Lines): one card per eligible position on the path.
        for id in navigator.learnablePositions(to: target, learned: []) {
            context.insert(ReviewCard(positionID: id))
        }
        let cards = try context.fetch(FetchDescriptor<ReviewCard>())
        #expect(!cards.isEmpty)
        #expect(cards.allSatisfy { $0.dueAt <= .now })

        // Daily: the freshly learned cards compose a single walk (path de-dup).
        let due = cards.sorted { $0.dueAt < $1.dueAt }.map(\.positionID)
        let targets = navigator.sessionTargets(dueIDs: due, limit: 5)
        #expect(targets == [target])

        let session = try #require(DailySession(
            graph: graph, cards: cards, targets: targets, context: context
        ))

        // Play the walk: always answer with the steering-preferred move.
        let distances = navigator.distances(to: target)
        var safety = 200
        while session.phase != .finished, safety > 0 {
            safety -= 1
            if session.phase == .prompting {
                let move = try #require(navigator.revealMove(
                    from: session.currentID, distancesToTarget: distances
                ))
                session.tap(square: String(move.uci.prefix(2)))
                session.tap(square: String(move.uci.dropFirst(2).prefix(2)))
            }
            try await Task.sleep(for: .milliseconds(100))
        }
        #expect(session.phase == .finished)
        #expect(session.totals.good > 0)
        #expect(session.totals.again == 0)

        // Persistence: every prompted card was rescheduled and logged.
        let reviewed = try context.fetch(FetchDescriptor<ReviewCard>())
            .filter { $0.reps > 0 }
        #expect(reviewed.count == session.totals.prompts)
        #expect(reviewed.allSatisfy { $0.dueAt > .now && $0.reliabilityEWMA == 1.0 })
        let logs = try context.fetch(FetchDescriptor<ReviewLogEntry>())
        #expect(logs.count == session.totals.prompts)

        // Lines: the repaint shows real coverage and perfect reliability.
        let records = Dictionary(uniqueKeysWithValues: try context
            .fetch(FetchDescriptor<ReviewCard>())
            .map { ($0.positionID, MasteryPainting.CardSnapshot($0)) })
        let painted = MasteryPainting.painted(graph, records: records)
        let paintedTarget = painted.positionsByID[target]!.mastery
        #expect(paintedTarget.isCovered)
        #expect(paintedTarget.reliability == 1.0)
    }
}
