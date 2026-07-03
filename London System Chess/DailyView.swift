//
//  DailyView.swift
//  London System Chess
//
//  The Daily tab: a day-scoped review session (CONTEXT.md) — up to five due
//  cards, each reviewed as a line-walk on an interactive board. The lobby shows
//  what's due (or the caught-up / nothing-learned states pointing at Lines);
//  DailySession drives the active walk.
//

import SwiftUI
import SwiftData

struct DailyView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var cards: [ReviewCard]
    @State private var session: DailySession?

    private let graph = LinesGraph.sample
    private static let sessionLimit = 5

    private var dueCards: [ReviewCard] {
        cards.filter { $0.dueAt <= .now }.sorted { $0.dueAt < $1.dueAt }
    }

    var body: some View {
        NavigationStack {
            Group {
                if let session {
                    if session.phase == .finished {
                        summary(session)
                    } else {
                        activeWalk(session)
                    }
                } else {
                    lobby
                }
            }
            .navigationTitle("Daily")
        }
    }

    // MARK: - Lobby

    @ViewBuilder
    private var lobby: some View {
        if cards.isEmpty {
            ContentUnavailableView(
                "Nothing learned yet",
                systemImage: AppTab.daily.systemImage,
                description: Text("Learn a line in Lines first — reviews of what you've learned appear here.")
            )
        } else if dueCards.isEmpty {
            ContentUnavailableView(
                "All caught up",
                systemImage: "checkmark.seal",
                description: Text("No positions are due. Learn another line in Lines, or come back tomorrow.")
            )
        } else {
            VStack(spacing: 20) {
                Spacer()
                Image(systemName: AppTab.daily.systemImage)
                    .font(.system(size: 56))
                    .foregroundStyle(.tint)
                Text("\(dueCards.count) position\(dueCards.count == 1 ? "" : "s") due")
                    .font(.title2.weight(.semibold))
                Text("Reviewed as whole lines — play your move at every turn.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button {
                    startSession()
                } label: {
                    Text("Start review")
                        .font(.headline)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.glassProminent)
                Spacer()
            }
            .padding()
        }
    }

    private func startSession() {
        let navigator = RepertoireNavigator(graph: graph)
        let targets = navigator.sessionTargets(
            dueIDs: dueCards.map(\.positionID),
            limit: Self.sessionLimit
        )
        session = DailySession(graph: graph, cards: cards, targets: targets, context: modelContext)
    }

    // MARK: - Active walk

    private func activeWalk(_ session: DailySession) -> some View {
        VStack(spacing: 16) {
            HStack {
                Text("Line \(session.walkIndex + 1) of \(session.targets.count)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("toward \(session.currentTargetLabel)")
                    .font(.subheadline.monospaced())
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal)

            ChessBoardView(
                fen: session.currentFEN,
                selectedSquare: session.selectedSquare,
                highlights: session.boardHighlights,
                onSquareTap: { session.tap(square: $0) }
            )
            .padding(.horizontal)

            statusLine(session)

            if session.shakyOffer != nil {
                Button {
                    withAnimation(.snappy) { session.demoteShakyToHard() }
                } label: {
                    Label("was shaky 😅", systemImage: "hand.raised")
                        .font(.subheadline)
                }
                .buttonStyle(.glass)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            Spacer()
        }
        .padding(.top, 8)
        .animation(.snappy, value: session.shakyOffer == nil)
    }

    @ViewBuilder
    private func statusLine(_ session: DailySession) -> some View {
        switch session.phase {
        case .prompting:
            Text(session.wrongAttempts == 0 ? "Your move" : "Not that one — try again")
                .font(.headline)
                .foregroundStyle(session.wrongAttempts == 0 ? .primary : Color.red)
        case .animating:
            Text("…")
                .font(.headline)
                .foregroundStyle(.secondary)
        case .revealing:
            Text("The move was \(session.revealSAN ?? "—")")
                .font(.headline)
                .foregroundStyle(.orange)
        case .finished:
            EmptyView()
        }
    }

    // MARK: - Summary

    private func summary(_ session: DailySession) -> some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "flag.checkered")
                .font(.system(size: 48))
                .foregroundStyle(.tint)
            Text("Session complete")
                .font(.title2.weight(.semibold))

            HStack(spacing: 24) {
                statBlock(count: session.totals.good, label: "Good", color: MasteryStyle.reliabilityColor(1.0))
                statBlock(count: session.totals.hard, label: "Hard", color: MasteryStyle.reliabilityColor(0.5))
                statBlock(count: session.totals.again, label: "Again", color: MasteryStyle.reliabilityColor(0.0))
            }

            if dueCards.isEmpty {
                Text("All caught up — nice.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text("\(dueCards.count) position\(dueCards.count == 1 ? "" : "s") still due.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                Button("Done") { self.session = nil }
                    .buttonStyle(.glass)
                if !dueCards.isEmpty {
                    Button("Review more") {
                        self.session = nil
                        startSession()
                    }
                    .buttonStyle(.glassProminent)
                }
            }
            Spacer()
        }
        .padding()
    }

    private func statBlock(count: Int, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.title.weight(.bold).monospacedDigit())
                .foregroundStyle(color)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 64)
    }
}

#Preview {
    DailyView()
        .modelContainer(for: ReviewCard.self, inMemory: true)
}
