//
//  LauncherController.swift
//  Lightsearch
//

import AppKit
import Carbon.HIToolbox
import CoreGraphics
import Darwin
import SwiftUI

@MainActor
final class LauncherController: NSObject, NSWindowDelegate {
    private let state = LauncherState()
    private let hotKey = GlobalHotKey()
    private var localKeyMonitor: Any?
    private var searchField: NSSearchField?
    private var focusRetryScheduled = false
    private var pasteTargetApplication: NSRunningApplication?
    private var isClipboardActionsPresented = false
    private let colorPickerController = ColorPickerController()

    private let panel: LauncherPanel

    override init() {
        panel = LauncherPanel(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: LauncherMetrics.panelWidth,
                height: LauncherMetrics.collapsedHeight
            ),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        super.init()

        panel.delegate = self
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.acceptsMouseMovedEvents = false
        panel.animationBehavior = .none
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = false
        // Inherit the app's effective appearance so Liquid Glass follows the
        // user's System Settings theme instead of the desktop behind the panel.
        panel.appearanceSource = NSApp

        let hostingView = NSHostingView(
            rootView: ContentView(
                state: state,
                onOpen: { [weak self] application in
                    self?.open(application)
                },
                onOpenSystemPreference: { [weak self] preference in
                    self?.open(preference)
                },
                onOpenFileSearch: { [weak self] in
                    self?.enterFileSearch()
                },
                onBackFromFileSearch: { [weak self] in
                    self?.returnToApplicationSearch()
                },
                onOpenClipboardHistory: { [weak self] in
                    self?.enterClipboardHistory()
                },
                onBackFromClipboardHistory: { [weak self] in
                    self?.returnToApplicationSearch()
                },
                onStartColorPicker: { [weak self] in
                    self?.startColorPicker()
                },
                onPasteClipboardEntry: { [weak self] entry in
                    self?.pasteClipboardEntry(entry)
                },
                onClipboardActionsPresentedChanged: { [weak self] isPresented in
                    self?.isClipboardActionsPresented = isPresented
                },
                onOpenFile: { [weak self] file in
                    self?.open(file)
                },
                onCopyConversion: { [weak self] conversion in
                    self?.copy(conversion)
                },
                onSearchFieldReady: { [weak self] searchField in
                    self?.searchField = searchField
                },
                onQueryChanged: { [weak self] shouldExpand in
                    self?.updatePanelSize(isExpanded: shouldExpand)
                }
            )
        )
        hostingView.frame = panel.contentView?.bounds ?? .zero
        hostingView.autoresizingMask = [.width, .height]
        panel.contentView = hostingView
    }

    func start() {
        state.loadIfNeeded()
        installLocalKeyMonitor()

        let registered = hotKey.register { [weak self] in
            self?.toggle()
        }

        if !registered {
            NSLog("Lightsearch: Cmd-Space could not be registered. Check the keyboard shortcut in System Settings.")
        }
    }

    func stop() {
        hotKey.unregister()
        colorPickerController.cancel()
        if let localKeyMonitor {
            NSEvent.removeMonitor(localKeyMonitor)
            self.localKeyMonitor = nil
        }
    }

    func toggle() {
        if panel.isVisible {
            hide()
        } else {
            show()
        }
    }

    func show() {
        rememberPasteTargetApplication()
        state.loadIfNeeded()
        state.resetForPresentation()
        updatePanelSize(isExpanded: false)
        positionPanel()

        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()

        focusSearchField()
    }

    private func focusSearchField() {
        focusSearchField(retryIfNeeded: true)
    }

    private func focusSearchField(retryIfNeeded: Bool) {
        guard panel.isVisible else { return }

        // The search field is an AppKit control inside the SwiftUI hierarchy.
        // It is normally ready by the time the panel is ordered front, so try
        // immediately. If SwiftUI is still attaching it, retry once after the
        // main queue has completed the current view update.
        guard let searchField else {
            if retryIfNeeded {
                scheduleFocusRetry()
            }
            return
        }

        guard panel.makeFirstResponder(searchField) else {
            if retryIfNeeded {
                scheduleFocusRetry()
            }
            return
        }

        searchField.selectText(nil)
    }

