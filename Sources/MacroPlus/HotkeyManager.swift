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

/// A key plus its modifier combination (⌃ ⌥ ⇧ ⌘).
struct HotkeyCombo: Equatable {
    var keyCode: UInt16
    var mods: UInt8     // bit0 shift, bit1 control, bit2 option, bit3 command

    static let shift: UInt8 = 1, control: UInt8 = 2, option: UInt8 = 4, command: UInt8 = 8

    static func mods(from f: NSEvent.ModifierFlags) -> UInt8 {
        var m: UInt8 = 0
        if f.contains(.shift)   { m |= shift }
        if f.contains(.control) { m |= control }
        if f.contains(.option)  { m |= option }
        if f.contains(.command) { m |= command }
        return m
    }

    static func mods(from f: CGEventFlags) -> UInt8 {
        var m: UInt8 = 0
        if f.contains(.maskShift)     { m |= shift }
        if f.contains(.maskControl)   { m |= control }
        if f.contains(.maskAlternate) { m |= option }
        if f.contains(.maskCommand)   { m |= command }
        return m
    }

    /// Human-readable form, e.g. "⌃⇧A" or "F6".
    var display: String {
        var s = ""
        if mods & Self.control != 0 { s += "⌃" }
        if mods & Self.option  != 0 { s += "⌥" }
        if mods & Self.shift   != 0 { s += "⇧" }
        if mods & Self.command != 0 { s += "⌘" }
        return s + KeyNames.name(for: keyCode)
    }
}

/// Listens for global trigger keys via a CGEventTap and fires the matching action.
final class HotkeyManager: ObservableObject {
    @Published var bindings: [HotkeyAction: HotkeyCombo]
    var handlers: [HotkeyAction: () -> Void] = [:]

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    init() {
        var defaults: [HotkeyAction: HotkeyCombo] = [:]
        for action in HotkeyAction.allCases {
            defaults[action] = HotkeyCombo(keyCode: action.defaultKey, mods: 0)
        }
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

    /// Rebinds an action, clearing any other action sharing the same combination.
    func rebind(_ action: HotkeyAction, to combo: HotkeyCombo) {
        for (a, c) in bindings where c == combo && a != action {
            bindings[a] = nil
        }
        bindings[action] = combo
    }

    func keyName(for action: HotkeyAction) -> String {
        bindings[action]?.display ?? "—"
    }

    private func action(for combo: HotkeyCombo) -> HotkeyAction? {
        bindings.first(where: { $0.value == combo })?.key
    }

    private func handle(type: CGEventType, event: CGEvent) {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
            return
        }
        let combo = HotkeyCombo(keyCode: UInt16(event.getIntegerValueField(.keyboardEventKeycode)),
                                mods: HotkeyCombo.mods(from: event.flags))
        guard let action = action(for: combo) else { return }
        DispatchQueue.main.async { [weak self] in self?.handlers[action]?() }
    }
}
