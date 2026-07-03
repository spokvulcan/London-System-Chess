# London System Chess

A training app for learning and practicing the London System chess opening. The app is organized into five permanent top-level sections, surfaced as a tab bar.

## Language

### Top-level sections

**Lines**:
The browsable reference of London System variations — a **graph** of positions a player studies, where transpositions converge to shared nodes (not a tree). The graph is also the canvas for the player's progress *in context*: mastery, weak branches, and mistake-markers are painted directly onto the nodes and edges, answering "**where** am I weak?". (Formerly "Atlas".)
_Avoid_: Atlas, Openings, Library, Tree

**Transposition**:
Two different move orders that arrive at the same position. Because transpositions converge, distinct lines share nodes — which is why Lines is a graph rather than a tree.
_Avoid_: Move-order swap

**Daily**:
A day-scoped **review session** — a short batch of spaced-repetition reviews (~5 positions) that refreshes each day. Daily is where the player *retains* moves already learned; it does not teach new material. Driven by an FSRS scheduler.
_Avoid_: Today, Challenge, Quiz (a Daily is reviews, not a trivia quiz)

**Spar**:
Practice play against a non-human opponent (bot/engine) through London positions.
_Avoid_: Play, Practice, Match

**Trends** (formerly "Stats"):
Progress *over time and in aggregate*, driven by **real game history**. Pulls the player's actual games, analyzes them over time windows (week/month), and cross-references the player's **rating bracket** to surface which positions are statistically likely to occur — pointing outward at the meta-game so the player knows what is worth studying. Answers "**how** am I trending, and what's worth my attention?".
_Avoid_: Stats, Progress, History, Insights

**Me**:
The player's own profile and app settings.
_Avoid_: Profile, Account, Settings

### Training concepts

**Repertoire**:
The Lines graph itself. Every White move stored in the graph is an acceptable repertoire move — there is (currently) no canonical "mainline" per position, so when training asks "what do you play here?", *any* outbound graph move is a correct answer. A future curation pass may designate mainlines; until then correctness = membership in the graph.
_Avoid_: Mainline (implies a canonical move we don't have yet)

**Learning**:
First-time study of a spot, initiated from Lines: the player picks a position in the graph and studies it there (via the board sheet). Learning is what makes a spot eligible for Review — you can only be quizzed on what you've learned.
_Avoid_: Onboarding, Introduction

**Review**:
A spaced-repetition rep on a previously learned spot, always experienced as part of a **line-walk** — the player replays a whole line (opponent moves auto-play) and must produce their move at each of their turns. Scheduling and grading are per *position* (the Card), so a mistake pinpoints exactly which spot in the line is weak, while the line's idea is rehearsed whole. Scheduled by FSRS, consumed in Daily. Distinct from Learning (first exposure) the same way Reliability is distinct from Coverage.
_Avoid_: Test, Drill

**Line-walk**:
A single review item's shape: a traversal from the start position to a leaf. The system auto-plays Black's moves, steering toward the walk's target (a due Card); the player produces White's moves and is graded at every prompt, due or not. If the player plays a correct move that leaves the target's path, the walk follows *their* line — the missed target simply stays due. A leaf is a position with no learned continuation; walks never enter never-learned territory.
_Avoid_: Quiz run, Playthrough

**Card**:
The unit FSRS schedules: one card per White-to-move position in the repertoire (id = the position's EPD). Black-to-move positions never have cards — those moves belong to the opponent. A card is created when the position is first Learned.
_Avoid_: Flashcard, Question

### Progress concepts

**Mastery**:
The player's command of the repertoire, expressed as two independent axes — **Coverage** and **Reliability**. Painted onto the Lines graph (see Lines). Not a single number.

**Coverage**:
How much the player has studied/encountered a given spot — from never-seen to thoroughly drilled. Independent of whether they get it right.
_Avoid_: Progress (reserved sense), Completion

**Reliability**:
How correctly the player handles a spot when tested — do they play the repertoire move, or blunder. A spot with no reps yet has *no* reliability (unknown), which is distinct from low reliability (studied but error-prone).
_Avoid_: Accuracy, Score

## Flagged ambiguities

- **Lines** — unresolved whether it's read-only reference or an interactive board you drill moves on. (Structure resolved: it's a graph. Progress-overlay resolved: yes, mastery/mistakes are painted onto the graph; this is distinct from Trends.)
- **Daily** — resolved: a multi-step session (~5 reviews), spaced-repetition-driven (FSRS).
- **Spar** — unresolved whether it's full games or timed tactical positions.