    private func scheduleFocusRetry() {
        guard !focusRetryScheduled else { return }
        focusRetryScheduled = true

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.focusRetryScheduled = false
            self.focusSearchField(retryIfNeeded: false)
        }
    }

    private func enterFileSearch() {
        state.enterFileSearch()
        updatePanelSize(isExpanded: true)
        focusSearchField()
    }

    private func enterClipboardHistory() {
        state.enterClipboardHistory()
        updatePanelSize(isExpanded: true)
        focusSearchField()
    }

    private func startColorPicker() {
        hide()
        colorPickerController.start { [weak self] color in
            guard ClipboardPasteboardWriter.writeColor(color) else { return }
            self?.state.recordColorPickerResult()
        }
    }

    private func returnToApplicationSearch() {
        if state.isClipboardPage {
            state.exitClipboardHistory()
        } else if state.isFileSearchPage {
            state.exitFileSearch()
        }
        updatePanelSize(isExpanded: false)
        focusSearchField()
    }

    func hide() {
        colorPickerController.cancel()
        guard panel.isVisible else { return }
        panel.orderOut(nil)
        state.resetForPresentation()
        updatePanelSize(isExpanded: false)
        malloc_zone_pressure_relief(nil, 0)
    }

    @objc func showFromMenu(_ sender: Any?) {
        show()
    }

    @objc func showClipboardHistoryFromMenu(_ sender: Any?) {
        rememberPasteTargetApplication()
        state.loadIfNeeded()
        state.resetForPresentation()
        enterClipboardHistory()
        positionPanel()

        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
        focusSearchField()
    }

    private func open(_ application: InstalledApplication) {
        hide()
        let applicationURL = URL(fileURLWithPath: application.path)
        Task.detached(priority: .userInitiated) { [state = self.state] in
            if NSWorkspace.shared.open(applicationURL) {
                await state.recordLaunch(of: application)
            }
        }
    }

    private func open(_ file: SearchFile) {
        hide()
        let fileURL = URL(fileURLWithPath: file.path)
        Task.detached(priority: .userInitiated) { [state = self.state] in
            if NSWorkspace.shared.open(fileURL) {
                await state.recordOpen(of: file)
            }
        }
    }

    private func open(_ preference: SystemPreference) {
        hide()
        guard let url = URL(string: preference.urlString) else { return }
        NSWorkspace.shared.open(url)
    }

    private func copy(_ conversion: ConversionResult) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(conversion.copyText, forType: .string)
        hide()
    }

    private func pasteClipboardEntry(_ entry: ClipboardEntry) {
        guard state.writeClipboardEntryToPasteboard(entry) else { return }

        let targetApplication = pasteTargetApplication
        hide()

        guard let targetApplication,
              !targetApplication.isTerminated,
              targetApplication.processIdentifier != ProcessInfo.processInfo.processIdentifier else {
            return
        }

        targetApplication.activate(options: [])
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) { [weak targetApplication] in
            guard let targetApplication,
                  !targetApplication.isTerminated,
                  let keyDown = CGEvent(
                    keyboardEventSource: nil,
                    virtualKey: CGKeyCode(kVK_ANSI_V),
                    keyDown: true
                  ),
                  let keyUp = CGEvent(
                    keyboardEventSource: nil,
                    virtualKey: CGKeyCode(kVK_ANSI_V),
                    keyDown: false
                  ) else {
                return
            }

            keyDown.flags = .maskCommand
            keyUp.flags = .maskCommand
            keyDown.postToPid(targetApplication.processIdentifier)
            keyUp.postToPid(targetApplication.processIdentifier)
        }
    }

    private func positionPanel() {
        let mouseLocation = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) }) ?? NSScreen.main
        guard let screen else { return }

        let visibleFrame = screen.visibleFrame
        let panelSize = panel.frame.size
        let x = visibleFrame.midX - panelSize.width / 2
        let y = visibleFrame.maxY - panelSize.height - 200
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func updatePanelSize(isExpanded: Bool) {
        let targetWidth: CGFloat
        let targetHeight: CGFloat
        if state.isClipboardPage {
            targetWidth = LauncherMetrics.panelWidth
            targetHeight = LauncherMetrics.expandedHeight
        } else {
            targetWidth = LauncherMetrics.panelWidth
            targetHeight = isExpanded
                ? LauncherMetrics.expandedHeight
                : LauncherMetrics.collapsedHeight
        }

        guard abs(panel.frame.width - targetWidth) > 0.5
            || abs(panel.frame.height - targetHeight) > 0.5 else {
            return
        }

        let currentFrame = panel.frame
        let resizedFrame = NSRect(
            x: currentFrame.midX - targetWidth / 2,
            y: currentFrame.maxY - targetHeight,
            width: targetWidth,
            height: targetHeight
        )
        panel.setFrame(resizedFrame, display: true, animate: false)
    }

    private func installLocalKeyMonitor() {
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.panel.isVisible, event.window === self.panel else {
                return event
            }

            switch event.keyCode {
            case UInt16(kVK_Escape):
                if self.isClipboardActionsPresented {
                    return event
                }
                if self.state.isFileSearchPage || self.state.isClipboardPage {
                    self.returnToApplicationSearch()
                } else {
                    self.hide()
                }
                return nil
            case UInt16(kVK_UpArrow):
                if self.isClipboardActionsPresented {
                    return event
                }
                self.state.moveSelection(by: -1)
                return nil
            case UInt16(kVK_DownArrow):
                if self.isClipboardActionsPresented {
                    return event
                }
                self.state.moveSelection(by: 1)
                return nil
            case UInt16(kVK_Return), UInt16(kVK_ANSI_KeypadEnter):
                if self.isClipboardActionsPresented {
                    return event
                }
                if self.state.isFileSearchPage {
                    if let file = self.state.selectedFile() {
                        self.open(file)
                    }
                } else if self.state.isClipboardPage {
                    if let entry = self.state.selectedClipboardEntry() {
                        self.pasteClipboardEntry(entry)
                    }
                } else {
                    switch self.state.selectedResult() {
                    case let .conversion(conversion):
                        self.copy(conversion)
                    case let .systemPreference(preference):
                        self.open(preference)
                    case .fileSearch:
                        self.enterFileSearch()
                    case .clipboardHistory:
                        self.enterClipboardHistory()
                    case .colorPicker:
                        self.startColorPicker()
                    case let .application(application):
                        self.open(application)
                    case nil:
                        break
                    }
                }
                return nil
            default:
                return event
            }
        }
    }

    func windowDidResignKey(_ notification: Notification) {
        // Keep the panel visible while AppKit is moving focus between the
        // search field and its child controls. applicationDidResignActive is
        // the actual outside-click boundary.
    }

    private func rememberPasteTargetApplication() {
        let currentProcessIdentifier = ProcessInfo.processInfo.processIdentifier
        let frontmostApplication = NSWorkspace.shared.frontmostApplication
        if frontmostApplication?.processIdentifier == currentProcessIdentifier {
            pasteTargetApplication = nil
        } else {
            pasteTargetApplication = frontmostApplication
        }
        state.setClipboardPasteTargetApplication(
            pasteTargetApplication?.localizedName
        )
    }
}

final class LauncherPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

final class GlobalHotKey {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private var callback: (() -> Void)?

    func register(callback: @escaping () -> Void) -> Bool {
        unregister()
        self.callback = callback

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: OSType(kEventHotKeyPressed)
        )
        let userData = Unmanaged.passUnretained(self).toOpaque()
        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, userData in
                guard let userData else { return OSStatus(eventNotHandledErr) }
                let hotKey = Unmanaged<GlobalHotKey>.fromOpaque(userData).takeUnretainedValue()
                hotKey.callback?()
                return noErr
            },
            1,
            &eventType,
            userData,
            &eventHandlerRef
        )

        guard installStatus == noErr else {
            self.callback = nil
            return false
        }

        let hotKeyID = EventHotKeyID(signature: 0x4C535243, id: 1) // "LSRC"
        let registerStatus = RegisterEventHotKey(
            UInt32(kVK_Space),
            UInt32(cmdKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        guard registerStatus == noErr else {
            RemoveEventHandler(eventHandlerRef)
            eventHandlerRef = nil
            self.callback = nil
            return false
        }

        return true
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
            self.eventHandlerRef = nil
        }
        callback = nil
    }

    deinit {
        unregister()
    }
}
