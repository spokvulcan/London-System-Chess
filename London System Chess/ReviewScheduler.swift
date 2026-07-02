//
//  ReviewScheduler.swift
//  London System Chess
//
//  The one file that imports FSRS. Converts ReviewCard <-> FSRS.Card, applies a
//  graded review, and maintains the reliability EWMA. Keeping the dependency
//  quarantined here means the rest of the app (models, walk logic, views) never
//  sees an FSRS type — the seam the old Expo app proved out.
//

import Foundation
import FSRS

/// The grade a walk prompt produces. Automatic (never self-assessed): first-try
/// correct → good, correct on retry → hard, failed retry → again. The optional
/// "was shaky" chip demotes good → hard after the fact. FSRS's `easy` is
/// deliberately unused — there is no signal that distinguishes it here.
enum ReviewGrade: String {
    case again
    case hard
    case good

    /// The demonstrated-accuracy value fed into the reliability EWMA.
    var reliabilityValue: Double {
        switch self {
        case .again: 0.0
        case .hard: 0.5
        case .good: 1.0
        }
    }

    fileprivate var fsrsRating: Rating {
        switch self {
        case .again: .again
        case .hard: .hard
        case .good: .good
        }
    }
}

struct ReviewScheduler {
    /// EWMA weight of the newest grade.
    static let ewmaAlpha = 0.3

    private let fsrs = FSRS(parameters: .init())

    /// Everything `applyReview` mutates, captured so the shaky-chip demote can
    /// rewind a Good and re-apply as Hard without FSRS needing an "undo".
    struct Snapshot {
        var dueAt: Date
        var stability: Double
        var difficulty: Double
        var elapsedDays: Double
        var scheduledDays: Double
        var learningSteps: Int
        var reps: Int
        var lapses: Int
        var stateRaw: Int
        var lastReviewedAt: Date?
        var reliabilityEWMA: Double?
    }

    func snapshot(of card: ReviewCard) -> Snapshot {
        Snapshot(
            dueAt: card.dueAt,
            stability: card.stability,
            difficulty: card.difficulty,
            elapsedDays: card.elapsedDays,
            scheduledDays: card.scheduledDays,
            learningSteps: card.learningSteps,
            reps: card.reps,
            lapses: card.lapses,
            stateRaw: card.stateRaw,
            lastReviewedAt: card.lastReviewedAt,
            reliabilityEWMA: card.reliabilityEWMA
        )
    }

    func restore(_ snapshot: Snapshot, to card: ReviewCard) {
        card.dueAt = snapshot.dueAt
        card.stability = snapshot.stability
        card.difficulty = snapshot.difficulty
        card.elapsedDays = snapshot.elapsedDays
        card.scheduledDays = snapshot.scheduledDays
        card.learningSteps = snapshot.learningSteps
        card.reps = snapshot.reps
        card.lapses = snapshot.lapses
        card.stateRaw = snapshot.stateRaw
        card.lastReviewedAt = snapshot.lastReviewedAt
        card.reliabilityEWMA = snapshot.reliabilityEWMA
    }

    /// Applies one graded review: FSRS reschedules the card, and the grade
    /// updates the reliability EWMA.
    func applyReview(to card: ReviewCard, grade: ReviewGrade, at date: Date = .now) throws {
        let next = try fsrs.next(card: fsrsCard(from: card), now: date, grade: grade.fsrsRating).card
        card.dueAt = next.due
        card.stability = next.stability
        card.difficulty = next.difficulty
        card.elapsedDays = next.elapsedDays
        card.scheduledDays = next.scheduledDays
        card.learningSteps = next.learningSteps
        card.reps = next.reps
        card.lapses = next.lapses
        card.stateRaw = next.state.rawValue
        card.lastReviewedAt = next.lastReview
        card.reliabilityEWMA = Self.updatedEWMA(card.reliabilityEWMA, grade: grade)
    }

    /// r ← (1-α)r + α·g; the first grade initializes r.
    static func updatedEWMA(_ current: Double?, grade: ReviewGrade) -> Double {
        guard let current else { return grade.reliabilityValue }
        return (1 - ewmaAlpha) * current + ewmaAlpha * grade.reliabilityValue
    }

    private func fsrsCard(from card: ReviewCard) -> Card {
        Card(
            due: card.dueAt,
            stability: card.stability,
            difficulty: card.difficulty,
            elapsedDays: card.elapsedDays,
            scheduledDays: card.scheduledDays,
            learningSteps: card.learningSteps,
            reps: card.reps,
            lapses: card.lapses,
            state: CardState(rawValue: card.stateRaw) ?? .new,
            lastReview: card.lastReviewedAt
        )
    }
}
