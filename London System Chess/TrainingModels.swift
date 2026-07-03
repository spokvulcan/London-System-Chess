//
//  TrainingModels.swift
//  London System Chess
//
//  The persisted training records. A ReviewCard is the Card of CONTEXT.md — one
//  per White-to-move repertoire position (keyed by EPD), created when the
//  position is first Learned, scheduled by FSRS (ADR 0004). The FSRS fields
//  mirror the package's `Card` struct field-for-field, but the FSRS types
//  themselves stay quarantined behind ReviewScheduler — these models are plain
//  SwiftData.
//

import Foundation
import SwiftData

@Model
final class ReviewCard {
    #Unique<ReviewCard>([\.positionID])

    /// The position's EPD — `LinePosition.id`. Transpositions share one card.
    var positionID: String
    /// When the position entered the repertoire (the Learn tap).
    var learnedAt: Date

    // FSRS scheduling state (mirrors FSRS.Card).
    var dueAt: Date
    var stability: Double
    var difficulty: Double
    var elapsedDays: Double
    var scheduledDays: Double
    var learningSteps: Int
    var reps: Int
    var lapses: Int
    /// FSRS CardState raw value: 0 new, 1 learning, 2 review, 3 relearning.
    var stateRaw: Int
    var lastReviewedAt: Date?

    /// Recency-weighted demonstrated accuracy (r ← 0.7r + 0.3g; Good=1, Hard=0.5,
    /// Again=0). `nil` until the first review — Reliability *unknown*, which
    /// CONTEXT.md keeps distinct from *low*.
    var reliabilityEWMA: Double?

    /// A freshly learned card: FSRS `new`, due immediately.
    init(positionID: String, learnedAt: Date = .now) {
        self.positionID = positionID
        self.learnedAt = learnedAt
        self.dueAt = learnedAt
        self.stability = 0
        self.difficulty = 0
        self.elapsedDays = 0
        self.scheduledDays = 0
        self.learningSteps = 0
        self.reps = 0
        self.lapses = 0
        self.stateRaw = 0
        self.lastReviewedAt = nil
        self.reliabilityEWMA = nil
    }
}

/// One graded prompt during a line-walk. Kept append-only so Trends can later
/// reconstruct history; Lines only needs the aggregates on ReviewCard.
@Model
final class ReviewLogEntry {
    var positionID: String
    /// ReviewGrade raw value: "again" / "hard" / "good".
    var gradeRaw: String
    var reviewedAt: Date

    init(positionID: String, gradeRaw: String, reviewedAt: Date = .now) {
        self.positionID = positionID
        self.gradeRaw = gradeRaw
        self.reviewedAt = reviewedAt
    }
}
