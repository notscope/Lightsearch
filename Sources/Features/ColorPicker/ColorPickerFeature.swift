//
//  ColorPickerFeature.swift
//  Lightsearch
//

import Foundation

@MainActor
final class ColorPickerFeature: LauncherSearchFeature {
    let identifier = "color-picker"
    var onChange: (() -> Void)?

    private static let searchAliases = [
        "color",
        "picker",
        "pick",
        "eyedropper",
        "sample"
    ]

    func searchResults(for context: LauncherSearchContext) -> LauncherFeatureSearchOutput {
        let query = context.query
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()

        guard Self.matchesSearchAlias(in: query) else {
            return LauncherFeatureSearchOutput(
                results: [],
                placement: .beforeApplications
            )
        }

        return LauncherFeatureSearchOutput(
            results: [.colorPicker],
            placement: .beforeApplications
        )
    }

    private static func matchesSearchAlias(in query: String) -> Bool {
        query.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).contains { token in
            guard token.count >= 2 else { return false }
            let token = String(token)
            return searchAliases.contains { alias in
                alias.hasPrefix(token) || token.hasPrefix(alias)
            }
        }
    }
}
