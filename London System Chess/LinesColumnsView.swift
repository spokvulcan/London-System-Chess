//
//  LinesColumnsView.swift
//  London System Chess
//
//  Renderer B — the depth columns (Miller-style, à la Chessable): a fixed board
//  panel beside a horizontally-scrolling stack of columns. Each column lists the
//  replies from the selected move in the column to its left; tapping a reply
//  reveals the next column and slides the line one ply deeper. Unlike the map,
//  transpositions necessarily DUPLICATE — the same position can surface in many
//  columns — so each duplicate is flagged with the merge glyph to stay honest
//  about it. Rows carry per-move (edge-level) reliability, the expanded level of
//  detail; the board panel shows the node aggregate for the deepest reply chosen.
//

import SwiftUI

struct LinesColumnsView: View {
    let graph: LinesGraph
    @Binding var selectedID: LinePosition.ID?
    let focusID: LinePosition.ID?
    /// Bumped by the toolbar Focus button — reveals the weak spot across the columns.
    let focusTick: Int

    /// The chosen reply at each depth (destination position ids). `path[k]` is the
    /// selection in column k; column k+1 lists the replies from it.
    @State private var path: [LinePosition.ID] = []
    @State private var pulseTargetID: LinePosition.ID?
    @State private var pulse = false

    @Environment(\.horizontalSizeClass) private var hSize

    private let byID: [LinePosition.ID: LinePosition]
    /// Outgoing edges keyed by source id, built once — the columns query replies
    /// from a position constantly (per column, per row), so a cached adjacency
    /// avoids re-scanning the whole move list on every render.
    private let movesFrom: [LinePosition.ID: [LineMove]]
    private let columnWidth: CGFloat = 212

    init(graph: LinesGraph, selectedID: Binding<LinePosition.ID?>, focusID: LinePosition.ID?, focusTick: Int) {
        self.graph = graph
        self._selectedID = selectedID
        self.focusID = focusID
        self.focusTick = focusTick
        self.byID = graph.positionsByID
        self.movesFrom = Dictionary(grouping: graph.moves, by: \.from)
    }

    /// Replies from a position, from the cached adjacency.
    private func replies(from id: LinePosition.ID) -> [LineMove] { movesFrom[id] ?? [] }

    var body: some View {
        Group {
            if hSize == .compact {
                VStack(spacing: 0) {
                    boardPanel.frame(maxHeight: 360)
                    Divider()
                    columnsScroller
                }
            } else {
                HStack(spacing: 0) {
                    boardPanel.frame(width: 340)
                    Divider()
                    columnsScroller
                }
            }
        }
        .onAppear {
            pulse = true
            if path.isEmpty, let focusID { reveal(focusID, pulsing: true) }
        }
        // The Focus button reveals the weak spot and pulses it.
        .onChange(of: focusTick) { _, _ in
            if let focusID { reveal(focusID, pulsing: true) }
        }
        // A deeper selection made elsewhere (e.g. a board-card continuation) is
        // revealed in the columns too, but without claiming the focus pulse.
        .onChange(of: selectedID) { _, newValue in
            if let id = newValue, byID[id] != nil { reveal(id, pulsing: false) }
        }
    }

    // MARK: Columns

    private struct ColumnData: Identifiable {
        let index: Int
        let parentID: LinePosition.ID
        let moves: [LineMove]
        let selectedDestination: LinePosition.ID?
        var id: Int { index }
    }

    /// Builds columns from the root down to one past the deepest selected reply.
    private var columns: [ColumnData] {
        guard let root = graph.root else { return [] }
        var result: [ColumnData] = []
        var parent = root.id
        var index = 0
        while true {
            let moves = sortedMoves(from: parent)
            if moves.isEmpty { break }
            let selected = index < path.count ? path[index] : nil
            result.append(ColumnData(index: index, parentID: parent, moves: moves, selectedDestination: selected))
            guard let sel = selected else { break }
            parent = sel
            index += 1
        }
        return result
    }

    private func sortedMoves(from id: LinePosition.ID) -> [LineMove] {
        replies(from: id).sorted { a, b in
            if a.coverage != b.coverage { return a.coverage > b.coverage }
            return a.san < b.san
        }
    }

