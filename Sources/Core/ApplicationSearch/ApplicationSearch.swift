//
//  ApplicationSearch.swift
//  Lightsearch
//

import Foundation

struct InstalledApplication: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let bundleIdentifier: String?
    let path: String
    let normalizedName: String
    let nameTokens: [String]
    let acronym: String
    let normalizedBundleIdentifier: String?
    let bundleTokens: [String]
    let bundleAcronym: String?

    init(
        id: String,
        name: String,
        bundleIdentifier: String?,
        path: String
    ) {
        self.id = id
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.path = path

        let normName = ApplicationSearch.normalize(name)
        self.normalizedName = normName
        let nTokens = ApplicationSearch.tokens(from: name)
        self.nameTokens = nTokens
        self.acronym = nTokens.compactMap(\.first).map(String.init).joined()

        if let bundleIdentifier {
            self.normalizedBundleIdentifier = ApplicationSearch.normalize(bundleIdentifier)
            let bTokens = ApplicationSearch.tokens(from: bundleIdentifier)
            self.bundleTokens = bTokens
            self.bundleAcronym = bTokens.compactMap(\.first).map(String.init).joined()
        } else {
            self.normalizedBundleIdentifier = nil
            self.bundleTokens = []
            self.bundleAcronym = nil
        }
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: InstalledApplication, rhs: InstalledApplication) -> Bool {
        lhs.id == rhs.id
    }
}

struct ApplicationLaunchUsage: Codable {
    var launchCount: Int
    var lastLaunchedAt: Date
}

final class ApplicationLaunchHistory {
    private let defaults: UserDefaults
    private let storageKey = "application-launch-history"
    private var usageByApplicationID: [String: ApplicationLaunchUsage]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: storageKey),
           let usage = try? JSONDecoder().decode(
               [String: ApplicationLaunchUsage].self,
               from: data
           ) {
            usageByApplicationID = usage
        } else {
            usageByApplicationID = [:]
        }
    }

    func recordLaunch(for applicationID: String, at date: Date = Date()) {
        var usage = usageByApplicationID[applicationID] ?? ApplicationLaunchUsage(
            launchCount: 0,
            lastLaunchedAt: date
        )
        usage.launchCount = min(usage.launchCount + 1, 1_000)
        usage.lastLaunchedAt = date
        usageByApplicationID[applicationID] = usage
        persist()
    }

    func frecencyScore(for applicationID: String, at date: Date = Date()) -> Double {
        guard let usage = usageByApplicationID[applicationID] else { return 0 }

        let age = max(0, date.timeIntervalSince(usage.lastLaunchedAt))
        let recency = exp(-age / (14 * 24 * 60 * 60))
        let frequency = min(
            log(Double(usage.launchCount) + 1) / log(11),
            1
        )

        // History should settle ties and close matches, not outrank a clearly
        // better name match. Keep the boost deliberately bounded.
        return 90 * (recency * 0.65 + frequency * 0.35)
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(usageByApplicationID) else { return }
        defaults.set(data, forKey: storageKey)
    }
}

enum ApplicationSearch {
    private struct ScoredApplication {
        let application: InstalledApplication
        let score: Double
    }

    static func rankedResults(
        _ applications: [InstalledApplication],
        query: String,
        history: ApplicationLaunchHistory? = nil
    ) -> [InstalledApplication] {
        let normalizedQuery = normalize(query)
        guard !normalizedQuery.isEmpty else { return applications }

        let queryTokens = tokens(from: query)
        let queryCharacters = Array(normalizedQuery)
        let now = Date()

        return applications
            .compactMap { application -> ScoredApplication? in
                guard let matchScore = score(
                    for: application,
                    normalizedQuery: normalizedQuery,
                    queryTokens: queryTokens,
                    queryCharacters: queryCharacters
                ) else {
                    return nil
                }

                return ScoredApplication(
                    application: application,
                    score: matchScore + (history?.frecencyScore(
                        for: application.id,
                        at: now
                    ) ?? 0)
                )
            }
            .sorted { lhs, rhs in
                if abs(lhs.score - rhs.score) > 0.001 {
                    return lhs.score > rhs.score
                }

                let nameComparison = lhs.application.name.localizedStandardCompare(
                    rhs.application.name
                )
                if nameComparison != .orderedSame {
                    return nameComparison == .orderedAscending
                }
                return lhs.application.path < rhs.application.path
            }
            .map(\.application)
    }

