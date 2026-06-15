import Foundation
import ApplicationServices
import IOKit.hid
import AppKit

/// Wraps the two macOS privacy permissions MacroPlus needs:
///  • Accessibility   — required to *post* synthetic mouse/keyboard events.
///  • Input Monitoring — required to *listen* to global input while recording.
final class Permissions: ObservableObject {
    @Published var trusted: Bool = AXIsProcessTrusted()
    @Published var inputMonitoring: Bool = (IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted)

    /// Re-checks both permissions (call when the app becomes active).
    func refresh() {
        let ax = AXIsProcessTrusted()
        if ax != trusted { trusted = ax }
        let im = IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted
        if im != inputMonitoring { inputMonitoring = im }
    }

    // MARK: Accessibility

    /// Prompts for Accessibility, opening the system dialog the first time.
    func requestWithPrompt() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [key: true] as CFDictionary
        trusted = AXIsProcessTrustedWithOptions(options)
    }

    func openSystemSettings() {
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    }

    // MARK: Input Monitoring

    /// Asks the system for Input Monitoring access (shows the prompt once).
    func requestInputMonitoring() {
        // IOHIDRequestAccess triggers the system prompt and adds MacroPlus to the list.
        _ = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
        inputMonitoring = IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted
    }

    func openInputMonitoringSettings() {
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")
    }

    private func open(_ string: String) {
        if let url = URL(string: string) { NSWorkspace.shared.open(url) }
    }
}
