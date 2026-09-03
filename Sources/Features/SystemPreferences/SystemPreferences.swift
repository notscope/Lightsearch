//
//  SystemPreferences.swift
//  Lightsearch
//
// Optional System Settings feature implementation.

import Foundation

struct SystemPreference: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let subtitle: String?
    let iconPath: String
    let urlString: String
    let searchableTokens: [String]
    let isSubitem: Bool
    let titleTokens: [String]
    let titleText: String
    let compactTitle: String

    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    nonisolated static func == (lhs: SystemPreference, rhs: SystemPreference) -> Bool {
        lhs.id == rhs.id
    }
}

enum SystemPreferencesScanner {
    private struct SearchEntry {
        let sectionKey: String
        let title: String
        let index: String
    }

    nonisolated static func scan() -> [SystemPreference] {
        autoreleasepool {
            let rootURL = URL(
                fileURLWithPath: "/System/Library/ExtensionKit/Extensions",
                isDirectory: true
            )
            let fileManager = FileManager.default

            guard let extensionURLs = try? fileManager.contentsOfDirectory(
                at: rootURL,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) else {
                return []
            }

            return extensionURLs
                .filter { $0.pathExtension == "appex" }
                .flatMap { url in
                    autoreleasepool {
                        makePreferences(for: url)
                    }
                }
                .sorted { lhs, rhs in
                    let titleComparison = lhs.title.localizedStandardCompare(rhs.title)
                    if titleComparison != .orderedSame {
                        return titleComparison == .orderedAscending
                    }
                    return lhs.id < rhs.id
                }
        }
    }

    nonisolated private static func makePreferences(
        for extensionURL: URL
    ) -> [SystemPreference] {
        guard let bundle = Bundle(url: extensionURL),
              let info = bundle.infoDictionary,
              let extensionAttributes = info["EXAppExtensionAttributes"] as? [String: Any],
              let settingsAttributes = extensionAttributes["SettingsExtensionAttributes"]
                  as? [String: Any],
              extensionAttributes["EXExtensionPointIdentifier"] as? String
                  == "com.apple.Settings.extension.ui",
              settingsAttributes["allowsXAppleSystemPreferencesURLScheme"] as? Bool == true,
              let searchTermsFileName = settingsAttributes["searchTermsFileName"] as? String,
              let bundleIdentifier = bundle.bundleIdentifier,
              let parentTitle = bundle.object(
                  forInfoDictionaryKey: "CFBundleDisplayName"
              ) as? String,
              let searchTermsPath = bundle.path(
                  forResource: searchTermsFileName,
                  ofType: "searchTerms"
              ) else {
            return []
        }

        let entries = loadSearchEntries(from: searchTermsPath)
        let iconPath = extensionURL.path
        let parentTitleTokens = SystemPreferenceSearch.tokens(from: parentTitle)
        let parentTitleText = parentTitleTokens.joined(separator: " ")
        let parentCompactTitle = parentTitleTokens.joined()
        var parentSearchTokens = parentTitleTokens
        for entry in entries {
            parentSearchTokens.append(contentsOf: SystemPreferenceSearch.tokens(from: entry.title))
            parentSearchTokens.append(contentsOf: SystemPreferenceSearch.tokens(from: entry.index))
        }

        let parent = SystemPreference(
            id: bundleIdentifier,
            title: parentTitle,
            subtitle: nil,
            iconPath: iconPath,
            urlString: makeURLString(bundleIdentifier: bundleIdentifier),
            searchableTokens: parentSearchTokens,
            isSubitem: false,
            titleTokens: parentTitleTokens,
            titleText: parentTitleText,
            compactTitle: parentCompactTitle
        )

        let children = entries.enumerated().map { index, entry in
            let childTitleTokens = SystemPreferenceSearch.tokens(from: entry.title)
            let childTitleText = childTitleTokens.joined(separator: " ")
            let childCompactTitle = childTitleTokens.joined()

            var childTokens = parentTitleTokens
            childTokens.append(contentsOf: childTitleTokens)
            childTokens.append(contentsOf: SystemPreferenceSearch.tokens(from: entry.index))
            return SystemPreference(
                id: "\(bundleIdentifier)#\(entry.sectionKey)#\(index)",
                title: entry.title,
                subtitle: parentTitle,
                iconPath: iconPath,
                urlString: makeURLString(
                    bundleIdentifier: bundleIdentifier,
                    sectionKey: entry.sectionKey
                ),
                searchableTokens: childTokens,
                isSubitem: true,
                titleTokens: childTitleTokens,
                titleText: childTitleText,
                compactTitle: childCompactTitle
            )
        }

        return [parent] + children
    }

