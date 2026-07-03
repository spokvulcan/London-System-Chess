# Reviews are per-position FSRS cards presented as line-walks

Spaced repetition needs a unit to schedule, and the obvious candidates conflict: the player must rehearse *whole lines* ("we learn the idea behind the moves, not one move"), but failures must be pinpointed to the exact spot in the line that is weak. We resolve this by splitting scheduling from presentation: **FSRS schedules one card per White-to-move position** (id = the position's EPD, so transpositions share a card), while **Daily presents every review as a line-walk** — a root→leaf traversal where the system auto-plays Black (steering toward the walk's target due card) and the player produces White's move at every prompt, each prompt graded individually. A wrong move therefore marks exactly one position weak and FSRS brings it back sooner, while the line's idea is always rehearsed in context. Grading is automatic (first-try correct → Good, one retry → Hard, failed retry → Again) with an optional transient "was shaky" demote — never Anki's four-button self-grade, which was explicitly rejected for flow reasons.

## Considered Options

- **One card per line (Chessable-style)** — matches how humans think about repertoires, but "line" isn't a first-class entity in the graph (transpositions make it a DAG of positions), and one flubbed move poisons the grade for the whole line, hiding *where* the weakness is.
- **One card per move (edge)** — finest grain, but with multiple acceptable repertoire moves per position it forces "recall specifically this move" when a sibling move is equally correct, contradicting the rule that any outbound graph move is a correct answer.
- **One card per position, walked as lines (chosen)** — per-position bookkeeping is the only grain that both localizes failure and survives transpositions; the line-level rehearsal the player needs is a *presentation* concern, recovered by walking due cards in context.

## Consequences

- The persisted schema (`ReviewCard` keyed by EPD) is grain-locked to positions; switching grains later means migrating scheduling state.
- A walk grades positions that aren't due yet (early reviews) — accepted, since correct answers are real evidence and FSRS handles early review timing.
- If the player answers with a correct move that leaves the target's path, the walk follows *their* line and the target simply stays due — target coverage is best-effort by Black-steering, never coerced by rewinding.
