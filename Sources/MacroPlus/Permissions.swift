import Foundation
import ApplicationServices
import AppKit

/// Wraps the macOS Accessibility permission required to post & observe input events.
final class Permissions: ObservableObject {
    @Published var trusted: Bool = AXIsProcessTrusted()

    /// Re-checks the current trust status (call when the app becomes active).
    func refresh() {
        let now = AXIsProcessTrusted()
        if now != trusted { trusted = now }
    }

    /// Prompts the user, opening the system permission dialog the first time.
    func requestWithPrompt() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [key: true] as CFDictionary
        trusted = AXIsProcessTrustedWithOptions(options)
    }

    /// Opens System Settings directly at the Accessibility pane.
    func openSystemSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}
