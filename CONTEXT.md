# London System Chess

A training app for learning and practicing the London System chess opening. The app is organized into five permanent top-level sections, surfaced as a tab bar.

## Language

### Top-level sections

**Lines**:
The browsable reference of London System variations — a **graph** of positions a player studies, where transpositions converge to shared nodes (not a tree). (Formerly "Atlas".)
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

**Stats**:
The player's performance metrics tracked over time.
_Avoid_: Progress, History, Insights

**Me**:
The player's own profile and app settings.
_Avoid_: Profile, Account, Settings

## Flagged ambiguities

- **Lines** — unresolved whether it's read-only reference or an interactive board you drill moves on. (Structure resolved: it's a graph.)
- **Daily** — unresolved whether it's a single item or a multi-step session.
- **Spar** — unresolved whether it's full games or timed tactical positions.
