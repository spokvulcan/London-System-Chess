# A navigation bar earns its Liquid Glass from a scroll view underneath it, never from a forced material

In iOS 26, a `NavigationStack`'s top bar is Liquid Glass automatically, but the frosted "glass" you see (the soft, translucent gradient on the Trends list) is the **scroll-edge effect**: the system frosting a *scroll view's* content as it underlaps the bar. With no scroll view beneath it, the bar stays fully clear — which is exactly why the Lines tab's bar looked empty while Trends (a `List`) looked right. The fix that *looks* correct but is wrong is to paint the bar yourself with `.toolbarBackground(.ultraThinMaterial, for: .navigationBar)` (optionally pinned via `.toolbarBackgroundVisibility(.visible, …)`): that renders the **legacy, pre-iOS-26 flat material bar**, not Liquid Glass, and is immediately recognizable as "the old look." So the rule for this codebase: **never force a `.toolbarBackground` material to fake glass; give the bar a scroll view to frost instead.**

The Lines **map** is a custom pan/zoom canvas (`GeometryReader` + `DragGesture`/`MagnifyGesture`), not a scroll view, so it got no glass for free. We host it in a non-scrolling scroll view purely as the surface the glass reads from — the canvas keeps its own gestures untouched:

```swift
ScrollView([.horizontal, .vertical]) {
    LinesMapView(…)
        .containerRelativeFrame([.horizontal, .vertical])  // fills the viewport: no actual scrolling
}
.scrollDisabled(true)                          // the map pans itself; the scroll view never scrolls
.scrollEdgeEffectStyle(.soft, for: .top)       // .soft = the diffused Trends-style gradient (.hard = sharp divider line)
.ignoresSafeArea(.container, edges: .top)      // canvas underlaps the bar so there's content to frost
```

As the map pans, nodes/edges dissolve into the soft glass under the bar — the genuine effect, verified on the simulator (iPhone 17 Pro, iOS 26.5). The Lines **columns** renderer deliberately keeps its breadcrumb/board header *below* the bar (not underlapping), so its bar reads clear — the same as the Trends list scrolled to the top, and intentional per the "header shouldn't slide under the glass" choice in [ADR 0002](0002-lines-two-renderers-one-model.md).

## Considered Options

- **Force `.toolbarBackground(.ultraThinMaterial)` + `.toolbarBackgroundVisibility(.visible)` (rejected)** — does produce a visible band (a `Color.red` probe confirmed the bar region renders), but it's the legacy flat material, not Liquid Glass; it has a hard bottom edge instead of the soft gradient and reads as pre-iOS-26 chrome.
- **Leave the bar clear, Maps-style (rejected)** — legitimate iOS 26 idiom for an immersive canvas, but not the look this app wants; the brief was explicitly "match the Trends bar."
- **Wrap the canvas in a `.scrollDisabled` scroll view + `.scrollEdgeEffectStyle(.soft)` (chosen)** — the only option that yields the *native* glass without re-architecting the map's pan/zoom onto a real `UIScrollView`. The scroll view exists solely to give the system content to frost.
