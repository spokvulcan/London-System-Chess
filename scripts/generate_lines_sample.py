#!/usr/bin/env python3
"""Generate LinesSampleData.swift — the shared mock London repertoire.

Authoring tool, not shipped. Walks real London System lines through python-chess
so every FEN is legal, and merges positions by EPD (placement + side + castling +
en passant) so transpositions converge to a single shared node — the graph model
of ADR 0001. Mock Coverage/Reliability is assigned deterministically (seeded by
position) so regeneration is stable.

Run:  .lines-authoring-venv/bin/python scripts/generate_lines_sample.py
"""

import hashlib
import random
from pathlib import Path

import chess

# --- The repertoire ----------------------------------------------------------
# A White London (1.d4 / 2.Bf4) repertoire as SAN lines from the start position.
# Lines deliberately overlap so move orders transpose; the EPD merge turns those
# overlaps into shared nodes. Comments mark the intended transposition families.
LINES = [
    # Classical 1.d4 d5 2.Bf4 main line and the bishop challenge with ...Bd6.
    "d4 d5 Bf4 Nf6 e3 e6 Nf3 Bd6 Bg3 O-O Bd3 c5 c3 Nc6 Nbd2",
    "d4 d5 Bf4 Nf6 e3 e6 Nf3 Bd6 Bg3 Bxg3 hxg3 c5 c3 Nc6 Nbd2",
    "d4 d5 Bf4 Nf6 e3 e6 Nf3 c5 c3 Nc6 Nbd2 Bd6 Bg3 O-O Bd3",
    # ...c5 with the critical ...Qb6 hit on b2 (the prepared focus weakness).
    "d4 d5 Bf4 Nf6 e3 c5 c3 Nc6 Nd2 Qb6 Qb3",
    "d4 d5 Bf4 Nf6 e3 c5 c3 Qb6 Qb3 c4 Qc2",
    "d4 d5 Bf4 c5 e3 Nc6 Nf3 Nf6 c3 e6",          # T2 family
    # T2: 2...c5 3.e3 e6  ==  2...e6 3.e3 c5  (same position after d4 d5 Bf4 + e3,c5,e6)
    "d4 d5 Bf4 c5 e3 e6 Nf3 Nc6 c3 Bd6 Bg3",
    "d4 d5 Bf4 e6 e3 c5 Nf3 Nc6 c3 Bd6 Bg3",
    # Early ...Bf5 and ...g6 sidelines.
    "d4 d5 Bf4 Bf5 e3 e6 Nf3 Nf6 Bd3 Bxd3 Qxd3",
    "d4 d5 Bf4 g6 Nc3 Bg7 Qd2 Nf6 O-O-O",
    "d4 d5 Bf4 a6 e3 Nf6 Nf3 e6 Bd3 c5 c3",
    # 1.d4 Nf6 (Indian) — these are where the big transpositions live.
    # T1: d4 d5 Bf4 Nf6  ==  d4 Nf6 Bf4 d5
    "d4 Nf6 Bf4 d5 e3 e6 Nf3 Bd6 Bg3 O-O Bd3",     # T1 -> rejoins line 1's path
    # T3: d4 Nf6 Bf4 e6 e3 d5  ==  d4 d5 Bf4 Nf6 e3 e6
    "d4 Nf6 Bf4 e6 e3 d5 Nf3 Bd6 Bg3 Bxg3 hxg3",
    "d4 Nf6 Bf4 e6 e3 c5 c3 d5 Nf3 Nc6 Nbd2",      # ...c5 then ...d5 transposes in
    # King's-Indian-style London setups vs ...g6.
    "d4 Nf6 Bf4 g6 e3 Bg7 Nf3 O-O Be2 d6 h3 Nbd7 O-O",
    "d4 Nf6 Bf4 g6 e3 Bg7 Nf3 d6 h3 O-O Be2",
    # ...c5 Benoni-ish try met by d5.
    "d4 Nf6 Bf4 c5 d5 b5 e4 d6 Nc3",
    "d4 Nf6 Bf4 c5 e3 cxd4 exd4 d5 Nf3 Nc6 c3",
    # ...d6 Old-Indian setup.
    "d4 Nf6 Bf4 d6 e3 Nbd7 Nf3 g6 h3 Bg7 Be2 O-O",
    # 1.d4 with ...e6 / ...c5 move orders that fold back into the main lines.
    "d4 e6 Bf4 d5 e3 Nf6 Nf3 Bd6 Bg3 O-O Bd3",     # transposes to the main line
    "d4 e6 Bf4 Nf6 e3 d5 Nf3 c5 c3 Nc6 Nbd2",
    "d4 c5 Bf4 cxd4 Bxb8 Rxb8 Qxd4 Nf6 Nc3",       # a sharp pawn-grab sideline
]

