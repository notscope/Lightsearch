//
//  ContentView.swift
//  Lightsearch
//
//

import AppKit
import SwiftUI

enum LauncherMetrics {
    static let panelWidth: CGFloat = 720
    static let clipboardListWidth: CGFloat = 300
    static let collapsedHeight: CGFloat = 48
    static let dividerHeight: CGFloat = 1
    static var dividerColor: Color {
        Color.primary.opacity(0.10)
    }
    static var selectionColor: Color {
        Color.primary.opacity(0.14)
    }
    static let rowHeight: CGFloat = 54
    static let rowSpacing: CGFloat = 5
    static let conversionLabelHeight: CGFloat = 28
    static let horizontalInset: CGFloat = 12
    static let searchBarHorizontalInset: CGFloat = 18
    static let searchBarSpacing: CGFloat = 12
    static let searchBarFieldHeight: CGFloat = 26
    static let searchBarControlSize: CGFloat = 24
    static let clipboardPreviewHeight: CGFloat = 200
    static let clipboardFooterHeight: CGFloat = 40
    static let footerHorizontalInset: CGFloat = 14
    static let verticalInset: CGFloat = 12
    static let cornerRadius: CGFloat = 16
    static let rowCornerRadius: CGFloat = 10
    static let visibleEntryCount: Int = 7

    /// A conversion card occupies the same vertical space as two rows.
    static var conversionCardHeight: CGFloat {
        (rowHeight * 2) + rowSpacing
    }

    /// Fixed height for every expanded search, including calculator results.
    static var expandedHeight: CGFloat {
        let entriesHeight = (CGFloat(visibleEntryCount) * rowHeight)
            + (CGFloat(max(visibleEntryCount - 1, 0)) * rowSpacing)
        let listContentHeight = (verticalInset * 2) + entriesHeight
        return collapsedHeight + dividerHeight + listContentHeight
    }
}

struct LauncherSearchBar<LeadingContent: View, TrailingContent: View>: View {
    @Binding var text: String

    let placeholder: String
    let onViewCreated: (NSSearchField) -> Void
    let leadingContent: LeadingContent
    let trailingContent: TrailingContent

    init(
        text: Binding<String>,
        placeholder: String,
        onViewCreated: @escaping (NSSearchField) -> Void,
        @ViewBuilder leadingContent: () -> LeadingContent,
        @ViewBuilder trailingContent: () -> TrailingContent
    ) {
        self._text = text
        self.placeholder = placeholder
        self.onViewCreated = onViewCreated
        self.leadingContent = leadingContent()
        self.trailingContent = trailingContent()
    }

