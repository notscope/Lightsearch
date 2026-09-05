//
//  SearchOperatorTests.swift
//  LightsearchTests
//

import Foundation
import XCTest
@testable import Lightsearch

final class SearchOperatorTests: XCTestCase {

    // MARK: - Parser Unit Tests

    func testEmptyAndNormalQueries() {
        let empty = LauncherQueryParser.parse("")
        XCTAssertNil(empty.filter)
        XCTAssertEqual(empty.searchTerm, "")

        let whitespace = LauncherQueryParser.parse("   ")
        XCTAssertNil(whitespace.filter)
        XCTAssertEqual(whitespace.searchTerm, "")

        let normal = LauncherQueryParser.parse("safari")
        XCTAssertNil(normal.filter)
        XCTAssertEqual(normal.searchTerm, "safari")

        let math = LauncherQueryParser.parse("2+2")
        XCTAssertNil(math.filter)
        XCTAssertEqual(math.searchTerm, "2+2")
    }

    func testIncompleteOrUnknownOperators() {
        let colonOnly = LauncherQueryParser.parse("type:")
        XCTAssertNil(colonOnly.filter)

        let colonSpace = LauncherQueryParser.parse("type: ")
        XCTAssertNil(colonSpace.filter)

        let kindColon = LauncherQueryParser.parse("kind:")
        XCTAssertNil(kindColon.filter)

        let unknown = LauncherQueryParser.parse("type: unknown")
        XCTAssertNil(unknown.filter)
        XCTAssertEqual(unknown.searchTerm, "type: unknown")
    }

    func testActionsOperator() {
        let cases = [
            "type:actions",
            "type:action",
            "type:act",
            "kind:actions",
            "kind:action",
            "TYPE:ACTIONS",
            "Type:Action"
        ]

        for input in cases {
            let parsed = LauncherQueryParser.parse(input)
            XCTAssertEqual(parsed.filter, .actions, "Failed on input: \(input)")
            XCTAssertEqual(parsed.searchTerm, "", "Failed on input: \(input)")
        }

        let withTerm = LauncherQueryParser.parse("type:actions clip")
        XCTAssertEqual(withTerm.filter, .actions)
        XCTAssertEqual(withTerm.searchTerm, "clip")

        let withTermMultipleWords = LauncherQueryParser.parse("type:actions color picker")
        XCTAssertEqual(withTermMultipleWords.filter, .actions)
        XCTAssertEqual(withTermMultipleWords.searchTerm, "color picker")

        let postfix = LauncherQueryParser.parse("history type:actions")
        XCTAssertEqual(postfix.filter, .actions)
        XCTAssertEqual(postfix.searchTerm, "history")
    }

    func testAppsOperator() {
        let cases = [
            "type:apps",
            "type:app",
            "type:application",
            "type:applications",
            "kind:apps",
            "kind:app",
            "TYPE:APPS"
        ]

        for input in cases {
            let parsed = LauncherQueryParser.parse(input)
            XCTAssertEqual(parsed.filter, .apps, "Failed on input: \(input)")
            XCTAssertEqual(parsed.searchTerm, "", "Failed on input: \(input)")
        }

        let withTerm = LauncherQueryParser.parse("type:apps safari")
        XCTAssertEqual(withTerm.filter, .apps)
        XCTAssertEqual(withTerm.searchTerm, "safari")

        let postfix = LauncherQueryParser.parse("xcode type:app")
        XCTAssertEqual(postfix.filter, .apps)
        XCTAssertEqual(postfix.searchTerm, "xcode")
    }

    func testSettingsOperator() {
        let cases = [
            "type:settings",
            "type:setting",
            "type:set",
            "type:pref",
            "type:prefs",
            "type:preference",
            "type:preferences",
            "kind:settings",
            "kind:setting",
            "TYPE:SETTINGS"
        ]

        for input in cases {
            let parsed = LauncherQueryParser.parse(input)
            XCTAssertEqual(parsed.filter, .settings, "Failed on input: \(input)")
            XCTAssertEqual(parsed.searchTerm, "", "Failed on input: \(input)")
        }

        let withTerm = LauncherQueryParser.parse("type:settings display")
        XCTAssertEqual(withTerm.filter, .settings)
        XCTAssertEqual(withTerm.searchTerm, "display")

        let postfix = LauncherQueryParser.parse("sound type:settings")
        XCTAssertEqual(postfix.filter, .settings)
        XCTAssertEqual(postfix.searchTerm, "sound")
    }

