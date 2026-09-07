// Optional file-search feature implementation.

import Foundation

struct SearchFile: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let path: String
    let isDirectory: Bool

    var parentPath: String {
        URL(fileURLWithPath: path).deletingLastPathComponent().path
    }
}

final class RecentFileHistory {
    private let defaults: UserDefaults
    private let storageKey = "recent-opened-file-paths"
    private let maximumEntries = 12
    private var paths: [String]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        paths = defaults.stringArray(forKey: storageKey) ?? []
    }

    func record(path: String) {
        let normalizedPath = URL(fileURLWithPath: path).standardizedFileURL.path
        paths.removeAll { $0 == normalizedPath }
        paths.insert(normalizedPath, at: 0)
        paths = Array(paths.prefix(maximumEntries))
        persist()
    }

    func recentFiles() -> [SearchFile] {
        var existingPaths: [String] = []
        let files = paths.compactMap { path -> SearchFile? in
            let url = URL(fileURLWithPath: path).standardizedFileURL
            guard FileManager.default.fileExists(atPath: url.path) else { return nil }

            let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
            existingPaths.append(url.path)

            return SearchFile(
                id: url.path,
                name: url.lastPathComponent.isEmpty ? url.path : url.lastPathComponent,
                path: url.path,
                isDirectory: isDirectory
            )
        }

        if existingPaths != paths {
            paths = existingPaths
            persist()
        }

        return files
    }

    private func persist() {
        defaults.set(paths, forKey: storageKey)
    }
}

@MainActor
final class FileSearchService: NSObject {
    private var metadataQuery: NSMetadataQuery?
    private var completion: (([SearchFile]) -> Void)?
    private var searchID = UUID()

    override init() {
        super.init()
    }

    func search(
        for queryText: String,
        completion: @escaping ([SearchFile]) -> Void
    ) {
        stop()

        let queryText = queryText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !queryText.isEmpty else {
            completion([])
            return
        }

        let searchID = UUID()
        self.searchID = searchID
        self.completion = completion

        let metadataQuery = NSMetadataQuery()
        metadataQuery.searchScopes = [NSMetadataQueryUserHomeScope]
        metadataQuery.operationQueue = .main
        metadataQuery.predicate = NSPredicate(
            format: "%K CONTAINS[cd] %@",
            NSMetadataItemFSNameKey,
            queryText
        )

        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(
            self,
            selector: #selector(metadataQueryDidFinishGathering(_:)),
            name: NSNotification.Name.NSMetadataQueryDidFinishGathering,
            object: metadataQuery
        )

        self.metadataQuery = metadataQuery
        guard metadataQuery.start() else {
            let resultHandler = self.completion
            stop()
            resultHandler?([])
            return
        }
    }

    func stop() {
        if let metadataQuery {
            NotificationCenter.default.removeObserver(
                self,
                name: NSNotification.Name.NSMetadataQueryDidFinishGathering,
                object: metadataQuery
            )
            metadataQuery.stop()
        }
        metadataQuery = nil

        completion = nil
        searchID = UUID()
    }

    @objc private func metadataQueryDidFinishGathering(_ notification: Notification) {
        guard let metadataQuery = notification.object as? NSMetadataQuery else { return }
        finish(query: metadataQuery, searchID: searchID)
    }

    private func finish(query: NSMetadataQuery, searchID: UUID) {
        guard self.searchID == searchID else { return }

        query.disableUpdates()
        let files = makeFiles(from: query.results)
        query.enableUpdates()

        let resultHandler = completion
        stop()
        resultHandler?(files)
    }

    private func makeFiles(from results: [Any]) -> [SearchFile] {
        var seenPaths = Set<String>()
        let files = results.compactMap { result -> SearchFile? in
            guard let item = result as? NSMetadataItem,
                  let path = item.value(forAttribute: NSMetadataItemPathKey) as? String else {
                return nil
            }

            let url = URL(fileURLWithPath: path).standardizedFileURL
            guard url.pathExtension.caseInsensitiveCompare("app") != .orderedSame,
                  seenPaths.insert(url.path).inserted else {
                return nil
            }

            let name = (item.value(forAttribute: NSMetadataItemFSNameKey) as? String)
                ?? url.lastPathComponent
            let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true

            return SearchFile(
                id: url.path,
                name: name,
                path: url.path,
                isDirectory: isDirectory
            )
        }

        return files.sorted { lhs, rhs in
            let nameComparison = lhs.name.localizedStandardCompare(rhs.name)
            if nameComparison != .orderedSame {
                return nameComparison == .orderedAscending
            }
            return lhs.path < rhs.path
        }
    }
}

