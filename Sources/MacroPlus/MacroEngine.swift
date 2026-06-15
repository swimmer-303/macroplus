import Foundation
import AppKit
import CoreGraphics

/// Records system input into a `Macro` and plays macros back via synthetic events.
final class MacroEngine: ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var isPlaying = false
    @Published private(set) var liveEventCount = 0
    @Published private(set) var playbackProgress: Double = 0   // 0...1

    /// Whether to capture mouse-move events (off by default — they create huge macros).
    var recordMouseMoves = false

    private var monitors: [Any] = []
    private var recorded: [MacroEvent] = []
    private var lastTimestamp: TimeInterval = 0
    private let source = CGEventSource(stateID: .hidSystemState)
    private var playbackWork: DispatchWorkItem?

    var onRecordingFinished: ((Macro) -> Void)?
    var onPlaybackFinished: (() -> Void)?

    // MARK: - Recording

    func startRecording() {
        guard !isRecording else { return }
        recorded = []
        liveEventCount = 0
        lastTimestamp = ProcessInfo.processInfo.systemUptime
        isRecording = true

        let mask: NSEvent.EventTypeMask = [
            .leftMouseDown, .leftMouseUp,
            .rightMouseDown, .rightMouseUp,
            .otherMouseDown, .otherMouseUp,
            .keyDown, .keyUp, .scrollWheel,
            recordMouseMoves ? .mouseMoved : []
        ]

        // Global monitor only: it fires for events sent to *other* apps, never to
        // MacroPlus itself. That means clicking our own Start/Stop buttons is never
        // recorded — a macro is meant to automate other applications.
        if let m = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { [weak self] event in
            self?.capture(event)
        }) {
            monitors.append(m)
        }
    }

    func stopRecording(name: String) {
        guard isRecording else { return }
        tearDownMonitors()
        isRecording = false
        let macro = Macro(name: name, events: recorded)
        DispatchQueue.main.async { [weak self] in self?.onRecordingFinished?(macro) }
    }

    private func capture(_ event: NSEvent) {
        let now = ProcessInfo.processInfo.systemUptime
        let delay = max(0, now - lastTimestamp)
        lastTimestamp = now

        let p = flippedMouseLocation()
        var ev: MacroEvent?

        switch event.type {
        case .leftMouseDown:   ev = MacroEvent(kind: .mouseDown, delay: delay, x: p.x, y: p.y, button: .left)
        case .leftMouseUp:     ev = MacroEvent(kind: .mouseUp, delay: delay, x: p.x, y: p.y, button: .left)
        case .rightMouseDown:  ev = MacroEvent(kind: .mouseDown, delay: delay, x: p.x, y: p.y, button: .right)
        case .rightMouseUp:    ev = MacroEvent(kind: .mouseUp, delay: delay, x: p.x, y: p.y, button: .right)
        case .otherMouseDown:  ev = MacroEvent(kind: .mouseDown, delay: delay, x: p.x, y: p.y, button: .middle)
        case .otherMouseUp:    ev = MacroEvent(kind: .mouseUp, delay: delay, x: p.x, y: p.y, button: .middle)
        case .mouseMoved:      ev = MacroEvent(kind: .mouseMove, delay: delay, x: p.x, y: p.y)
        case .keyDown:
            ev = MacroEvent(kind: .keyDown, delay: delay, keyCode: event.keyCode,
                            flags: UInt64(event.modifierFlags.rawValue))
        case .keyUp:
            ev = MacroEvent(kind: .keyUp, delay: delay, keyCode: event.keyCode,
                            flags: UInt64(event.modifierFlags.rawValue))
        case .scrollWheel:
            var e = MacroEvent(kind: .scroll, delay: delay, x: p.x, y: p.y)
            e.scrollY = Int32(event.scrollingDeltaY)
            e.scrollX = Int32(event.scrollingDeltaX)
            ev = e
        default:
            break
        }

        if let ev = ev {
            recorded.append(ev)
            DispatchQueue.main.async { [weak self] in self?.liveEventCount = self?.recorded.count ?? 0 }
        }
    }

    // MARK: - Playback

    /// Plays a macro `repeatCount` times at `speed` multiplier (2.0 = twice as fast).
    func play(_ macro: Macro, repeatCount: Int, speed: Double) {
        stopPlayback()
        guard !macro.events.isEmpty else { return }
        isPlaying = true
        playbackProgress = 0

        let work = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            let loops = max(1, repeatCount)
            let totalSteps = macro.events.count * loops
            var step = 0

            for _ in 0..<loops {
                for ev in macro.events {
                    if self.playbackWork?.isCancelled ?? true { return }
                    let wait = ev.delay / max(0.05, speed)
                    if wait > 0 { Thread.sleep(forTimeInterval: wait) }
                    self.perform(ev)
                    step += 1
                    let progress = Double(step) / Double(totalSteps)
                    DispatchQueue.main.async { self.playbackProgress = progress }
                }
            }
            DispatchQueue.main.async {
                self.isPlaying = false
                self.playbackProgress = 1
                self.onPlaybackFinished?()
            }
        }
        playbackWork = work
        DispatchQueue.global(qos: .userInteractive).async(execute: work)
    }

    func stopPlayback() {
        playbackWork?.cancel()
        playbackWork = nil
        if isPlaying {
            isPlaying = false
            DispatchQueue.main.async { [weak self] in self?.onPlaybackFinished?() }
        }
    }

    private func perform(_ ev: MacroEvent) {
        switch ev.kind {
        case .mouseDown:
            postMouse(ev.button.downEvent, button: ev.button, at: CGPoint(x: ev.x, y: ev.y))
        case .mouseUp:
            postMouse(ev.button.upEvent, button: ev.button, at: CGPoint(x: ev.x, y: ev.y))
        case .mouseMove:
            if let e = CGEvent(mouseEventSource: source, mouseType: .mouseMoved,
                               mouseCursorPosition: CGPoint(x: ev.x, y: ev.y), mouseButton: .left) {
                e.post(tap: .cghidEventTap)
            }
        case .keyDown:
            postKey(ev.keyCode, down: true, flags: ev.flags)
        case .keyUp:
            postKey(ev.keyCode, down: false, flags: ev.flags)
        case .scroll:
            if let e = CGEvent(scrollWheelEvent2Source: source, units: .pixel,
                               wheelCount: 2, wheel1: ev.scrollY, wheel2: ev.scrollX, wheel3: 0) {
                e.post(tap: .cghidEventTap)
            }
        case .delay:
            break
        }
    }

    private func postMouse(_ type: CGEventType, button: MouseButtonChoice, at point: CGPoint) {
        if let e = CGEvent(mouseEventSource: source, mouseType: type,
                           mouseCursorPosition: point, mouseButton: button.cgButton) {
            e.post(tap: .cghidEventTap)
        }
    }

    private func postKey(_ code: UInt16, down: Bool, flags: UInt64) {
        if let e = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: down) {
            e.flags = CGEventFlags(rawValue: flags)
            e.post(tap: .cghidEventTap)
        }
    }

    private func flippedMouseLocation() -> CGPoint {
        let loc = NSEvent.mouseLocation
        let screenHeight = NSScreen.screens.first?.frame.height ?? 0
        return CGPoint(x: loc.x, y: screenHeight - loc.y)
    }

    private func tearDownMonitors() {
        for m in monitors { NSEvent.removeMonitor(m) }
        monitors.removeAll()
    }
}
