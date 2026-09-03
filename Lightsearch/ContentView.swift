//
//  ContentView.swift
//  Lightsearch
//
//  The launcher surface is SwiftUI content hosted inside an AppKit NSPanel.
//

import AppKit
import SwiftUI

enum LauncherMetrics {
    static let panelWidth: CGFloat = 680
    static let collapsedHeight: CGFloat = 64
    static let dividerHeight: CGFloat = 1
    static let rowHeight: CGFloat = 54
    static let rowSpacing: CGFloat = 5
    static let horizontalInset: CGFloat = 12
    static let verticalInset: CGFloat = 12
    static let cornerRadius: CGFloat = 32
    static let visibleEntryCount: Int = 7

    /// Dynamically computed height to fit exactly `visibleEntryCount` entries before scrolling
    static var expandedHeight: CGFloat {
        let entriesHeight = (CGFloat(visibleEntryCount) * rowHeight) + (CGFloat(visibleEntryCount - 1) * rowSpacing)
        let listContentHeight = (verticalInset * 2) + entriesHeight
        return collapsedHeight + dividerHeight + listContentHeight
    }
}

struct ContentView: View {
    @ObservedObject var state: LauncherState

    let onOpen: (InstalledApplication) -> Void
    let onOpenFileSearch: () -> Void
    let onBackFromFileSearch: () -> Void
    let onOpenFile: (SearchFile) -> Void
    let onSearchFieldReady: (NSSearchField) -> Void
    let onQueryChanged: (Bool) -> Void

    init(
        state: LauncherState,
        onOpen: @escaping (InstalledApplication) -> Void,
        onOpenFileSearch: @escaping () -> Void = {},
        onBackFromFileSearch: @escaping () -> Void = {},
        onOpenFile: @escaping (SearchFile) -> Void = { _ in },
        onSearchFieldReady: @escaping (NSSearchField) -> Void = { _ in },
        onQueryChanged: @escaping (Bool) -> Void = { _ in }
    ) {
        self.state = state
        self.onOpen = onOpen
        self.onOpenFileSearch = onOpenFileSearch
        self.onBackFromFileSearch = onBackFromFileSearch
        self.onOpenFile = onOpenFile
        self.onSearchFieldReady = onSearchFieldReady
        self.onQueryChanged = onQueryChanged
    }

    var body: some View {
        VStack(spacing: 0) {
            searchBar
                .frame(maxWidth: .infinity)
                .frame(height: LauncherMetrics.collapsedHeight)

            if showsExpandedContent {
                Rectangle()
                    .fill(Color(nsColor: .separatorColor))
                    .frame(height: LauncherMetrics.dividerHeight)

                Group {
                    if state.isFileSearchPage {
                        fileResults
                    } else {
                        results
                    }
                }
                .padding(.horizontal, LauncherMetrics.horizontalInset)
            }
        }
        .frame(
            width: LauncherMetrics.panelWidth,
            height: showsExpandedContent ? LauncherMetrics.expandedHeight : LauncherMetrics.collapsedHeight
        )
        .systemThemedSurface(cornerRadius: LauncherMetrics.cornerRadius)
        .clipShape(RoundedRectangle(cornerRadius: LauncherMetrics.cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: LauncherMetrics.cornerRadius, style: .continuous)
                .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.8)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(
            state.isFileSearchPage
                ? "Lightsearch file search"
                : "Lightsearch application launcher"
        )
        .onChange(of: state.query) { _, newQuery in
            let hasQuery = !newQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            onQueryChanged(hasQuery || state.isFileSearchPage)
        }
    }

