import SwiftUI

public struct PreferencesView: View {
    @ObservedObject private var prefs = PreferencesManager.shared

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    networkSpeedSection
                    appearanceSection
                    menuBarSection
                    modulesSection
                    generalSection
                }
                .padding()
            }
        }
        .frame(width: 420)
    }

    // MARK: - Network Speed (Live)

    private var networkSpeedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "network")
                    .font(.title3)
                    .foregroundColor(.accentColor)
                Text("Live Network Speed")
                    .font(.headline)
                Spacer()
                Circle()
                    .fill(prefs.networkStats.isConnected ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                Text(prefs.networkStats.isConnected ? "Connected" : "Disconnected")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                speedRow(
                    icon: "arrow.down.circle.fill",
                    iconColor: .green,
                    label: "Download",
                    value: prefs.networkStats.downloadSpeed
                )
                speedRow(
                    icon: "arrow.up.circle.fill",
                    iconColor: .orange,
                    label: "Upload",
                    value: prefs.networkStats.uploadSpeed
                )
                Divider()
                infoRow(icon: "clock.fill", iconColor: .blue, label: "Latency", value: prefs.networkStats.latency)
                infoRow(icon: "network", iconColor: .purple, label: "Interface", value: prefs.networkStats.interface)
                infoRow(icon: "globe", iconColor: .cyan, label: "Public IP", value: prefs.networkStats.publicIP)
                Divider()
                infoRow(icon: "arrow.triangle.2.circlepath", iconColor: .gray, label: "Session Down", value: prefs.networkStats.sessionDownloaded)
                infoRow(icon: "arrow.triangle.2.circlepath", iconColor: .gray, label: "Session Up", value: prefs.networkStats.sessionUploaded)
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .controlBackgroundColor)))
        }
    }

    private func speedRow(icon: String, iconColor: Color, label: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(iconColor)
                .frame(width: 20)
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(.body, design: .monospaced))
                .fontWeight(.medium)
        }
        .font(.subheadline)
    }

    private func infoRow(icon: String, iconColor: Color, label: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(iconColor)
                .frame(width: 20)
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .monospacedDigit()
        }
    }

    // MARK: - Appearance

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "paintbrush")
                    .font(.title3)
                    .foregroundColor(.accentColor)
                Text("Appearance")
                    .font(.headline)
            }

            HStack {
                Text("Theme")
                    .font(.subheadline)
                Spacer()
                Picker("", selection: $prefs.preferences.theme) {
                    ForEach(Theme.allCases, id: \.self) { theme in
                        Text(theme.rawValue.capitalized).tag(theme)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }

            HStack {
                Text("Density")
                    .font(.subheadline)
                Spacer()
                Picker("", selection: $prefs.preferences.density) {
                    ForEach(Density.allCases, id: \.self) { density in
                        Text(density.rawValue.capitalized).tag(density)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 240)
            }

            Toggle("Compact Mode", isOn: $prefs.preferences.compactMode)
                .font(.subheadline)
        }
    }

    // MARK: - Menu Bar

    private var menuBarSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "menubar.rectangle")
                    .font(.title3)
                    .foregroundColor(.accentColor)
                Text("Menu Bar")
                    .font(.headline)
            }

            Toggle("Show Arrows", isOn: $prefs.preferences.showArrows)
                .font(.subheadline)
            Toggle("Show Units", isOn: $prefs.preferences.showUnits)
                .font(.subheadline)
            Toggle("Fixed Width", isOn: $prefs.preferences.fixedWidth)
                .font(.subheadline)
        }
    }

    // MARK: - Modules

    private var modulesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "puzzlepiece.fill")
                    .font(.title3)
                    .foregroundColor(.accentColor)
                Text("Modules")
                    .font(.headline)
            }

            Toggle("Show Disabled Modules", isOn: $prefs.preferences.showDisabledModules)
                .font(.subheadline)

            ForEach(prefs.preferences.moduleConfigs, id: \.id) { config in
                ModuleConfigRow(config: config)
            }
        }
    }

    // MARK: - General

    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "gear")
                    .font(.title3)
                    .foregroundColor(.accentColor)
                Text("General")
                    .font(.headline)
            }

            HStack {
                Text("Refresh Interval (seconds)")
                    .font(.subheadline)
                Spacer()
                TextField("1", text: Binding(
                    get: { String(Int(prefs.preferences.updateInterval)) },
                    set: { newValue in
                        prefs.update { $0.updateInterval = Double(newValue) ?? 1 }
                    }
                ))
                .textFieldStyle(.roundedBorder)
                .frame(width: 60)
                .multilineTextAlignment(.center)
            }

            Toggle("Launch at Login", isOn: $prefs.preferences.launchAtLogin)
                .font(.subheadline)

            Toggle("Analytics", isOn: $prefs.preferences.analyticsEnabled)
                .font(.subheadline)
        }
    }
}

// MARK: - Module Config Row

private struct ModuleConfigRow: View {
    let config: ModuleConfig

    var body: some View {
        HStack {
            Image(systemName: moduleIcon(for: config.id))
                .foregroundColor(.accentColor)
                .frame(width: 20)
            Text(config.name)
                .font(.subheadline)
            Spacer()
            Toggle("", isOn: Binding(
                get: { config.enabled },
                set: { _ in
                    ModuleManager.shared.toggleModule(config.id)
                }
            ))
            .toggleStyle(.switch)
            .controlSize(.small)
        }
    }

    private func moduleIcon(for moduleID: String) -> String {
        switch moduleID {
        case "network": return "network"
        case "system": return "desktopcomputer"
        case "developer": return "chevron.left.forwardslash.chevron.right"
        case "productivity": return "calendar"
        default: return "puzzlepiece.fill"
        }
    }
}
