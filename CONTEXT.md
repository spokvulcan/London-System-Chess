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
A day-scoped training item that refreshes each day.
_Avoid_: Today, Challenge

**Spar**:
Practice play against a non-human opponent (bot/engine) through London positions.
_Avoid_: Play, Practice, Match

**Trends** (formerly "Stats"):
Progress *over time and in aggregate*, driven by **real game history**. Pulls the player's actual games, analyzes them over time windows (week/month), and cross-references the player's **rating bracket** to surface which positions are statistically likely to occur — pointing outward at the meta-game so the player knows what is worth studying. Answers "**how** am I trending, and what's worth my attention?".
_Avoid_: Stats, Progress, History, Insights

**Me**:
The player's own profile and app settings.
_Avoid_: Profile, Account, Settings

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
- **Daily** — unresolved whether it's a single item or a multi-step session.
- **Spar** — unresolved whether it's full games or timed tactical positions.
