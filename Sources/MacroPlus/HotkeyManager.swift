import Foundation
import AppKit

/// Listens for a single global trigger key and fires a callback.
/// Uses NSEvent global+local monitors (requires Accessibility permission for global).
final class HotkeyManager: ObservableObject {
    @Published var keyCode: UInt16 = 97   // F6 by default

    private var globalMonitor: Any?
    private var localMonitor: Any?
    var onTrigger: (() -> Void)?

    func install() {
        uninstall()
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            self?.handle(event)
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            // Don't swallow text input in our own fields unless it's the hotkey.
            if event.keyCode == self?.keyCode {
                self?.handle(event)
                return nil
            }
            return event
        }
    }

    func uninstall() {
        if let g = globalMonitor { NSEvent.removeMonitor(g); globalMonitor = nil }
        if let l = localMonitor { NSEvent.removeMonitor(l); localMonitor = nil }
    }

    private func handle(_ event: NSEvent) {
        guard event.keyCode == keyCode else { return }
        DispatchQueue.main.async { [weak self] in self?.onTrigger?() }
    }

    var keyName: String { KeyNames.name(for: keyCode) }
}
