//
//  ClipboardFeature.swift
//  Lightsearch
//
// Clipboard capture and clipboard-history page state.

import AppKit
import Foundation

@MainActor
final class ClipboardFeature: LauncherSearchFeature, ClipboardPageFeature {
    let identifier = "clipboard"
    var onChange: (() -> Void)?

    let page: LauncherPage = .clipboard
    private(set) var isActive = false
    private(set) var entries: [ClipboardEntry]
    private(set) var filter: ClipboardFilter = .all
    private(set) var isCapturing: Bool

    private let historyStore: ClipboardHistoryStore
    private let defaults: UserDefaults
    private let captureEnabledKey = "clipboard-history-capture-enabled"
    private let maximumVisibleEntries = ClipboardEntry.maximumHistoryEntries
    private var currentQuery = ""
    private var monitorTimer: Timer?
    private var lastChangeCount: Int?
    private var hasLoaded = false

    private static let searchAliases = ["clip", "clipboard", "paste", "history"]

    init(
        historyStore: ClipboardHistoryStore? = nil,
        defaults: UserDefaults = .standard
    ) {
        self.historyStore = historyStore ?? ClipboardHistoryStore()
        self.defaults = defaults
        self.entries = []
        self.isCapturing = defaults.object(forKey: captureEnabledKey) as? Bool ?? true
    }

    deinit {
        monitorTimer?.invalidate()
    }

    func load() async {
        guard !hasLoaded else { return }
        hasLoaded = true

        let historyStore = historyStore
        let encryptedHistory = await Task.detached(priority: .utility) {
            historyStore.loadData()
        }.value

        guard !Task.isCancelled else { return }
        if let encryptedHistory,
           let archive = try? JSONDecoder().decode(
               ClipboardHistoryArchive.self,
               from: encryptedHistory
           ),
           archive.version == 1 {
            let loadedEntries = archive.entries
                .prefix(ClipboardEntry.maximumHistoryEntries)
                .map { entry in
                    guard entry.kind == .color, entry.source == nil else {
                        return entry
                    }
                    var updatedEntry = entry
                    updatedEntry.source = .lightsearch
                    return updatedEntry
                }

            var migratedEntries: [ClipboardEntry] = []
            var didMigrateAnyImage = false
            for entry in loadedEntries {
                if entry.kind == .image, let fullData = entry.payload.imageData {
                    historyStore.saveImageData(fullData, for: entry.id)
                    let thumbnail = entry.payload.thumbnailData ?? ClipboardThumbnailGenerator.makeThumbnail(from: fullData)
                    migratedEntries.append(entry.withoutImageData(thumbnailData: thumbnail))
                    didMigrateAnyImage = true
                } else {
                    migratedEntries.append(entry)
                }
            }

            entries = migratedEntries
            trimHistoryToLimits()
            if didMigrateAnyImage || entries != archive.entries {
                persist()
            }
            let validIDs = Set(entries.map(\.id))
            historyStore.pruneImageData(keeping: validIDs)
        }
        lastChangeCount = NSPasteboard.general.changeCount
        startMonitoring()
    }

