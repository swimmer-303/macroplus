import SwiftUI

// Lets a UUID drive `.sheet(item:)` directly.
extension UUID: @retroactive Identifiable {
    public var id: UUID { self }
}

/// Full editor for a recorded macro: tune the wait before each step (incl. press
/// duration), edit coordinates, reorder, delete, and insert wait steps.
struct MacroEditorView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) private var dismiss

    let macroID: UUID
    @State private var name: String = ""
    @State private var events: [MacroEvent] = []
    @State private var loaded = false

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            if events.isEmpty {
                Spacer()
                Text("This macro has no steps.").foregroundStyle(.secondary)
                Spacer()
            } else {
                columnHeader
                List {
                    ForEach($events) { $event in
                        EventEditorRow(event: $event)
                    }
                    .onDelete { events.remove(atOffsets: $0) }
                    .onMove { events.move(fromOffsets: $0, toOffset: $1) }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }
            Divider()
            footer
        }
        .frame(width: 660, height: 560)
        .onAppear(perform: loadOnce)
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            Image(systemName: "slider.horizontal.3").foregroundStyle(Theme.accent)
            TextField("Macro name", text: $name)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 280)
            Spacer()
            Button {
                events.append(MacroEvent(kind: .delay, delay: 0.5))
            } label: {
                Label("Add wait", systemImage: "plus.circle")
            }
            .buttonStyle(.bordered)
        }
        .padding(14)
    }

    private var columnHeader: some View {
        HStack(spacing: 8) {
            Text("#").frame(width: 34, alignment: .trailing)
            Text("Action").frame(width: 220, alignment: .leading)
            Text("Wait before (ms)").frame(width: 130, alignment: .leading)
            Text("Position / key").frame(maxWidth: .infinity, alignment: .leading)
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

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(Theme.accent)
                .frame(width: 34, alignment: .center)

            Text(actionLabel)
                .frame(width: 220, alignment: .leading)

            TextField("ms", value: msBinding, format: .number)
                .textFieldStyle(.roundedBorder)
                .frame(width: 130)

            detail
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 2)
    }

    // Wait-before in milliseconds, backed by the event's seconds delay.
    private var msBinding: Binding<Double> {
        Binding(get: { (event.delay * 1000).rounded() },
                set: { event.delay = max(0, $0) / 1000 })
    }

    @ViewBuilder
    private var detail: some View {
        switch event.kind {
        case .mouseDown, .mouseUp, .mouseMove, .scroll:
            HStack(spacing: 6) {
                Text("X").foregroundStyle(.secondary)
                TextField("X", value: $event.x, format: .number)
                    .textFieldStyle(.roundedBorder).frame(width: 70)
                Text("Y").foregroundStyle(.secondary)
                TextField("Y", value: $event.y, format: .number)
                    .textFieldStyle(.roundedBorder).frame(width: 70)
            }
        case .keyDown, .keyUp:
            Text(KeyNames.name(for: event.keyCode))
                .font(.body.monospaced())
                .foregroundStyle(.secondary)
        case .delay:
            Text("Pause").foregroundStyle(.secondary)
        }
    }

    private var actionLabel: String {
        switch event.kind {
        case .mouseDown: return "\(event.button.label) button press"
        case .mouseUp:   return "\(event.button.label) button release"
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
