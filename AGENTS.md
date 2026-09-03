# Repository Guidelines

## Project Structure & Module Organization

This repository is a small macOS SwiftUI/AppKit launcher. Production code lives in `Lightsearch/`:

- `LightsearchApp.swift` configures the menu-bar application and tray behavior.
- `LauncherController.swift` owns the `NSPanel`, keyboard monitoring, sizing, and app/file launching.
- `ApplicationSearch.swift` is the core application catalog, ranking, launch history, and app scanner.
- `LauncherState.swift` owns core query/selection state and delegates optional work to the feature registry.
- `LauncherResult.swift` contains the shared result/page boundary used by the core and extensions.
- `LauncherFeatures.swift` is the only feature registry; its short enabled-feature list is the removal point for optional features.
- `CalculatorFeature.swift` adapts calculator, date/time, and time-zone behavior; `CalculatorExpression.swift`, `Conversion.swift`, `TimeZoneResolver.swift`, and `ConversionUnits*.swift` are its implementation files.
- `ContentView.swift` contains the launcher UI and reusable result-row views.
- `FileSearch.swift` contains the optional Spotlight file-search feature and recent-file persistence.
- `SystemPreferences.swift` contains the optional Apple Settings discovery, search, and URL feature.
- `LightsearchTests/CalculatorExpressionTests.swift` contains the calculator parser and `ConversionEngine` regression suite.
- `Assets.xcassets/` contains the app icon and color assets.

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

After a significant change passes validation, merge its branch back into `main`, remove the temporary branch when it is no longer needed, and leave `main` checked out with a clean worktree. Trivial changes made directly on `main` should also finish clean.

## Testing Guidelines

Run the Debug build and XCTest commands above. Calculator changes must keep the expression tests green; add table-driven cases for every new operator/function and invalid domain or overflow case. Also manually check the menu-bar item, keyboard navigation, panel resizing, app launching, file search, and dismissal behavior. For UI changes, include a screenshot or a concise manual reproduction in the pull request.

## Commit & Pull Request Guidelines

Git history currently contains only `Initial Commit`, so no established message convention is available. Use short imperative subjects, for example `Fix keyboard selection wrapping`. Pull requests should describe the behavior change, list validation commands, note signing or permission requirements, and include screenshots for visible UI changes.

## macOS Configuration Notes

The target uses automatic signing, App Sandbox, and `LSUIElement` for a menu-bar-only app. Preserve the existing bundle identifier and entitlements unless a task explicitly requires changing them.