# --- Walk the lines, merging by position identity ----------------------------
EPD_FIELDS = 4  # placement, side to move, castling, en passant


def epd_key(board: chess.Board) -> str:
    return " ".join(board.fen().split(" ")[:EPD_FIELDS])


# position id -> dict(node fields); order of discovery preserved for stable output.
nodes: dict[str, dict] = {}
# (from_id, san, to_id) -> dict(edge fields)
edges: dict[tuple, dict] = {}
# count of *distinct* parents reaching a node, to flag transpositions.
parents: dict[str, set] = {}


def ensure_node(board: chess.Board, ply: int, san: str | None, side: str | None):
    key = epd_key(board)
    if key not in nodes:
        if san is None:
            label = "Start"
        else:
            move_no = ply // 2 + (1 if ply % 2 else 0)
            move_no = (ply - 1) // 2 + 1
            label = f"{move_no}.{san}" if side == "white" else f"{move_no}...{san}"
        nodes[key] = {
            "id": key,
            "fen": board.fen(),
            "ply": ply,
            "side_to_move": "white" if board.turn == chess.WHITE else "black",
            "label": label,
            "san": san,
        }
        parents[key] = set()
    return key


for line in LINES:
    board = chess.Board()
    prev_key = ensure_node(board, 0, None, None)
    ply = 0
    for token in line.split():
        mover = "white" if board.turn == chess.WHITE else "black"
        board.push_san(token)  # raises on an illegal/typo move — our correctness gate
        ply += 1
        cur_key = ensure_node(board, ply, token, mover)
        parents[cur_key].add(prev_key)
        edges.setdefault(
            (prev_key, token, cur_key),
            {"from": prev_key, "to": cur_key, "san": token, "side": mover},
        )
        prev_key = cur_key

for key, ps in parents.items():
    nodes[key]["is_transposition"] = len(ps) > 1

# --- Deterministic mock Coverage / Reliability -------------------------------
# Believable distribution: shallow main-line spots are well known; depth erodes
# coverage; deep/offbeat branches go unseen; one well-studied spot is left weak
# to anchor the focus affordance.


def seeded(key: str) -> random.Random:
    return random.Random(int(hashlib.sha1(key.encode()).hexdigest(), 16))


def mock_mastery(node: dict) -> tuple[float, float | None]:
    ply = node["ply"]
    r = seeded(node["id"])
    if ply == 0:
        return 1.0, 1.0
    if ply <= 2:
        return round(r.uniform(0.85, 1.0), 2), round(r.uniform(0.8, 1.0), 2)
    if ply <= 4:
        cov = round(r.uniform(0.55, 0.9), 2)
        rel = round(r.uniform(0.45, 0.95), 2)
        return cov, rel
    if ply <= 6:
        if r.random() < 0.25:
            return 0.0, None  # some mid-depth spots never reached
        cov = round(r.uniform(0.25, 0.7), 2)
        rel = round(r.uniform(0.35, 0.9), 2)
        return cov, rel
    # ply 7+ : mostly unseen, a few lightly studied
    if r.random() < 0.6:
        return 0.0, None
    return round(r.uniform(0.1, 0.45), 2), round(r.uniform(0.4, 0.85), 2)


for node in nodes.values():
    cov, rel = mock_mastery(node)
    # Keep covered reliabilities clear of the focus spot's value so the focus is unique.
    if cov >= 0.5 and rel is not None:
        rel = max(rel, 0.3)
    node["coverage"], node["reliability"] = cov, rel