    private static func score(
        for application: InstalledApplication,
        normalizedQuery: String,
        queryTokens: [String],
        queryCharacters: [Character]
    ) -> Double? {
        var fieldScores: [Double] = []

        if let nameScore = fieldScore(
            query: normalizedQuery,
            queryTokens: queryTokens,
            queryCharacters: queryCharacters,
            field: application.normalizedName,
            fieldTokens: application.nameTokens,
            acronym: application.acronym
        ) {
            fieldScores.append(nameScore)
        }

        if let normalizedBundle = application.normalizedBundleIdentifier,
           let bundleAcronym = application.bundleAcronym {
            if let bundleScore = fieldScore(
                query: normalizedQuery,
                queryTokens: queryTokens,
                queryCharacters: queryCharacters,
                field: normalizedBundle,
                fieldTokens: application.bundleTokens,
                acronym: bundleAcronym
            ) {
                // Bundle identifiers are useful fallback metadata, but a name
                // match should normally remain more important.
                fieldScores.append(bundleScore * 0.55)
            }
        }

        return fieldScores.max()
    }

    private static func fieldScore(
        query: String,
        queryTokens: [String],
        queryCharacters: [Character],
        field: String,
        fieldTokens: [String],
        acronym: String
    ) -> Double? {
        guard !field.isEmpty else { return nil }

        if field == query {
            return 1_000
        }

        if field.hasPrefix(query) {
            return 900 + prefixCoverage(query: query, field: field) * 30
        }

        if fieldTokens.contains(query) {
            return 850
        }

        if fieldTokens.contains(where: { $0.hasPrefix(query) }) {
            return 810 + prefixCoverage(query: query, field: field) * 20
        }

        if queryTokens.count > 1,
           let tokenScore = multiTokenScore(queryTokens: queryTokens, fieldTokens: fieldTokens) {
            return tokenScore
        }

        if acronym.hasPrefix(query) {
            return 760 + prefixCoverage(query: query, field: acronym) * 20
        }

        if field.contains(query) {
            return 640 + prefixCoverage(query: query, field: field) * 20
        }

        if let fuzzyScore = subsequenceScore(queryCharacters: queryCharacters, in: field) {
            return 500 + fuzzyScore * 100
        }

        return nil
    }

    private static func multiTokenScore(
        queryTokens: [String],
        fieldTokens: [String]
    ) -> Double? {
        guard !fieldTokens.isEmpty else { return nil }

        var totalCoverage = 0.0
        for queryToken in queryTokens {
            guard let matchingToken = fieldTokens.first(where: {
                $0 == queryToken || $0.hasPrefix(queryToken)
            }) else {
                return nil
            }
            totalCoverage += prefixCoverage(query: queryToken, field: matchingToken)
        }

        let averageCoverage = totalCoverage / Double(queryTokens.count)
        return 760 + averageCoverage * 30
    }

    private static func subsequenceScore(queryCharacters: [Character], in field: String) -> Double? {
        guard !queryCharacters.isEmpty, !field.isEmpty else { return nil }

        var searchStart = field.startIndex
        var firstMatchIndex: Int?
        var previousMatchIndex: Int?
        var totalGap = 0

        for queryCharacter in queryCharacters {
            guard searchStart < field.endIndex,
                  let matchIndex = field[searchStart...].firstIndex(of: queryCharacter) else {
                return nil
            }

            let intOffset = field.distance(from: field.startIndex, to: matchIndex)
            if firstMatchIndex == nil {
                firstMatchIndex = intOffset
            }
            if let previousMatchIndex {
                totalGap += intOffset - previousMatchIndex - 1
            }

            previousMatchIndex = intOffset
            searchStart = field.index(after: matchIndex)
        }

        let coverage = Double(queryCharacters.count) / Double(field.count)
        let compactness = 1 / (1 + Double(totalGap))
        let startBonus = firstMatchIndex == 0 ? 0.15 : 0
        return min(1, coverage * 0.45 + compactness * 0.4 + startBonus)
    }

