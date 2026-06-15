import Foundation
import AppKit
import CoreGraphics

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

/// Listens for global trigger keys via a CGEventTap and fires the matching action.
/// (NSEvent global monitors drop keyDown events — a CGEventTap is reliable.)
final class HotkeyManager: ObservableObject {
    @Published var bindings: [HotkeyAction: UInt16]
    var handlers: [HotkeyAction: () -> Void] = [:]

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    init() {
        var defaults: [HotkeyAction: UInt16] = [:]
        for action in HotkeyAction.allCases { defaults[action] = action.defaultKey }
        bindings = defaults
    }

    func install() {
        uninstall()
        let mask: CGEventMask = (1 << CGEventType.keyDown.rawValue)
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon in
                if let refcon = refcon {
                    let mgr = Unmanaged<HotkeyManager>.fromOpaque(refcon).takeUnretainedValue()
                    mgr.handle(type: type, event: event)
                }
                return Unmanaged.passUnretained(event)
            },
            userInfo: refcon
        ) else { return }   // fails until Accessibility/Input Monitoring is granted

        let src = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), src, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        eventTap = tap
        runLoopSource = src
    }

    func uninstall() {
        if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let src = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), src, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }

    /// Re-installs the tap — call once permissions are granted so hotkeys come alive.
    func reinstallIfNeeded() {
        if eventTap == nil { install() }
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

    private func handle(type: CGEventType, event: CGEvent) {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
            return
        }
        let code = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        guard let action = action(for: code) else { return }
        DispatchQueue.main.async { [weak self] in self?.handlers[action]?() }
    }
}
