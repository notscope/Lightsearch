//
//  LauncherFeatures.swift
//  Lightsearch
//

import Foundation

enum LauncherFeatureResultPlacement {
    case beforeApplications
    case afterApplications
}

struct LauncherFeatureSearchOutput {
    let results: [LauncherResult]
    let placement: LauncherFeatureResultPlacement
}

struct LauncherFeatureSearchResults {
    let applicationQuery: String
    let leading: [LauncherResult]
    let trailing: [LauncherResult]
}

struct LauncherSearchContext {
    let query: String
    let applicationQuery: String
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
    var fileResults: [SearchFile] { get }
    var visibleFileResults: [SearchFile] { get }
    var recentFiles: [SearchFile] { get }
    var isLoading: Bool { get }
    var resultCountLabel: String { get }

    func enter()
    func exit()
    func recordOpen(of file: SearchFile)
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
        searchFeatures.reduce(query) { currentQuery, feature in
            feature.applicationQuery(for: currentQuery)
        }
    }

    func searchResults(for query: String) -> LauncherFeatureSearchResults {
        let context = LauncherSearchContext(
            query: query,
            applicationQuery: applicationQuery(for: query)
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

        return LauncherFeatureSearchResults(
            applicationQuery: context.applicationQuery,
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
        pageFeatures.first { $0.page == .files }?.recordOpen(of: file)
    }

    var fileSearch: (any LauncherPageFeature)? {
        pageFeatures.first { $0.page == .files }
    }

    private func connectChangeCallbacks() {
        for feature in searchFeatures {
            feature.onChange = onChange
        }
    }
}
