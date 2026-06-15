import Foundation
import AppKit

/// Actions that can be triggered by a global hotkey.
enum HotkeyAction: String, CaseIterable, Identifiable {
    case toggleClicker
    case toggleRecording
    case playMacro

    var id: String { rawValue }

    var label: String {
        switch self {
        case .toggleClicker: return "Start / stop autoclicker"
        case .toggleRecording: return "Record / stop macro"
        case .playMacro: return "Play / stop macro"
        }
    }

    var defaultKey: UInt16 {
        switch self {
        case .toggleClicker: return 97    // F6
        case .toggleRecording: return 98  // F7
        case .playMacro: return 100       // F8
        }
    }
}

/// Listens for global trigger keys and fires the matching action.
/// Uses NSEvent global+local monitors (global requires Accessibility permission).
final class HotkeyManager: ObservableObject {
    @Published var bindings: [HotkeyAction: UInt16]
    var handlers: [HotkeyAction: () -> Void] = [:]

    private var globalMonitor: Any?
    private var localMonitor: Any?

    init() {
        var defaults: [HotkeyAction: UInt16] = [:]
        for action in HotkeyAction.allCases { defaults[action] = action.defaultKey }
        bindings = defaults
    }

    func install() {
        uninstall()
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            self?.handle(event)
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            // Swallow the key only when it's bound to an action, so we don't
            // interfere with normal typing in our own text fields.
            if self?.action(for: event.keyCode) != nil {
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

    /// Rebinds an action, refusing duplicates by clearing any other action on that key.
    func rebind(_ action: HotkeyAction, to keyCode: UInt16) {
        for (a, k) in bindings where k == keyCode && a != action {
            bindings[a] = nil
        }
        bindings[action] = keyCode
    }

    func keyName(for action: HotkeyAction) -> String {
        guard let code = bindings[action] else { return "—" }
        return KeyNames.name(for: code)
    }

    private func action(for keyCode: UInt16) -> HotkeyAction? {
        bindings.first(where: { $0.value == keyCode })?.key
    }

    private func handle(_ event: NSEvent) {
        guard let action = action(for: event.keyCode) else { return }
        DispatchQueue.main.async { [weak self] in self?.handlers[action]?() }
    }
}
