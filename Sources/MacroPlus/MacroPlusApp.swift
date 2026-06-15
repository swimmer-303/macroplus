import SwiftUI
import AppKit

@main
struct MacroPlusApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var state = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(state)
                .frame(minWidth: 760, minHeight: 540)
                .onAppear { appDelegate.attach(state) }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("Control") {
                Button("Start / Stop Autoclicker") { state.toggleClicker() }
                    .keyboardShortcut("r", modifiers: [.command])
                Button("Record / Stop Macro") { state.toggleRecording() }
                    .keyboardShortcut("e", modifiers: [.command])
                Button("Play / Stop Macro") { state.togglePlayback() }
                    .keyboardShortcut("p", modifiers: [.command])
            }
        }
    }
}

/// Manages the status-bar (menu bar) item and app lifecycle.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private weak var state: AppState?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        setupStatusItem()
    }

    func attach(_ state: AppState) {
        self.state = state
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            for window in sender.windows { window.makeKeyAndOrderFront(self) }
        }
        return true
    }

    func applicationWillBecomeActive(_ notification: Notification) {
        state?.permissions.refresh()
        // Re-arm global hotkeys in case permission was just granted.
        state?.hotkey.reinstallIfNeeded()
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "cursorarrow.click.2",
                                   accessibilityDescription: "MacroPlus")
            button.imagePosition = .imageOnly
        }
        let menu = NSMenu()
        menu.addItem(withTitle: "Start / Stop Autoclicker",
                     action: #selector(toggleClick), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Record / Stop Macro",
                     action: #selector(toggleRecord), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Show MacroPlus",
                     action: #selector(showWindow), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit MacroPlus",
                     action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.menu = menu
        statusItem = item
    }

    @objc private func toggleClick() { state?.toggleClicker() }
    @objc private func toggleRecord() { state?.toggleRecording() }
    @objc private func showWindow() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.windows.first?.makeKeyAndOrderFront(self)
    }
}
