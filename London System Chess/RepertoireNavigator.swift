//
//  RepertoireNavigator.swift
//  London System Chess
//
//  Pure graph logic behind Learning and line-walks (CONTEXT.md): which positions
//  can carry a Card, the path a Learn tap covers, how Black's auto-played replies
//  steer a walk toward its target due card, and where a walk must stop (the edge
//  of learned territory). No persistence, no FSRS — operates on LinesGraph plus
//  a set of learned position ids, so every rule here is unit-testable.
//

import Foundation

struct RepertoireNavigator {
    let graph: LinesGraph

    private let positionsByID: [LinePosition.ID: LinePosition]
    private let movesFrom: [LinePosition.ID: [LineMove]]
    private let rootID: LinePosition.ID?

    init(graph: LinesGraph) {
        self.graph = graph
        self.positionsByID = graph.positionsByID
        self.movesFrom = Dictionary(grouping: graph.moves, by: \.from)
        self.rootID = graph.root?.id
    }

    // MARK: - Card eligibility

    /// A position can carry a Card iff it's White to move (the player's turn)
    /// and at least one repertoire move continues from it. White-to-move leaves
    /// have nothing to recall.
    func isCardEligible(_ id: LinePosition.ID) -> Bool {
        guard let position = positionsByID[id] else { return false }
        return position.sideToMove == .white && !(movesFrom[id] ?? []).isEmpty
    }

    // MARK: - Learning

    /// The positions a Learn tap covers: a shortest path from the start position
    /// to `targetID` (BFS, so transposed routes pick one arbitrary-but-stable
    /// representative — cards are per position, so the route choice is harmless).
    /// Empty when the target is unknown or unreachable.
    func learnPath(to targetID: LinePosition.ID) -> [LinePosition.ID] {
        guard let rootID, positionsByID[targetID] != nil else { return [] }
        if targetID == rootID { return [rootID] }
        var predecessor: [LinePosition.ID: LinePosition.ID] = [:]
        var queue: [LinePosition.ID] = [rootID]
        var visited: Set<LinePosition.ID> = [rootID]
        while !queue.isEmpty {
            let current = queue.removeFirst()
            for move in movesFrom[current] ?? [] where !visited.contains(move.to) {
                visited.insert(move.to)
                predecessor[move.to] = current
                if move.to == targetID {
                    var path = [targetID]
                    var node = targetID
                    while let prev = predecessor[node] {
                        path.append(prev)
                        node = prev
                    }
                    return path.reversed()
                }
                queue.append(move.to)
            }
        }
        return []
    }

    /// The card-eligible positions on the learn path that aren't learned yet —
    /// exactly the cards a Learn tap creates.
    func learnablePositions(
        to targetID: LinePosition.ID,
        learned: Set<LinePosition.ID>
    ) -> [LinePosition.ID] {
        learnPath(to: targetID).filter { isCardEligible($0) && !learned.contains($0) }
    }

    // MARK: - Walk stepping

    /// A walk prompts at a position iff the player has learned it (it carries a
    /// card) and a repertoire move continues from it. Anything else ends the walk.
    func isPromptable(_ id: LinePosition.ID, learned: Set<LinePosition.ID>) -> Bool {
        isCardEligible(id) && learned.contains(id)
    }

    /// The player's answer, matched against the position's outbound repertoire
    /// moves. Any graph move is correct (the graph *is* the repertoire); a pair
    /// of squares matching nothing is a wrong answer.
    func move(from id: LinePosition.ID, matching fromSquare: String, _ toSquare: String) -> LineMove? {
        (movesFrom[id] ?? []).first { $0.uci.hasPrefix(fromSquare + toSquare) }
    }

    /// Hop counts from every position that can reach `targetID`, for Black
    /// steering. Computed once per walk.
    func distances(to targetID: LinePosition.ID) -> [LinePosition.ID: Int] {
        guard positionsByID[targetID] != nil else { return [:] }
        var inbound: [LinePosition.ID: [LineMove]] = Dictionary(grouping: graph.moves, by: \.to)
        var dist: [LinePosition.ID: Int] = [targetID: 0]
        var queue: [LinePosition.ID] = [targetID]
        while !queue.isEmpty {
            let current = queue.removeFirst()
            for move in inbound[current] ?? [] where dist[move.from] == nil {
                dist[move.from] = dist[current]! + 1
                queue.append(move.from)
            }
        }
        inbound.removeAll()
        return dist
    }