    private static func prefixCoverage(query: String, field: String) -> Double {
        guard !field.isEmpty else { return 0 }
        return min(Double(query.count) / Double(field.count), 1)
    }

    nonisolated static func tokens(from value: String) -> [String] {
        var separated = ""
        var previousCharacterWasLowercase = false

        for character in value {
            if character.isLetter || character.isNumber {
                if character.isUppercase && previousCharacterWasLowercase {
                    separated.append(" ")
                }
                separated.append(character)
                previousCharacterWasLowercase = character.isLowercase
            } else {
                separated.append(" ")
                previousCharacterWasLowercase = false
            }
        }

        return separated
            .split(whereSeparator: \.isWhitespace)
            .map { normalize(String($0)) }
    }

    nonisolated static func normalize(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(
                options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive],
                locale: .current
            )
            .lowercased()
    }
}

enum InstalledApplicationScanner {
    nonisolated static func scan() -> [InstalledApplication] {
        let fileManager = FileManager.default
        let domains: [FileManager.SearchPathDomainMask] = [
            .userDomainMask,
            .localDomainMask,
            .systemDomainMask,
            .networkDomainMask
        ]

        var roots = Set<String>()
        for domain in domains {
            if let applicationsDirectory = fileManager.urls(for: .applicationDirectory, in: domain).first {
                roots.insert(applicationsDirectory.standardizedFileURL.path)
            }
        }

        var applicationsByIdentifier = [String: InstalledApplication]()

        for rootPath in roots.sorted() {
            let rootURL = URL(fileURLWithPath: rootPath, isDirectory: true)
            guard let enumerator = fileManager.enumerator(
                at: rootURL,
                includingPropertiesForKeys: [.isDirectoryKey, .isPackageKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else {
                continue
            }

            for case let applicationURL as URL in enumerator {
                autoreleasepool {
                    guard applicationURL.pathExtension.caseInsensitiveCompare("app") == .orderedSame else {
                        return
                    }

                    let values = try? applicationURL.resourceValues(forKeys: [.isDirectoryKey])
                    guard values?.isDirectory == true else { return }

                    // Prefer direct Info.plist parsing to avoid creating and retaining
                    // hundreds of permanent CFBundle/NSBundle records in CoreFoundation.
                    let plistURL = applicationURL.appendingPathComponent("Contents/Info.plist")
                    var displayName: String?
                    var bundleIdentifier: String?

                    if let plistData = try? Data(contentsOf: plistURL, options: .mappedIfSafe),
                       let plist = try? PropertyListSerialization.propertyList(
                           from: plistData,
                           options: [],
                           format: nil
                       ) as? [String: Any] {
                        displayName = (plist["CFBundleDisplayName"] as? String)
                            ?? (plist["CFBundleName"] as? String)
                        bundleIdentifier = plist["CFBundleIdentifier"] as? String
                    } else if let bundle = Bundle(url: applicationURL) {
                        displayName = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
                            ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
                        bundleIdentifier = bundle.bundleIdentifier
                    }

                    let name = displayName ?? applicationURL.deletingPathExtension().lastPathComponent
                    let standardizedPath = applicationURL.standardizedFileURL.path
                    let identifier = bundleIdentifier ?? standardizedPath

                    let application = InstalledApplication(
                        id: identifier,
                        name: name,
                        bundleIdentifier: bundleIdentifier,
                        path: standardizedPath
                    )

                    // A bundle can be visible in more than one application domain.
                    // Keep the first stable result and avoid duplicate rows.
                    applicationsByIdentifier[identifier] = applicationsByIdentifier[identifier] ?? application
                }
            }
        }

        return applicationsByIdentifier.values.sorted {
            let nameComparison = $0.name.localizedStandardCompare($1.name)
            if nameComparison == .orderedSame {
                return $0.path < $1.path
            }
            return nameComparison == .orderedAscending
        }
    }
}
