//
//  LauncherState.swift
//  Lightsearch
//

import Combine
import Foundation

private let fileSearchActionID = "io.notscope.Lightsearch.action.file-search"

struct InstalledApplication: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let bundleIdentifier: String?
    let path: String
}

enum LauncherPage: Equatable {
    case applications
    case files
}

enum LauncherResult: Identifiable {
    case application(InstalledApplication)
    case fileSearch

    var id: String {
        switch self {
        case let .application(application):
            return application.id
        case .fileSearch:
            return fileSearchActionID
        }
    }
}

private struct ApplicationLaunchUsage: Codable {
    var launchCount: Int
    var lastLaunchedAt: Date
}

private final class ApplicationLaunchHistory {
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

private enum ApplicationSearch {
    private struct ScoredApplication {
        let application: InstalledApplication
        let score: Double
    }

    static func rankedResults(
        _ applications: [InstalledApplication],
        query: String,
        history: ApplicationLaunchHistory
    ) -> [InstalledApplication] {
        let normalizedQuery = normalize(query)
        guard !normalizedQuery.isEmpty else { return applications }

        let queryTokens = tokens(from: query)
        let now = Date()

        return applications
            .compactMap { application -> ScoredApplication? in
                guard let matchScore = score(
                    for: application,
                    normalizedQuery: normalizedQuery,
                    queryTokens: queryTokens
                ) else {
                    return nil
                }

                return ScoredApplication(
                    application: application,
                    score: matchScore + history.frecencyScore(
                        for: application.id,
                        at: now
                    )
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
        queryTokens: [String]
    ) -> Double? {
        let name = normalize(application.name)
        let nameTokens = tokens(from: application.name)
        var fieldScores: [Double] = []

        if let nameScore = fieldScore(
            query: normalizedQuery,
            queryTokens: queryTokens,
            field: name,
            fieldTokens: nameTokens
        ) {
            fieldScores.append(nameScore)
        }

        if let bundleIdentifier = application.bundleIdentifier {
            let bundle = normalize(bundleIdentifier)
            let bundleTokens = tokens(from: bundleIdentifier)
            if let bundleScore = fieldScore(
                query: normalizedQuery,
                queryTokens: queryTokens,
                field: bundle,
                fieldTokens: bundleTokens
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
        field: String,
        fieldTokens: [String]
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

        let acronym = fieldTokens.compactMap(\.first).map(String.init).joined()
        if acronym.hasPrefix(query) {
            return 760 + prefixCoverage(query: query, field: acronym) * 20
        }

        if field.contains(query) {
            return 640 + prefixCoverage(query: query, field: field) * 20
        }

        if let fuzzyScore = subsequenceScore(query: query, field: field) {
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

    private static func subsequenceScore(query: String, field: String) -> Double? {
        let queryCharacters = Array(query)
        let fieldCharacters = Array(field)
        guard !queryCharacters.isEmpty, !fieldCharacters.isEmpty else { return nil }

        var searchStart = 0
        var firstMatchIndex: Int?
        var previousMatchIndex: Int?
        var totalGap = 0

        for queryCharacter in queryCharacters {
            guard searchStart < fieldCharacters.count,
                  let matchIndex = fieldCharacters[searchStart...].firstIndex(
                      of: queryCharacter
                  ) else {
                return nil
            }

            if firstMatchIndex == nil {
                firstMatchIndex = matchIndex
            }
            if let previousMatchIndex {
                totalGap += matchIndex - previousMatchIndex - 1
            }

            previousMatchIndex = matchIndex
            searchStart = matchIndex + 1
        }

        let coverage = Double(queryCharacters.count) / Double(fieldCharacters.count)
        let compactness = 1 / (1 + Double(totalGap))
        let startBonus = firstMatchIndex == 0 ? 0.15 : 0
        return min(1, coverage * 0.45 + compactness * 0.4 + startBonus)
    }

    private static func prefixCoverage(query: String, field: String) -> Double {
        guard !field.isEmpty else { return 0 }
        return min(Double(query.count) / Double(field.count), 1)
    }

    private static func tokens(from value: String) -> [String] {
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

    private static func normalize(_ value: String) -> String {
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
                guard applicationURL.pathExtension.caseInsensitiveCompare("app") == .orderedSame else {
                    continue
                }

                let values = try? applicationURL.resourceValues(forKeys: [.isDirectoryKey])
                guard values?.isDirectory == true else { continue }

                let bundle = Bundle(url: applicationURL)
                let name = (
                    bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                ) ?? (
                    bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String
                ) ?? applicationURL.deletingPathExtension().lastPathComponent
                let bundleIdentifier = bundle?.bundleIdentifier
                let identifier = bundleIdentifier ?? applicationURL.standardizedFileURL.path

                let application = InstalledApplication(
                    id: identifier,
                    name: name,
                    bundleIdentifier: bundleIdentifier,
                    path: applicationURL.standardizedFileURL.path
                )

                // A bundle can be visible in more than one application domain.
                // Keep the first stable result and avoid duplicate rows.
                applicationsByIdentifier[identifier] = applicationsByIdentifier[identifier] ?? application
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

@MainActor
final class LauncherState: ObservableObject {
    private let minimumVisibleResults = 9

    @Published var query = "" {
        didSet {
            selectedIndex = 0
            if page == .applications {
                rememberNonEmptyResults()
            } else {
                scheduleFileSearch()
            }
        }
    }

    @Published private(set) var page: LauncherPage = .applications
    @Published private(set) var applications: [InstalledApplication]
    @Published private(set) var fileResults: [SearchFile] = []
    @Published private(set) var isLoading = true
    @Published private(set) var isFileSearchLoading = false
    @Published var selectedIndex = 0

    private var hasStartedLoading = false
    private let launchHistory = ApplicationLaunchHistory()
    private let fileSearchService = FileSearchService()
    private let recentFileHistory = RecentFileHistory()
    private var fileSearchTask: Task<Void, Never>?
    private var previousResults: [InstalledApplication] = []
    private let maximumFileResults = 50

    init(previewApplications: [InstalledApplication] = []) {
        applications = previewApplications
        isLoading = previewApplications.isEmpty
    }

    var filteredApplications: [InstalledApplication] {
        ApplicationSearch.rankedResults(
            applications,
            query: query,
            history: launchHistory
        )
    }

    var displayedApplications: [InstalledApplication] {
        let matches = filteredApplications
        let primaryResults = matches.isEmpty ? previousResults : matches
        return fillResults(primaryResults)
    }

    var visibleResults: [LauncherResult] {
        Array(displayedResults.prefix(minimumVisibleResults))
    }

    var isFileSearchPage: Bool {
        page == .files
    }

    var visibleFileResults: [SearchFile] {
        let files = query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? recentFiles
            : fileResults
        return Array(files.prefix(minimumVisibleResults))
    }

    var recentFiles: [SearchFile] {
        recentFileHistory.recentFiles()
    }

    var fileResultCountLabel: String {
        let count = fileResults.count
        if count >= maximumFileResults {
            return "\(maximumFileResults)+ files"
        }
        return "\(count) \(count == 1 ? "file" : "files")"
    }

    func loadIfNeeded() {
        guard !hasStartedLoading else { return }
        hasStartedLoading = true

        Task { [weak self] in
            let applications = await Task.detached(priority: .userInitiated) {
                InstalledApplicationScanner.scan()
            }.value

            guard !Task.isCancelled else { return }
            self?.applications = applications
            self?.isLoading = false
            self?.selectedIndex = 0
            self?.rememberNonEmptyResults()
        }
    }

    func moveSelection(by offset: Int) {
        let count = isFileSearchPage ? visibleFileResults.count : visibleResults.count
        guard count > 0 else { return }

        let nextIndex = selectedIndex + offset
        selectedIndex = ((nextIndex % count) + count) % count
    }

    func selectedResult() -> LauncherResult? {
        guard page == .applications else { return nil }
        guard visibleResults.indices.contains(selectedIndex) else { return nil }
        return visibleResults[selectedIndex]
    }

    func selectedFile() -> SearchFile? {
        guard page == .files else { return nil }
        guard visibleFileResults.indices.contains(selectedIndex) else { return nil }
        return visibleFileResults[selectedIndex]
    }

    func recordLaunch(of application: InstalledApplication) {
        launchHistory.recordLaunch(for: application.id)
    }

    func recordOpen(of file: SearchFile) {
        recentFileHistory.record(path: file.path)
    }

    func resetForPresentation() {
        stopFileSearch()
        page = .applications
        query = ""
        selectedIndex = 0
    }

    func enterFileSearch() {
        stopFileSearch()
        page = .files
        query = ""
        fileResults = []
        selectedIndex = 0
    }

    func exitFileSearch() {
        stopFileSearch()
        page = .applications
        query = ""
        selectedIndex = 0
    }

    private func rememberNonEmptyResults() {
        let matches = filteredApplications
        if !matches.isEmpty {
            previousResults = matches
        }
    }

    private func fillResults(_ primaryResults: [InstalledApplication]) -> [InstalledApplication] {
        guard !applications.isEmpty else { return primaryResults }

        let currentIDs = Set(applications.map(\.id))
        var results = primaryResults.filter { currentIDs.contains($0.id) }
        var seenIDs = Set(results.map(\.id))
        let fallbackResults = previousResults + applications

        for application in fallbackResults where seenIDs.insert(application.id).inserted {
            results.append(application)
            if results.count >= minimumVisibleResults {
                break
            }
        }

        return results
    }

    private func scheduleFileSearch() {
        stopFileSearch()
        fileResults = []

        let searchText = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard page == .files, !searchText.isEmpty else {
            isFileSearchLoading = false
            return
        }

        isFileSearchLoading = true
        fileSearchTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: 120_000_000)
            } catch {
                return
            }

            guard !Task.isCancelled, let self else { return }
            self.fileSearchService.search(for: searchText) { [weak self] results in
                guard let self, self.page == .files else { return }
                self.fileResults = Array(results.prefix(self.maximumFileResults))
                self.isFileSearchLoading = false
                self.selectedIndex = 0
            }
        }
    }

    private func stopFileSearch() {
        fileSearchTask?.cancel()
        fileSearchTask = nil
        fileSearchService.stop()
        isFileSearchLoading = false
    }

    private var displayedResults: [LauncherResult] {
        var results = filteredLauncherResults
        var seenIDs = Set(results.map(\.id))

        for application in displayedApplications where seenIDs.insert(application.id).inserted {
            results.append(.application(application))
            if results.count >= minimumVisibleResults {
                break
            }
        }

        return results
    }

    private var filteredLauncherResults: [LauncherResult] {
        var candidates = applications
        let searchText = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !searchText.isEmpty {
            candidates.append(
                InstalledApplication(
                    id: fileSearchActionID,
                    name: "File Search",
                    bundleIdentifier: "Search files and folders",
                    path: ""
                )
            )
        }

        return ApplicationSearch.rankedResults(
            candidates,
            query: query,
            history: launchHistory
        ).map { candidate in
            candidate.id == fileSearchActionID
                ? .fileSearch
                : .application(candidate)
        }
    }
}
