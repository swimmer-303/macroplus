import Foundation
import CoreGraphics
import AppKit

/// Configuration captured at the moment the user presses Start.
struct ClickJob {
    var interval: Double          // seconds between clicks
    var button: MouseButtonChoice
    var kind: ClickKind
    var repeatForever: Bool
    var repeatCount: Int
    var useFixedLocation: Bool
    var fixedPoint: CGPoint
    var humanize: Bool            // add small random jitter to interval/position
}

/// Drives synthetic mouse clicks on a background timer.
final class AutoClicker: ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var clicksDone = 0

    private var timer: DispatchSourceTimer?
    private let queue = DispatchQueue(label: "com.macroplus.autoclicker", qos: .userInteractive)
    private var job: ClickJob?
    private let source = CGEventSource(stateID: .hidSystemState)

    var onFinished: (() -> Void)?
    var onTick: ((Int) -> Void)?

    func start(_ job: ClickJob) {
        stop()
        guard job.interval > 0 else { return }
        self.job = job
        clicksDone = 0
        isRunning = true

        let t = DispatchSource.makeTimerSource(queue: queue)
        // Leeway kept tiny for accurate cadence at high CPS.
        t.schedule(deadline: .now(), repeating: job.interval, leeway: .nanoseconds(0))
        t.setEventHandler { [weak self] in
            self?.fire()
        }
        timer = t
        t.resume()
    }

    func stop() {
        timer?.cancel()
        timer = nil
        if isRunning {
            isRunning = false
            DispatchQueue.main.async { [weak self] in self?.onFinished?() }
        }
    }

    /// Performs one click iteration on the timer queue.
    private func fire() {
        guard let job = job else { return }

        let point: CGPoint
        if job.useFixedLocation {
            point = jitter(job.fixedPoint, enabled: job.humanize, radius: 1.5)
        } else {
            point = currentMouseLocation()
        }

        postClick(at: point, button: job.button)
        if job.kind == .double {
            // Second click of a double-click, tagged so the OS recognises it.
            postClick(at: point, button: job.button, clickState: 2)
        }

        let total = clicksDone + 1
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.clicksDone = total
            self.onTick?(total)
        }

        if !job.repeatForever && total >= job.repeatCount {
            stop()
        } else if job.humanize {
            // Re-schedule with a slightly randomised next interval for a human feel.
            rescheduleHumanized(base: job.interval)
        }
    }

    private func rescheduleHumanized(base: Double) {
        guard let t = timer else { return }
        let jitterFraction = Double.random(in: -0.12...0.12)
        let next = max(0.001, base * (1.0 + jitterFraction))
        t.schedule(deadline: .now() + next, repeating: base, leeway: .nanoseconds(0))
    }

    private func postClick(at point: CGPoint, button: MouseButtonChoice, clickState: Int64 = 1) {
        guard let down = CGEvent(mouseEventSource: source,
                                 mouseType: button.downEvent,
                                 mouseCursorPosition: point,
                                 mouseButton: button.cgButton),
              let up = CGEvent(mouseEventSource: source,
                               mouseType: button.upEvent,
                               mouseCursorPosition: point,
                               mouseButton: button.cgButton) else { return }
        down.setIntegerValueField(.mouseEventClickState, value: clickState)
        up.setIntegerValueField(.mouseEventClickState, value: clickState)
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }

    private func currentMouseLocation() -> CGPoint {
        // NSEvent uses bottom-left origin; CGEvent uses top-left. Flip Y.
        let loc = NSEvent.mouseLocation
        let screenHeight = NSScreen.screens.first?.frame.height ?? 0
        return CGPoint(x: loc.x, y: screenHeight - loc.y)
    }

    private func jitter(_ p: CGPoint, enabled: Bool, radius: Double) -> CGPoint {
        guard enabled else { return p }
        return CGPoint(x: p.x + Double.random(in: -radius...radius),
                       y: p.y + Double.random(in: -radius...radius))
    }
}
