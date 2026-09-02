# Repository Guidelines

## Project Structure & Module Organization

This repository is a small macOS SwiftUI/AppKit launcher. Production code lives in `Lightsearch/`:

- `LightsearchApp.swift` configures the menu-bar application and tray behavior.
- `LauncherController.swift` owns the `NSPanel`, keyboard monitoring, sizing, and app/file launching.
- `LauncherState.swift` contains application models, ranking, launch history, and selection state.
- `ContentView.swift` contains the launcher UI and reusable result-row views.
- `FileSearch.swift` contains Spotlight file search and recent-file persistence.
- `Assets.xcassets/` contains the app icon and color assets.

The Xcode project is `Lightsearch.xcodeproj`. There is currently no test target.

## Build, Test, and Development Commands

Run these from the repository root:

```sh
xcodebuild -project Lightsearch.xcodeproj -scheme Lightsearch -configuration Debug build
./relaunch.sh
git diff --check
```

The first command compiles the app. `relaunch.sh` builds the configured Release product, quits any running Lightsearch instance, and launches the rebuilt app. It uses the default automatic code-signing configuration. `git diff --check` catches whitespace errors.

## Coding Style & Naming Conventions

Use four-space indentation, standard Swift formatting, and concise comments only for non-obvious AppKit or concurrency behavior. Types and protocols use `UpperCamelCase`; properties, methods, and local values use `lowerCamelCase`. Keep UI state on `@MainActor`, prefer SwiftUI composition for presentation, and keep panel/event logic in `LauncherController`. Use stable IDs for `ForEach` rows and avoid force unwraps/casts.

## Testing Guidelines

Because no automated test target exists, validate changes with a clean `xcodebuild` build and manual checks of the menu-bar item, keyboard navigation, panel resizing, app launching, file search, and dismissal behavior. For UI changes, include a screenshot or a concise manual reproduction in the pull request.

## Commit & Pull Request Guidelines

Git history currently contains only `Initial Commit`, so no established message convention is available. Use short imperative subjects, for example `Fix keyboard selection wrapping`. Pull requests should describe the behavior change, list validation commands, note signing or permission requirements, and include screenshots for visible UI changes.

## macOS Configuration Notes

The target uses automatic signing, App Sandbox, and `LSUIElement` for a menu-bar-only app. Preserve the existing bundle identifier and entitlements unless a task explicitly requires changing them.