    private var columnsScroller: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: true) {
                HStack(alignment: .top, spacing: 0) {
                    ForEach(columns) { column in
                        columnView(column)
                            .frame(width: columnWidth)
                            .id(column.index)
                        Divider()
                    }
                }
            }
            .onChange(of: path) { _, _ in
                withAnimation(.snappy) { proxy.scrollTo(columns.count - 1, anchor: .trailing) }
            }
        }
    }

    private func columnView(_ column: ColumnData) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(columnHeader(for: column))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            Divider()
            ScrollView {
                VStack(spacing: 4) {
                    ForEach(column.moves) { move in
                        moveRow(move, in: column)
                    }
                }
                .padding(8)
            }
        }
    }

    private func columnHeader(for column: ColumnData) -> String {
        // The replies in this column are played by whoever is to move at the parent.
        guard let parent = byID[column.parentID] else { return "Replies" }
        let moveNumber = parent.ply / 2 + 1
        return parent.sideToMove == .white ? "White · move \(moveNumber)" : "Black · move \(moveNumber)"
    }

    private func moveRow(_ move: LineMove, in column: ColumnData) -> some View {
        let destination = byID[move.to]
        let isSelected = column.selectedDestination == move.to
        let isFocus = move.to == pulseTargetID
        let hasReplies = !replies(from: move.to).isEmpty
        return Button {
            select(move, atColumn: column.index)
        } label: {
            HStack(spacing: 8) {
                // Per-move (edge) reliability as the leading signal.
                Circle()
                    .fill(MasteryStyle.reliabilityColor(move.reliability))
                    .frame(width: 10, height: 10)
                    .overlay(Circle().stroke(.white.opacity(0.4), lineWidth: 0.5))
                Text(move.san)
                    .font(.body.monospaced())
                    .foregroundStyle(.primary)
                if destination?.isTransposition == true {
                    Image(systemName: "arrow.triangle.merge")
                        .font(.caption2)
                        .foregroundStyle(.tint)
                }
                Spacer(minLength: 4)
                if hasReplies {
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(isSelected ? .primary : .tertiary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                // Coverage of the destination tints the row body; selection lifts it.
                RoundedRectangle(cornerRadius: 10)
                    .fill(MasteryStyle.tint(for: destination?.mastery ?? .unseen).opacity(isSelected ? 0.9 : 0.45))
            }
            .overlay {
                // Never-studied replies get a dashed grey "frontier" border (matching
                // the map), unless focus or selection claims a stronger stroke.
                let isUnseen = destination?.mastery.isUnseen ?? true
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        isFocus ? MasteryStyle.focusAccent
                            : (isSelected ? Color.primary.opacity(0.6)
                               : (isUnseen ? Color.secondary.opacity(0.5) : .clear)),
                        style: StrokeStyle(
                            lineWidth: isFocus ? 2.5 : 1.5,
                            dash: (isUnseen && !isFocus && !isSelected) ? [3, 3] : []
                        )
                    )
                    .scaleEffect(isFocus && pulse ? 1.03 : 1)
                    .opacity(isFocus && pulse ? 0.6 : 1)
                    .animation(isFocus ? .easeInOut(duration: 1).repeatForever(autoreverses: true) : .default, value: pulse)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(rowAccessibilityLabel(move, destination: destination, isFocus: isFocus))
        .accessibilityIdentifier("col-\(column.index)-\(move.san)")
    }

    private func rowAccessibilityLabel(_ move: LineMove, destination: LinePosition?, isFocus: Bool) -> String {
        var parts = [move.san]
        if let mastery = destination?.mastery { parts.append(MasteryStyle.summary(for: mastery)) }
        if destination?.isTransposition == true { parts.append("transposition") }
        if isFocus { parts.append("suggested focus") }
        return parts.joined(separator: ", ")
    }

    private func select(_ move: LineMove, atColumn index: Int) {
        pulseTargetID = nil
        withAnimation(.snappy) {
            path = Array(path.prefix(index)) + [move.to]
        }
    }

    // MARK: Board panel

    private var deepestID: LinePosition.ID? { path.last ?? graph.root?.id }

    @ViewBuilder
    private var boardPanel: some View {
        if let id = deepestID, let position = byID[id] {
            VStack(alignment: .leading, spacing: 14) {
                breadcrumb
                ChessBoardView(fen: position.fen)
                    .frame(maxWidth: .infinity)
                    // Tapping the board opens the richer shared card (continuations, etc.).
                    .onTapGesture { withAnimation(.snappy) { selectedID = id } }
                positionSummary(position)
                Spacer(minLength: 0)
            }
            .padding(18)
        } else {
            ContentUnavailableView("No lines", systemImage: "square.stack.3d.up.slash")
        }
    }

    /// The line played so far, as SAN — the column equivalent of the map's path.
    private var lineSANs: [String] {
        guard let root = graph.root else { return [] }
        var sans: [String] = []
        var parent = root.id
        for dest in path {
            if let mv = replies(from: parent).first(where: { $0.to == dest }) {
                sans.append(mv.san)
            }
            parent = dest
        }
        return sans
    }

    private var breadcrumb: some View {
        Text(lineSANs.isEmpty ? "Starting position" : lineSANs.joined(separator: " "))
            .font(.callout.monospaced())
            .foregroundStyle(.secondary)
            .lineLimit(2)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func positionSummary(_ position: LinePosition) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(position.label)
                    .font(.title3.weight(.semibold))
                if position.isTransposition {
                    Image(systemName: "arrow.triangle.merge")
                        .foregroundStyle(.tint)
                }
            }
            HStack(spacing: 10) {
                Circle()
                    .fill(MasteryStyle.tint(for: position.mastery))
                    .frame(width: 13, height: 13)
                    .overlay(Circle().stroke(.white.opacity(0.5), lineWidth: 0.5))
                Text(MasteryStyle.summary(for: position.mastery))
                    .font(.subheadline)
            }
            Text(position.sideToMove == .white ? "White to move" : "Black to move")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: Navigation

    /// Sets the column path so `target` is revealed and flags it for a pulse.
    private func reveal(_ target: LinePosition.ID, pulsing: Bool) {
        guard let newPath = path(to: target) else { return }
        withAnimation(.snappy) { path = newPath }
        pulseTargetID = pulsing ? target : nil
    }

    /// BFS shortest sequence of destination ids from the root to `target`
    /// (excluding the root). `nil` if unreachable; `[]` if target is the root.
    private func path(to target: LinePosition.ID) -> [LinePosition.ID]? {
        guard let root = graph.root else { return nil }
        if target == root.id { return [] }
        var queue: [[LinePosition.ID]] = [[root.id]]
        var seen: Set<LinePosition.ID> = [root.id]
        while !queue.isEmpty {
            let trail = queue.removeFirst()
            guard let last = trail.last else { continue }
            for move in replies(from: last) {
                if move.to == target { return Array((trail + [move.to]).dropFirst()) }
                if seen.insert(move.to).inserted { queue.append(trail + [move.to]) }
            }
        }
        return nil
    }
}
