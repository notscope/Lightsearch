//
//  LightsearchApp.swift
//  Lightsearch
//
//  Lightsearch application entry point.
//

import AppKit
import SwiftUI

@main
struct LightsearchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // Lightsearch is a menu-bar utility. The launcher itself is an AppKit
        // panel created by AppDelegate, so there is no document window to keep
        // alive in SwiftUI's scene system.
        Settings {
            EmptyView()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var launcherController: LauncherController?
    private var statusItem: NSStatusItem?
    private var contextMenu: NSMenu?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let launcherController = LauncherController()
        self.launcherController = launcherController
        installStatusItem(for: launcherController)
        launcherController.start()
    }

    func applicationDidResignActive(_ notification: Notification) {
        // A launcher should disappear as soon as the user returns to another
        // app. The status item and global shortcut remain available.
        launcherController?.hide()
    }

    func applicationWillTerminate(_ notification: Notification) {
        launcherController?.stop()
    }

    private func installStatusItem(for launcherController: LauncherController) {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem.button else { return }

        button.image = NSImage(
            systemSymbolName: "sparkle.magnifyingglass",
            accessibilityDescription: "Lightsearch"
        )
        button.image?.isTemplate = true
        button.toolTip = "Lightsearch"
        button.target = self
        button.action = #selector(statusItemPressed(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])

        let contextMenu = makeMenu(
            title: "Show Launcher",
            action: #selector(LauncherController.showFromMenu(_:)),
            target: launcherController
        )

        let clipboardItem = NSMenuItem(
            title: "Show Clipboard History",
            action: #selector(LauncherController.showClipboardHistoryFromMenu(_:)),
            keyEquivalent: ""
        )
        clipboardItem.target = launcherController
        contextMenu.insertItem(clipboardItem, at: 1)

        self.contextMenu = contextMenu
        self.statusItem = statusItem
    }

    @objc private func statusItemPressed(_ sender: NSStatusBarButton) {
        guard NSApp.currentEvent?.type == .rightMouseUp else {
            launcherController?.toggle()
            return
        }

        guard let contextMenu else { return }

        contextMenu.popUp(
            positioning: nil,
            at: NSPoint(x: sender.bounds.midX, y: sender.bounds.minY),
            in: sender
        )
    }

    private func makeMenu(title: String, action: Selector, target: AnyObject) -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false

        let openItem = NSMenuItem(title: title, action: action, keyEquivalent: "")
        openItem.target = target
        menu.addItem(openItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit Lightsearch",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        quitItem.keyEquivalentModifierMask = [.command]
        quitItem.target = NSApp
        menu.addItem(quitItem)
        return menu
    }
}