    /// Black's auto-played reply. Candidates are replies landing on a learned,
    /// promptable position (walks never enter never-learned territory). Steering:
    /// prefer the reply that closes in on the target (via `distancesToTarget`);
    /// with no reachable target, prefer the deepest learned continuation so the
    /// walk rehearses as much line as possible. Returns nil when the walk ends.
    func blackReply(
        from id: LinePosition.ID,
        learned: Set<LinePosition.ID>,
        distancesToTarget: [LinePosition.ID: Int]?
    ) -> LineMove? {
        let candidates = (movesFrom[id] ?? []).filter { isPromptable($0.to, learned: learned) }
        guard !candidates.isEmpty else { return nil }
        if let dist = distancesToTarget {
            let onPath = candidates.compactMap { move in dist[move.to].map { (move, $0) } }
            if let best = onPath.min(by: { $0.1 < $1.1 }) {
                return best.0
            }
        }
        var memo: [LinePosition.ID: Int] = [:]
        return candidates.max { a, b in
            learnedDepth(from: a.to, learned: learned, memo: &memo)
                < learnedDepth(from: b.to, learned: learned, memo: &memo)
        }
    }

    /// The move to reveal after a failed retry: prefer the one steering toward
    /// the target so the walk can still reach it, else any repertoire move.
    func revealMove(
        from id: LinePosition.ID,
        distancesToTarget: [LinePosition.ID: Int]?
    ) -> LineMove? {
        let moves = movesFrom[id] ?? []
        if let dist = distancesToTarget {
            let onPath = moves.compactMap { move in dist[move.to].map { (move, $0) } }
            if let best = onPath.min(by: { $0.1 < $1.1 }) {
                return best.0
            }
        }
        return moves.first
    }

    /// Longest chain of learned prompts reachable from `id` (DAG, so plain memoized DFS).
    private func learnedDepth(
        from id: LinePosition.ID,
        learned: Set<LinePosition.ID>,
        memo: inout [LinePosition.ID: Int]
    ) -> Int {
        if let cached = memo[id] { return cached }
        var best = 0
        for move in movesFrom[id] ?? [] {
            let isStep = isPromptable(move.to, learned: learned) || positionsByID[move.to]?.sideToMove == .black
            guard isStep else { continue }
            // Only continue through learned White positions; a Black node is a
            // pass-through whose own children decide whether it extends the chain.
            if let position = positionsByID[move.to] {
                if position.sideToMove == .white, !learned.contains(move.to) { continue }
            }
            best = max(best, 1 + learnedDepth(from: move.to, learned: learned, memo: &memo))
        }
        memo[id] = best
        return best
    }

    // MARK: - Session composition

    /// Picks up to `limit` walk targets from the due cards, most overdue first.
    /// Each pick extends to the *deepest* due card whose root→target path passes
    /// through the overdue one — a single walk then prompts the whole due chain
    /// (right after Learning a line, every card on it is due at once; without
    /// this, each shallow card would spawn its own near-identical walk). Cards
    /// on an already-picked path are skipped (that walk prompts them anyway).
    func sessionTargets(
        dueIDs sortedDueIDs: [LinePosition.ID],
        limit: Int
    ) -> [LinePosition.ID] {
        let paths = Dictionary(uniqueKeysWithValues: sortedDueIDs.map { ($0, learnPath(to: $0)) })
        var targets: [LinePosition.ID] = []
        var covered: Set<LinePosition.ID> = []
        for id in sortedDueIDs where targets.count < limit {
            guard !covered.contains(id) else { continue }
            let target = sortedDueIDs
                .filter { paths[$0]?.contains(id) == true }
                .max { (paths[$0]?.count ?? 0) < (paths[$1]?.count ?? 0) } ?? id
            targets.append(target)
            covered.formUnion(paths[target] ?? [target])
        }
        return targets
    }
}