@MainActor
final class FileSearchFeature: LauncherSearchFeature, FileSearchPageFeature {
    let identifier = "file-search"
    var onChange: (() -> Void)?

    let page: LauncherPage = .files
    private(set) var isActive = false
    private(set) var fileResults: [SearchFile] = []
    private(set) var isLoading = false

    private let fileSearchService = FileSearchService()
    private let recentFileHistory = RecentFileHistory()
    private let maximumResults = 50
    private var currentQuery = ""
    private var searchTask: Task<Void, Never>?

    var visibleFileResults: [SearchFile] {
        currentQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? recentFiles
            : fileResults
    }

    var recentFiles: [SearchFile] {
        recentFileHistory.recentFiles()
    }

    var resultCountLabel: String {
        let count = fileResults.count
        if count >= maximumResults {
            return "\(maximumResults)+ files"
        }
        return "\(count) \(count == 1 ? "file" : "files")"
    }

    func searchResults(for context: LauncherSearchContext) -> LauncherFeatureSearchOutput {
        if let filter = context.filter {
            guard filter == .actions else {
                return LauncherFeatureSearchOutput(results: [], placement: .afterApplications)
            }
            if context.searchTerm.isEmpty {
                return LauncherFeatureSearchOutput(results: [.fileSearch], placement: .afterApplications)
            }
            let application = InstalledApplication(
                id: fileSearchActionID,
                name: "File Search",
                bundleIdentifier: "Search files and folders",
                path: ""
            )
            let matches = ApplicationSearch.rankedResults(
                [application],
                query: context.searchTerm
            )
            return LauncherFeatureSearchOutput(
                results: matches.isEmpty ? [] : [.fileSearch],
                placement: .afterApplications
            )
        }

        let searchQuery = context.applicationQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !searchQuery.isEmpty else {
            return LauncherFeatureSearchOutput(
                results: [],
                placement: .afterApplications
            )
        }

        let application = InstalledApplication(
            id: fileSearchActionID,
            name: "File Search",
            bundleIdentifier: "Search files and folders",
            path: ""
        )
        let matches = ApplicationSearch.rankedResults(
            [application],
            query: searchQuery
        )

        return LauncherFeatureSearchOutput(
            results: matches.isEmpty ? [] : [.fileSearch],
            placement: .afterApplications
        )
    }


    func queryChanged(_ query: String, page: LauncherPage) {
        currentQuery = query
        guard isActive, page == .files else {
            stopSearch()
            return
        }
        scheduleSearch()
    }

    func enter() {
        isActive = true
        stopSearch()
        currentQuery = ""
        fileResults = []
    }

    func exit() {
        isActive = false
        stopSearch()
        currentQuery = ""
        fileResults = []
    }

    func recordOpen(of file: SearchFile) {
        recentFileHistory.record(path: file.path)
    }

    func stop() {
        stopSearch()
    }

    private func scheduleSearch() {
        stopSearch()
        fileResults = []

        let searchText = currentQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !searchText.isEmpty else { return }

        isLoading = true
        searchTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: 120_000_000)
            } catch {
                return
            }

            guard !Task.isCancelled, let self else { return }
            self.fileSearchService.search(for: searchText) { [weak self] results in
                guard let self,
                      self.isActive,
                      self.currentQuery.trimmingCharacters(in: .whitespacesAndNewlines)
                          == searchText else {
                    return
                }

                self.fileResults = Array(results.prefix(self.maximumResults))
                self.isLoading = false
                self.onChange?()
            }
        }
    }

    private func stopSearch() {
        searchTask?.cancel()
        searchTask = nil
        fileSearchService.stop()
        isLoading = false
    }
}
