import SwiftUI
import AppKit

struct AutoClickerView: View {
    @EnvironmentObject var state: AppState

    private var clicker: AutoClicker { state.clicker }

    var body: some View {
        VStack(spacing: 16) {
            header
            HStack(alignment: .top, spacing: 16) {
                intervalCard
                VStack(spacing: 16) {
                    optionsCard
                    locationCard
                }
            }
            actionBar
        }
        .padding(20)
    }

    // MARK: header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Autoclicker").font(.title2.bold())
                Text("Fire mouse clicks automatically at a precise rate.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            Spacer()
            cpsBadge
        }
    }

    private var cpsBadge: some View {
        let cps = state.interval.clicksPerSecond
        return VStack(spacing: 0) {
            Text(cps >= 100 ? String(format: "%.0f", cps) : String(format: "%.1f", cps))
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.accentGradient)
            Text("clicks / sec").font(.caption2).foregroundStyle(.secondary)
        }
        .frame(width: 120)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.accent.opacity(0.10)))
    }

    // MARK: interval

    private var intervalCard: some View {
        Card(title: "Click interval", systemImage: "timer") {
            HStack(spacing: 10) {
                timeField("hr", value: $state.interval.hours, range: 0...99)
                timeField("min", value: $state.interval.minutes, range: 0...59)
                timeField("sec", value: $state.interval.seconds, range: 0...59)
                timeField("ms", value: $state.interval.milliseconds, range: 0...999)
            }
            Divider()
            Text("Presets").font(.caption).foregroundStyle(.secondary)
            HStack {
                presetButton("10 CPS", ms: 100)
                presetButton("25 CPS", ms: 40)
                presetButton("50 CPS", ms: 20)
                presetButton("100 CPS", ms: 10)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func timeField(_ label: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        // A plain, typeable number box that clamps to its range on entry.
        let clamped = Binding<Int>(
            get: { value.wrappedValue },
            set: { value.wrappedValue = min(max($0, range.lowerBound), range.upperBound) }
        )
        return VStack(spacing: 4) {
            TextField("0", value: clamped, format: .number)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.center)
                .font(.system(.title3, design: .rounded).monospacedDigit())
                .frame(width: 68)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
    }

    private func presetButton(_ title: String, ms: Int) -> some View {
        Button(title) {
            state.interval = IntervalComponents(hours: 0, minutes: 0, seconds: 0, milliseconds: ms)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    // MARK: options

    private var optionsCard: some View {
        Card(title: "Click options", systemImage: "cursorarrow.rays") {
            labeledPicker("Mouse button") {
                Picker("", selection: $state.button) {
                    ForEach(MouseButtonChoice.allCases) { Text($0.label).tag($0) }
                }.pickerStyle(.segmented).labelsHidden()
            }
            labeledPicker("Click type") {
                Picker("", selection: $state.clickKind) {
                    ForEach(ClickKind.allCases) { Text($0.label).tag($0) }
                }.pickerStyle(.segmented).labelsHidden()
            }
            labeledPicker("Repeat") {
                Picker("", selection: $state.repeatMode) {
                    ForEach(RepeatMode.allCases) { Text($0.label).tag($0) }
                }.pickerStyle(.segmented).labelsHidden()
            }
            if state.repeatMode == .count {
                HStack {
                    Text("Number of clicks").font(.callout)
                    Spacer()
                    TextField("", value: $state.repeatCount, format: .number)
                        .textFieldStyle(.roundedBorder).frame(width: 80)
                        .multilineTextAlignment(.center)
                }
            }
            Toggle(isOn: $state.humanize) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Humanize").font(.callout)
                    Text("Add tiny random timing & position jitter")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            .toggleStyle(.switch)
        }
    }

    // MARK: location

    private var locationCard: some View {
        Card(title: "Click location", systemImage: "scope") {
            Picker("", selection: $state.locationMode) {
                ForEach(LocationMode.allCases) { Text($0.label).tag($0) }
            }.pickerStyle(.segmented).labelsHidden()

            if state.locationMode == .fixed {
                HStack(spacing: 10) {
                    coordField("X", value: $state.fixedX)
                    coordField("Y", value: $state.fixedY)
                    Button {
                        let p = currentFlippedLocation()
                        state.fixedX = Double(Int(p.x))
                        state.fixedY = Double(Int(p.y))
                    } label: {
                        Label("Capture cursor", systemImage: "dot.scope")
                    }
                    .buttonStyle(.bordered)
                }
            } else {
                Text("Clicks happen wherever your cursor is.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func coordField(_ label: String, value: Binding<Double>) -> some View {
        VStack(spacing: 4) {
            TextField("", value: value, format: .number)
                .textFieldStyle(.roundedBorder).frame(width: 80)
                .multilineTextAlignment(.center)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
    }

    // MARK: action

    private var actionBar: some View {
        HStack(spacing: 12) {
            PrimaryButton(
                title: clicker.isRunning ? "Stop" : "Start clicking",
                systemImage: clicker.isRunning ? "stop.fill" : "play.fill",
                active: clicker.isRunning
            ) { state.toggleClicker() }

            Text("or press \(state.hotkey.keyName(for: .toggleClicker))")
                .font(.callout).foregroundStyle(.secondary)
                .frame(width: 110)
        }
    }

    // MARK: helpers

    private func labeledPicker<V: View>(_ label: String, @ViewBuilder content: () -> V) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            content()
        }
    }

    private func currentFlippedLocation() -> CGPoint {
        let loc = NSEvent.mouseLocation
        let h = NSScreen.screens.first?.frame.height ?? 0
        return CGPoint(x: loc.x, y: h - loc.y)
    }
}
