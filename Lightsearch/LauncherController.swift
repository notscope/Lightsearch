//
//  LauncherController.swift
//  Lightsearch
//

import AppKit
import Carbon.HIToolbox
import SwiftUI

@MainActor
final class LauncherController: NSObject, NSWindowDelegate {
    private let state = LauncherState()
    private let hotKey = GlobalHotKey()
    private var localKeyMonitor: Any?
    private var searchField: NSSearchField?

    private let panel: LauncherPanel

    override init() {
        panel = LauncherPanel(
            contentRect: NSRect(x: 0, y: 0, width: 680, height: 64),
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

        let hostingView = NSHostingView(
            rootView: ContentView(
                state: state,
                onOpen: { [weak self] application in
                    self?.open(application)
                },
                onOpenFileSearch: { [weak self] in
                    self?.enterFileSearch()
                },
                onBackFromFileSearch: { [weak self] in
                    self?.returnToApplicationSearch()
                },
                onOpenFile: { [weak self] file in
                    self?.open(file)
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
        // The search field is an AppKit control inside the SwiftUI hierarchy.
        // Deferring one run-loop turn lets AppKit finish attaching it to the
        // panel before requesting first responder status.
        DispatchQueue.main.async { [weak self] in
            guard let self, self.panel.isVisible else { return }
            if let searchField = self.searchField {
                self.panel.makeFirstResponder(searchField)
                searchField.selectText(nil)
            }
        }
    }

    private func enterFileSearch() {
        state.enterFileSearch()
        updatePanelSize(isExpanded: true)
        focusSearchField()
    }

    private func returnToApplicationSearch() {
        state.exitFileSearch()
        updatePanelSize(isExpanded: false)
        focusSearchField()
    }

    func hide() {
        guard panel.isVisible else { return }
        panel.orderOut(nil)
        state.resetForPresentation()
        updatePanelSize(isExpanded: false)
    }

    @objc func showFromMenu(_ sender: Any?) {
        show()
    }

    private func open(_ application: InstalledApplication) {
        hide()
        let applicationURL = URL(fileURLWithPath: application.path)
        Task.detached(priority: .userInitiated) { [weak self, state = self.state] in
            if NSWorkspace.shared.open(applicationURL) {
                await state.recordLaunch(of: application)
            }
        }
    }

    private func open(_ file: SearchFile) {
        hide()
        let fileURL = URL(fileURLWithPath: file.path)
        Task.detached(priority: .userInitiated) { [weak self, state = self.state] in
            if NSWorkspace.shared.open(fileURL) {
                await state.recordOpen(of: file)
            }
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
        let targetHeight: CGFloat = isExpanded ? 560 : 64
        guard abs(panel.frame.height - targetHeight) > 0.5 else { return }

        let currentFrame = panel.frame
        // Keep the search field/top edge fixed; the results area grows below it.
        let resizedFrame = NSRect(
            x: currentFrame.minX,
            y: currentFrame.maxY - targetHeight,
            width: 680,
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
                if self.state.isFileSearchPage {
                    self.returnToApplicationSearch()
                } else {
                    self.hide()
                }
                return nil
            case UInt16(kVK_UpArrow):
                self.state.moveSelection(by: -1)
                return nil
            case UInt16(kVK_DownArrow):
                self.state.moveSelection(by: 1)
                return nil
            case UInt16(kVK_Return):
                if self.state.isFileSearchPage {
                    if let file = self.state.selectedFile() {
                        self.open(file)
                    }
                } else {
                    switch self.state.selectedResult() {
                    case .fileSearch:
                        self.enterFileSearch()
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
