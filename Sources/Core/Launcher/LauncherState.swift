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

    private var hasStartedLoading = false
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
        Array(
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
            self.isLoading = false
            self.selectedIndex = 0
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
    }

    func enterFileSearch() {
        guard features.canEnter(page: .files) else { return }

        page = .files
        features.enter(page: .files)
        query = ""
        selectedIndex = 0
    }

    func exitFileSearch() {
        features.exit(page: .files)
        page = .applications
        query = ""
        selectedIndex = 0
    }

    func enterClipboardHistory() {
        guard features.canEnter(page: .clipboard) else { return }

        page = .clipboard
        features.enter(page: .clipboard)
        query = ""
        selectedIndex = 0
    }

    func exitClipboardHistory() {
        features.exit(page: .clipboard)
        page = .applications
        query = ""
        selectedIndex = 0
    }

    func setClipboardFilter(_ filter: ClipboardFilter) {
        features.clipboard?.setFilter(filter)
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

    private var displayedResults: [LauncherResult] {
        var results = filteredLauncherResults
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
        let rankedApplications = ApplicationSearch.rankedResults(
            applications,
            query: featureResults.applicationQuery,
            history: launchHistory
        )
        let applicationMatches = Array(rankedApplications.prefix(maximumApplicationResults))
        if page == .applications && !applicationMatches.isEmpty {
            previousResults = applicationMatches
        }
        let applicationResults = applicationMatches.map { LauncherResult.application($0) }

        return featureResults.leading
            + applicationResults
            + featureResults.trailing
    }
}
