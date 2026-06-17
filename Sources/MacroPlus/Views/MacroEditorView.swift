import SwiftUI
import AppKit

// Lets a UUID drive `.sheet(item:)` directly.
extension UUID: @retroactive Identifiable {
    public var id: UUID { self }
}

/// Full editor for a recorded macro: add/remove/reorder steps and tune the wait
/// before each one (incl. press duration), coordinates, mouse button and key.
struct MacroEditorView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) private var dismiss

    let macroID: UUID
    @State private var name: String = ""
    @State private var events: [MacroEvent] = []
    @State private var selection: MacroEvent.ID?
    @State private var loaded = false

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            if events.isEmpty {
                emptyState
            } else {
                columnHeader
                List(selection: $selection) {
                    ForEach($events) { $event in
                        EventEditorRow(event: $event,
                                       onDuplicate: { duplicate($event.wrappedValue) },
                                       onDelete: { delete($event.wrappedValue) })
                        .tag(event.id)
                    }
                    .onDelete { events.remove(atOffsets: $0) }
                    .onMove { events.move(fromOffsets: $0, toOffset: $1) }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }
            Divider()
            footer
        }
        .frame(width: 720, height: 580)
        .onAppear(perform: loadOnce)
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            Image(systemName: "slider.horizontal.3").foregroundStyle(Theme.accent)
            TextField("Macro name", text: $name)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 260)
            Spacer()
            addMenu
        }
        .padding(14)
    }

    private var addMenu: some View {
        Menu {
            Button { insert(clickEvents(.left)) }   label: { Label("Left click", systemImage: "cursorarrow.click") }
            Button { insert(clickEvents(.right)) }  label: { Label("Right click", systemImage: "cursorarrow.click") }
            Button { insert(clickEvents(.middle)) } label: { Label("Middle click", systemImage: "cursorarrow.click") }
            Divider()
            Button { insert(keyEvents()) }          label: { Label("Key press", systemImage: "keyboard") }
            Button { insert([moveEvent()]) }        label: { Label("Mouse move", systemImage: "arrow.up.left.and.arrow.down.right") }
            Button { insert([scrollEvent(up: true)]) }  label: { Label("Scroll up", systemImage: "arrow.up") }
            Button { insert([scrollEvent(up: false)]) } label: { Label("Scroll down", systemImage: "arrow.down") }
            Divider()
            Button { insert([MacroEvent(kind: .delay, delay: 0.5)]) } label: { Label("Wait", systemImage: "clock") }
        } label: {
            Label("Add step", systemImage: "plus.circle.fill")
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "plus.rectangle.on.rectangle")
                .font(.largeTitle).foregroundStyle(.secondary)
            Text("No steps yet — use “Add step” to build one.")
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var columnHeader: some View {
        HStack(spacing: 8) {
            Text("Action").frame(width: 168, alignment: .leading)
            Text("Wait (ms)").frame(width: 92, alignment: .leading)
            Text("Details").frame(maxWidth: .infinity, alignment: .leading)
            Text("").frame(width: 70)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 22)
        .padding(.vertical, 6)
    }

    private var footer: some View {
        HStack {
            Text("\(events.count) steps · total \(String(format: "%.2f", events.reduce(0) { $0 + $1.delay }))s")
                .font(.caption).foregroundStyle(.secondary)
            Spacer()
            Button("Cancel") { dismiss() }
                .keyboardShortcut(.cancelAction)
            Button("Save") { save() }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
        }
        .padding(14)
    }

    // MARK: - Insert / remove helpers

    /// Inserts events after the selected row, or at the end if nothing is selected.
    private func insert(_ newEvents: [MacroEvent]) {
        if let sel = selection, let idx = events.firstIndex(where: { $0.id == sel }) {
            events.insert(contentsOf: newEvents, at: idx + 1)
        } else {
            events.append(contentsOf: newEvents)
        }
        selection = newEvents.last?.id
    }

    private func duplicate(_ event: MacroEvent) {
        guard let idx = events.firstIndex(where: { $0.id == event.id }) else { return }
        var copy = event
        copy.id = UUID()
        events.insert(copy, at: idx + 1)
        selection = copy.id
    }

    private func delete(_ event: MacroEvent) {
        events.removeAll { $0.id == event.id }
    }

    // MARK: - New-event templates

    private func clickEvents(_ button: MouseButtonChoice) -> [MacroEvent] {
        let p = cursor()
        return [
            MacroEvent(kind: .mouseDown, delay: 0.10, x: p.x, y: p.y, button: button),
            MacroEvent(kind: .mouseUp, delay: 0.05, x: p.x, y: p.y, button: button),
        ]
    }

    private func keyEvents() -> [MacroEvent] {
        [
            MacroEvent(kind: .keyDown, delay: 0.10, keyCode: 49),  // space
            MacroEvent(kind: .keyUp, delay: 0.05, keyCode: 49),
        ]
    }

    private func moveEvent() -> MacroEvent {
        let p = cursor()
        return MacroEvent(kind: .mouseMove, delay: 0.10, x: p.x, y: p.y)
    }

    private func scrollEvent(up: Bool) -> MacroEvent {
        var e = MacroEvent(kind: .scroll, delay: 0.10)
        e.scrollY = up ? 10 : -10
        return e
    }

    private func cursor() -> CGPoint {
        let loc = NSEvent.mouseLocation
        let h = NSScreen.screens.first?.frame.height ?? 0
        return CGPoint(x: (loc.x).rounded(), y: (h - loc.y).rounded())
    }

    // MARK: - Load / save

    private func loadOnce() {
        guard !loaded, let macro = state.store.macros.first(where: { $0.id == macroID }) else { return }
        name = macro.name
        events = macro.events
        loaded = true
    }

    private func save() {
        guard var macro = state.store.macros.first(where: { $0.id == macroID }) else { dismiss(); return }
        macro.name = name.isEmpty ? macro.name : name
        macro.events = events
        state.store.update(macro)
        state.statusMessage = "Saved \(macro.name) (\(events.count) steps)"
        dismiss()
    }
}

