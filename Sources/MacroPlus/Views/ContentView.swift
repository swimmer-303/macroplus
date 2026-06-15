import SwiftUI

enum Panel: String, CaseIterable, Identifiable {
    case clicker = "Autoclicker"
    case macros = "Macros"
    case settings = "Settings"

    var id: String { rawValue }
    var icon: String {
        switch self {
        case .clicker: return "cursorarrow.click.2"
        case .macros: return "record.circle"
        case .settings: return "gearshape"
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var state: AppState
    @State private var panel: Panel = .clicker

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            VStack(spacing: 0) {
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                StatusBar()
            }
        }
        .navigationSplitViewStyle(.balanced)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 4) {
            brand
                .padding(.horizontal, 12)
                .padding(.top, 18)
                .padding(.bottom, 12)

            ForEach(Panel.allCases) { p in
                SidebarRow(panel: p, selected: panel == p) { panel = p }
            }
            Spacer()
            PermissionBadge()
                .padding(12)
        }
        .frame(minWidth: 200)
    }

    private var brand: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Theme.accentGradient)
                    .frame(width: 34, height: 34)
                Image(systemName: "cursorarrow.click.2")
                    .foregroundStyle(.white)
                    .font(.system(size: 16, weight: .bold))
            }
            VStack(alignment: .leading, spacing: 0) {
                Text("MacroPlus").font(.headline)
                Text("Click & macro studio")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        ScrollView {
            switch panel {
            case .clicker: AutoClickerView()
            case .macros: MacroView()
            case .settings: SettingsView()
            }
        }
    }
}

struct SidebarRow: View {
    let panel: Panel
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: panel.icon)
                    .frame(width: 20)
                    .foregroundStyle(selected ? Theme.accent : .secondary)
                Text(panel.rawValue)
                    .foregroundStyle(selected ? .primary : .secondary)
                Spacer()
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(selected ? Theme.accent.opacity(0.14) : .clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
    }
}

struct StatusBar: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(state.clicker.isRunning || state.macroEngine.isPlaying || state.macroEngine.isRecording
                      ? Color.green : Color.secondary.opacity(0.4))
                .frame(width: 8, height: 8)
            Text(state.statusMessage)
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer()
            if state.clicker.isRunning {
                Text("\(state.clicker.clicksDone) clicks")
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(Theme.accent)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(.bar)
    }
}

struct PermissionBadge: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        let allOK = state.permissions.trusted && state.permissions.inputMonitoring
        return Button {
            if !state.permissions.trusted { state.permissions.requestWithPrompt() }
            else if !state.permissions.inputMonitoring {
                state.permissions.requestInputMonitoring()
                state.permissions.openInputMonitoringSettings()
            } else {
                state.permissions.openSystemSettings()
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: allOK ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                    .foregroundStyle(allOK ? .green : .orange)
                VStack(alignment: .leading, spacing: 1) {
                    Text(allOK ? "Permissions on" : "Permission needed")
                        .font(.caption.weight(.semibold))
                    Text(allOK ? "Ready to click & record"
                         : (!state.permissions.trusted ? "Grant Accessibility" : "Grant Input Monitoring"))
                        .font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.05)))
        }
        .buttonStyle(.plain)
    }
}
