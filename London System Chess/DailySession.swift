//
//  DailySession.swift
//  London System Chess
//
//  The state machine behind one Daily review session: up to five line-walks,
//  each targeting a due card (CONTEXT.md: Daily, Review, Line-walk). The player
//  produces White's moves by tapping from→to; Black auto-plays, steering toward
//  the target; every prompt is graded automatically (first-try Good, retry Hard,
//  failed retry Again + reveal) with the optional "was shaky" demote. All graph
//  rules live in RepertoireNavigator; all FSRS math behind ReviewScheduler —
//  this class only sequences them and owns the persistence writes.
//

import Foundation
import SwiftData
import SwiftUI

@Observable
@MainActor
final class DailySession {
    enum Phase: Equatable {
        /// Waiting for the player's from→to taps.
        case prompting
        /// A move just played; the opponent's reply (or walk end) is pending.
        case animating
        /// Failed retry: the correct move is shown before auto-playing it.
        case revealing
        /// All walks done — summary.
        case finished
    }

    struct Totals {
        var good = 0
        var hard = 0
        var again = 0
        var prompts: Int { good + hard + again }
    }

    /// A just-earned Good the player can still confess into a Hard.
    struct ShakyOffer {
        let positionID: LinePosition.ID
        let snapshot: ReviewScheduler.Snapshot
        let logEntry: ReviewLogEntry
        let reviewedAt: Date
    }

    private let navigator: RepertoireNavigator
    private let scheduler = ReviewScheduler()
    private let context: ModelContext
    private let positionsByID: [LinePosition.ID: LinePosition]
    private let learned: Set<LinePosition.ID>
    private var cardsByID: [LinePosition.ID: ReviewCard]

    let targets: [LinePosition.ID]
    private(set) var walkIndex = 0
    private(set) var currentID: LinePosition.ID
    private(set) var phase: Phase = .prompting
    private(set) var selectedSquare: String?
    private(set) var wrongAttempts = 0
    /// Squares of the most recently played move, for the board highlight.
    private(set) var lastMoveSquares: [String] = []
    /// Destination square of a wrong attempt, flashed red.
    private(set) var wrongFlashSquare: String?
    /// SAN of the revealed correct move while `.revealing`.
    private(set) var revealSAN: String?
    private(set) var totals = Totals()
    private(set) var shakyOffer: ShakyOffer?

    private var distancesToTarget: [LinePosition.ID: Int]?

    init?(
        graph: LinesGraph,
        cards: [ReviewCard],
        targets: [LinePosition.ID],
        context: ModelContext
    ) {
        guard let root = graph.root, !targets.isEmpty else { return nil }
        self.navigator = RepertoireNavigator(graph: graph)
        self.context = context
        self.positionsByID = graph.positionsByID
        self.learned = Set(cards.map(\.positionID))
        self.cardsByID = Dictionary(uniqueKeysWithValues: cards.map { ($0.positionID, $0) })
        self.targets = targets
        self.currentID = root.id
        guard navigator.isPromptable(root.id, learned: learned) else { return nil }
        self.distancesToTarget = navigator.distances(to: targets[0])
    }

    // MARK: - View-facing state

    var currentFEN: String { positionsByID[currentID]?.fen ?? "" }

    var currentTargetLabel: String {
        positionsByID[targets[min(walkIndex, targets.count - 1)]]?.label ?? ""
    }

    var boardHighlights: [String: Color] {
        var highlights: [String: Color] = [:]
        for square in lastMoveSquares { highlights[square] = .yellow }
        if phase == .revealing, let reveal = currentRevealMove {
            highlights[String(reveal.uci.prefix(2))] = .green
            highlights[String(reveal.uci.dropFirst(2).prefix(2))] = .green
        }
        if let wrongFlashSquare { highlights[wrongFlashSquare] = .red }
        return highlights
    }

    // MARK: - Input

    func tap(square: String) {
        guard phase == .prompting else { return }
        let isOwnPiece = ChessBoardView.piece(at: square, in: currentFEN)?.isUppercase == true
        if let selected = selectedSquare {
            if square == selected {
                selectedSquare = nil
            } else if isOwnPiece {
                selectedSquare = square
            } else {
                attempt(from: selected, to: square)
            }
        } else if isOwnPiece {
            selectedSquare = square
        }
    }

    /// The shaky-chip confession: rewinds the last Good and re-applies as Hard.
    func demoteShakyToHard() {
        guard let offer = shakyOffer, let card = cardsByID[offer.positionID] else { return }
        shakyOffer = nil
        scheduler.restore(offer.snapshot, to: card)
        applyGrade(.hard, to: card, at: offer.reviewedAt, reusing: offer.logEntry)
        totals.good -= 1
        totals.hard += 1
    }

