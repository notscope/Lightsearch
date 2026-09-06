//
//  ClipboardHistoryView.swift
//  Lightsearch
//
// Clipboard history presentation based on the supplied two-pane design.

import AppKit
import ImageIO
import SwiftUI

private enum ClipboardAction: CaseIterable, Hashable {
    case pasteToClipboard
    case pin
    case delete
    case capture
    case clear
}

private enum ClipboardConfirmationAction: CaseIterable, Hashable {
    case cancel
    case clear
}

struct ClipboardHistoryView: View {
    @ObservedObject var state: LauncherState

    let onBack: () -> Void
    let onPaste: (ClipboardEntry) -> Void
    let onCopy: (ClipboardEntry) -> Void
    let onSearchFieldReady: (NSSearchField) -> Void
    let onActionsPresentedChanged: (Bool) -> Void

    @State private var isActionsPresented = false
    @State private var isClearConfirmationPresented = false
    @State private var isHoveringPaste = false
    @State private var isHoveringActions = false
    @FocusState private var focusedAction: ClipboardAction?
    @FocusState private var focusedConfirmationAction: ClipboardConfirmationAction?

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                searchBar
                    .frame(height: LauncherMetrics.collapsedHeight)

                Rectangle()
                    .fill(LauncherMetrics.dividerColor)
                    .frame(height: LauncherMetrics.dividerHeight)

                if groupedEntries.isEmpty {
                    clipboardList
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    HStack(spacing: 0) {
                        clipboardList
                            .frame(width: LauncherMetrics.clipboardListWidth)

                        Rectangle()
                            .fill(LauncherMetrics.dividerColor)
                            .frame(width: LauncherMetrics.dividerHeight)

                        clipboardDetails
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }

                Rectangle()
                    .fill(LauncherMetrics.dividerColor)
                    .frame(height: LauncherMetrics.dividerHeight)

                clipboardFooter
            }

            if isActionsPresented, let entry = state.selectedClipboardEntry() {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        dismissActions()
                    }
                    .accessibilityHidden(true)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .zIndex(1)