    private var hasQuery: Bool {
        !state.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var showsExpandedContent: Bool {
        hasQuery || state.isFileSearchPage
    }

    private var searchBar: some View {
        HStack(spacing: 12) {
            if state.isFileSearchPage {
                Button(action: onBackFromFileSearch) {
                    Image(systemName: "chevron.left")
                        .font(.title3.weight(.medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back to applications")
                .help("Back to applications")
            } else {
                Image(systemName: "magnifyingglass")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
            }

            SearchFieldRepresentable(
                text: $state.query,
                placeholder: state.isFileSearchPage
                    ? "Search files and folders..."
                    : "Search for apps and commands...",
                onViewCreated: onSearchFieldReady
            )
            .frame(height: 30)

            if state.isFileSearchPage {
                if !state.query.isEmpty {
                    Button {
                        state.query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.body)
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                    .help("Clear search")
                }

                Image(systemName: "folder")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
                    .accessibilityHidden(true)
            } else if !state.query.isEmpty {
                Button {
                    state.query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.body)
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .help("Clear search")
            }
        }
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var results: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                LazyVStack(spacing: LauncherMetrics.rowSpacing) {
                    if state.visibleResults.isEmpty {
                        if state.isLoading && state.applications.isEmpty {
                            loadingState
                        } else {
                            emptyState
                        }
                    } else {
                        ForEach(Array(state.visibleResults.enumerated()), id: \.element.id) { index, result in
                            resultRow(result, at: index)
                                .id(result.id)
                        }
                    }
                }
            }
            .contentMargins(.vertical, LauncherMetrics.verticalInset, for: .scrollContent)
            .scrollIndicators(.never)
            .onChange(of: state.selectedIndex) { _, newIndex in
                guard state.visibleResults.indices.contains(newIndex) else { return }
                proxy.scrollTo(state.visibleResults[newIndex].id, anchor: nil)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder
    private func resultRow(_ result: LauncherResult, at index: Int) -> some View {
        switch result {
        case .fileSearch:
            SearchResultRow(
                title: "File Search",
                subtitle: "Search files and folders",
                icon: Image(systemName: "doc.text.magnifyingglass")
                    .font(.body.weight(.medium))
                    .foregroundStyle(.secondary),
                isSelected: state.selectedIndex == index,
                accessibilityHint: "Search files and folders",
                onSelect: {
                    state.selectedIndex = index
                },
                onOpen: {
                    state.selectedIndex = index
                    onOpenFileSearch()
                }
            )
        case let .application(application):
            SearchResultRow(
                title: application.name,
                subtitle: application.bundleIdentifier ?? application.path,
                icon: WorkspaceIconView(path: application.path),
                isSelected: state.selectedIndex == index,
                accessibilityHint: "Opens the application",
                onSelect: {
                    state.selectedIndex = index
                },
                onOpen: {
                    state.selectedIndex = index
                    onOpen(application)
                }
            )
        }
    }

    @ViewBuilder
    private var fileResults: some View {
        if hasQuery {
            fileSearchResults
        } else {
            recentFileResults
        }
    }

    private var fileSearchResults: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Files")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.8)

                Spacer()

                if state.isFileSearchLoading {
                    ProgressView()
                        .controlSize(.small)
                        .scaleEffect(0.75)
                } else {
                    Text(state.fileResultCountLabel)
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.top, 12)

            if state.isFileSearchLoading && state.fileResults.isEmpty {
                fileLoadingState
            } else if state.visibleFileResults.isEmpty {
                fileEmptyState
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.vertical) {
                        LazyVStack(spacing: 5) {
                            ForEach(Array(state.visibleFileResults.enumerated()), id: \.element.id) { index, file in
                                SearchResultRow(
                                    title: file.name,
                                    subtitle: file.parentPath,
                                    icon: WorkspaceIconView(path: file.path),
                                    isSelected: state.selectedIndex == index,
                                    accessibilityHint: file.isDirectory ? "Opens the folder" : "Opens the file",
                                    onSelect: {
                                        state.selectedIndex = index
                                    },
                                    onOpen: {
                                        state.selectedIndex = index
                                        onOpenFile(file)
                                    }
                                )
                                .id(file.id)
                            }
                        }
                    }
                    .contentMargins(.bottom, 12, for: .scrollContent)
                    .scrollIndicators(.never)
                    .onChange(of: state.selectedIndex) { _, newIndex in
                        guard state.visibleFileResults.indices.contains(newIndex) else { return }
                        proxy.scrollTo(state.visibleFileResults[newIndex].id, anchor: nil)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var recentFileResults: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Recent files")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.8)

                Spacer()
            }
            .padding(.top, 12)

            if state.recentFiles.isEmpty {
                recentFilesEmptyState
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.vertical) {
                        LazyVGrid(
                            columns: Array(
                                repeating: GridItem(.flexible(), spacing: 8),
                                count: 3
                            ),
                            spacing: 8
                        ) {
                            ForEach(Array(state.visibleFileResults.enumerated()), id: \.element.id) { index, file in
                                RecentFileCard(
                                    file: file,
                                    isSelected: state.selectedIndex == index,
                                    onSelect: {
                                        state.selectedIndex = index
                                    },
                                    onOpen: {
                                        state.selectedIndex = index
                                        onOpenFile(file)
                                    }
                                )
                                .id(file.id)
                            }
                        }
                    }
                    .contentMargins(.bottom, 12, for: .scrollContent)
                    .scrollIndicators(.never)
                    .onChange(of: state.selectedIndex) { _, newIndex in
                        guard state.visibleFileResults.indices.contains(newIndex) else { return }
                        proxy.scrollTo(state.visibleFileResults[newIndex].id, anchor: nil)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var loadingState: some View {
        VStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)
            Text("Looking for installed apps…")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var fileLoadingState: some View {
        VStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)
            Text("Searching files…")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "square.grid.2x2")
                .font(.title2.weight(.medium))
                .foregroundStyle(.secondary)

            Text("No applications found")
                .font(.headline)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var fileEmptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.title2.weight(.medium))
                .foregroundStyle(.secondary)

            Text("No files found")
                .font(.headline)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var recentFilesEmptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "clock")
                .font(.title2.weight(.medium))
                .foregroundStyle(.secondary)

            Text("No recent files")
                .font(.headline)

            Text("Files you open will appear here")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

}

private struct RecentFileCard: View {
    let file: SearchFile
    let isSelected: Bool
    let onSelect: () -> Void
    let onOpen: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 7) {
                WorkspaceIconView(path: file.path)
                    .frame(width: 38, height: 38)

                Text(file.name)
                    .font(.body.weight(.medium))
                    .lineLimit(1)

                Text(file.parentPath)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            if isSelected {
                HStack(spacing: 7) {
                    Image(systemName: "return")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)

                    Image(systemName: "arrow.up.right")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 104, maxHeight: 104, alignment: .topLeading)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isSelected ? Color.accentColor : Color.clear)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(
                    isSelected ? Color.clear : Color(nsColor: .separatorColor).opacity(0.4),
                    lineWidth: 0.7
                )
        }
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            ClickTargetRepresentable(
                onSingleClick: onSelect,
                onDoubleClick: onOpen
            )
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(file.name)
        .accessibilityHint(file.isDirectory ? "Opens the folder" : "Opens the file")
    }
}

