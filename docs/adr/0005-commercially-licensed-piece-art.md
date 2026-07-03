# Piece art must be commercially licensed, so the board ships Chessnut — not the prettier lichess sets

The board is the app's core learning surface, and the obvious source of beautiful piece art is the lichess piece library ([lila `public/piece/`](https://github.com/lichess-org/lila), licenses in its `COPYING.md`). But the app is assumed to be **commercially distributed** (App Store, possibly paid/monetized later), and lichess's best-looking modern sets — Staunty, Maestro, Fresca, Cardinal, Gioco, Caliente, Cooke, Monarchy — are all **CC BY-NC-SA 4.0 (non-commercial)**, while the classic defaults (Cburnett, Merida) are GPL-family, which is a poor fit for embedded App Store assets. Anyone later asking "why doesn't this app use the nice lichess pieces?" — this is why.

Within the commercially usable candidates (Apache/CC0/CC BY/MIT), **Chessnut by Alexis Luengas (Apache 2.0)** was chosen by visual comparison on the app's actual board palettes at full, card, and 26 px thumbnail sizes: it's a clean modern Staunton redraw, closest in spirit to the chess.com/lichess defaults, stays legible at thumbnail size, and its SVGs are pure paths/strokes (no gradients, filters, or masks), so they convert losslessly to the vector PDFs the asset catalog wants. Apache 2.0 requires shipping the license text (a `LICENSE` copy alongside the assets and/or an acknowledgements entry), but no in-UI credit.

The pieces are bundled as vector PDFs in the asset catalog, **namespaced by set** (`Chessnut/wK` … `Chessnut/bP`), so a second set — a commissioned custom set, or a CC BY set like Firi with its attribution line — can be added later without touching the board renderer.

The **black pieces are recolored from upstream** (a modification Apache 2.0 permits and asks us to state): body `#000` → `#0A0908`, detail lines `#f2f2f2` → `#D9D6D0`. Upstream's pure-white linework glowed against the green boards; warming and slightly dimming it keeps the set standing out next to the white pieces without the glare. (A first attempt at `#26241F`/`#A19E97` made the set read gray and dim — the body must stay essentially black.) White pieces are untouched.

## Considered Options

- **The pretty lichess NC sets (Staunty, Maestro, Fresca, …) (rejected)** — the best aesthetics available, but CC BY-NC-SA is incompatible with commercial distribution; shipping them would force an asset swap (and a visible re-skin) at exactly the moment the app tries to monetize.
- **Cburnett / Merida, the familiar defaults (rejected)** — listed under GPL-family licenses in lila's `COPYING.md`; embedding copyleft-licensed assets in a proprietary App Store binary is a legal gray zone not worth entering when permissive alternatives exist.
- **CC BY 4.0 sets (Firi, Kiwen-suwi, Totoy, Papercut) (viable, not chosen)** — commercially fine with attribution; Firi was the runner-up on looks. Chessnut won on visual neutrality plus the lighter Apache obligation.
- **Chessnut, Apache 2.0 (chosen)** — see above.
- **Commission a custom set (deferred)** — the only path to a truly ownable look; the set-namespaced asset layout keeps this open without rework.
