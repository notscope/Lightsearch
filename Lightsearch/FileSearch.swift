//
//  FileSearch.swift
//  Lightsearch
//

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
