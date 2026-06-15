import Foundation

/// Persists macros to JSON in Application Support and exposes them to the UI.
final class MacroStore: ObservableObject {
    @Published var macros: [Macro] = []

    private let fileURL: URL

    init() {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("MacroPlus", isDirectory: true)
        try? fm.createDirectory(at: base, withIntermediateDirectories: true)
        fileURL = base.appendingPathComponent("macros.json")
        load()
    }

    func add(_ macro: Macro) {
        macros.insert(macro, at: 0)
        save()
    }

    func delete(_ macro: Macro) {
        macros.removeAll { $0.id == macro.id }
        save()
    }

    func rename(_ macro: Macro, to name: String) {
        guard let i = macros.firstIndex(where: { $0.id == macro.id }) else { return }
        macros[i].name = name
        save()
    }

    func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        if let decoded = try? JSONDecoder().decode([Macro].self, from: data) {
            macros = decoded
        }
    }

    func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        if let data = try? encoder.encode(macros) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    /// Exports a macro to an arbitrary URL (for the Export… command).
    func export(_ macro: Macro, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        try encoder.encode(macro).write(to: url, options: .atomic)
    }

    /// Imports a macro from a JSON file.
    func importMacro(from url: URL) throws {
        let data = try Data(contentsOf: url)
        let macro = try JSONDecoder().decode(Macro.self, from: data)
        add(macro)
    }
}
