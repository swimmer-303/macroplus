import Foundation
import CoreGraphics

// MARK: - Click configuration

enum MouseButtonChoice: String, CaseIterable, Codable, Identifiable {
    case left
    case right
    case middle

    var id: String { rawValue }

    var label: String {
        switch self {
        case .left: return "Left"
        case .right: return "Right"
        case .middle: return "Middle"
        }
    }

    var cgButton: CGMouseButton {
        switch self {
        case .left: return .left
        case .right: return .right
        case .middle: return .center
        }
    }

    var downEvent: CGEventType {
        switch self {
        case .left: return .leftMouseDown
        case .right: return .rightMouseDown
        case .middle: return .otherMouseDown
        }
    }

    var upEvent: CGEventType {
        switch self {
        case .left: return .leftMouseUp
        case .right: return .rightMouseUp
        case .middle: return .otherMouseUp
        }
    }
}

enum ClickKind: String, CaseIterable, Codable, Identifiable {
    case single
    case double

    var id: String { rawValue }
    var label: String { self == .single ? "Single" : "Double" }
}

enum RepeatMode: String, CaseIterable, Identifiable {
    case forever
    case count

    var id: String { rawValue }
    var label: String { self == .forever ? "Until stopped" : "Repeat N times" }
}

enum LocationMode: String, CaseIterable, Identifiable {
    case current
    case fixed

    var id: String { rawValue }
    var label: String { self == .current ? "Current cursor" : "Fixed point" }
}

// MARK: - Time interval helper

/// Editable interval broken into hours/minutes/seconds/milliseconds for the UI.
struct IntervalComponents: Equatable {
    var hours: Int = 0
    var minutes: Int = 0
    var seconds: Int = 0
    var milliseconds: Int = 100

    var totalSeconds: Double {
        Double(hours) * 3600
            + Double(minutes) * 60
            + Double(seconds)
            + Double(milliseconds) / 1000.0
    }

    /// Clicks per second derived from the interval (0 if interval is 0).
    var clicksPerSecond: Double {
        let t = totalSeconds
        return t > 0 ? 1.0 / t : 0
    }
}

// MARK: - Macro events

enum MacroEventKind: String, Codable {
    case mouseDown
    case mouseUp
    case mouseMove
    case keyDown
    case keyUp
    case scroll
    case delay
}

/// A single recorded action in a macro.
struct MacroEvent: Codable, Identifiable {
    var id = UUID()
    var kind: MacroEventKind
    /// Seconds to wait *before* performing this event, relative to the previous one.
    var delay: Double
    // Mouse
    var x: Double = 0
    var y: Double = 0
    var button: MouseButtonChoice = .left
    // Keyboard
    var keyCode: UInt16 = 0
    var flags: UInt64 = 0
    // Scroll
    var scrollY: Int32 = 0
    var scrollX: Int32 = 0

    var summary: String {
        switch kind {
        case .mouseDown: return "\(button.label) press · (\(Int(x)), \(Int(y)))"
        case .mouseUp:   return "\(button.label) release · (\(Int(x)), \(Int(y)))"
        case .mouseMove: return "Move → (\(Int(x)), \(Int(y)))"
        case .keyDown:   return "Key down · \(KeyNames.name(for: keyCode))"
        case .keyUp:     return "Key up · \(KeyNames.name(for: keyCode))"
        case .scroll:    return "Scroll · Δy \(scrollY) Δx \(scrollX)"
        case .delay:     return "Wait \(String(format: "%.0f", delay * 1000)) ms"
        }
    }
}

/// A named, saveable sequence of events.
struct Macro: Codable, Identifiable {
    var id = UUID()
    var name: String
    var events: [MacroEvent]
    var createdAt: Date = Date()

    var duration: Double { events.reduce(0) { $0 + $1.delay } }
}
