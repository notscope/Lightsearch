import Foundation

enum SearchKindFilter: String, CaseIterable, Equatable, Sendable {
    case actions
    case apps
    case settings

    var displayTitle: String {
        switch self {
        case .actions:
            return "Actions"
        case .apps:
            return "Applications"
        case .settings:
            return "Settings"
        }
    }

    static func matching(token: String) -> SearchKindFilter? {
        let normalized = token
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()

        guard !normalized.isEmpty else { return nil }

        switch normalized {
        case "action", "actions", "act":
            return .actions
        case "app", "apps", "application", "applications":
            return .apps
        case "setting", "settings", "pref", "preference", "preferences", "prefs", "set":
            return .settings
        default:
            return nil
        }
    }
}

struct ParsedSearchQuery: Equatable, Sendable {
    let rawQuery: String
    let filter: SearchKindFilter?
    let searchTerm: String
}

enum LauncherQueryParser {
    private static let operatorRegex: NSRegularExpression? = {
        try? NSRegularExpression(
            pattern: #"(?:^|\s)(?:type:|kind:)([a-zA-Z]+)"#,
            options: [.caseInsensitive]
        )
    }()

    /// Parses a raw user query string to extract any `type:<kind>` or `kind:<kind>` filter operator.
    /// Note: A colon must be followed directly by the kind name with no space (e.g. `type:apps`, not `type: apps`).
    ///
    /// Examples:
    /// - `"type:actions"` -> filter: `.actions`, searchTerm: `""`
    /// - `"type:actions clip"` -> filter: `.actions`, searchTerm: `"clip"`
    /// - `"type:apps safari"` -> filter: `.apps`, searchTerm: `"safari"`
    /// - `"type:settings display"` -> filter: `.settings`, searchTerm: `"display"`
    /// - `"kind:apps"` -> filter: `.apps`, searchTerm: `""`
    /// - `"safari type:apps"` -> filter: `.apps`, searchTerm: `"safari"`
    /// - `"normal search"` -> filter: `nil`, searchTerm: `"normal search"`
    static func parse(_ query: String) -> ParsedSearchQuery {

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return ParsedSearchQuery(rawQuery: query, filter: nil, searchTerm: "")
        }

        guard let regex = operatorRegex else {
            return ParsedSearchQuery(rawQuery: query, filter: nil, searchTerm: trimmed)
        }

        let nsString = trimmed as NSString
        let fullRange = NSRange(location: 0, length: nsString.length)

        guard let match = regex.firstMatch(in: trimmed, options: [], range: fullRange) else {
            return ParsedSearchQuery(rawQuery: query, filter: nil, searchTerm: trimmed)
        }

        let tokenRange = match.range(at: 1)
        guard tokenRange.location != NSNotFound else {
            return ParsedSearchQuery(rawQuery: query, filter: nil, searchTerm: trimmed)
        }

        let kindToken = nsString.substring(with: tokenRange)
        guard let filter = SearchKindFilter.matching(token: kindToken) else {
            return ParsedSearchQuery(rawQuery: query, filter: nil, searchTerm: trimmed)
        }

        let operatorRange = match.range(at: 0)
        var remaining = nsString.replacingCharacters(in: operatorRange, with: "")
        remaining = remaining.trimmingCharacters(in: .whitespacesAndNewlines)

        return ParsedSearchQuery(
            rawQuery: query,
            filter: filter,
            searchTerm: remaining
        )
    }
}