    var body: some View {
        HStack(spacing: LauncherMetrics.searchBarSpacing) {
            leadingContent

            SearchFieldRepresentable(
                text: $text,
                placeholder: placeholder,
                onViewCreated: onViewCreated
            )
            .frame(height: LauncherMetrics.searchBarFieldHeight)

            trailingContent
        }
        .padding(.horizontal, LauncherMetrics.searchBarHorizontalInset)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ContentView: View {
    @ObservedObject var state: LauncherState

    let onOpen: (InstalledApplication) -> Void
    let onOpenSystemPreference: (SystemPreference) -> Void
    let onOpenFileSearch: () -> Void
    let onBackFromFileSearch: () -> Void
    let onOpenClipboardHistory: () -> Void
    let onBackFromClipboardHistory: () -> Void
    let onStartColorPicker: () -> Void
    let onPasteClipboardEntry: (ClipboardEntry) -> Void
    let onCopyClipboardEntry: (ClipboardEntry) -> Void
    let onClipboardActionsPresentedChanged: (Bool) -> Void
    let onOpenFile: (SearchFile) -> Void
    let onCopyConversion: (ConversionResult) -> Void
    let onSearchFieldReady: (NSSearchField) -> Void
    let onQueryChanged: (Bool) -> Void

    init(
        state: LauncherState,
        onOpen: @escaping (InstalledApplication) -> Void,
        onOpenSystemPreference: @escaping (SystemPreference) -> Void = { _ in },
        onOpenFileSearch: @escaping () -> Void = {},
        onBackFromFileSearch: @escaping () -> Void = {},
        onOpenClipboardHistory: @escaping () -> Void = {},
        onBackFromClipboardHistory: @escaping () -> Void = {},
        onStartColorPicker: @escaping () -> Void = {},
        onPasteClipboardEntry: @escaping (ClipboardEntry) -> Void = { _ in },
        onCopyClipboardEntry: @escaping (ClipboardEntry) -> Void = { _ in },
        onClipboardActionsPresentedChanged: @escaping (Bool) -> Void = { _ in },
        onOpenFile: @escaping (SearchFile) -> Void = { _ in },
        onCopyConversion: @escaping (ConversionResult) -> Void = { _ in },
        onSearchFieldReady: @escaping (NSSearchField) -> Void = { _ in },
        onQueryChanged: @escaping (Bool) -> Void = { _ in }
    ) {
        self.state = state
        self.onOpen = onOpen
        self.onOpenSystemPreference = onOpenSystemPreference
        self.onOpenFileSearch = onOpenFileSearch
        self.onBackFromFileSearch = onBackFromFileSearch
        self.onOpenClipboardHistory = onOpenClipboardHistory
        self.onBackFromClipboardHistory = onBackFromClipboardHistory
        self.onStartColorPicker = onStartColorPicker
        self.onPasteClipboardEntry = onPasteClipboardEntry
        self.onCopyClipboardEntry = onCopyClipboardEntry
        self.onClipboardActionsPresentedChanged = onClipboardActionsPresentedChanged
        self.onOpenFile = onOpenFile
        self.onCopyConversion = onCopyConversion
        self.onSearchFieldReady = onSearchFieldReady
        self.onQueryChanged = onQueryChanged
    }

    var body: some View {
        Group {
            if state.isClipboardPage {
                ClipboardHistoryView(
                    state: state,
                    onBack: onBackFromClipboardHistory,
                    onPaste: onPasteClipboardEntry,
                    onCopy: onCopyClipboardEntry,
                    onSearchFieldReady: onSearchFieldReady,
                    onActionsPresentedChanged: onClipboardActionsPresentedChanged
                )
            } else {
                launcherContent
            }
        }
        .frame(
            width: LauncherMetrics.panelWidth,
            height: state.isClipboardPage || showsExpandedContent
                ? LauncherMetrics.expandedHeight
                : LauncherMetrics.collapsedHeight
        )
        .systemThemedSurface(cornerRadius: LauncherMetrics.cornerRadius)
        .clipShape(RoundedRectangle(cornerRadius: LauncherMetrics.cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: LauncherMetrics.cornerRadius, style: .continuous)
                .strokeBorder(LauncherMetrics.dividerColor, lineWidth: 0.8)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(
            state.isFileSearchPage
                ? "Lightsearch file search"
                : state.isClipboardPage
                    ? "Lightsearch clipboard history"
                    : "Lightsearch application launcher"
        )
        .onChange(of: state.query) { _, newQuery in
            let hasQuery = !newQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            onQueryChanged(hasQuery || state.isFileSearchPage || state.isClipboardPage)
        }
        .onChange(of: state.applications) { _, applications in
            WorkspaceIconCache.shared.prewarm(paths: applications.map(\.path))
        }
        .onAppear {
            WorkspaceIconCache.shared.prewarm(paths: state.applications.map(\.path))
        }
    }

    private var launcherContent: some View {
        VStack(spacing: 0) {
            searchBar
                .frame(height: LauncherMetrics.collapsedHeight)

            if showsExpandedContent {
                Rectangle()
                    .fill(LauncherMetrics.dividerColor)
                    .frame(height: LauncherMetrics.dividerHeight)

                Group {
                    if state.isFileSearchPage {
                        fileResults
                    } else {
                        results
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private var hasQuery: Bool {
        !state.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var showsExpandedContent: Bool {
        hasQuery || state.isFileSearchPage
    }

    private var searchBar: some View {
        LauncherSearchBar(
            text: $state.query,
            placeholder: state.isFileSearchPage
                ? "Search files and folders..."
                : "Search for apps and commands...",
            onViewCreated: onSearchFieldReady,
            leadingContent: {
                if state.isFileSearchPage {
                    Button(action: onBackFromFileSearch) {
                        Image(systemName: "chevron.left")
                            .font(.title3.weight(.medium))
                            .foregroundStyle(.secondary)
                            .frame(
                                width: LauncherMetrics.searchBarControlSize,
                                height: LauncherMetrics.searchBarControlSize
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Back to applications")
                    .help("Back to applications")
                } else {
                    Image(systemName: "magnifyingglass")
                        .font(.title3.weight(.medium))
                        .foregroundStyle(.secondary)
                        .frame(
                            width: LauncherMetrics.searchBarControlSize,
                            height: LauncherMetrics.searchBarControlSize
                        )
                }
            },
            trailingContent: {
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
                        .frame(
                            width: LauncherMetrics.searchBarControlSize,
                            height: LauncherMetrics.searchBarControlSize
                        )
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
        )
    }

    @ViewBuilder
    private var results: some View {
        if state.visibleResults.isEmpty {
            if state.isLoading && state.applications.isEmpty {
                loadingState
            } else {
                emptyState
            }
        } else {
            ScrollViewReader { proxy in
                ScrollView(.vertical) {
                    LazyVStack(spacing: LauncherMetrics.rowSpacing) {
                        ForEach(Array(state.visibleResults.enumerated()), id: \.element.id) { index, result in
                            resultRow(result, at: index)
                                .id(result.id)
                        }
                    }
                    .padding(.horizontal, LauncherMetrics.horizontalInset)
                }
                .contentMargins(.vertical, LauncherMetrics.verticalInset, for: .scrollContent)
                .onChange(of: state.selectedIndex) { _, newIndex in
                    guard state.visibleResults.indices.contains(newIndex) else { return }
                    proxy.scrollTo(state.visibleResults[newIndex].id, anchor: nil)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    @ViewBuilder
    private func resultRow(_ result: LauncherResult, at index: Int) -> some View {
        let shortcutNumber = index < LauncherMetrics.visibleEntryCount ? index + 1 : nil
        let isCommandPressed = state.isCommandPressed
        switch result {
        case let .conversion(conversion):
            ConversionResultCard(
                conversion: conversion,
                isSelected: state.selectedIndex == index,
                shortcutNumber: shortcutNumber,
                isCommandPressed: isCommandPressed,
                onSelect: {
                    state.selectedIndex = index
                },
                onOpen: {
                    state.selectedIndex = index
                    onCopyConversion(conversion)
                }
            )
        case let .systemPreference(preference):
            SearchResultRow(
                title: preference.title,
                subtitle: preference.subtitle,
                kind: "System Setting",
                icon: WorkspaceIconView(path: preference.iconPath),
                isSelected: state.selectedIndex == index,
                shortcutNumber: shortcutNumber,
                isCommandPressed: isCommandPressed,
                accessibilityHint: "Opens this setting in System Settings",
                onSelect: {
                    state.selectedIndex = index
                },
                onOpen: {
                    state.selectedIndex = index
                    onOpenSystemPreference(preference)
                }
            )
        case .fileSearch:
            SearchResultRow(
                title: "File Search",
                subtitle: "Search files and folders",
                kind: "Action",
                icon: ActionIconView(systemName: "doc.text.magnifyingglass"),
                isSelected: state.selectedIndex == index,
                shortcutNumber: shortcutNumber,
                isCommandPressed: isCommandPressed,
                accessibilityHint: "Search files and folders",
                onSelect: {
                    state.selectedIndex = index
                },
                onOpen: {
                    state.selectedIndex = index
                    onOpenFileSearch()
                }
            )
        case .clipboardHistory:
            SearchResultRow(
                title: "Clipboard History",
                subtitle: "Search and paste copied items",
                kind: "Action",
                icon: ActionIconView(systemName: "clipboard"),
                isSelected: state.selectedIndex == index,
                shortcutNumber: shortcutNumber,
                isCommandPressed: isCommandPressed,
                accessibilityHint: "Opens clipboard history",
                onSelect: {
                    state.selectedIndex = index
                },
                onOpen: {
                    state.selectedIndex = index
                    onOpenClipboardHistory()
                }
            )
        case .colorPicker:
            SearchResultRow(
                title: "Color Picker",
                subtitle: "Pick a color from your screen",
                kind: "Action",
                icon: ActionIconView(systemName: "eyedropper"),
                isSelected: state.selectedIndex == index,
                shortcutNumber: shortcutNumber,
                isCommandPressed: isCommandPressed,
                accessibilityHint: "Picks a color from the screen",
                onSelect: {
                    state.selectedIndex = index
                },
                onOpen: {
                    state.selectedIndex = index
                    onStartColorPicker()
                }
            )
        case let .application(application):
            SearchResultRow(
                title: application.name,
                subtitle: application.bundleIdentifier ?? application.path,
                kind: "Application",
                icon: WorkspaceIconView(path: application.path),
                isSelected: state.selectedIndex == index,
                shortcutNumber: shortcutNumber,
                isCommandPressed: isCommandPressed,
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
        Group {
            if state.isFileSearchLoading && state.fileResults.isEmpty {
                fileLoadingState
            } else if state.visibleFileResults.isEmpty {
                fileEmptyState
            } else {
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
                    .padding(.horizontal, LauncherMetrics.horizontalInset)
                    .padding(.top, 12)

                    ScrollViewReader { proxy in
                        ScrollView(.vertical) {
                            LazyVStack(spacing: 5) {
                                ForEach(Array(state.visibleFileResults.enumerated()), id: \.element.id) { index, file in
                                    SearchResultRow(
                                        title: file.name,
                                        subtitle: file.parentPath,
                                        kind: file.isDirectory ? "Folder" : "File",
                                        icon: WorkspaceIconView(path: file.path),
                                        isSelected: state.selectedIndex == index,
                                        shortcutNumber: index < LauncherMetrics.visibleEntryCount ? index + 1 : nil,
                                        isCommandPressed: state.isCommandPressed,
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
                            .padding(.horizontal, LauncherMetrics.horizontalInset)
                        }
                        .contentMargins(.bottom, 12, for: .scrollContent)
                        .onChange(of: state.selectedIndex) { _, newIndex in
                            guard state.visibleFileResults.indices.contains(newIndex) else { return }
                            proxy.scrollTo(state.visibleFileResults[newIndex].id, anchor: nil)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
    }

    private var recentFileResults: some View {
        Group {
            if state.recentFiles.isEmpty {
                recentFilesEmptyState
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Recent files")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                            .tracking(0.8)

                        Spacer()
                    }
                    .padding(.horizontal, LauncherMetrics.horizontalInset)
                    .padding(.top, 12)

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
                                        shortcutNumber: index < LauncherMetrics.visibleEntryCount ? index + 1 : nil,
                                        isCommandPressed: state.isCommandPressed,
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
                            .padding(.horizontal, LauncherMetrics.horizontalInset)
                        }
                        .contentMargins(.bottom, 12, for: .scrollContent)
                        .onChange(of: state.selectedIndex) { _, newIndex in
                            guard state.visibleFileResults.indices.contains(newIndex) else { return }
                            proxy.scrollTo(state.visibleFileResults[newIndex].id, anchor: nil)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
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
        let parsed = LauncherQueryParser.parse(state.query)
        let image: String
        let title: String
        let subtitle: String

        switch parsed.filter {
        case .apps:
            image = "square.grid.2x2"
            title = "No applications found"
            subtitle = "Check your spelling or try a different search term"
        case .settings:
            image = "gearshape"
            title = "No settings found"
            subtitle = "No system settings match your search"
        case .actions:
            image = "command"
            title = "No actions found"
            subtitle = "No launcher actions match your search"
        case nil:
            image = "magnifyingglass"
            title = "No results found"
            subtitle = "Check your spelling or try a different search term"
        }

        return PlaceholderStateView(
            systemImage: image,
            title: title,
            subtitle: subtitle
        )
    }

    private var fileEmptyState: some View {
        PlaceholderStateView(
            systemImage: "doc.text.magnifyingglass",
            title: "No files found",
            subtitle: "Check your spelling or try searching in another location"
        )
    }

    private var recentFilesEmptyState: some View {
        PlaceholderStateView(
            systemImage: "clock",
            title: "No recent files",
            subtitle: "Files you open will appear here"
        )
    }

}

private struct RecentFileCard: View {
    let file: SearchFile
    let isSelected: Bool
    var shortcutNumber: Int? = nil
    var isCommandPressed: Bool = false
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

            if isCommandPressed, let shortcutNumber {
                KeyboardHintBadge(shortcutNumber)
            } else if isSelected {
                KeyboardHintBadge.action("Open")
                    .transition(.opacity)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 104, maxHeight: 104, alignment: .topLeading)
        .background {
            RoundedRectangle(cornerRadius: LauncherMetrics.rowCornerRadius, style: .continuous)
                .fill(isSelected ? LauncherMetrics.selectionColor : Color.clear)
        }
        .overlay {
            RoundedRectangle(cornerRadius: LauncherMetrics.rowCornerRadius, style: .continuous)
                .strokeBorder(
                    isSelected ? Color.clear : LauncherMetrics.dividerColor,
                    lineWidth: 0.7
                )
        }
        .contentShape(RoundedRectangle(cornerRadius: LauncherMetrics.rowCornerRadius, style: .continuous))
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


private struct ConversionResultCard: View {
    let conversion: ConversionResult
    let isSelected: Bool
    var shortcutNumber: Int? = nil
    var isCommandPressed: Bool = false
    let onSelect: () -> Void
    let onOpen: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            valueColumn(
                value: conversion.inputValue,
                label: conversion.inputLabel
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Image(systemName: "arrow.right")
                .font(.title.weight(.semibold))
                .foregroundStyle(isSelected ? .primary : .secondary)
                .frame(width: 32)

            valueColumn(
                value: conversion.outputValue,
                label: conversion.outputLabel
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(height: LauncherMetrics.conversionCardHeight, alignment: .top)
        .overlay(alignment: .bottom) {
            Text("Calculator")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(isSelected ? Color.primary.opacity(0.7) : Color.secondary)
                .textCase(.uppercase)
                .tracking(0.8)
                .padding(.bottom, 6)
        }
        .overlay(alignment: .topTrailing) {
            if isCommandPressed, let shortcutNumber {
                KeyboardHintBadge(shortcutNumber)
                    .padding(8)
            }
        }
        .background {
            RoundedRectangle(cornerRadius: LauncherMetrics.rowCornerRadius, style: .continuous)
                .fill(isSelected ? LauncherMetrics.selectionColor : Color.conversionContainerBackground)
        }
        .clipShape(RoundedRectangle(cornerRadius: LauncherMetrics.rowCornerRadius, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: LauncherMetrics.rowCornerRadius, style: .continuous))
        .overlay {
            ClickTargetRepresentable(
                onSingleClick: onSelect,
                onDoubleClick: onOpen
            )
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Convert \(conversion.inputValue) to \(conversion.outputValue)"
        )
        .accessibilityHint("Copies the conversion result")
    }

    private func valueColumn(value: String, label: String) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.title.weight(.bold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.65)

            Text(label)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background {
                    Capsule()
                        .fill(isSelected ? Color.primary.opacity(0.18) : Color.conversionPillBackground)
                }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 10)
    }
}

private struct SearchResultRow<Icon: View>: View {
    let title: String
    let subtitle: String?
    var kind: String? = nil
    let icon: Icon
    let isSelected: Bool
    var shortcutNumber: Int? = nil
    var isCommandPressed: Bool = false
    let accessibilityHint: String
    let onSelect: () -> Void
    let onOpen: () -> Void

    var body: some View {
        HStack(spacing: 13) {
            icon
                .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: subtitle == nil ? 0 : 3) {
                Text(title)
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if let subtitle {
                    Text(subtitle)
                        .font(.system(.subheadline, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 12)

            if isCommandPressed, let shortcutNumber {
                KeyboardHintBadge(shortcutNumber)
            } else if isSelected {
                KeyboardHintBadge.action("Open")
                    .transition(.opacity)
            } else if let kind {
                Text(kind)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: LauncherMetrics.rowHeight)
        .background {
            RoundedRectangle(cornerRadius: LauncherMetrics.rowCornerRadius, style: .continuous)
                .fill(isSelected ? LauncherMetrics.selectionColor : Color.clear)
        }
        .contentShape(RoundedRectangle(cornerRadius: LauncherMetrics.rowCornerRadius, style: .continuous))
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

private final class IconStorage: @unchecked Sendable {
    private nonisolated(unsafe) let cache: NSCache<NSString, NSImage> = {
        let cache = NSCache<NSString, NSImage>()
        cache.countLimit = 96
        return cache
    }()

    nonisolated func icon(forPath path: String) -> NSImage {
        let key = path as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }

        let rawIcon = NSWorkspace.shared.icon(forFile: path)
        rawIcon.size = NSSize(width: 34, height: 34)
        cache.setObject(rawIcon, forKey: key)
        return rawIcon
    }

    nonisolated func clear() {
        cache.removeAllObjects()
    }
}

@MainActor
final class WorkspaceIconCache {
    static let shared = WorkspaceIconCache()

    private let storage = IconStorage()
    private var prewarmingTask: Task<Void, Never>?

    func icon(forPath path: String) -> NSImage {
        storage.icon(forPath: path)
    }

    func prewarm(paths: [String]) {
        prewarmingTask?.cancel()

        var seenPaths = Set<String>()
        let paths = paths.filter { path in
            !path.isEmpty && seenPaths.insert(path).inserted
        }
        guard !paths.isEmpty else { return }

        let storage = storage
        prewarmingTask = Task.detached(priority: .utility) {
            for path in paths {
                guard !Task.isCancelled else { return }
                autoreleasepool {
                    _ = storage.icon(forPath: path)
                }
            }
        }
    }

    func clear() {
        prewarmingTask?.cancel()
        prewarmingTask = nil
        storage.clear()
    }
}

private struct ActionIconView: View {
    let systemName: String

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(nsColor: NSColor(name: nil) { appearance in
                                appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                                    ? NSColor(white: 0.28, alpha: 1.0)
                                    : NSColor(white: 0.96, alpha: 1.0)
                            }),
                            Color(nsColor: NSColor(name: nil) { appearance in
                                appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                                    ? NSColor(white: 0.18, alpha: 1.0)
                                    : NSColor(white: 0.86, alpha: 1.0)
                            })
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(
                    Color(nsColor: NSColor(name: nil) { appearance in
                        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                            ? NSColor(white: 1.0, alpha: 0.12)
                            : NSColor(white: 0.0, alpha: 0.10)
                    }),
                    lineWidth: 0.8
                )

            Image(systemName: systemName)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.accentColor)
        }
        .frame(width: 28, height: 28)
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
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
            if icon == nil {
                icon = WorkspaceIconCache.shared.icon(forPath: path)
            }
        }
    }
}

struct SearchFieldRepresentable: NSViewRepresentable {
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

extension Color {
    static var launcherSelection: Color {
        LauncherMetrics.selectionColor
    }

    static var launcherDivider: Color {
        LauncherMetrics.dividerColor
    }

    static let conversionContainerBackground = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(white: 1.0, alpha: 0.10)
            : NSColor(white: 1.0, alpha: 0.65)
    })

    static let conversionPillBackground = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(white: 1.0, alpha: 0.12)
            : NSColor(white: 0.0, alpha: 0.06)
    })
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
