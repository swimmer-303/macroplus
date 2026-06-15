import SwiftUI
import AppKit

struct SettingsView: View {
    @EnvironmentObject var state: AppState
    @State private var capturingHotkey = false
    @State private var keyMonitor: Any?

    var body: some View {
        VStack(spacing: 16) {
            header
            hotkeyCard
            recordingCard
            permissionCard
            aboutCard
        }
        .padding(20)
        .onDisappear { stopCapture() }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Settings").font(.title2.bold())
                Text("Tune triggers, capture options and permissions.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var hotkeyCard: some View {
        Card(title: "Start / stop hotkey", systemImage: "keyboard") {
            HStack {
                Text("Global trigger for the autoclicker.")
                    .font(.callout).foregroundStyle(.secondary)
                Spacer()
                Button {
                    capturingHotkey ? stopCapture() : startCapture()
                } label: {
                    Text(capturingHotkey ? "Press any key…" : state.hotkey.keyName)
                        .font(.body.monospaced())
                        .frame(minWidth: 80)
                        .padding(.vertical, 6).padding(.horizontal, 14)
                        .background(RoundedRectangle(cornerRadius: 8)
                            .fill(capturingHotkey ? Theme.accent.opacity(0.2) : Color.primary.opacity(0.06)))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var recordingCard: some View {
        Card(title: "Macro recording", systemImage: "record.circle") {
            Toggle(isOn: $state.recordMouseMoves) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Record mouse movement").font(.callout)
                    Text("Captures the full cursor path (larger macros)")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            .toggleStyle(.switch)
        }
    }

    private var permissionCard: some View {
        Card(title: "Permissions", systemImage: "lock.shield") {
            HStack {
                Image(systemName: state.permissions.trusted ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(state.permissions.trusted ? .green : .orange)
                Text(state.permissions.trusted
                     ? "Accessibility access granted."
                     : "MacroPlus needs Accessibility access to send input.")
                    .font(.callout)
                Spacer()
                Button("Open System Settings") { state.permissions.openSystemSettings() }
                    .buttonStyle(.bordered)
            }
        }
    }

    private var aboutCard: some View {
        Card(title: "About", systemImage: "info.circle") {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Theme.accentGradient).frame(width: 56, height: 56)
                    Image(systemName: "cursorarrow.click.2")
                        .font(.system(size: 26, weight: .bold)).foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("MacroPlus 1.0").font(.headline)
                    Text("A fast, native autoclicker & macro studio for macOS.")
                        .font(.caption).foregroundStyle(.secondary)
                    Text("⌘R start · ⌘E record · ⌘P play")
                        .font(.caption2.monospaced()).foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
    }

    // MARK: hotkey capture

    private func startCapture() {
        capturingHotkey = true
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            state.hotkey.keyCode = event.keyCode
            stopCapture()
            return nil
        }
    }

    private func stopCapture() {
        capturingHotkey = false
        if let m = keyMonitor { NSEvent.removeMonitor(m); keyMonitor = nil }
    }
}