    func searchResults(for context: LauncherSearchContext) -> LauncherFeatureSearchOutput {
        if let filter = context.filter {
            guard filter == .actions else {
                return LauncherFeatureSearchOutput(results: [], placement: .beforeApplications)
            }
            if context.searchTerm.isEmpty {
                return LauncherFeatureSearchOutput(results: [.clipboardHistory], placement: .beforeApplications)
            }
            let query = context.searchTerm
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
                .lowercased()
            guard Self.matchesSearchAlias(in: query) else {
                return LauncherFeatureSearchOutput(results: [], placement: .beforeApplications)
            }
            return LauncherFeatureSearchOutput(results: [.clipboardHistory], placement: .beforeApplications)
        }

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
            results: [.clipboardHistory],
            placement: .beforeApplications
        )
    }


    func queryChanged(_ query: String, page: LauncherPage) {
        currentQuery = query
    }

    func enter() {
        isActive = true
        currentQuery = ""
        filter = .all
    }

    func exit() {
        isActive = false
        currentQuery = ""
        filter = .all
    }

    func stop() {
        // Clipboard monitoring intentionally continues while the launcher is
        // hidden. The feature's search work is entirely synchronous.
    }

    var visibleEntries: [ClipboardEntry] {
        let normalizedQuery = currentQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let selectedKind = filter.entryKind

        let filtered = entries.filter { entry in
            guard selectedKind == nil || entry.kind == selectedKind else { return false }
            guard !normalizedQuery.isEmpty else { return true }
            return matches(normalizedQuery, in: entry)
        }

        return filtered
            .sorted { lhs, rhs in
                if lhs.isPinned != rhs.isPinned {
                    return lhs.isPinned && !rhs.isPinned
                }
                return lhs.lastCopiedAt > rhs.lastCopiedAt
            }
            .prefix(maximumVisibleEntries)
            .map { $0 }
    }

    var resultCountLabel: String {
        let count = visibleEntries.count
        return "\(count) \(count == 1 ? "entry" : "entries")"
    }

    func setFilter(_ filter: ClipboardFilter) {
        guard self.filter != filter else { return }
        self.filter = filter
        onChange?()
    }

    func setCaptureEnabled(_ isEnabled: Bool) {
        guard isCapturing != isEnabled else { return }
        isCapturing = isEnabled
        defaults.set(isEnabled, forKey: captureEnabledKey)
        if !isEnabled {
            lastChangeCount = NSPasteboard.general.changeCount
        }
        onChange?()
    }

    func togglePin(for id: UUID) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[index] = entries[index].settingPinned(!entries[index].isPinned)
        trimHistoryToLimits()
        persist()
        onChange?()
    }

    func deleteEntry(withID id: UUID) {
        let originalCount = entries.count
        entries.removeAll { $0.id == id }
        guard entries.count != originalCount else { return }
        historyStore.deleteImageData(for: id)
        persist()
        onChange?()
    }

    func clearHistory() {
        guard !entries.isEmpty else { return }
        entries.removeAll(keepingCapacity: true)
        historyStore.clear()
        onChange?()
    }

    @discardableResult
    func writeToPasteboard(_ entry: ClipboardEntry) -> Bool {
        let hydratedEntry = hydrateEntryIfNeeded(entry)
        let didWrite = ClipboardPasteboardWriter.write(hydratedEntry)
        if didWrite {
            lastChangeCount = NSPasteboard.general.changeCount
        }
        return didWrite
    }

    func loadImageData(for id: UUID) -> Data? {
        historyStore.loadImageData(for: id)
    }

    func makeDragPayload(for entry: ClipboardEntry) -> ClipboardDragPayload? {
        let hydratedEntry = hydrateEntryIfNeeded(entry)
        return ClipboardPasteboardWriter.makeDragPayload(for: hydratedEntry)
    }

    private func hydrateEntryIfNeeded(_ entry: ClipboardEntry) -> ClipboardEntry {
        if entry.kind == .image && entry.payload.imageData == nil {
            if let fullData = historyStore.loadImageData(for: entry.id) {
                return entry.withImageData(fullData)
            }
        }
        return entry
    }

    func recordColorPickerResult() {
        recordColorPickerResult(from: .general)
    }

    func recordColorPickerResult(from pasteboard: NSPasteboard) {
        lastChangeCount = pasteboard.changeCount
        guard isCapturing,
              let snapshot = ClipboardSnapshot.read(
                  from: pasteboard,
                  source: .lightsearch
              ) else {
            return
        }
        ingest(snapshot)
    }

    private func startMonitoring() {
        guard monitorTimer == nil else { return }

        monitorTimer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.pollPasteboard()
            }
        }
    }

    private func pollPasteboard() {
        let pasteboard = NSPasteboard.general
        let changeCount = pasteboard.changeCount
        guard lastChangeCount != changeCount else { return }
        lastChangeCount = changeCount
        guard isCapturing else { return }

        let source = Self.currentSourceApplication()
        autoreleasepool {
            guard let snapshot = ClipboardSnapshot.read(
                from: pasteboard,
                source: source
            ) else {
                return
            }
            ingest(snapshot)
        }
    }

    func ingest(_ snapshot: ClipboardSnapshot) {
        guard isCapturing, let rawEntry = snapshot.makeEntry() else { return }

        let newEntry: ClipboardEntry
        if rawEntry.kind == .image, let fullData = rawEntry.payload.imageData {
            historyStore.saveImageData(fullData, for: rawEntry.id)
            let thumbnail = rawEntry.payload.thumbnailData ?? ClipboardThumbnailGenerator.makeThumbnail(from: fullData)
            newEntry = rawEntry.withoutImageData(thumbnailData: thumbnail)
        } else {
            newEntry = rawEntry
        }

        if let existingIndex = entries.firstIndex(where: {
            $0.fingerprint == newEntry.fingerprint
        }) {
            let existingEntry = entries.remove(at: existingIndex)
            entries.insert(
                existingEntry.refreshed(
                    at: newEntry.lastCopiedAt,
                    source: newEntry.source
                ),
                at: 0
            )
        } else {
            entries.insert(newEntry, at: 0)
            trimHistoryToLimits()
        }

        persist()
        onChange?()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(
            ClipboardHistoryArchive(
                entries: Array(entries.prefix(ClipboardEntry.maximumHistoryEntries))
            )
        ) else {
            return
        }
        historyStore.saveData(data)
    }

    private func matches(_ query: String, in entry: ClipboardEntry) -> Bool {
        let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
        let metadata = [
            entry.title,
            entry.subtitle ?? "",
            entry.source?.displayName ?? "",
            entry.urlString ?? ""
        ]
        if metadata.contains(where: { $0.range(of: query, options: options) != nil }) {
            return true
        }
        if entry.payload.filePaths.contains(where: { $0.range(of: query, options: options) != nil }) {
            return true
        }
        return entry.plainText?.range(of: query, options: options) != nil
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

    private func trimHistoryToLimits() {
        let pinnedEntries = entries.filter(\.isPinned)
        let unpinnedEntries = entries.filter { !$0.isPinned }
        var retained = Array(pinnedEntries.prefix(ClipboardEntry.maximumHistoryEntries))
        var byteCount = retained.reduce(0) { $0 + $1.byteCount }

        for entry in unpinnedEntries {
            guard retained.count < ClipboardEntry.maximumHistoryEntries else { break }
            guard entry.byteCount <= ClipboardEntry.maximumHistoryBytes - min(
                byteCount,
                ClipboardEntry.maximumHistoryBytes
            ) else {
                continue
            }
            retained.append(entry)
            byteCount += entry.byteCount
        }

        let previousCount = entries.count
        entries = retained
        if retained.count < previousCount {
            let retainedIDs = Set(entries.map(\.id))
            historyStore.pruneImageData(keeping: retainedIDs)
        }
    }

    private static func currentSourceApplication() -> ClipboardSource? {
        guard let application = NSWorkspace.shared.frontmostApplication,
              application.processIdentifier != ProcessInfo.processInfo.processIdentifier else {
            return nil
        }

        return ClipboardSource(
            name: application.localizedName ?? "",
            bundleIdentifier: application.bundleIdentifier,
            bundlePath: application.bundleURL?.path
        )
    }
}