private struct SearchResultRow<Icon: View>: View {
    let title: String
    let subtitle: String
    let icon: Icon
    let isSelected: Bool
    let accessibilityHint: String
    let onSelect: () -> Void
    let onOpen: () -> Void

    var body: some View {
        HStack(spacing: 13) {
            icon
                .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(subtitle)
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .opacity(isSelected ? 0.85 : 1.0)
                    .lineLimit(1)
            }

            Spacer(minLength: 12)

            if isSelected {
                HStack(spacing: 7) {
                    Image(systemName: "return")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)

                    Image(systemName: "arrow.up.right")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .transition(.opacity)
                }
            }
        }
        .padding(.horizontal, 12)
        .frame(height: LauncherMetrics.rowHeight)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isSelected ? Color.accentColor : Color.clear)
        }
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            ClickTargetRepresentable(
                onSingleClick: onSelect,
                onDoubleClick: onOpen
            )
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityHint(accessibilityHint)
    }
}

private struct WorkspaceIconView: View {
    let path: String

    @State private var icon: NSImage?

    var body: some View {
        Group {
            if let icon {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
            } else {
                Image(systemName: "app.fill")
                    .resizable()
                    .scaledToFit()
                    .padding(6)
                    .foregroundStyle(.secondary)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onAppear {
            guard icon == nil else { return }
            icon = NSWorkspace.shared.icon(forFile: path)
        }
    }
}

private struct SearchFieldRepresentable: NSViewRepresentable {
    @Binding var text: String

    let placeholder: String
    let onViewCreated: (NSSearchField) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSSearchField {
        let searchField = NSSearchField()
        searchField.delegate = context.coordinator
        searchField.placeholderString = placeholder
        searchField.isBordered = false
        searchField.drawsBackground = false
        searchField.focusRingType = .none
        searchField.font = .preferredFont(forTextStyle: .title2)
        searchField.controlSize = .large
        searchField.cell?.lineBreakMode = .byTruncatingTail
        if let searchCell = searchField.cell as? NSSearchFieldCell {
            // The magnifying glass and clear affordance are owned by the
            // surrounding SwiftUI bar, so the native field does not render a
            // second copy of either control.
            searchCell.searchButtonCell = nil
            searchCell.cancelButtonCell = nil
        }
        onViewCreated(searchField)
        return searchField
    }

    func updateNSView(_ searchField: NSSearchField, context: Context) {
        context.coordinator.parent = self
        searchField.placeholderString = placeholder
        if searchField.stringValue != text {
            searchField.stringValue = text
        }
    }

    final class Coordinator: NSObject, NSSearchFieldDelegate {
        var parent: SearchFieldRepresentable

        init(_ parent: SearchFieldRepresentable) {
            self.parent = parent
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let searchField = notification.object as? NSSearchField else { return }
            if parent.text != searchField.stringValue {
                parent.text = searchField.stringValue
            }
        }
    }
}

private extension View {
    func systemThemedSurface(cornerRadius: CGFloat) -> some View {
        background(
            .thickMaterial,
            in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        )
    }
}

private struct ClickTargetRepresentable: NSViewRepresentable {
    let onSingleClick: () -> Void
    let onDoubleClick: () -> Void

    func makeNSView(context: Context) -> ClickTargetView {
        let view = ClickTargetView()
        view.onSingleClick = onSingleClick
        view.onDoubleClick = onDoubleClick
        return view
    }

    func updateNSView(_ nsView: ClickTargetView, context: Context) {
        nsView.onSingleClick = onSingleClick
        nsView.onDoubleClick = onDoubleClick
    }

    final class ClickTargetView: NSView {
        var onSingleClick: (() -> Void)?
        var onDoubleClick: (() -> Void)?

        override func mouseDown(with event: NSEvent) {
            if event.clickCount == 2 {
                onDoubleClick?()
            } else {
                onSingleClick?()
            }
        }
    }
}
