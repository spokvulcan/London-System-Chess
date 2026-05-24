# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project state

The UI is built with **SwiftUI using the iOS 26+ Liquid Glass API**. New and refactored UI should adopt Liquid Glass. See the `build-ios-apps:swiftui-liquid-glass` skill for implementation and review guidance.

## Build, run, and test

This is an Xcode project (no Swift Package Manager, no workspace). There is a single shared scheme, `London System Chess`, with three targets: the app, `London System ChessTests` (unit tests, **Swift Testing**), and `London System ChessUITests` (XCUITest).

Use the **XcodeBuildMCP** tools (the `build-ios-apps` plugin) for all build/run/test/debug cycles rather than invoking `xcodebuild` by hand:

- At session start, call `session_show_defaults` to confirm the active project, scheme, and simulator. If they're unset or wrong, use `discover_projs` / `list_schemes` / `list_sims` and `session_set_defaults`.
- Build and launch on a simulator with `build_run_sim` (usually with empty args once defaults are set); `build_sim` to compile only.
- Run tests with `test_sim`. Target a single test by passing its identifier (e.g. `London System ChessTests/London_System_ChessTests/example`); coverage via `get_coverage_report`.
- Inspect and drive the running app with the Computer Use and debug with the LLDB tools (`debug_attach_sim`, `debug_breakpoint_add`, `debug_stack`, …).

Only the simulator workflow is enabled by default; device/macOS/advanced workflows must be enabled in the XcodeBuildMCP config.

### Relevant skills

- `build-ios-apps:ios-debugger-agent` — build, run, launch, and drive the app on a simulator; inspect on-screen state and logs.
- `build-ios-apps:test-triage` is macOS-oriented; for iOS test runs use `test_sim` directly. `verify` and `run` (built-in) help confirm a change works in the real app.
- `build-ios-apps:swiftui-ui-patterns`, `swiftui-view-refactor`, `swiftui-liquid-glass`, `swiftui-performance-audit`, `ios-memgraph-leaks`, `ios-ettrace-performance`, `ios-app-intents` — feature-specific guidance.

## Conventions worth knowing

- **Universal iOS app** (`TARGETED_DEVICE_FAMILY = "1,2"`, iPhone + iPad), deployment target **iOS 26.5**, Swift 6.2 mode.
- Unit tests use the **Swift Testing** framework (`import Testing`, `@Test`, `#expect`), not XCTest. UI tests use XCTest.
- **SwiftData** is the persistence layer. The `ModelContainer` is created in `London_System_ChessApp.swift` and injected via `.modelContainer(...)`; views read data with `@Query` and write through `@Environment(\.modelContext)`. When adding models, register them in the `Schema` in `London_System_ChessApp`.
- Source type names are prefixed/underscored from the display name (e.g. `London_System_Chess`, bundle id `app.london-system.chess.London-System-Chess`).

## Agent skills

### Issue tracker

Issues and PRDs are tracked as GitHub issues via the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Triage labels

Five canonical triage roles using their default label names. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: `CONTEXT.md` + `docs/adr/` at the repo root. See `docs/agents/domain.md`.
