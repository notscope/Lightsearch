//
//  LauncherState.swift
//  Lightsearch
//

import Combine
import Foundation

@MainActor
final class LauncherState: ObservableObject {
    // The core state owns the application search. Optional features are
    // coordinated through LauncherFeatureRegistry and do not add their own
    // scanners, parsers, or async work here.
    @Published var query = "" {
        didSet {
            selectedIndex = 0
            features.queryChanged(query, page: page)
        }
    }

    @Published private(set) var page: LauncherPage = .applications
    @Published private(set) var applications: [InstalledApplication]
    @Published private(set) var isLoading = true
    @Published var selectedIndex = 0
    @Published var isCommandPressed = false
    @Published var isClipboardFilterPresented = false
    @Published var focusedClipboardFilter: ClipboardFilter = .all

    private var hasStartedLoading = false
    private var directoryWatcher: ApplicationDirectoryWatcher?
    private var lastScannedDirectoryTimestamps: [String: ApplicationDirectoryTimestamp] = [:]
    private let launchHistory = ApplicationLaunchHistory()
    private let features: LauncherFeatureRegistry
    private var previousResults: [InstalledApplication] = []
    private let maximumApplicationResults = 20

    init(previewApplications: [InstalledApplication] = []) {
        applications = previewApplications
        previousResults = previewApplications
        isLoading = previewApplications.isEmpty

        let features = LauncherFeatureRegistry()
        self.features = features
        features.onChange = { [weak self] in
            self?.objectWillChange.send()
        }
    }

    var filteredApplications: [InstalledApplication] {
        let parsed = LauncherQueryParser.parse(query)
        if let filter = parsed.filter, filter != .apps {
            return []
        }
        return Array(
            ApplicationSearch.rankedResults(
                applications,
                query: features.applicationQuery(for: query),
                history: launchHistory
            ).prefix(maximumApplicationResults)
        )
    }


    var visibleResults: [LauncherResult] {
        displayedResults
    }

    var isFileSearchPage: Bool {
        page == .files
    }

    var isClipboardPage: Bool {
        page == .clipboard
    }

    var fileResults: [SearchFile] {
        features.fileSearch?.fileResults ?? []
    }

    var visibleFileResults: [SearchFile] {
        features.fileSearch?.visibleFileResults ?? []
    }

    var recentFiles: [SearchFile] {
        features.fileSearch?.recentFiles ?? []
    }

    var fileResultCountLabel: String {
        features.fileSearch?.resultCountLabel ?? "0 files"
    }

    var isFileSearchLoading: Bool {
        features.fileSearch?.isLoading ?? false
    }

    var clipboardEntries: [ClipboardEntry] {
        features.clipboard?.entries ?? []
    }

    var visibleClipboardEntries: [ClipboardEntry] {
        features.clipboard?.visibleEntries ?? []
    }

    var clipboardFilter: ClipboardFilter {
        features.clipboard?.filter ?? .all
    }

    var isClipboardCapturing: Bool {
        features.clipboard?.isCapturing ?? false
    }

    var clipboardResultCountLabel: String {
        features.clipboard?.resultCountLabel ?? "0 entries"
    }

    var clipboardTargetApplicationName: String {
        clipboardPasteTargetName ?? "your app"
    }

    private var clipboardPasteTargetName: String?

    func loadIfNeeded() {
        guard !hasStartedLoading else { return }
        hasStartedLoading = true

        Task { [weak self] in
            guard let self else { return }
            let applicationsTask = Task.detached(priority: .userInitiated) {
                InstalledApplicationScanner.scan()
            }

            await self.features.load()
            let loadedApplications = await applicationsTask.value

            guard !Task.isCancelled else { return }
            self.applications = loadedApplications
            self.previousResults = loadedApplications
            self.lastScannedDirectoryTimestamps = ApplicationDirectoryWatcher.currentTimestamps()
            self.isLoading = false
            self.selectedIndex = 0
            self.startDirectoryWatcher()
        }
    }

    private func startDirectoryWatcher() {
        directoryWatcher = ApplicationDirectoryWatcher { [weak self] in
            Task { @MainActor [weak self] in
                self?.refreshApplications()
            }
        }
    }

    func refreshApplicationsIfNeeded() {
        guard hasStartedLoading else { return }
        let currentTimestamps = ApplicationDirectoryWatcher.currentTimestamps()
        if currentTimestamps != lastScannedDirectoryTimestamps {
            refreshApplications()
        }
    }

    func refreshApplications() {
        Task { [weak self] in
            guard let self else { return }
            let loadedApplications = await Task.detached(priority: .userInitiated) {
                InstalledApplicationScanner.scan()
            }.value

            guard !Task.isCancelled else { return }
            self.lastScannedDirectoryTimestamps = ApplicationDirectoryWatcher.currentTimestamps()
            if self.applications != loadedApplications {
                self.applications = loadedApplications
                self.previousResults = loadedApplications
            }
        }
    }

    func moveSelection(by offset: Int) {
        let count: Int
        if isFileSearchPage {
            count = visibleFileResults.count
        } else if isClipboardPage {
            count = visibleClipboardEntries.count
        } else {
            count = visibleResults.count
        }
        guard count > 0 else { return }

        let nextIndex = selectedIndex + offset
        selectedIndex = ((nextIndex % count) + count) % count
    }

