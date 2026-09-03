# Repository Guidelines

## Project Structure & Module Organization

This repository is a small macOS SwiftUI/AppKit launcher. Production code lives in `Lightsearch/`:

- `LightsearchApp.swift` configures the menu-bar application and tray behavior.
- `LauncherController.swift` owns the `NSPanel`, keyboard monitoring, sizing, and app/file launching.
- `LauncherState.swift` contains application models, ranking, launch history, and selection state.
- `ContentView.swift` contains the launcher UI and reusable result-row views.
- `FileSearch.swift` contains Spotlight file search and recent-file persistence.
- `SystemPreferences.swift` discovers Apple Settings extensions, localized search terms, and URLs.
- `Assets.xcassets/` contains the app icon and color assets.

The Xcode project is `Lightsearch.xcodeproj`. There is currently no test target.

## Build, Test, and Development Commands

Run these from the repository root:

```sh
xcodebuild -project Lightsearch.xcodeproj -scheme Lightsearch -configuration Debug build
git diff --check
```

The first command compiles the app. Run `./relaunch.sh` only after changes that touch Swift/source code and require the rebuilt app to be refreshed; Markdown-only documentation edits do not require a relaunch. The script builds the configured Release product, quits any running Lightsearch instance, and launches the rebuilt app. It uses the default automatic code-signing configuration. `git diff --check` catches whitespace errors.

## Coding Style & Naming Conventions

Use four-space indentation, standard Swift formatting, and concise comments only for non-obvious AppKit or concurrency behavior. Types and protocols use `UpperCamelCase`; properties, methods, and local values use `lowerCamelCase`. Keep UI state on `@MainActor`, prefer SwiftUI composition for presentation, and keep panel/event logic in `LauncherController`. Use stable IDs for `ForEach` rows and avoid force unwraps/casts.

## Implementation Priorities

Prioritize the fastest practical implementation and reliable behavior over visual polish. Prefer native platform APIs and local, direct operations; avoid unnecessary work, allocations, I/O, network requests, view layers, and recomputation. Choose the simplest design that satisfies the requirement: do not add speculative abstractions, dependencies, state, or components unless they solve real complexity. Keep code easy to read and maintain, and make each feature behave exactly as its name and description promise.

## Branching & Change Scope

Treat documentation edits, typo fixes, and isolated low-risk changes as trivial; they may remain on the current branch or `main`. Treat new features, refactors, UI overhauls, performance or concurrency work, and build, signing, or dependency changes as significant; do them on a separate `codex/<short-description>` branch so `main` remains unaffected if something breaks. If the worktree already contains uncommitted changes, inspect and preserve them before switching branches or creating a branch; never stash, discard, or move them without explicit direction. When uncertain, classify the change as significant.

After a significant change passes validation, merge its branch back into `main`, remove the temporary branch when it is no longer needed, and leave `main` checked out with a clean worktree. Trivial changes made directly on `main` should also finish clean.

## Testing Guidelines

Because no automated test target exists, validate changes with a clean `xcodebuild` build and manual checks of the menu-bar item, keyboard navigation, panel resizing, app launching, file search, and dismissal behavior. For UI changes, include a screenshot or a concise manual reproduction in the pull request.

## Commit & Pull Request Guidelines

Git history currently contains only `Initial Commit`, so no established message convention is available. Use short imperative subjects, for example `Fix keyboard selection wrapping`. Pull requests should describe the behavior change, list validation commands, note signing or permission requirements, and include screenshots for visible UI changes.

## macOS Configuration Notes

The target uses automatic signing, App Sandbox, and `LSUIElement` for a menu-bar-only app. Preserve the existing bundle identifier and entitlements unless a task explicitly requires changing them.
