//
//  LauncherFeatures.swift
//  Lightsearch
//

import Foundation

enum LauncherFeatureResultPlacement: Equatable {
    case beforeApplications
    case afterApplications
}

struct LauncherFeatureSearchOutput {
    let results: [LauncherResult]
    let placement: LauncherFeatureResultPlacement
}

struct LauncherFeatureSearchResults {
    let applicationQuery: String
    let parsedQuery: ParsedSearchQuery
    let leading: [LauncherResult]
    let trailing: [LauncherResult]
}

struct LauncherSearchContext {
    let query: String
    let applicationQuery: String
    let filter: SearchKindFilter?
    let searchTerm: String

    init(
        query: String,
        applicationQuery: String,
        filter: SearchKindFilter? = nil,
        searchTerm: String = ""
    ) {
        self.query = query
        self.applicationQuery = applicationQuery
        self.filter = filter
        self.searchTerm = searchTerm
    }
}


@MainActor
protocol LauncherSearchFeature: AnyObject {
    var identifier: String { get }
    var onChange: (() -> Void)? { get set }

    func load() async
    func queryChanged(_ query: String, page: LauncherPage)
    func applicationQuery(for query: String) -> String
    func searchResults(for context: LauncherSearchContext) -> LauncherFeatureSearchOutput
    func stop()
}

extension LauncherSearchFeature {
    func load() async {}

    func queryChanged(_ query: String, page: LauncherPage) {}

    func applicationQuery(for query: String) -> String {
        query
    }

    func stop() {}
}

@MainActor
protocol LauncherPageFeature: AnyObject {
    var page: LauncherPage { get }
    var isActive: Bool { get }

    func enter()
    func exit()
}

@MainActor
protocol FileSearchPageFeature: LauncherPageFeature {
    var fileResults: [SearchFile] { get }
    var visibleFileResults: [SearchFile] { get }
    var recentFiles: [SearchFile] { get }
    var isLoading: Bool { get }
    var resultCountLabel: String { get }

    func recordOpen(of file: SearchFile)
}

@MainActor
protocol ClipboardPageFeature: LauncherPageFeature {
    var entries: [ClipboardEntry] { get }
    var visibleEntries: [ClipboardEntry] { get }
    var filter: ClipboardFilter { get }
    var isCapturing: Bool { get }
    var resultCountLabel: String { get }

    func setFilter(_ filter: ClipboardFilter)
    func setCaptureEnabled(_ isEnabled: Bool)
    func togglePin(for id: UUID)
    func deleteEntry(withID id: UUID)
    func clearHistory()
    func writeToPasteboard(_ entry: ClipboardEntry) -> Bool
    func recordColorPickerResult()
    func loadImageData(for id: UUID) -> Data?
    func makeDragPayload(for entry: ClipboardEntry) -> ClipboardDragPayload?
}

@MainActor
final class LauncherFeatureRegistry {
    // Optional features are enabled here. Remove or comment out one line to
    // remove that feature from the launcher without changing the core search.
    private let searchFeatures: [any LauncherSearchFeature]
    private let pageFeatures: [any LauncherPageFeature]

    var onChange: (() -> Void)? {
        didSet {
            connectChangeCallbacks()
        }
    }

    init() {
        let enabledFeatures: [any LauncherSearchFeature] = [
            CalculatorFeature(),
            ColorPickerFeature(),
            ClipboardFeature(),
            FileSearchFeature(),
            SystemPreferencesFeature()
        ]

        searchFeatures = enabledFeatures
        pageFeatures = enabledFeatures.compactMap { feature in
            feature as? any LauncherPageFeature
        }
    }

    func load() async {
        for feature in searchFeatures {
            await feature.load()
        }
    }

    func queryChanged(_ query: String, page: LauncherPage) {
        for feature in searchFeatures {
            feature.queryChanged(query, page: page)
        }
    }

    func applicationQuery(for query: String) -> String {
        let parsed = LauncherQueryParser.parse(query)
        if parsed.filter != nil {
            return parsed.searchTerm
        }
        return searchFeatures.reduce(query) { currentQuery, feature in
            feature.applicationQuery(for: currentQuery)
        }
    }

    func searchResults(for query: String) -> LauncherFeatureSearchResults {
        let parsedQuery = LauncherQueryParser.parse(query)
        let appQuery = applicationQuery(for: query)
        let context = LauncherSearchContext(
            query: query,
            applicationQuery: appQuery,
            filter: parsedQuery.filter,
            searchTerm: parsedQuery.searchTerm
        )
        var leadingResults: [LauncherResult] = []
        var trailingResults: [LauncherResult] = []

        for feature in searchFeatures {
            let output = feature.searchResults(for: context)
            switch output.placement {
            case .beforeApplications:
                leadingResults.append(contentsOf: output.results)
            case .afterApplications:
                trailingResults.append(contentsOf: output.results)
            }
        }

        if let filter = parsedQuery.filter {
            leadingResults = leadingResults.filter { $0.kind == filter }
            trailingResults = trailingResults.filter { $0.kind == filter }
        }

        return LauncherFeatureSearchResults(
            applicationQuery: context.applicationQuery,
            parsedQuery: parsedQuery,
            leading: leadingResults,
            trailing: trailingResults
        )
    }


    func stop() {
        for feature in searchFeatures {
            feature.stop()
        }
    }

    func reset() {
        stop()
        for feature in pageFeatures {
            feature.exit()
        }
    }

    func canEnter(page: LauncherPage) -> Bool {
        pageFeatures.contains { $0.page == page }
    }

    func enter(page: LauncherPage) {
        pageFeatures.first { $0.page == page }?.enter()
    }

    func exit(page: LauncherPage) {
        pageFeatures.first { $0.page == page }?.exit()
    }

    func recordOpen(of file: SearchFile) {
        fileSearch?.recordOpen(of: file)
    }

    var fileSearch: (any FileSearchPageFeature)? {
        pageFeatures.compactMap { $0 as? any FileSearchPageFeature }.first
    }

    var clipboard: (any ClipboardPageFeature)? {
        pageFeatures.compactMap { $0 as? any ClipboardPageFeature }.first
    }

    private func connectChangeCallbacks() {
        for feature in searchFeatures {
            feature.onChange = onChange
        }
    }
}
