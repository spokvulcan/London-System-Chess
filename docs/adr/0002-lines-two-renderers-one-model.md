# Lines renders one data model through two interchangeable visualizations

The Lines tab needs to teach the London System effectively, and it is not yet known whether a **spatial graph-map** (zoomable layered DAG where transpositions merge into a shared node) or **depth columns** (Chessable-style ply columns where transpositions necessarily duplicate) is the better tool for learning and memorization. Rather than guess, we build **both renderers over a single shared data model and Mastery overlay**, switchable via a toolbar segmented toggle, so the comparison is honest — only the navigation varies, never the data. This shapes the prototype's architecture (the renderer is a swappable layer, not baked into the data) and is recorded because a future reader will reasonably wonder why two view trees exist over one model; the intent is an A/B experiment, and once a winner emerges it will likely replace the other.

## Considered Options

- **Spatial graph-map only** — best bird's-eye view of progress; merges transpositions truthfully (per ADR 0001); but layout at 60–100 nodes is hard and unproven for study.
- **Depth columns only** — most legible navigation; but structurally duplicates transposed positions, hiding the graph's nature.
- **Both over one model (chosen)** — costs building two renderers, but the only way to learn which actually teaches the opening better, and the shared model keeps the comparison fair.