    nonisolated private static func loadSearchEntries(from path: String) -> [SearchEntry] {
        let url = URL(fileURLWithPath: path)
        guard let data = try? Data(contentsOf: url),
              let propertyList = try? PropertyListSerialization.propertyList(
                  from: data,
                  options: [],
                  format: nil
              ),
              let sections = propertyList as? [String: Any] else {
            return []
        }

        var entries: [SearchEntry] = []
        for sectionKey in sections.keys.sorted() {
            guard let section = sections[sectionKey] as? [String: Any],
                  let localizableStrings = section["localizableStrings"] as? [[String: Any]
                  ] else {
                continue
            }

            for item in localizableStrings {
                guard let title = item["title"] as? String,
                      !title.isEmpty else {
                    continue
                }

                entries.append(
                    SearchEntry(
                        sectionKey: sectionKey,
                        title: title,
                        index: item["index"] as? String ?? ""
                    )
                )
            }
        }
        return entries
    }

    nonisolated private static func makeURLString(
        bundleIdentifier: String,
        sectionKey: String? = nil
    ) -> String {
        var urlString = "x-apple.systempreferences:\(bundleIdentifier)"
        guard let sectionKey, !sectionKey.isEmpty else { return urlString }

        let allowedCharacters = CharacterSet.alphanumerics.union(
            CharacterSet(charactersIn: "-._~")
        )
        let encodedSection = sectionKey.addingPercentEncoding(
            withAllowedCharacters: allowedCharacters
        ) ?? sectionKey
        urlString += "?\(encodedSection)"
        return urlString
    }
}

struct SystemPreferenceSearchIntent {
    let query: String
    let isExplicit: Bool
}

enum SystemPreferenceSearch {
    private struct ScoredPreference {
        let preference: SystemPreference
        let score: Double
    }

    private static let explicitIntentTokens: Set<String> = [
        "setting",
        "preference"
    ]

    static func intent(for query: String) -> SystemPreferenceSearchIntent {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let queryTokens = tokens(from: trimmedQuery)
        let isExplicit = queryTokens.contains(where: explicitIntentTokens.contains)

        guard isExplicit else {
            return SystemPreferenceSearchIntent(
                query: trimmedQuery,
                isExplicit: false
            )
        }

        let searchTokens = queryTokens.filter {
            !explicitIntentTokens.contains($0) && $0 != "system"
        }
        return SystemPreferenceSearchIntent(
            query: searchTokens.joined(separator: " "),
            isExplicit: true
        )
    }

    static func rankedResults(
        _ preferences: [SystemPreference],
        query: String,
        includeSubitems: Bool = false
    ) -> [SystemPreference] {
        let queryTokens = tokens(from: query)
        guard !queryTokens.isEmpty else {
            return includeSubitems
                ? preferences.filter { !$0.isSubitem }
                : []
        }

        let candidates = includeSubitems
            ? preferences
            : preferences.filter { !$0.isSubitem }
        let queryText = queryTokens.joined(separator: " ")
        let compactQuery = queryTokens.joined()
        let queryLength = queryTokens.reduce(0) { $0 + $1.count }

        return candidates
            .compactMap { preference -> ScoredPreference? in
                guard let score = score(
                    for: preference,
                    queryTokens: queryTokens,
                    queryText: queryText,
                    compactQuery: compactQuery,
                    queryLength: queryLength
                ) else {
                    return nil
                }
                return ScoredPreference(preference: preference, score: score)
            }
            .sorted { lhs, rhs in
                if abs(lhs.score - rhs.score) > 0.001 {
                    return lhs.score > rhs.score
                }
                if lhs.preference.isSubitem != rhs.preference.isSubitem {
                    return !lhs.preference.isSubitem
                }
                let titleComparison = lhs.preference.title.localizedStandardCompare(
                    rhs.preference.title
                )
                if titleComparison != .orderedSame {
                    return titleComparison == .orderedAscending
                }
                return lhs.preference.id < rhs.preference.id
            }
            .map(\.preference)
    }