                actionPopover(for: entry)
                    .padding(.trailing, LauncherMetrics.footerHorizontalInset)
                    .padding(
                        .bottom,
                        LauncherMetrics.clipboardFooterHeight
                            + LauncherMetrics.dividerHeight
                            + 8
                    )
                    .zIndex(2)
            }

            if isClearConfirmationPresented {
                Color.black.opacity(0.42)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        dismissClearConfirmation()
                    }
                    .accessibilityHidden(true)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .zIndex(3)

                clearConfirmationDialog
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .zIndex(4)
            }
        }
        .onChange(of: isActionsPresented) { _, isPresented in
            onActionsPresentedChanged(isPresented || isClearConfirmationPresented)
            focusedAction = isPresented ? .pasteToClipboard : nil
        }
        .onChange(of: isClearConfirmationPresented) { _, isPresented in
            onActionsPresentedChanged(isPresented || isActionsPresented)
            focusedConfirmationAction = isPresented ? .cancel : nil
        }
    }

    private var searchBar: some View {
        LauncherSearchBar(
            text: $state.query,
            placeholder: "Type to filter entries...",
            onViewCreated: onSearchFieldReady,
            leadingContent: {
                Button(action: onBack) {
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
            },
            trailingContent: {
                Menu {
                    ForEach(ClipboardFilter.allCases) { filter in
                        Button {
                            state.setClipboardFilter(filter)
                        } label: {
                            if state.clipboardFilter == filter {
                                Label(filter.title, systemImage: "checkmark")
                            } else {
                                Text(filter.title)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: state.clipboardFilter.systemImageName)
                            .font(.title3.weight(.medium))
                        Text(state.clipboardFilter.title)
                            .font(.title3)
                        Image(systemName: "chevron.down")
                            .font(.caption.weight(.bold))
                    }
                    .foregroundStyle(.secondary)
                    .contentShape(Rectangle())
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .accessibilityLabel("Clipboard type filter")
                .help("Filter clipboard entries by type")
            }
        )
    }

    private var clipboardList: some View {
        Group {
            if groupedEntries.isEmpty {
                clipboardEmptyState
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.vertical) {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(groupedEntries) { group in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(group.title)
                                        .font(.headline.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 2)
                                        .padding(.top, group.title == "Pinned" ? 0 : 4)
                                        .id(group.id)

                                    ForEach(group.entries) { indexedEntry in
                                        ClipboardEntryRow(
                                            entry: indexedEntry.entry,
                                            isSelected: state.selectedClipboardEntry()?.id
                                                == indexedEntry.entry.id,
                                            onSelect: {
                                                state.selectedIndex = indexedEntry.index
                                            },
                                            onOpen: {
                                                state.selectedIndex = indexedEntry.index
                                                onPaste(indexedEntry.entry)
                                            },
                                            onDrag: {
                                                state.makeClipboardDragPayload(for: indexedEntry.entry)
                                            }
                                        )
                                        .id(indexedEntry.entry.id)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 12)
                    }
                    .contentMargins(.vertical, LauncherMetrics.verticalInset, for: .scrollContent)
                    .onChange(of: state.selectedIndex) { _, newIndex in
                        guard state.visibleClipboardEntries.indices.contains(newIndex) else { return }
                        if newIndex == 0, let topID = groupedEntries.first?.id {
                            proxy.scrollTo(topID, anchor: .top)
                        } else if newIndex == state.visibleClipboardEntries.count - 1 {
                            proxy.scrollTo(state.visibleClipboardEntries[newIndex].id, anchor: .bottom)
                        } else {
                            proxy.scrollTo(state.visibleClipboardEntries[newIndex].id, anchor: nil)
                        }
                    }
                    .onChange(of: state.query) { _, _ in
                        if let topID = groupedEntries.first?.id {
                            proxy.scrollTo(topID, anchor: .top)
                        }
                    }
                    .onChange(of: state.clipboardFilter) { _, _ in
                        if let topID = groupedEntries.first?.id {
                            proxy.scrollTo(topID, anchor: .top)
                        }
                    }
                }
            }
        }
        .frame(maxHeight: .infinity)
    }

    private var clipboardDetails: some View {
        Group {
            if let entry = state.selectedClipboardEntry() {
                VStack(spacing: 0) {
                    ClipboardPreview(entry: entry, state: state)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, LauncherMetrics.footerHorizontalInset)
                        .padding(.top, LauncherMetrics.footerHorizontalInset)

                    ScrollView(.vertical) {
                        VStack(alignment: .leading, spacing: 7) {
                            Text("Information")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(.secondary)

                            information(for: entry)
                        }
                        .padding(.horizontal, LauncherMetrics.footerHorizontalInset)
                        .padding(.bottom, LauncherMetrics.footerHorizontalInset)
                    }
                    .scrollIndicators(.automatic)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
        .frame(maxHeight: .infinity)
    }

    private var clipboardFooter: some View {
        HStack(spacing: 0) {
            clipboardFooterLabel

            Spacer(minLength: 16)

            if let entry = state.selectedClipboardEntry() {
                clipboardActionBar(for: entry)
            }
        }
        .padding(.horizontal, LauncherMetrics.footerHorizontalInset)
        .frame(height: LauncherMetrics.clipboardFooterHeight)
    }

    private var groupedEntries: [ClipboardEntryGroup] {
        var groups: [ClipboardEntryGroup] = []
        var currentGroupID: String?

        for (index, entry) in state.visibleClipboardEntries.enumerated() {
            let title = groupTitle(for: entry)
            if title != currentGroupID {
                groups.append(ClipboardEntryGroup(title: title, entries: []))
                currentGroupID = title
            }
            groups[groups.count - 1].entries.append(
                IndexedClipboardEntry(index: index, entry: entry)
            )
        }
        return groups
    }

    private func groupTitle(for entry: ClipboardEntry) -> String {
        if entry.isPinned {
            return "Pinned"
        }

        let calendar = Calendar.current
        if calendar.isDateInToday(entry.lastCopiedAt) {
            return "Today"
        }
        if calendar.isDateInYesterday(entry.lastCopiedAt) {
            return "Yesterday"
        }
        if let weekInterval = calendar.dateInterval(of: .weekOfYear, for: Date()),
           entry.lastCopiedAt >= weekInterval.start {
            return "This Week"
        }

        return entry.lastCopiedAt.formatted(.dateTime.month(.abbreviated).day())
    }

    private func information(for entry: ClipboardEntry) -> some View {
        let source = entry.source ?? (entry.kind == .color ? .lightsearch : nil)

        return VStack(spacing: 2) {
            informationRow(
                title: "Source",
                value: source?.displayName ?? "Unknown Application",
                iconPath: source?.bundlePath
            )
            informationRow(title: "Type", value: entry.kind.title)

            switch entry.kind {
            case .image:
                if let dimensions = entry.dimensionsLabel {
                    informationRow(title: "Dimensions", value: dimensions)
                }
            case .link:
                if let urlString = entry.urlString {
                    informationRow(title: "URL", value: urlString)
                    informationRow(title: "Title", value: entry.title)
                }
            case .text:
                informationRow(title: "Characters", value: "\(entry.characterCount)")
                informationRow(title: "Words", value: "\(entry.wordCount)")
            case .file:
                if let path = entry.payload.filePaths.first {
                    informationRow(title: "Location", value: path)
                }
            case .color:
                if let colorHex = entry.colorHex {
                    informationRow(title: "Hex", value: colorHex)
                }
            }

            informationRow(title: "Size", value: entry.sizeLabel)
            informationRow(title: "Times copied", value: "\(entry.copyCount)")
            informationRow(title: "Last copied", value: formattedDate(entry.lastCopiedAt))
            informationRow(title: "First copied", value: formattedDate(entry.firstCopiedAt))
        }
    }

    private func informationRow(
        title: String,
        value: String,
        iconPath: String? = nil
    ) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.callout.weight(.medium))
                .foregroundStyle(.secondary)

            Spacer(minLength: 12)

            HStack(spacing: 6) {
                if let iconPath {
                    ClipboardSourceIcon(path: iconPath)
                        .frame(width: 18, height: 18)
                }
                Text(value)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .padding(.horizontal, 10)
        .frame(minHeight: 34)
        .background {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.primary.opacity(0.045))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(value)")
    }

    private func clipboardActionBar(for entry: ClipboardEntry) -> some View {
        HStack(spacing: 12) {
            Button {
                onPaste(entry)
            } label: {
                HStack(spacing: 5) {
                    Text("Paste to \(state.clipboardTargetApplicationName)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(isHoveringPaste ? Color.primary : Color.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    KeycapView(symbol: "↵")
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onHover { isHoveringPaste = $0 }
            .accessibilityLabel("Paste to \(state.clipboardTargetApplicationName)")

            Button {
                isActionsPresented.toggle()
            } label: {
                HStack(spacing: 5) {
                    Text("Actions")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(
                            isHoveringActions || isActionsPresented
                                ? Color.primary
                                : Color.secondary
                        )
                    KeycapView(symbol: "⌘K")
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onHover { isHoveringActions = $0 }
            .keyboardShortcut("k", modifiers: .command)
            .accessibilityLabel("Clipboard actions")
        }
    }

    private func actionPopover(for entry: ClipboardEntry) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            actionButton(
                .pasteToClipboard,
                title: "Paste to Clipboard",
                systemImage: "doc.on.clipboard",
                entry: entry
            )
            .keyboardShortcut("c", modifiers: .command)

            actionButton(
                .pin,
                title: entry.isPinned ? "Unpin Entry" : "Pin Entry",
                systemImage: entry.isPinned ? "pin.slash" : "pin",
                entry: entry
            )
            .keyboardShortcut("p", modifiers: .command)

            actionButton(
                .delete,
                title: "Delete Entry",
                systemImage: "trash",
                entry: entry
            )
            .keyboardShortcut(.delete, modifiers: [])

            Rectangle()
                .fill(LauncherMetrics.dividerColor)
                .frame(height: 1)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)

            actionButton(
                .capture,
                title: state.isClipboardCapturing ? "Pause Capture" : "Resume Capture",
                systemImage: state.isClipboardCapturing ? "pause.circle" : "play.circle",
                entry: entry
            )

            actionButton(
                .clear,
                title: "Clear History…",
                systemImage: "trash.fill",
                entry: entry,
                isDestructive: true
            )
        }
        .padding(10)
        .frame(width: 200, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.18), lineWidth: 0.8)
        }
        .shadow(color: .black.opacity(0.24), radius: 12, y: 4)
        .onKeyPress(
            keys: [
                .upArrow,
                .downArrow,
                .tab,
                .return,
                .space,
                .escape,
                .delete
            ]
        ) { press in
            handleActionKeyPress(press)
        }
        .onAppear {
            focusedAction = .pasteToClipboard
        }
        .onDisappear {
            if !isClearConfirmationPresented {
                onActionsPresentedChanged(false)
            }
            focusedAction = nil
        }
    }

    private var clearConfirmationDialog: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Clear Clipboard History?")
                    .font(.title3.weight(.bold))

                Text("All unpinned and pinned clipboard entries will be removed from this Mac.")
                    .font(.body)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 10) {
                confirmationButton(.cancel, title: "Cancel")
                confirmationButton(.clear, title: "Clear History", isDestructive: true)
            }
        }
        .padding(22)
        .frame(width: 430)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.2), lineWidth: 0.8)
        }
        .shadow(color: .black.opacity(0.28), radius: 18, y: 8)
        .onAppear {
            focusedConfirmationAction = .cancel
        }
    }

    private func confirmationButton(
        _ action: ClipboardConfirmationAction,
        title: String,
        isDestructive: Bool = false
    ) -> some View {
        Button {
            performConfirmationAction(action)
        } label: {
            Text(title)
                .font(.body.weight(.semibold))
                .foregroundStyle(isDestructive ? Color.red : Color.primary)
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .background {
                    Capsule()
                        .fill(
                            focusedConfirmationAction == action
                                ? (isDestructive
                                    ? Color.red.opacity(0.2)
                                    : Color.primary.opacity(0.15))
                                : Color.primary.opacity(0.08)
                        )
                }
        }
        .buttonStyle(.plain)
        .focusable()
        .focused($focusedConfirmationAction, equals: action)
        .focusEffectDisabled()
        .onKeyPress(
            keys: [
                .leftArrow,
                .rightArrow,
                .upArrow,
                .downArrow,
                .tab,
                .return,
                .space,
                .escape
            ]
        ) { press in
            handleConfirmationKeyPress(press)
        }
    }

    private func handleConfirmationKeyPress(_ press: KeyPress) -> KeyPress.Result {
        switch press.key {
        case .leftArrow, .upArrow:
            moveConfirmation(by: -1)
            return .handled
        case .rightArrow, .downArrow:
            moveConfirmation(by: 1)
            return .handled
        case .tab:
            moveConfirmation(by: press.modifiers.contains(.shift) ? -1 : 1)
            return .handled
        case .return, .space:
            guard let focusedConfirmationAction else {
                return .ignored
            }
            performConfirmationAction(focusedConfirmationAction)
            return .handled
        case .escape:
            dismissClearConfirmation()
            return .handled
        default:
            return .ignored
        }
    }

    private func moveConfirmation(by offset: Int) {
        guard let focusedConfirmationAction,
              let currentIndex = ClipboardConfirmationAction.allCases.firstIndex(
                  of: focusedConfirmationAction
              ) else {
            self.focusedConfirmationAction = .cancel
            return
        }

        let nextIndex = (currentIndex + offset + ClipboardConfirmationAction.allCases.count)
            % ClipboardConfirmationAction.allCases.count
        self.focusedConfirmationAction = ClipboardConfirmationAction.allCases[nextIndex]
    }

    private func performConfirmationAction(_ action: ClipboardConfirmationAction) {
        switch action {
        case .cancel:
            dismissClearConfirmation()
        case .clear:
            dismissClearConfirmation()
            state.clearClipboardHistory()
        }
    }

    private func dismissClearConfirmation() {
        isClearConfirmationPresented = false
        focusedConfirmationAction = nil
    }

    private func actionButton(
        _ action: ClipboardAction,
        title: String,
        systemImage: String,
        entry: ClipboardEntry,
        isDestructive: Bool = false
    ) -> some View {
        Button {
            performAction(action, for: entry)
        } label: {
            Label(title, systemImage: systemImage)
                .font(.body)
                .foregroundStyle(isDestructive ? Color.red : Color.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .frame(height: 32)
                .background(
                    focusedAction == action
                        ? LauncherMetrics.selectionColor
                        : Color.clear,
                    in: RoundedRectangle(cornerRadius: 7, style: .continuous)
                )
        }
        .buttonStyle(.plain)
        .focusable()
        .focused($focusedAction, equals: action)
        .focusEffectDisabled()
    }

    private func handleActionKeyPress(_ press: KeyPress) -> KeyPress.Result {
        switch press.key {
        case .upArrow:
            moveAction(by: -1)
            return .handled
        case .downArrow:
            moveAction(by: 1)
            return .handled
        case .tab:
            moveAction(by: press.modifiers.contains(.shift) ? -1 : 1)
            return .handled
        case .return, .space:
            guard let focusedAction,
                  let entry = state.selectedClipboardEntry() else {
                return .ignored
            }
            performAction(focusedAction, for: entry)
            return .handled
        case .escape:
            dismissActions()
            return .handled
        case .delete:
            guard focusedAction == .delete,
                  let entry = state.selectedClipboardEntry() else {
                return .ignored
            }
            performAction(.delete, for: entry)
            return .handled
        default:
            return .ignored
        }
    }

    private func moveAction(by offset: Int) {
        guard let focusedAction,
              let currentIndex = ClipboardAction.allCases.firstIndex(of: focusedAction) else {
            self.focusedAction = .pasteToClipboard
            return
        }

        let nextIndex = (currentIndex + offset + ClipboardAction.allCases.count)
            % ClipboardAction.allCases.count
        self.focusedAction = ClipboardAction.allCases[nextIndex]
    }

    private func performAction(_ action: ClipboardAction, for entry: ClipboardEntry) {
        if action == .clear {
            onActionsPresentedChanged(true)
            isClearConfirmationPresented = true
        }
        dismissActions()

        switch action {
        case .pasteToClipboard:
            onCopy(entry)
        case .pin:
            state.toggleClipboardPin(for: entry.id)
        case .delete:
            state.deleteClipboardEntry(withID: entry.id)
        case .capture:
            state.setClipboardCaptureEnabled(!state.isClipboardCapturing)
        case .clear:
            break
        }
    }

    private func dismissActions() {
        isActionsPresented = false
        focusedAction = nil
    }

    private var clipboardFooterLabel: some View {
        HStack(spacing: 7) {
            Image(systemName: "clipboard")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            Text("Clipboard History")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Clipboard History")
    }

    private var clipboardEmptyState: some View {
        PlaceholderStateView(
            systemImage: "clipboard",
            title: state.query.isEmpty ? "No clipboard entries" : "No matching entries",
            subtitle: state.query.isEmpty
                ? (state.isClipboardCapturing
                    ? "Copied text, links, images, files, and colors will appear here"
                    : "Clipboard capture is paused")
                : "Check your spelling or try a different search term"
        )
    }


    private func formattedDate(_ date: Date) -> String {
        date.formatted(
            .dateTime
                .day()
                .month(.abbreviated)
                .year()
                .hour()
                .minute()
                .second()
        )
    }
}

private struct ClipboardEntryGroup: Identifiable {
    let title: String
    var entries: [IndexedClipboardEntry]

    var id: String { title }
}

private struct IndexedClipboardEntry: Identifiable {
    let index: Int
    let entry: ClipboardEntry

    var id: UUID { entry.id }
}

private struct ClipboardEntryRow: View {
    let entry: ClipboardEntry
    let isSelected: Bool
    let onSelect: () -> Void
    let onOpen: () -> Void
    let onDrag: () -> ClipboardDragPayload?

    var body: some View {
        HStack(spacing: 13) {
            ClipboardEntryThumbnail(entry: entry)
                .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: entry.subtitle == nil ? 0 : 2) {
                Text(entry.title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if let subtitle = entry.subtitle {
                    Text(subtitle)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 6)

            if entry.isPinned {
                Image(systemName: "pin.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 48)
        .background {
            RoundedRectangle(cornerRadius: LauncherMetrics.rowCornerRadius, style: .continuous)
                .fill(isSelected ? LauncherMetrics.selectionColor : Color.clear)
        }
        .contentShape(RoundedRectangle(cornerRadius: LauncherMetrics.rowCornerRadius, style: .continuous))
        .overlay {
            ClipboardClickTargetRepresentable(
                onSingleClick: onSelect,
                onDoubleClick: onOpen,
                onDrag: onDrag
            )
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(entry.title)
        .accessibilityHint("Selects the clipboard entry. Double-click to paste.")
    }
}

private struct ClipboardEntryThumbnail: View {
    let entry: ClipboardEntry

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.primary.opacity(0.10))

            if entry.kind == .color,
               let colorHex = entry.colorHex,
               let color = ClipboardColorCodec.color(fromHex: colorHex) {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color(nsColor: color))
                    .overlay {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .strokeBorder(.white.opacity(0.8), lineWidth: 1)
                    }
                    .padding(1)
            } else if entry.kind == .image, let thumbnailData = entry.payload.thumbnailData ?? entry.payload.imageData {
                ClipboardThumbnailImageView(data: thumbnailData)
                    .padding(2)
            } else {
                Image(systemName: entry.kind.systemImageName)
                    .font(.title3.weight(.medium))
                    .foregroundStyle(entry.kind == .link ? .pink : .secondary)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
}

private struct ClipboardPreview: View {
    let entry: ClipboardEntry
    let state: LauncherState

    var body: some View {
        Group {
            switch entry.kind {
            case .text:
                textPreview
            case .link:
                linkPreview
            case .image:
                imagePreview
            case .file:
                filePreview
            case .color:
                colorPreview
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: LauncherMetrics.clipboardPreviewHeight)
    }

    private var textPreview: some View {
        ScrollView(.vertical) {
            Text(entry.previewText ?? "Rich text")
                .font(.system(.callout, design: .monospaced))
                .foregroundStyle(.white)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityLabel(entry.previewText ?? "Rich text preview")
    }

    private var linkPreview: some View {
        VStack(spacing: 14) {
            Image(systemName: "link.circle.fill")
                .font(.system(size: 44, weight: .medium))
                .foregroundStyle(.pink)

            Text(entry.title)
                .font(.headline.weight(.semibold))
                .lineLimit(2)
                .multilineTextAlignment(.center)

            Text(entry.urlString ?? "")
                .font(.system(.callout, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var imagePreview: some View {
        ClipboardImagePreviewView(entry: entry, state: state)
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var filePreview: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.on.doc.fill")
                .font(.system(size: 42, weight: .medium))
                .foregroundStyle(.secondary)
            Text(entry.title)
                .font(.headline.weight(.semibold))
                .lineLimit(2)
            if let subtitle = entry.subtitle {
                Text(subtitle)
                    .font(.system(.callout, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var colorPreview: some View {
        Group {
            if let colorHex = entry.colorHex,
               let color = ClipboardColorCodec.color(fromHex: colorHex) {
                VStack(alignment: .leading, spacing: 0) {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(nsColor: color))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(.white, lineWidth: 3)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 142)
                        .padding(8)

                    Text(colorHex)
                        .font(.system(.headline, design: .monospaced).weight(.medium))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 15)
                }
                .frame(width: 300)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else {
                Image(systemName: "eyedropper")
                    .font(.system(size: 46, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityLabel(entry.colorHex ?? "Color preview")
    }
}

private struct ClipboardThumbnailImageView: View {
    let data: Data

    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
            } else {
                Color.clear
            }
        }
        .task(id: data) {
            image = ClipboardThumbnailCache.image(for: data)
        }
    }
}

private enum ClipboardThumbnailCache {
    private static let cache: NSCache<NSData, NSImage> = {
        let cache = NSCache<NSData, NSImage>()
        cache.countLimit = 160
        return cache
    }()

    static func image(for data: Data) -> NSImage? {
        let key = data as NSData
        if let cached = cache.object(forKey: key) {
            return cached
        }
        guard let image = ClipboardThumbnailGenerator.downsampleToThumbnail(from: data, maxPixelSize: 96)
            ?? NSImage(data: data) else { return nil }
        cache.setObject(image, forKey: key)
        return image
    }
}

private struct ClipboardImagePreviewView: View {
    let entry: ClipboardEntry
    let state: LauncherState

    @State private var displayImage: NSImage?
    @State private var isLoading = true

    var body: some View {
        ZStack {
            if let displayImage {
                Image(nsImage: displayImage)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
            } else if isLoading {
                ProgressView()
                    .controlSize(.small)
            } else if let thumbnailData = entry.payload.thumbnailData,
                      let thumb = NSImage(data: thumbnailData) {
                Image(nsImage: thumb)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(maxWidth: 160, maxHeight: 160)
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
            }
        }
        .task(id: entry.id) {
            await loadPreviewImage()
        }
        .onDisappear {
            displayImage = nil
        }
    }

    private func loadPreviewImage() async {
        isLoading = true
        let entryID = entry.id
        let rawData = entry.payload.imageData
            ?? state.loadClipboardImageData(for: entryID)
            ?? entry.payload.thumbnailData

        guard let rawData else {
            isLoading = false
            return
        }

        let image = await Task.detached(priority: .userInitiated) { () -> NSImage? in
            NSImage(data: rawData)
        }.value

        guard !Task.isCancelled else { return }
        self.displayImage = image
        self.isLoading = false
    }
}

private struct ClipboardSourceIcon: View {
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
                    .foregroundStyle(.secondary)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        .task {
            icon = NSWorkspace.shared.icon(forFile: path)
        }
    }
}

private struct ClipboardClickTargetRepresentable: NSViewRepresentable {
    let onSingleClick: () -> Void
    let onDoubleClick: () -> Void
    let onDrag: () -> ClipboardDragPayload?

    func makeNSView(context: Context) -> ClickTargetView {
        let view = ClickTargetView()
        view.onSingleClick = onSingleClick
        view.onDoubleClick = onDoubleClick
        view.onDrag = onDrag
        return view
    }

    func updateNSView(_ nsView: ClickTargetView, context: Context) {
        nsView.onSingleClick = onSingleClick
        nsView.onDoubleClick = onDoubleClick
        nsView.onDrag = onDrag
    }

    final class ClickTargetView: NSView, NSDraggingSource {
        var onSingleClick: (() -> Void)?
        var onDoubleClick: (() -> Void)?
        var onDrag: (() -> ClipboardDragPayload?)?

        private var mouseDownLocation: NSPoint?
        private var dragCleanup: (() -> Void)?

        override func mouseDown(with event: NSEvent) {
            mouseDownLocation = convert(event.locationInWindow, from: nil)
            if event.clickCount == 2 {
                onDoubleClick?()
            } else {
                onSingleClick?()
            }
        }

        override func mouseDragged(with event: NSEvent) {
            guard dragCleanup == nil,
                  let mouseDownLocation,
                  let onDrag else {
                return
            }

            let location = convert(event.locationInWindow, from: nil)
            let deltaX = location.x - mouseDownLocation.x
            let deltaY = location.y - mouseDownLocation.y
            guard (deltaX * deltaX) + (deltaY * deltaY) >= 16 else { return }
            guard let payload = onDrag() else { return }

            let cursorOnlyFrame = NSRect(
                x: location.x - 1,
                y: location.y - 1,
                width: 2,
                height: 2
            )
            let draggingItems = payload.pasteboardItems.map { pasteboardItem in
                let draggingItem = NSDraggingItem(pasteboardWriter: pasteboardItem)
                draggingItem.setDraggingFrame(cursorOnlyFrame, contents: nil)
                return draggingItem
            }
            guard !draggingItems.isEmpty else { return }

            dragCleanup = payload.cleanup
            beginDraggingSession(with: draggingItems, event: event, source: self)
        }

        override func mouseUp(with event: NSEvent) {
            mouseDownLocation = nil
            super.mouseUp(with: event)
        }

        func draggingSession(
            _ session: NSDraggingSession,
            sourceOperationMaskFor context: NSDraggingContext)
            -> NSDragOperation {
            .copy
        }

        func draggingSession(
            _ session: NSDraggingSession,
            endedAt screenPoint: NSPoint,
            operation: NSDragOperation
        ) {
            dragCleanup?()
            dragCleanup = nil
            mouseDownLocation = nil
        }
    }
}