    func testOperatorRequiresNoSpaceAfterColon() {
        // "type: apps" and "kind: apps" with spaces MUST NOT be supported as operators
        let spaceCases = [
            "type: apps",
            "type: actions",
            "type: settings",
            "type: apps safari",
            "kind: apps",
            "kind: actions",
            "kind: settings",
            "kind: apps safari"
        ]

        for input in spaceCases {
            let parsed = LauncherQueryParser.parse(input)
            XCTAssertNil(parsed.filter, "\(input) with space after colon should not be treated as an operator")
            XCTAssertEqual(parsed.searchTerm, input)
        }

        // Without space, both type: and kind: MUST be supported
        let noSpaceAppsType = LauncherQueryParser.parse("type:apps")
        XCTAssertEqual(noSpaceAppsType.filter, .apps)
        XCTAssertEqual(noSpaceAppsType.searchTerm, "")

        let noSpaceAppsKind = LauncherQueryParser.parse("kind:apps")
        XCTAssertEqual(noSpaceAppsKind.filter, .apps)
        XCTAssertEqual(noSpaceAppsKind.searchTerm, "")

        let noSpaceActionsType = LauncherQueryParser.parse("type:actions")
        XCTAssertEqual(noSpaceActionsType.filter, .actions)

        let noSpaceActionsKind = LauncherQueryParser.parse("kind:actions")
        XCTAssertEqual(noSpaceActionsKind.filter, .actions)

        let noSpaceSettingsType = LauncherQueryParser.parse("type:settings")
        XCTAssertEqual(noSpaceSettingsType.filter, .settings)

        let noSpaceSettingsKind = LauncherQueryParser.parse("kind:settings")
        XCTAssertEqual(noSpaceSettingsKind.filter, .settings)
    }

    // MARK: - State Integration Tests

    @MainActor
    func testStateFilteringActions() {
        let app1 = InstalledApplication(id: "app1", name: "Alpha", bundleIdentifier: "com.test.alpha", path: "/Applications/Alpha.app")
        let app2 = InstalledApplication(id: "app2", name: "Beta", bundleIdentifier: "com.test.beta", path: "/Applications/Beta.app")
        let state = LauncherState(previewApplications: [app1, app2])

        state.query = "type:actions"
        let results = state.visibleResults

        // Should return only actions
        XCTAssertFalse(results.isEmpty)
        for result in results {
            XCTAssertEqual(result.kind, .actions, "Result should be an action but was: \(result)")
        }

        // Must not contain any applications
        XCTAssertFalse(results.contains { if case .application = $0 { return true } else { return false } })

        // No fallback app padding to fill 7 items
        XCTAssertLessThanOrEqual(results.count, 3)
    }

    @MainActor
    func testStateFilteringSpecificAction() {
        let app = InstalledApplication(id: "app1", name: "Clip App", bundleIdentifier: "com.test.clip", path: "/Applications/Clip.app")
        let state = LauncherState(previewApplications: [app])

        state.query = "type:actions clip"
        let results = state.visibleResults

        XCTAssertEqual(results.count, 1)
        if case .clipboardHistory = results[0] {
            // expected
        } else {
            XCTFail("Expected .clipboardHistory but got \(results[0])")
        }
    }

    @MainActor
    func testStateFilteringApps() {
        let app1 = InstalledApplication(id: "app1", name: "Safari", bundleIdentifier: "com.apple.Safari", path: "/Applications/Safari.app")
        let app2 = InstalledApplication(id: "app2", name: "Notes", bundleIdentifier: "com.apple.Notes", path: "/Applications/Notes.app")
        let state = LauncherState(previewApplications: [app1, app2])

        state.query = "type:apps safari"
        let results = state.visibleResults

        XCTAssertEqual(results.count, 1)
        if case let .application(app) = results[0] {
            XCTAssertEqual(app.name, "Safari")
        } else {
            XCTFail("Expected Safari application result")
        }
    }
}
