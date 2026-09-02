//
//  ContentView.swift
//  Lightsearch
//
//  The launcher surface is SwiftUI content hosted inside an AppKit NSPanel.
//

import AppKit
import SwiftUI

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
                .frame(height: 64)

            if showsExpandedContent {
                Divider()

                Group {
                    if state.isFileSearchPage {
                        fileResults
                    } else {
                        results
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 12)
            }
        }
        .frame(width: 680, height: showsExpandedContent ? 560 : 64)
        .foregroundStyle(.primary)
        .lightsearchGlass(cornerRadius: 28)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
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
        HStack(spacing: 11) {
            if state.isFileSearchPage {
                Button(action: onBackFromFileSearch) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back to applications")
                .help("Back to applications")
            } else {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 17, weight: .medium))
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
            .frame(height: 26)

            if state.isFileSearchPage {
                if !state.query.isEmpty {
                    Button {
                        state.query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                    .help("Clear search")
                }

                Image(systemName: "folder")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
                    .accessibilityHidden(true)
            } else if !state.query.isEmpty {
                Button {
                    state.query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .help("Clear search")
            }
        }
        .padding(.horizontal, 15)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var results: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollViewReader { proxy in
                ScrollView(.vertical) {
                    LazyVStack(spacing: 5) {
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
                                    .onHover { isHovering in
                                        if isHovering && !state.isKeyboardNavigating {
                                            state.selectedIndex = index
                                        }
                                    }
                            }
                        }
                    }
                    .padding(.horizontal, 2)
                }
                .scrollIndicators(.never)
                .onChange(of: state.selectedIndex) { _, newIndex in
                    guard state.visibleResults.indices.contains(newIndex) else { return }
                    proxy.scrollTo(state.visibleResults[newIndex].id, anchor: nil)
                }
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
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.secondary),
                isSelected: state.selectedIndex == index,
                accessibilityHint: "Search files and folders"
            ) {
                state.selectedIndex = index
                onOpenFileSearch()
            }
        case let .application(application):
            SearchResultRow(
                title: application.name,
                subtitle: application.bundleIdentifier ?? application.path,
                icon: WorkspaceIconView(path: application.path),
                isSelected: state.selectedIndex == index,
                accessibilityHint: "Opens the application"
            ) {
                state.selectedIndex = index
                onOpen(application)
            }
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
                    .font(.system(size: 11, weight: .semibold))
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
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 10)

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
                                    accessibilityHint: file.isDirectory ? "Opens the folder" : "Opens the file"
                                ) {
                                    state.selectedIndex = index
                                    onOpenFile(file)
                                }
                                .id(file.id)
                                .onHover { isHovering in
                                    if isHovering && !state.isKeyboardNavigating {
                                        state.selectedIndex = index
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 2)
                    }
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
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.8)

                Spacer()
            }
            .padding(.horizontal, 10)

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
                                    isSelected: state.selectedIndex == index
                                ) {
                                    state.selectedIndex = index
                                    onOpenFile(file)
                                }
                                .id(file.id)
                                .onHover { isHovering in
                                    if isHovering && !state.isKeyboardNavigating {
                                        state.selectedIndex = index
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 2)
                    }
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
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var fileLoadingState: some View {
        VStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)
            Text("Searching files…")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 25, weight: .medium))
                .foregroundStyle(.secondary)

            Text("No applications found")
                .font(.system(size: 14, weight: .medium))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var fileEmptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 25, weight: .medium))
                .foregroundStyle(.secondary)

            Text("No files found")
                .font(.system(size: 14, weight: .medium))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var recentFilesEmptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "clock")
                .font(.system(size: 25, weight: .medium))
                .foregroundStyle(.secondary)

            Text("No recent files")
                .font(.system(size: 14, weight: .medium))

            Text("Files you open will appear here")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

}

private struct RecentFileCard: View {
    let file: SearchFile
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                VStack(alignment: .leading, spacing: 7) {
                    WorkspaceIconView(path: file.path)
                        .frame(width: 38, height: 38)

                    Text(file.name)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)

                    Text(file.parentPath)
                        .font(.system(size: 9, weight: .regular, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                if isSelected {
                    HStack(spacing: 7) {
                        Image(systemName: "return")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.primary)

                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 11, weight: .semibold))
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
        }
        .buttonStyle(.plain)
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
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 13) {
                icon
                    .frame(width: 34, height: 34)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(subtitle)
                        .font(.system(size: 10, weight: .regular, design: .monospaced))
                        .foregroundStyle(isSelected ? .primary : .secondary)
                        .opacity(isSelected ? 0.85 : 1.0)
                        .lineLimit(1)
                }

                Spacer(minLength: 12)

                if isSelected {
                    HStack(spacing: 7) {
                        Image(systemName: "return")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.primary)

                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.primary)
                            .transition(.opacity)
                    }
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 54)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? Color.accentColor : Color.clear)
            }
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
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
        searchField.font = .systemFont(ofSize: 16, weight: .regular)
        searchField.controlSize = .regular
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
    @ViewBuilder
    func lightsearchGlass(cornerRadius: CGFloat) -> some View {
        if #available(macOS 26.0, *) {
            glassEffect(
                .regular,
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
        } else {
            background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
    }
}
