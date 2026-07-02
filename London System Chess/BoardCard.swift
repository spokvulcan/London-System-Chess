//
//  BoardCard.swift
//  London System Chess
//
//  The floating Liquid Glass card shown when a node/move is selected (tap → board
//  card, not a persistent pane — so each renderer keeps the full canvas). It shows
//  the real position, its Mastery, and the continuations from here as per-move
//  (edge) reliability — letting you step deeper without leaving the card.
//

import SwiftUI

struct BoardCard: View {
    let graph: LinesGraph
    @Binding var selectedID: LinePosition.ID?
    /// Positions already in the repertoire (carrying a ReviewCard).
    var learnedIDs: Set<LinePosition.ID> = []
    /// Present = the card offers the Learn action (CONTEXT.md: Learning) —
    /// called with the selected position; the owner creates the cards.
    var onLearn: ((LinePosition.ID) -> Void)? = nil

    var body: some View {
        if let id = selectedID, let position = graph.positionsByID[id] {
            ZStack {
                // Dimmed, tap-to-dismiss backdrop keeps the canvas in view behind.
                Rectangle()
                    .fill(.black.opacity(0.25))
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { dismiss() }

                card(for: position)
                    .frame(maxWidth: 420)
                    .padding(24)
            }
            .transition(.opacity.combined(with: .scale(scale: 0.96)))
        }
    }

    @ViewBuilder
    private func card(for position: LinePosition) -> some View {
        let continuations = graph.moves(from: position.id)
        // The close button is glass and sits on the card's glass surface; a
        // container lets the two blend instead of stacking glass-on-glass.
        GlassEffectContainer {
            VStack(alignment: .leading, spacing: 16) {
                header(for: position)

                ChessBoardView(fen: position.fen)
                    .frame(maxWidth: .infinity)

                masteryRow(for: position.mastery)

                learnRow(for: position)

                if !continuations.isEmpty {
                    Divider()
                    continuationList(continuations)
                }
            }
            .padding(20)
            .glassEffect(.regular, in: .rect(cornerRadius: 28))
        }
    }

    private func header(for position: LinePosition) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(position.label)
                    .font(.title2.weight(.semibold))
                HStack(spacing: 6) {
                    Text(position.sideToMove == .white ? "White to move" : "Black to move")
                    if position.isTransposition {
                        Text("· transposition")
                            .foregroundStyle(.tint)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.body.weight(.semibold))
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
        }
    }

    private func masteryRow(for mastery: Mastery) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(MasteryStyle.tint(for: mastery))
                .frame(width: 14, height: 14)
                .overlay(Circle().stroke(.white.opacity(0.5), lineWidth: 0.5))
            Text(MasteryStyle.summary(for: mastery))
                .font(.subheadline)
            Spacer()
        }
    }

    /// The Learn action: one tap puts the whole line down to this position into
    /// the repertoire (a card per unlearned White-to-move spot on the path).
    /// The full learning sheet replaces this minimal flow later.
    @ViewBuilder
    private func learnRow(for position: LinePosition) -> some View {
        if let onLearn {
            let navigator = RepertoireNavigator(graph: graph)
            let newCount = navigator.learnablePositions(to: position.id, learned: learnedIDs).count
            if newCount > 0 {
                Button {
                    withAnimation(.snappy) { onLearn(position.id) }
                } label: {
                    Label("Learn line to here", systemImage: "plus.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
            } else if learnedIDs.contains(position.id) || !navigator.isCardEligible(position.id) {
                Label(
                    learnedIDs.contains(position.id) ? "In your repertoire" : "Line learned to here",
                    systemImage: "checkmark.seal.fill"
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
        }
    }

    private func continuationList(_ moves: [LineMove]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Continuations")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            ForEach(moves) { move in
                Button {
                    withAnimation(.snappy) { selectedID = move.to }
                } label: {
                    HStack {
                        Circle()
                            .fill(MasteryStyle.reliabilityColor(move.reliability))
                            .frame(width: 9, height: 9)
                        Text(move.san)
                            .font(.body.monospaced())
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func dismiss() {
        withAnimation(.snappy) { selectedID = nil }
    }
}