/// One editable row in the macro editor.
struct EventEditorRow: View {
    @Binding var event: MacroEvent
    var onDuplicate: () -> Void
    var onDelete: () -> Void

    @State private var capturingKey = false
    @State private var keyMonitor: Any?

    var body: some View {
        HStack(spacing: 8) {
            Label(actionLabel, systemImage: icon)
                .labelStyle(.titleAndIcon)
                .frame(width: 168, alignment: .leading)

            TextField("ms", value: msBinding, format: .number)
                .textFieldStyle(.roundedBorder)
                .frame(width: 92)

            detail.frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 2) {
                Button(action: onDuplicate) { Image(systemName: "plus.square.on.square") }
                    .buttonStyle(.borderless).help("Duplicate")
                Button(action: onDelete) { Image(systemName: "trash") }
                    .buttonStyle(.borderless).foregroundStyle(.red).help("Delete")
            }
            .frame(width: 70, alignment: .trailing)
        }
        .padding(.vertical, 2)
        .onDisappear(perform: stopCapture)
    }

    private var msBinding: Binding<Double> {
        Binding(get: { (event.delay * 1000).rounded() },
                set: { event.delay = max(0, $0) / 1000 })
    }

    @ViewBuilder
    private var detail: some View {
        switch event.kind {
        case .mouseDown, .mouseUp:
            HStack(spacing: 6) {
                buttonPicker
                coord("X", $event.x)
                coord("Y", $event.y)
            }
        case .mouseMove:
            HStack(spacing: 6) { coord("X", $event.x); coord("Y", $event.y) }
        case .scroll:
            HStack(spacing: 6) {
                Text("Δ").foregroundStyle(.secondary)
                TextField("Δy", value: $event.scrollY, format: .number)
                    .textFieldStyle(.roundedBorder).frame(width: 60)
            }
        case .keyDown, .keyUp:
            HStack(spacing: 8) {
                Text(KeyNames.name(for: event.keyCode))
                    .font(.body.monospaced())
                Button(capturingKey ? "Press a key…" : "Set key") {
                    capturingKey ? stopCapture() : startCapture()
                }
                .buttonStyle(.bordered).controlSize(.small)
            }
        case .delay:
            Text("Pause").foregroundStyle(.secondary)
        }
    }

    private var buttonPicker: some View {
        Picker("", selection: $event.button) {
            ForEach(MouseButtonChoice.allCases) { Text($0.label).tag($0) }
        }
        .labelsHidden()
        .frame(width: 90)
    }

    private func coord(_ label: String, _ value: Binding<Double>) -> some View {
        HStack(spacing: 3) {
            Text(label).foregroundStyle(.secondary)
            TextField(label, value: value, format: .number)
                .textFieldStyle(.roundedBorder).frame(width: 62)
        }
    }

    // Capture a real keystroke to set this step's key + modifiers.
    private func startCapture() {
        stopCapture()
        capturingKey = true
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { ev in
            event.keyCode = ev.keyCode
            event.flags = UInt64(ev.modifierFlags.rawValue)
            stopCapture()
            return nil
        }
    }

    private func stopCapture() {
        capturingKey = false
        if let m = keyMonitor { NSEvent.removeMonitor(m); keyMonitor = nil }
    }

    private var actionLabel: String {
        switch event.kind {
        case .mouseDown: return "Button press"
        case .mouseUp:   return "Button release"
        case .mouseMove: return "Mouse move"
        case .keyDown:   return "Key down"
        case .keyUp:     return "Key up"
        case .scroll:    return "Scroll"
        case .delay:     return "Wait"
        }
    }

    private var icon: String {
        switch event.kind {
        case .mouseDown, .mouseUp: return "cursorarrow.click"
        case .mouseMove: return "arrow.up.left.and.arrow.down.right"
        case .keyDown, .keyUp: return "keyboard"
        case .scroll: return "scroll"
        case .delay: return "clock"
        }
    }
}
