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

    private var recorded: [MacroEvent] = []
    private var lastTimestamp: TimeInterval = 0
    private let source = CGEventSource(stateID: .hidSystemState)
    private var playbackWork: DispatchWorkItem?

    // CGEventTap state — a listen-only tap reliably captures both keyboard and mouse.
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    var onRecordingFinished: ((Macro) -> Void)?
    var onPlaybackFinished: (() -> Void)?

    // MARK: - Recording

    func startRecording() {
        guard !isRecording else { return }
        recorded = []
        liveEventCount = 0
        lastTimestamp = ProcessInfo.processInfo.systemUptime

        var mask: CGEventMask =
            (1 << CGEventType.leftMouseDown.rawValue) |
            (1 << CGEventType.leftMouseUp.rawValue) |
            (1 << CGEventType.rightMouseDown.rawValue) |
            (1 << CGEventType.rightMouseUp.rawValue) |
            (1 << CGEventType.otherMouseDown.rawValue) |
            (1 << CGEventType.otherMouseUp.rawValue) |
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.keyUp.rawValue) |
            (1 << CGEventType.scrollWheel.rawValue)
        if recordMouseMoves {
            mask |= (1 << CGEventType.mouseMoved.rawValue)
        }

        let refcon = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon in
                if let refcon = refcon {
                    let engine = Unmanaged<MacroEngine>.fromOpaque(refcon).takeUnretainedValue()
                    engine.handleTap(type: type, event: event)
                }
                return Unmanaged.passUnretained(event)
            },
            userInfo: refcon
        ) else {
            // Tap creation fails when permissions are missing.
            DispatchQueue.main.async { [weak self] in
                self?.onRecordingFinished?(Macro(name: "", events: []))
            }
            return
        }

        let src = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), src, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        eventTap = tap
        runLoopSource = src
        isRecording = true
    }

    func stopRecording(name: String) {
        guard isRecording else { return }
        tearDownTap()
        isRecording = false
        let macro = Macro(name: name, events: recorded)
        DispatchQueue.main.async { [weak self] in self?.onRecordingFinished?(macro) }
    }

    /// Called from the event-tap callback for every observed system event.
    fileprivate func handleTap(type: CGEventType, event: CGEvent) {
        // The system can disable a tap on timeout/heavy load — re-enable it.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
            return
        }

        let now = ProcessInfo.processInfo.systemUptime
        let delay = max(0, now - lastTimestamp)
        lastTimestamp = now

        let p = event.location   // global coords, top-left origin (matches playback)
        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags.rawValue
        var ev: MacroEvent?

        switch type {
        case .leftMouseDown:   ev = MacroEvent(kind: .mouseDown, delay: delay, x: p.x, y: p.y, button: .left)
        case .leftMouseUp:     ev = MacroEvent(kind: .mouseUp, delay: delay, x: p.x, y: p.y, button: .left)
        case .rightMouseDown:  ev = MacroEvent(kind: .mouseDown, delay: delay, x: p.x, y: p.y, button: .right)
        case .rightMouseUp:    ev = MacroEvent(kind: .mouseUp, delay: delay, x: p.x, y: p.y, button: .right)
        case .otherMouseDown:  ev = MacroEvent(kind: .mouseDown, delay: delay, x: p.x, y: p.y, button: .middle)
        case .otherMouseUp:    ev = MacroEvent(kind: .mouseUp, delay: delay, x: p.x, y: p.y, button: .middle)
        case .mouseMoved:      ev = MacroEvent(kind: .mouseMove, delay: delay, x: p.x, y: p.y)
        case .keyDown:         ev = MacroEvent(kind: .keyDown, delay: delay, keyCode: keyCode, flags: flags)
        case .keyUp:           ev = MacroEvent(kind: .keyUp, delay: delay, keyCode: keyCode, flags: flags)
        case .scrollWheel:
            var e = MacroEvent(kind: .scroll, delay: delay, x: p.x, y: p.y)
            e.scrollY = Int32(event.getIntegerValueField(.scrollWheelEventDeltaAxis1))
            e.scrollX = Int32(event.getIntegerValueField(.scrollWheelEventDeltaAxis2))
            ev = e
        default:
            break
        }

        if let ev = ev {
            recorded.append(ev)
            let count = recorded.count
            DispatchQueue.main.async { [weak self] in self?.liveEventCount = count }
        }
    }

    // MARK: - Playback

    /// Plays a macro at `speed` multiplier (2.0 = twice as fast).
    /// If `loopForever` is true it repeats until `stopPlayback()` is called;
    /// otherwise it runs `repeatCount` times.
    func play(_ macro: Macro, loopForever: Bool, repeatCount: Int, speed: Double) {
        stopPlayback()
        guard !macro.events.isEmpty else { return }
        isPlaying = true
        playbackProgress = 0

        let work = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            let loops = max(1, repeatCount)
            let totalSteps = macro.events.count * loops
            var step = 0
            var loop = 0

            while loopForever || loop < loops {
                for ev in macro.events {
                    if self.playbackWork?.isCancelled ?? true { return }
                    let wait = ev.delay / max(0.05, speed)
                    if wait > 0 { Thread.sleep(forTimeInterval: wait) }
                    self.perform(ev)
                    if !loopForever {
                        step += 1
                        let progress = Double(step) / Double(totalSteps)
                        DispatchQueue.main.async { self.playbackProgress = progress }
                    }
                }
                loop += 1
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

    private func tearDownTap() {
        if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let src = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), src, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }
}