    private static func score(
        for preference: SystemPreference,
        queryTokens: [String],
        queryText: String,
        compactQuery: String,
        queryLength: Int
    ) -> Double? {
        if preference.titleText == queryText || preference.compactTitle == compactQuery {
            return 1_000
        }

        if preference.titleText.hasPrefix(queryText) || preference.compactTitle.hasPrefix(compactQuery) {
            return 900 + coverage(queryLength: queryLength, in: preference.titleTokens) * 30
        }

        if queryTokens.count == 1, preference.titleTokens.contains(queryTokens[0]) {
            return 850
        }

        if queryTokens.count > 1,
           let titleScore = tokenMatchScore(queryTokens, in: preference.titleTokens) {
            return titleScore
        }

        if let keywordScore = tokenMatchScore(queryTokens, in: preference.searchableTokens) {
            return keywordScore - 100
        }

        return nil
    }

    private static func tokenMatchScore(
        _ queryTokens: [String],
        in fieldTokens: [String]
    ) -> Double? {
        guard !fieldTokens.isEmpty else { return nil }

        var totalCoverage = 0.0
        for queryToken in queryTokens {
            guard let matchingToken = fieldTokens.first(where: {
                $0 == queryToken || $0.hasPrefix(queryToken)
            }) else {
                return nil
            }
            totalCoverage += min(
                Double(queryToken.count) / Double(matchingToken.count),
                1
            )
        }

        let averageCoverage = totalCoverage / Double(queryTokens.count)
        return 760 + averageCoverage * 30
    }

    private static func coverage(queryLength: Int, in fieldTokens: [String]) -> Double {
        guard !fieldTokens.isEmpty else { return 0 }
        let fieldLength = fieldTokens.reduce(0) { $0 + $1.count }
        guard fieldLength > 0 else { return 0 }
        return min(Double(queryLength) / Double(fieldLength), 1)
    }

    nonisolated static func tokens(from value: String) -> [String] {
        let folded = value.folding(
            options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive],
            locale: .current
        )
        var tokens: [String] = []
        var token = ""

        for character in folded {
            if character.isLetter || character.isNumber {
                token.append(character.lowercased())
            } else if !token.isEmpty {
                tokens.append(normalizeToken(token))
                token = ""
            }
        }

        if !token.isEmpty {
            tokens.append(normalizeToken(token))
        }
        return tokens
    }

    nonisolated private static func normalizeToken(_ token: String) -> String {
        guard token.count > 4, token.hasSuffix("s"), !token.hasSuffix("ss") else {
            return token
        }
        return String(token.dropLast())
    }
}

@MainActor
final class SystemPreferencesFeature: LauncherSearchFeature {
    let identifier = "system-preferences"
    var onChange: (() -> Void)?

    private let maximumResults = 20
    private let maximumDefaultResults = 1
    private var preferences: [SystemPreference] = []

    func load() async {
        let scannedPreferences = await Task.detached(priority: .utility) {
            SystemPreferencesScanner.scan()
        }.value

        guard !Task.isCancelled else { return }
        preferences = scannedPreferences
        onChange?()
    }

    func applicationQuery(for query: String) -> String {
        SystemPreferenceSearch.intent(for: query).query
    }

    func searchResults(for context: LauncherSearchContext) -> LauncherFeatureSearchOutput {
        let intent = SystemPreferenceSearch.intent(for: context.query)
        let rankedPreferences = SystemPreferenceSearch.rankedResults(
            preferences,
            query: context.applicationQuery,
            includeSubitems: intent.isExplicit
        )
        let limit = intent.isExplicit ? maximumResults : maximumDefaultResults
        let results = rankedPreferences
            .prefix(limit)
            .map { LauncherResult.systemPreference($0) }

        return LauncherFeatureSearchOutput(
            results: Array(results),
            placement: intent.isExplicit
                ? .beforeApplications
                : .afterApplications
        )
    }
}
