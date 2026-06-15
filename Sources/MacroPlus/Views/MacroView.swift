import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct MacroView: View {
    @EnvironmentObject var state: AppState

    private var engine: MacroEngine { state.macroEngine }
    private var store: MacroStore { state.store }

    private var speedLabel: String {
        let s = state.macroSpeed
        return s < 10 ? String(format: "%.2g×", s) : "\(Int(s))×"
    }

    var body: some View {
        VStack(spacing: 16) {
            header
            recordCard
            HStack(alignment: .top, spacing: 16) {
                libraryCard
                detailCard
            }
        }
        .padding(20)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Macros").font(.title2.bold())
                Text("Record clicks & keystrokes, then replay them on demand.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    // MARK: record

    private var recordCard: some View {
        Card {
            HStack(spacing: 16) {
                Button {
                    state.toggleRecording()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: engine.isRecording ? "stop.circle.fill" : "record.circle")
                            .font(.title2)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(engine.isRecording ? "Stop recording" : "Record new macro")
                                .fontWeight(.semibold)
                            Text(engine.isRecording
                                 ? "\(engine.liveEventCount) events captured"
                                 : "Captures mouse & keyboard system-wide")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 10).padding(.horizontal, 14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 12)
                        .fill(engine.isRecording ? Color.red.opacity(0.15) : Theme.accent.opacity(0.10)))
                }
                .buttonStyle(.plain)
                .foregroundStyle(engine.isRecording ? .red : Theme.accent)

                if engine.isRecording {
                    RecordingPulse()
                }
            }
        }
    }

    // MARK: library

    private var libraryCard: some View {
        Card(title: "Library", systemImage: "square.stack.3d.up") {
            if store.macros.isEmpty {
                Text("No macros yet. Record one to get started.")
                    .font(.callout).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
            } else {
                VStack(spacing: 6) {
                    ForEach(store.macros) { macro in
                        macroRow(macro)
                    }
                }
            }
            Divider()
            Button { importMacro() } label: {
                Label("Import…", systemImage: "square.and.arrow.down")
            }
            .buttonStyle(.bordered).controlSize(.small)
        }
        .frame(width: 280)
    }

    private func macroRow(_ macro: Macro) -> some View {
        let selected = state.selectedMacroID == macro.id
        return Button {
            state.selectedMacroID = macro.id
        } label: {
            HStack {
                Image(systemName: "play.rectangle.fill")
                    .foregroundStyle(selected ? Theme.accent : .secondary)
                VStack(alignment: .leading, spacing: 1) {
                    Text(macro.name).fontWeight(.medium)
                    Text("\(macro.events.count) events · \(String(format: "%.1f", macro.duration))s")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 8)
                .fill(selected ? Theme.accent.opacity(0.12) : .clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Export…") { exportMacro(macro) }
            Button("Delete", role: .destructive) { store.delete(macro) }
        }
    }

    // MARK: detail

    @ViewBuilder
    private var detailCard: some View {
        if let macro = state.selectedMacro {
            Card(title: macro.name, systemImage: "list.bullet.rectangle") {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Repeat").font(.caption).foregroundStyle(.secondary)
                    Picker("", selection: $state.macroRepeatMode) {
                        ForEach(RepeatMode.allCases) { Text($0.label).tag($0) }
                    }.pickerStyle(.segmented).labelsHidden()
                    if state.macroRepeatMode == .count {
                        Stepper(value: $state.macroRepeat, in: 1...100000) {
                            Text("\(state.macroRepeat)×").monospacedDigit()
                        }.frame(width: 140)
                    } else {
                        Text("Loops until you press \(state.hotkey.keyName(for: .playMacro)) (or Stop) again.")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Speed \(speedLabel)").font(.caption).foregroundStyle(.secondary)
                    Slider(value: $state.macroSpeed, in: 0.25...50.0)
                    HStack {
                        ForEach([1.0, 2.0, 5.0, 10.0, 25.0, 50.0], id: \.self) { s in
                            Button(s < 1 ? "\(s)×" : "\(Int(s))×") { state.macroSpeed = s }
                                .buttonStyle(.bordered).controlSize(.small)
                        }
                    }
                }

                if engine.isPlaying {
                    if state.macroRepeatMode == .forever {
                        ProgressView().tint(Theme.accent)   // looping: indeterminate
                    } else {
                        ProgressView(value: engine.playbackProgress).tint(Theme.accent)
                    }
                }

                HStack {
                    PrimaryButton(
                        title: engine.isPlaying ? "Stop" : "Play",
                        systemImage: engine.isPlaying ? "stop.fill" : "play.fill",
                        active: engine.isPlaying
                    ) {
                        if engine.isPlaying { state.stopMacro() } else { state.playSelected() }
                    }
                    Button(role: .destructive) {
                        store.delete(macro)
                        state.selectedMacroID = nil
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.bordered)
                }

                Divider()
                Text("Steps").font(.caption).foregroundStyle(.secondary)
                eventList(macro)
            }
            .frame(maxWidth: .infinity)
        } else {
            Card {
                VStack(spacing: 8) {
                    Image(systemName: "hand.point.up.left")
                        .font(.largeTitle).foregroundStyle(.secondary)
                    Text("Select a macro to see its steps")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 40)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func eventList(_ macro: Macro) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 3) {
                ForEach(Array(macro.events.prefix(200).enumerated()), id: \.element.id) { index, ev in
                    HStack(spacing: 8) {
                        Text("\(index + 1)")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary).frame(width: 28, alignment: .trailing)
                        Image(systemName: icon(for: ev.kind))
                            .font(.caption).foregroundStyle(Theme.accent).frame(width: 16)
                        Text(ev.summary).font(.caption)
                        Spacer()
                        Text("+\(String(format: "%.0f", ev.delay * 1000))ms")
                            .font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 1)
                }
                if macro.events.count > 200 {
                    Text("…and \(macro.events.count - 200) more")
                        .font(.caption2).foregroundStyle(.secondary).padding(.top, 4)
                }
            }
        }
        .frame(maxHeight: 220)
    }

    private func icon(for kind: MacroEventKind) -> String {
        switch kind {
        case .mouseDown, .mouseUp: return "cursorarrow.click"
        case .mouseMove: return "arrow.up.left.and.arrow.down.right"
        case .keyDown, .keyUp: return "keyboard"
        case .scroll: return "scroll"
        case .delay: return "clock"
        }
    }

    // MARK: import / export

    private func importMacro() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            try? store.importMacro(from: url)
        }
    }

    private func exportMacro(_ macro: Macro) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "\(macro.name).json"
        if panel.runModal() == .OK, let url = panel.url {
            try? store.export(macro, to: url)
        }
    }
}

/// Animated red dot shown while recording.
struct RecordingPulse: View {
    @State private var on = false
    var body: some View {
        Circle()
            .fill(Color.red)
            .frame(width: 12, height: 12)
            .opacity(on ? 0.3 : 1)
            .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: on)
            .onAppear { on = true }
    }
}
