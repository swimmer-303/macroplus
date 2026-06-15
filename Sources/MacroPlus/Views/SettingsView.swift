import SwiftUI
import AppKit

struct SettingsView: View {
    @EnvironmentObject var state: AppState
    @State private var capturingAction: HotkeyAction?
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
        Card(title: "Global hotkeys", systemImage: "keyboard") {
            Text("Trigger actions from anywhere, even when MacroPlus isn't focused.")
                .font(.callout).foregroundStyle(.secondary)
            ForEach(HotkeyAction.allCases) { action in
                HStack {
                    Text(action.label).font(.callout)
                    Spacer()
                    Button {
                        capturingAction == action ? stopCapture() : startCapture(action)
                    } label: {
                        Text(capturingAction == action ? "Press any key…" : state.hotkey.keyName(for: action))
                            .font(.body.monospaced())
                            .frame(minWidth: 90)
                            .padding(.vertical, 6).padding(.horizontal, 14)
                            .background(RoundedRectangle(cornerRadius: 8)
                                .fill(capturingAction == action ? Theme.accent.opacity(0.2) : Color.primary.opacity(0.06)))
                    }
                    .buttonStyle(.plain)
                }
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
            permissionRow(
                ok: state.permissions.trusted,
                title: "Accessibility",
                detail: "Required to send clicks & keystrokes (autoclicker + playback).",
                action: { state.permissions.openSystemSettings() }
            )
            Divider()
            permissionRow(
                ok: state.permissions.inputMonitoring,
                title: "Input Monitoring",
                detail: "Required to record global mouse & keyboard input.",
                action: {
                    state.permissions.requestInputMonitoring()
                    state.permissions.openInputMonitoringSettings()
                }
            )
        }
    }

    private func permissionRow(ok: Bool, title: String, detail: String,
                               action: @escaping () -> Void) -> some View {
        HStack {
            Image(systemName: ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(ok ? .green : .orange)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.callout.weight(.medium))
                Text(detail).font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            Button(ok ? "Open Settings" : "Grant…", action: action)
                .buttonStyle(.bordered)
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
                    Text("Global: \(state.hotkey.keyName(for: .toggleClicker)) click · \(state.hotkey.keyName(for: .toggleRecording)) record · \(state.hotkey.keyName(for: .playMacro)) play")
                        .font(.caption2.monospaced()).foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
    }

    // MARK: hotkey capture

    private func startCapture(_ action: HotkeyAction) {
        stopCapture()
        capturingAction = action
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            state.hotkey.rebind(action, to: event.keyCode)
            stopCapture()
            return nil
        }
    }

    private func stopCapture() {
        capturingAction = nil
        if let m = keyMonitor { NSEvent.removeMonitor(m); keyMonitor = nil }
    }
}
