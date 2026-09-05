# Repository Guidelines

## Project Structure & Module Organization

This repository is a macOS SwiftUI/AppKit launcher organized into a clean `Sources/` and `Tests/` hierarchy:

- `Sources/App/`:
  - `LightsearchApp.swift` configures the menu-bar application, lifecycle, and tray behavior.
- `Sources/Core/`:
  - `Launcher/`:
    - `LauncherController.swift` owns the `NSPanel`, keyboard monitoring, sizing, and app/file launching.
    - `LauncherState.swift` owns core query/selection state and delegates optional work to the feature registry.
    - `LauncherResult.swift` contains the shared result/page boundary used by the core and extensions.
    - `LauncherFeatures.swift` is the only feature registry; its short enabled-feature list is the removal point for optional features.
  - `ApplicationSearch/`:
    - `ApplicationSearch.swift` is the core application catalog, ranking, launch history, and app scanner.
- `Sources/Features/`:
  - `Calculator/`: `CalculatorFeature.swift` adapts calculator, date/time, and time-zone behavior; `CalculatorExpression.swift`, `Conversion.swift`, `TimeZoneResolver.swift`, and `ConversionUnits*.swift` are its implementation files.
  - `FileSearch/`: `FileSearch.swift` contains the Spotlight file-search feature and recent-file persistence.
  - `SystemPreferences/`: `SystemPreferences.swift` contains the Apple Settings discovery, search, and URL feature.
- `Sources/UI/`:
  - `ContentView.swift` contains the launcher UI and reusable result-row views.
- `Sources/Resources/`:
  - `Assets.xcassets/` contains the app icon and color assets.
- `Tests/Core/`:
  - `PerformanceBenchmarkTests.swift` contains the throughput and memory benchmark regression suite.
- `Tests/Features/Calculator/`:
  - `CalculatorExpressionTests.swift` contains the calculator parser and `ConversionEngine` regression suite.
  - `TimeZoneDateTimeTests.swift` contains regression tests for time zone resolution, country labels, and date & time calculations.
- `Tests/Features/SystemPreferences/`:
  - `SystemPreferencesTests.swift` contains the scanner benchmark and search ranking regression suite for System Settings.
- `docs/`:
  - `BENCHMARKS.md` contains historical benchmark records, reproduction commands, and memory profiles.
  - Audit and technical specification reports.

The Xcode project is `Lightsearch.xcodeproj`, with the `LightsearchTests` XCTest target.

## Build, Test, and Development Commands

Run these from the repository root:

```sh
xcodebuild -project Lightsearch.xcodeproj -scheme Lightsearch -configuration Debug build
xcodebuild -project Lightsearch.xcodeproj -scheme Lightsearch -configuration Debug test
git diff --check
```

The first command compiles the app; the second runs the XCTest target, including the calculator correctness suite. Run `./relaunch.sh` only after changes that touch Swift/source code and require the rebuilt app to be refreshed; Markdown-only documentation edits do not require a relaunch. The script builds the configured Release product, quits any running Lightsearch instance, and launches the rebuilt app. It uses the default automatic code-signing configuration. `git diff --check` catches whitespace errors.

## Optional Feature Architecture

Application search is the product core. Calculator, file search, and System Settings are `LauncherSearchFeature` implementations registered in `LauncherFeatures.swift`. Each feature owns its parser/scanner, loading, cancellation, and result ranking. To disable one, remove its line from `enabledFeatures`; remove its source files only after the corresponding UI/result case is no longer needed. Keep core application ranking independent of optional features.

## Coding Style & Naming Conventions

Use four-space indentation, standard Swift formatting, and concise comments only for non-obvious AppKit or concurrency behavior. Types and protocols use `UpperCamelCase`; properties, methods, and local values use `lowerCamelCase`. Keep UI state on `@MainActor`, prefer SwiftUI composition for presentation, and keep panel/event logic in `LauncherController`. Use stable IDs for `ForEach` rows and avoid force unwraps/casts.

## Implementation Priorities

Prioritize the fastest practical implementation and reliable behavior over visual polish. Prefer native platform APIs and local, direct operations; avoid unnecessary work, allocations, I/O, network requests, view layers, and recomputation. Choose the simplest design that satisfies the requirement: do not add speculative abstractions, dependencies, state, or components unless they solve real complexity. Keep code easy to read and maintain, and make each feature behave exactly as its name and description promise.

## Branching & Change Scope

Treat documentation edits, typo fixes, and isolated low-risk changes as trivial; they may remain on the current branch or `main`. Treat new features, refactors, UI overhauls, performance or concurrency work, and build, signing, or dependency changes as significant; do them on a separate `codex/<short-description>` branch so `main` remains unaffected if something breaks. If the worktree already contains uncommitted changes, inspect and preserve them before switching branches or creating a branch; never stash, discard, or move them without explicit direction. When uncertain, classify the change as significant.

**CRITICAL MERGE RULE**: NEVER merge any branch back into `main` until the user explicitly gives the green light to do so. Keep all work on the feature/fix branch and present the results to the user first. Only perform the merge to `main` once the user explicitly instructs you to merge.

## Testing Guidelines

Run the Debug build and XCTest commands above when modifying core logic, state management, parsers, or scanners. Calculator changes must keep the expression tests green; add table-driven cases for every new operator/function and invalid domain or overflow case.

**COSMETIC CHANGES**: For purely cosmetic, visual UI styling, or layout margin/padding tweaks, there is NO NEED to run the test suite. Only compile/build to ensure syntax correctness. Also manually check the menu-bar item, keyboard navigation, panel resizing, app launching, file search, and dismissal behavior where applicable.

## Commit & Pull Request Guidelines

Git history currently contains only `Initial Commit`, so no established message convention is available. Use short imperative subjects, for example `Fix keyboard selection wrapping`. Pull requests should describe the behavior change, list validation commands, note signing or permission requirements, and include screenshots for visible UI changes.

## macOS Configuration Notes

The target uses automatic signing, App Sandbox, and `LSUIElement` for a menu-bar-only app. Preserve the existing bundle identifier and entitlements unless a task explicitly requires changing them.