    func result(at index: Int) -> LauncherResult? {
        guard page == .applications else { return nil }
        guard visibleResults.indices.contains(index) else { return nil }
        return visibleResults[index]
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

    func selectedClipboardEntry() -> ClipboardEntry? {
        guard page == .clipboard else { return nil }
        guard visibleClipboardEntries.indices.contains(selectedIndex) else { return nil }
        return visibleClipboardEntries[selectedIndex]
    }

    func recordLaunch(of application: InstalledApplication) {
        launchHistory.recordLaunch(for: application.id)
    }

    func recordOpen(of file: SearchFile) {
        features.recordOpen(of: file)
    }

    func resetForPresentation() {
        features.reset()
        page = .applications
        query = ""
        selectedIndex = 0
        isClipboardFilterPresented = false
    }

    func enterFileSearch() {
        guard features.canEnter(page: .files) else { return }

        page = .files
        features.enter(page: .files)
        query = ""
        selectedIndex = 0
        isClipboardFilterPresented = false
    }

    func exitFileSearch() {
        features.exit(page: .files)
        page = .applications
        query = ""
        selectedIndex = 0
        isClipboardFilterPresented = false
    }

    func enterClipboardHistory() {
        guard features.canEnter(page: .clipboard) else { return }

        page = .clipboard
        features.enter(page: .clipboard)
        query = ""
        selectedIndex = 0
        isClipboardFilterPresented = false
        focusedClipboardFilter = clipboardFilter
    }

    func exitClipboardHistory() {
        features.exit(page: .clipboard)
        page = .applications
        query = ""
        selectedIndex = 0
        isClipboardFilterPresented = false
    }

    func openClipboardFilterDropdown() {
        focusedClipboardFilter = clipboardFilter
        isClipboardFilterPresented = true
    }

    func closeClipboardFilterDropdown() {
        isClipboardFilterPresented = false
    }

    func toggleClipboardFilterPresented() {
        if isClipboardFilterPresented {
            closeClipboardFilterDropdown()
        } else {
            openClipboardFilterDropdown()
        }
    }

    func moveFocusedClipboardFilter(by offset: Int) {
        let all = ClipboardFilter.allCases
        guard let currentIndex = all.firstIndex(of: focusedClipboardFilter) else {
            focusedClipboardFilter = .all
            return
        }
        let nextIndex = (currentIndex + offset + all.count) % all.count
        focusedClipboardFilter = all[nextIndex]
    }

    func applyFocusedClipboardFilter() {
        setClipboardFilter(focusedClipboardFilter)
        closeClipboardFilterDropdown()
    }

    func setClipboardFilter(_ filter: ClipboardFilter) {
        features.clipboard?.setFilter(filter)
        focusedClipboardFilter = filter
        selectedIndex = 0
    }

    func setClipboardCaptureEnabled(_ isEnabled: Bool) {
        features.clipboard?.setCaptureEnabled(isEnabled)
    }

    func toggleClipboardPin(for id: UUID) {
        features.clipboard?.togglePin(for: id)
    }

    func deleteClipboardEntry(withID id: UUID) {
        features.clipboard?.deleteEntry(withID: id)
        selectedIndex = min(selectedIndex, max(visibleClipboardEntries.count - 1, 0))
    }

    func clearClipboardHistory() {
        features.clipboard?.clearHistory()
        selectedIndex = 0
    }

    @discardableResult
    func writeClipboardEntryToPasteboard(_ entry: ClipboardEntry) -> Bool {
        features.clipboard?.writeToPasteboard(entry) ?? false
    }

    func recordColorPickerResult() {
        features.clipboard?.recordColorPickerResult()
    }

    func setClipboardPasteTargetApplication(_ name: String?) {
        clipboardPasteTargetName = name
    }

    func loadClipboardImageData(for id: UUID) -> Data? {
        features.clipboard?.loadImageData(for: id)
    }

    func makeClipboardDragPayload(for entry: ClipboardEntry) -> ClipboardDragPayload? {
        features.clipboard?.makeDragPayload(for: entry)
    }

    private var displayedResults: [LauncherResult] {
        var results = filteredLauncherResults
        let parsed = LauncherQueryParser.parse(query)

        // When a specific filter is active, never pad with fallback applications
        // unless filtering for apps with an empty search term.
        if let filter = parsed.filter {
            if filter != .apps {
                return results
            }
            if !parsed.searchTerm.isEmpty {
                return results
            }
        }

        guard results.count < LauncherMetrics.visibleEntryCount, !applications.isEmpty else {
            return results
        }

        var seenIDs = Set(results.map(\.id))
        let fallbackCandidates = previousResults + applications

        for application in fallbackCandidates where seenIDs.insert(application.id).inserted {
            results.append(.application(application))
            if results.count >= LauncherMetrics.visibleEntryCount {
                break
            }
        }

        return results
    }

    private var filteredLauncherResults: [LauncherResult] {
        let featureResults = features.searchResults(for: query)
        let filter = featureResults.parsedQuery.filter

        let applicationResults: [LauncherResult]
        if filter == nil || filter == .apps {
            let rankedApplications = ApplicationSearch.rankedResults(
                applications,
                query: featureResults.applicationQuery,
                history: launchHistory
            )
            let applicationMatches = Array(rankedApplications.prefix(maximumApplicationResults))
            if page == .applications && !applicationMatches.isEmpty {
                previousResults = applicationMatches
            }
            applicationResults = applicationMatches.map { LauncherResult.application($0) }
        } else {
            applicationResults = []
        }

        return featureResults.leading
            + applicationResults
            + featureResults.trailing
    }
}
