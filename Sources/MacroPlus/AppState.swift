import Foundation
import SwiftUI
import CoreGraphics
import Combine

/// The single source of truth shared across all views and engines.
final class AppState: ObservableObject {
    private var cancellables = Set<AnyCancellable>()
    // Engines
    let clicker = AutoClicker()
    let macroEngine = MacroEngine()
    let store = MacroStore()
    let hotkey = HotkeyManager()
    let permissions = Permissions()

    // Autoclicker settings
    @Published var interval = IntervalComponents()
    @Published var button: MouseButtonChoice = .left
    @Published var clickKind: ClickKind = .single
    @Published var repeatMode: RepeatMode = .forever
    @Published var repeatCount: Int = 50
    @Published var locationMode: LocationMode = .current
    @Published var fixedX: Double = 500
    @Published var fixedY: Double = 400
    @Published var humanize: Bool = false

    // Macro settings
    @Published var macroRepeatMode: RepeatMode = .forever
    @Published var macroRepeat: Int = 1
    @Published var macroSpeed: Double = 1.0
    @Published var recordMouseMoves: Bool = false
    @Published var selectedMacroID: UUID?

    // UI
    @Published var statusMessage: String = "Ready"

    init() {
        forwardChanges()
        wireUp()
    }

    /// Re-publish nested ObservableObject changes so SwiftUI views observing
    /// AppState refresh when an engine's state changes.
    private func forwardChanges() {
        for publisher in [clicker.objectWillChange,
                          macroEngine.objectWillChange,
                          store.objectWillChange,
                          permissions.objectWillChange,
                          hotkey.objectWillChange] {
            publisher
                .receive(on: RunLoop.main)
                .sink { [weak self] in self?.objectWillChange.send() }
                .store(in: &cancellables)
        }
    }

    private func wireUp() {
        clicker.onFinished = { [weak self] in
            guard let self = self else { return }
            self.statusMessage = "Stopped after \(self.clicker.clicksDone) clicks"
        }
        macroEngine.onRecordingFinished = { [weak self] macro in
            guard let self = self else { return }
            guard !macro.events.isEmpty else {
                self.statusMessage = "Nothing recorded — check Input Monitoring & Accessibility"
                return
            }
            var m = macro
            if m.name.isEmpty { m.name = "Macro \(self.store.macros.count + 1)" }
            self.store.add(m)
            self.selectedMacroID = m.id
            self.statusMessage = "Recorded \(m.events.count) events"
        }
        macroEngine.onPlaybackFinished = { [weak self] in
            self?.statusMessage = "Playback finished"
        }
        hotkey.handlers[.toggleClicker] = { [weak self] in self?.toggleClicker() }
        hotkey.handlers[.toggleRecording] = { [weak self] in self?.toggleRecording() }
        hotkey.handlers[.playMacro] = { [weak self] in self?.togglePlayback() }
        hotkey.install()
    }

    // MARK: - Autoclicker control

    func toggleClicker() {
        if clicker.isRunning {
            clicker.stop()
        } else {
            startClicker()
        }
    }

    func startClicker() {
        guard ensureTrusted() else { return }
        let job = ClickJob(
            interval: interval.totalSeconds,
            button: button,
            kind: clickKind,
            repeatForever: repeatMode == .forever,
            repeatCount: repeatCount,
            useFixedLocation: locationMode == .fixed,
            fixedPoint: CGPoint(x: fixedX, y: fixedY),
            humanize: humanize
        )
        guard job.interval > 0 else {
            statusMessage = "Set an interval greater than 0"
            return
        }
        clicker.start(job)
        statusMessage = repeatMode == .forever
            ? "Clicking… press \(hotkey.keyName(for: .toggleClicker)) to stop"
            : "Clicking \(repeatCount)×…"
    }

    // MARK: - Macro control

    func toggleRecording() {
        if macroEngine.isRecording {
            macroEngine.stopRecording(name: "")
            return
        }
        guard ensureCanRecord() else { return }
        macroEngine.recordMouseMoves = recordMouseMoves
        macroEngine.startRecording()
        statusMessage = "Recording… click & type, then press Stop"
    }

    func playSelected() {
        guard ensureTrusted(), let macro = selectedMacro else { return }
        let forever = macroRepeatMode == .forever
        macroEngine.play(macro, loopForever: forever,
                         repeatCount: macroRepeat, speed: macroSpeed)
        statusMessage = forever
            ? "Looping \(macro.name)… press \(hotkey.keyName(for: .playMacro)) to stop"
            : "Playing \(macro.name) \(macroRepeat)×…"
    }

    func stopMacro() {
        macroEngine.stopPlayback()
    }

    func togglePlayback() {
        if macroEngine.isPlaying { stopMacro() } else { playSelected() }
    }

    var selectedMacro: Macro? {
        store.macros.first { $0.id == selectedMacroID }
    }

    // MARK: - Permissions gate

    @discardableResult
    func ensureTrusted() -> Bool {
        permissions.refresh()
        if !permissions.trusted {
            permissions.requestWithPrompt()
            statusMessage = "Grant Accessibility access, then try again"
            return false
        }
        return true
    }

    /// Recording listens to global input, which needs the Input Monitoring permission.
    @discardableResult
    func ensureCanRecord() -> Bool {
        permissions.refresh()
        if !permissions.inputMonitoring {
            permissions.requestInputMonitoring()
            permissions.openInputMonitoringSettings()
            statusMessage = "Enable MacroPlus under Input Monitoring, then record again"
            return false
        }
        return true
    }
}
