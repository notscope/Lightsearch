# Repository instructions

## Scope

Lightsearch is a macOS SwiftUI/AppKit menu-bar launcher. The project targets macOS 26 and uses Swift 5.0. The Xcode project is `Lightsearch.xcodeproj`; the test target is `LightsearchTests`.

Keep changes focused and preserve unrelated user work. Do not add credentials, API keys, private keys, or other secrets to source, tests, documentation, or project settings.

## Layout

- `Sources/App/` — application lifecycle and menu-bar integration
- `Sources/Core/` — application catalog, launcher panel/state, results, and query parsing
- `Sources/Features/` — calculator, clipboard, color picker, file search, and System Settings features
- `Sources/UI/` — SwiftUI/AppKit presentation
- `Tests/` — XCTest coverage and performance benchmarks
- `docs/` — benchmark and technical notes

Application search is the core. Optional features conform to `LauncherSearchFeature` and are registered in `Sources/Core/Launcher/LauncherFeatures.swift`. Keep feature-specific parsing, loading, cancellation, and ranking out of core launcher state. If removing a feature, remove its registry entry first and update any corresponding UI/result cases before deleting files.

## Implementation

- Use four-space indentation and standard Swift naming.
- Keep UI state on `@MainActor`.
- Keep panel and event logic in `LauncherController`.
- Prefer SwiftUI composition for presentation and native macOS APIs for platform behavior.
- Use stable IDs for `ForEach` rows; avoid force unwraps and force casts.
- Prefer simple, direct implementations. Avoid unnecessary dependencies, allocations, I/O, network requests, state, or abstractions.
- Keep behavior local and predictable.

## Build and test

Run these from the repository root when changing Swift code, state management, parsers, scanners, persistence, or other core behavior:

```sh
xcodebuild -project Lightsearch.xcodeproj -scheme Lightsearch -configuration Debug build
xcodebuild -project Lightsearch.xcodeproj -scheme Lightsearch -configuration Debug test
git diff --check
```

Add or update focused tests for changed behavior, including invalid input and boundary cases. Calculator, clipboard, System Settings, search-operator, and performance tests live under `Tests/`.

For purely visual changes, a Debug build and manual UI check are sufficient. Check the menu-bar item, launcher presentation, keyboard navigation, app/file launching, clipboard actions, and dismissal behavior when relevant.

Use `./relaunch.sh` only when a rebuilt app needs to be refreshed locally. It builds a Release product, quits a running Lightsearch instance, and launches the result.

## Git and scope

Use a type-prefixed branch for changes: `feat/<short-description>`, `fix/<short-description>`, `refactor/<short-description>`, `docs/<short-description>`, `test/<short-description>`, or `chore/<short-description>`. Documentation and isolated low-risk fixes may remain on the current branch. Inspect and preserve existing uncommitted changes; never reset, discard, or stash them without explicit direction.

Do not merge a feature branch into `main` until the user explicitly approves the merge.

Preserve the existing bundle identifier, App Sandbox entitlements, automatic signing setup, and `LSUIElement` menu-bar behavior unless the task explicitly requires a change.