    // MARK: - Walk stepping

    private func attempt(from: String, to: String) {
        expireShakyOffer()
        if let move = navigator.move(from: currentID, matching: from, to) {
            let grade: ReviewGrade = wrongAttempts == 0 ? .good : .hard
            grade.log(into: &totals)
            if let card = cardsByID[currentID] {
                if grade == .good {
                    let snapshot = scheduler.snapshot(of: card)
                    let entry = applyGrade(grade, to: card, at: .now)
                    offerShaky(ShakyOffer(
                        positionID: currentID, snapshot: snapshot,
                        logEntry: entry, reviewedAt: .now
                    ))
                } else {
                    applyGrade(grade, to: card, at: .now)
                }
            }
            play(move)
        } else {
            selectedSquare = nil
            wrongAttempts += 1
            flashWrong(at: to)
            if wrongAttempts >= 2 {
                failPrompt()
            }
        }
    }

    private func failPrompt() {
        if let card = cardsByID[currentID] {
            applyGrade(.again, to: card, at: .now)
        }
        ReviewGrade.again.log(into: &totals)
        guard let reveal = currentRevealMove else {
            endWalk()
            return
        }
        revealSAN = reveal.san
        phase = .revealing
        Task {
            try? await Task.sleep(for: .seconds(1.6))
            guard phase == .revealing else { return }
            revealSAN = nil
            play(reveal)
        }
    }

    private var currentRevealMove: LineMove? {
        navigator.revealMove(from: currentID, distancesToTarget: distancesToTarget)
    }

    /// Advances through the player's (or revealed) move, then the opponent's.
    private func play(_ move: LineMove) {
        selectedSquare = nil
        wrongAttempts = 0
        if currentID == currentTarget {
            // Target prompted; steer the rest of the walk by learned depth.
            distancesToTarget = nil
        }
        lastMoveSquares = Self.squares(of: move.uci)
        currentID = move.to
        phase = .animating
        Task {
            try? await Task.sleep(for: .seconds(0.7))
            guard phase == .animating else { return }
            stepOpponent()
        }
    }

    private func stepOpponent() {
        guard let reply = navigator.blackReply(
            from: currentID, learned: learned, distancesToTarget: distancesToTarget
        ) else {
            endWalk()
            return
        }
        lastMoveSquares = Self.squares(of: reply.uci)
        currentID = reply.to
        if navigator.isPromptable(currentID, learned: learned) {
            phase = .prompting
        } else {
            endWalk()
        }
    }

    private func endWalk() {
        walkIndex += 1
        guard walkIndex < targets.count, let root = navigator.graph.root else {
            phase = .finished
            return
        }
        currentID = root.id
        selectedSquare = nil
        wrongAttempts = 0
        lastMoveSquares = []
        revealSAN = nil
        distancesToTarget = navigator.distances(to: targets[walkIndex])
        phase = .prompting
    }

    // MARK: - Grading

    @discardableResult
    private func applyGrade(
        _ grade: ReviewGrade,
        to card: ReviewCard,
        at date: Date,
        reusing entry: ReviewLogEntry? = nil
    ) -> ReviewLogEntry {
        do {
            try scheduler.applyReview(to: card, grade: grade, at: date)
        } catch {
            assertionFailure("FSRS rejected a review: \(error)")
        }
        if let entry {
            entry.gradeRaw = grade.rawValue
            return entry
        }
        let newEntry = ReviewLogEntry(positionID: card.positionID, gradeRaw: grade.rawValue, reviewedAt: date)
        context.insert(newEntry)
        return newEntry
    }

    private func offerShaky(_ offer: ShakyOffer) {
        shakyOffer = offer
        Task {
            try? await Task.sleep(for: .seconds(3))
            if shakyOffer?.reviewedAt == offer.reviewedAt { shakyOffer = nil }
        }
    }

    private func expireShakyOffer() {
        shakyOffer = nil
    }

    private func flashWrong(at square: String) {
        wrongFlashSquare = square
        Task {
            try? await Task.sleep(for: .seconds(0.5))
            if wrongFlashSquare == square { wrongFlashSquare = nil }
        }
    }

    private var currentTarget: LinePosition.ID {
        targets[min(walkIndex, targets.count - 1)]
    }

    private static func squares(of uci: String) -> [String] {
        guard uci.count >= 4 else { return [] }
        return [String(uci.prefix(2)), String(uci.dropFirst(2).prefix(2))]
    }
}

private extension ReviewGrade {
    func log(into totals: inout DailySession.Totals) {
        switch self {
        case .good: totals.good += 1
        case .hard: totals.hard += 1
        case .again: totals.again += 1
        }
    }
}