# Anchor the focus affordance on the ...Qb6 hit (well studied, error-prone).
focus_key = next(
    (k for k, n in nodes.items() if n["san"] == "Qb6"),
    None,
)
if focus_key:
    nodes[focus_key]["coverage"] = 0.85
    nodes[focus_key]["reliability"] = 0.16  # uniquely lowest among covered -> the focus

# Edge mastery mirrors its destination node (node aggregate vs. per-move detail
# stay consistent), with light deterministic jitter on the reliability.
for edge in edges.values():
    dst = nodes[edge["to"]]
    edge["coverage"] = dst["coverage"]
    if dst["reliability"] is None:
        edge["reliability"] = None
    else:
        jr = seeded(edge["from"] + edge["san"] + edge["to"])
        edge["reliability"] = round(
            min(1.0, max(0.0, dst["reliability"] + jr.uniform(-0.08, 0.08))), 2
        )

# --- Emit Swift --------------------------------------------------------------
def swift_str(s: str) -> str:
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def swift_opt_double(v) -> str:
    return "nil" if v is None else f"{v:.2f}"


def mastery_init(cov, rel) -> str:
    return f"Mastery(coverage: {cov:.2f}, reliability: {swift_opt_double(rel)})"


node_lines = []
for n in sorted(nodes.values(), key=lambda x: (x["ply"], x["label"])):
    san = "nil" if n["san"] is None else swift_str(n["san"])
    node_lines.append(
        "        LinePosition("
        f"id: {swift_str(n['id'])}, "
        f"fen: {swift_str(n['fen'])}, "
        f"ply: {n['ply']}, "
        f"sideToMove: .{n['side_to_move']}, "
        f"label: {swift_str(n['label'])}, "
        f"san: {san}, "
        f"isTransposition: {str(n['is_transposition']).lower()}, "
        f"mastery: {mastery_init(n['coverage'], n['reliability'])}),"
    )

edge_lines = []
for e in sorted(edges.values(), key=lambda x: (nodes[x["from"]]["ply"], x["san"])):
    edge_lines.append(
        "        LineMove("
        f"from: {swift_str(e['from'])}, "
        f"to: {swift_str(e['to'])}, "
        f"san: {swift_str(e['san'])}, "
        f"side: .{e['side']}, "
        f"reliability: {swift_opt_double(e['reliability'])}, "
        f"coverage: {e['coverage']:.2f}),"
    )

transposition_count = sum(1 for n in nodes.values() if n["is_transposition"])
header = f"""//
//  LinesSampleData.swift
//  London System Chess
//
//  GENERATED by scripts/generate_lines_sample.py — do not edit by hand.
//  A hand-authored slice of real London System theory, walked through
//  python-chess so every FEN is legal and transpositions merge into shared
//  nodes (ADR 0001). Mock Coverage/Reliability is for visualizing progress only.
//
//  Positions: {len(nodes)}   Moves: {len(edges)}   Transpositions: {transposition_count}   Max ply: {max(n['ply'] for n in nodes.values())}
//

import Foundation

extension LinesGraph {{
    /// Shared sample repertoire consumed by both Lines renderers (ADR 0002).
    static let sample = LinesGraph(
        positions: [
{chr(10).join(node_lines)}
        ],
        moves: [
{chr(10).join(edge_lines)}
        ]
    )
}}
"""

out = Path(__file__).resolve().parent.parent / "London System Chess" / "LinesSampleData.swift"
out.write_text(header)

# --- Console summary ---------------------------------------------------------
covered = [n for n in nodes.values() if n["coverage"] > 0]
unseen = [n for n in nodes.values() if n["coverage"] == 0]
print(f"Wrote {out}")
print(f"  positions:      {len(nodes)}")
print(f"  moves:          {len(edges)}")
print(f"  transpositions: {transposition_count}  {[nodes[k]['label'] for k,n in nodes.items() if n['is_transposition']]}")
print(f"  max ply:        {max(n['ply'] for n in nodes.values())}")
print(f"  covered/unseen: {len(covered)}/{len(unseen)}")
if focus_key:
    fn = nodes[focus_key]
    print(f"  focus spot:     {fn['label']}  cov={fn['coverage']} rel={fn['reliability']}")
