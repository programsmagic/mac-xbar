import SwiftUI

enum SettingsSection: String, CaseIterable, Identifiable {
    case general = "General"
    case menuBar = "Menu Bar"
    case modules = "Modules"
    case network = "Network"
    case appearance = "Appearance"
    case notifications = "Notifications"
    case automation = "Automation"
    case advanced = "Advanced"
    case updates = "Updates"
    case about = "About"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return "Application"
        case .menuBar: return "Menu Bar Display"
        case .modules: return "Module toggles"
        case .network: return "Network speed"
        case .appearance: return "Theme and density"
        case .notifications: return "Alerts"
        case .automation: return "Webhooks and shortcuts"
        case .advanced: return "Diagnostics and advanced"
        case .updates: return "Update checks"
        case .about: return "About and system"
        }
    }

    var icon: String {
        switch self {
        case .general: return "gear"
        case .menuBar: return "menubar.rectangle"
        case .modules: return "puzzlepiece.fill"
        case .network: return "network"
        case .appearance: return "paintbrush"
        case .notifications: return "bell"
        case .automation: return "bolt"
        case .advanced: return "wrench.and.screwdriver"
        case .updates: return "arrow.triangle.2.circlepath"
        case .about: return "info.circle"
        }
    }
}

public struct SettingsView: View {
    @ObservedObject private var prefs = PreferencesManager.shared
    @State private var selectedSection: SettingsSection = .general
    @State private var searchText: String = ""

    public init() {}

    public var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detailContent
        }
        .searchable(text: $searchText, prompt: "Search settings...")
    }

    private var sidebar: some View {
        List(selection: $selectedSection) {
            ForEach(filteredSections, id: \.self) { section in
                Label(section.rawValue, systemImage: section.icon)
                    .tag(section)
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 160, ideal: 180, max: 220)
    }

    private var filteredSections: [SettingsSection] {
        let query = searchText.lowercased()
        if query.isEmpty { return SettingsSection.allCases }
        return SettingsSection.allCases.filter {
            $0.rawValue.lowercased().contains(query) ||
            $0.title.lowercased().contains(query)
        }
    }

    @ViewBuilder
    private var detailContent: some View {
        switch selectedSection {
        case .general:
            GeneralSettingsView()
        case .menuBar:
            MenuBarSettingsView()
        case .modules:
            ModulesSettingsView()
        case .network:
            NetworkSettingsView()
        case .appearance:
            AppearanceSettingsView()
        case .notifications:
            NotificationsSettingsView()
        case .automation:
            AutomationSettingsView()
        case .advanced:
            AdvancedSettingsView()
        case .updates:
            UpdateSettingsView()
        case .about:
            AboutSettingsView()
        }
    }
}

// MARK: - General Settings

struct GeneralSettingsView: View {
    @ObservedObject private var prefs = PreferencesManager.shared

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "3.0.0"
    }

    var body: some View {
        Form {
            Section {
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.accentColor)
                    Text("mac-xbar")
                        .font(.headline)
                    Spacer()
                    Text("v\(version)")
                        .foregroundStyle(.secondary)
                }

                Toggle("Launch at Login", isOn: $prefs.preferences.launchAtLogin)
                    .toggleStyle(.switch)

                HStack {
                    Text("Refresh Interval")
                    Spacer()
                    Picker("", selection: $prefs.preferences.updateInterval) {
                        Text("1 sec").tag(1.0)
                        Text("2 sec").tag(2.0)
                        Text("5 sec").tag(5.0)
                        Text("10 sec").tag(10.0)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 240)
                }
            } header: {
                Text("Application")
            }

            Section {
                Toggle("Send Anonymous Analytics", isOn: $prefs.preferences.analyticsEnabled)
                    .toggleStyle(.switch)

                Toggle("Show Disabled Modules", isOn: $prefs.preferences.showDisabledModules)
                    .toggleStyle(.switch)
            } header: {
                Text("Privacy")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("General")
    }
}

// MARK: - Menu Bar Settings

struct MenuBarSettingsView: View {
    @ObservedObject private var prefs = PreferencesManager.shared

    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Menu Bar Icon")
                    Spacer()
                    Picker("", selection: $prefs.preferences.menuBarIcon) {
                        ForEach(MenuBarIcon.allCases, id: \.self) { icon in
                            Label(icon.title, systemImage: icon.symbol ?? "square.dashed")
                                .tag(icon)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 200)
                }
            } header: {
                Text("Live Icon")
            } footer: {
                Text("Choose the icon shown in the menu bar alongside live speeds.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                HStack {
                    Text("Layout")
                    Spacer()
                    Picker("", selection: $prefs.preferences.menuBarLayout) {
                        ForEach(MenuBarLayout.allCases, id: \.self) { layout in
                            Text("\(layout.title) — \(layout.example)").tag(layout)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 220)
                }

                HStack {
                    Text("Traffic Color")
                    Spacer()
                    Picker("", selection: $prefs.preferences.trafficStyle) {
                        ForEach(TrafficStyle.allCases, id: \.self) { style in
                            Text(style.title).tag(style)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 200)
                }

                HStack {
                    Text("Badge Style")
                    Spacer()
                    Picker("", selection: $prefs.preferences.badgeStyle) {
                        ForEach(BadgeStyle.allCases, id: \.self) { style in
                            Text(style.title).tag(style)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 200)
                }
            } header: {
                Text("Display Mode")
            } footer: {
                Text("Layout changes how speeds appear. Adaptive switches between Minimal and Professional based on traffic.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                HStack {
                    Image(systemName: "gauge.badge.automatic")
                    Text("Adaptive Mode")
                    Spacer()
                    Text("Automatic — adjusts to traffic")
                        .foregroundStyle(.secondary)
                }

                Toggle("Fixed Width (prevents jitter)", isOn: $prefs.preferences.fixedWidth)
                    .toggleStyle(.switch)
            } header: {
                Text("Behavior")
            }

            Section {
                Toggle("Show Arrows (↑↓)", isOn: $prefs.preferences.showArrows)
                    .toggleStyle(.switch)

                Toggle("Show Units (B/s, KB/s)", isOn: $prefs.preferences.showUnits)
                    .toggleStyle(.switch)

                Toggle("Compact Mode", isOn: $prefs.preferences.compactMode)
                    .toggleStyle(.switch)
            } header: {
                Text("Content")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Menu Bar")
    }
}

// MARK: - Modules Settings

struct ModulesSettingsView: View {
    @ObservedObject private var prefs = PreferencesManager.shared

    var body: some View {
        Form {
            Section {
                ForEach(prefs.preferences.moduleConfigs, id: \.id) { config in
                    ModuleRow(config: config)
                }
            } header: {
                Text("Enabled Modules")
            } footer: {
                Text("Toggle modules on/off. Disabled modules won't use CPU or memory.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Modules")
    }
}

struct ModuleRow: View {
    let config: ModuleConfig

    var body: some View {
        HStack {
            Image(systemName: moduleIcon(for: config.id))
                .foregroundColor(.accentColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(config.name)
                    .font(.subheadline)
                Text("Refresh: \(Int(config.refreshInterval))s")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { config.enabled },
                set: { _ in
                    AppDelegate.shared?.moduleManager?.toggleModule(config.id, scheduler: AppDelegate.shared?.scheduler)
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

// MARK: - Network Settings

struct NetworkSettingsView: View {
    @ObservedObject private var prefs = PreferencesManager.shared

    var body: some View {
        Form {
            Section {
                HStack {
                    Circle()
                        .fill(prefs.networkStats.isConnected ? Color.green : Color.red)
                        .frame(width: 10, height: 10)
                    Text(prefs.networkStats.isConnected ? "Connected" : "Disconnected")
                        .font(.subheadline)
                    Spacer()
                    Text(prefs.networkStats.interface)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundColor(.green)
                    Text("Download")
                    Spacer()
                    Text(prefs.networkStats.downloadSpeed)
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.medium)
                }

                HStack {
                    Image(systemName: "arrow.up.circle.fill")
                        .foregroundColor(.orange)
                    Text("Upload")
                    Spacer()
                    Text(prefs.networkStats.uploadSpeed)
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.medium)
                }
            } header: {
                Text("Live Speed")
            }

            Section {
                HStack {
                    Image(systemName: "clock.fill")
                        .foregroundColor(.blue)
                    Text("Latency")
                    Spacer()
                    Text(prefs.networkStats.latency)
                }

                HStack {
                    Image(systemName: "globe")
                    Text("Public IP")
                    Spacer()
                    Text(prefs.networkStats.publicIP)
                        .monospacedDigit()
                }

                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath")
                    Text("Session Down")
                    Spacer()
                    Text(prefs.networkStats.sessionDownloaded)
                }

                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath")
                    Text("Session Up")
                    Spacer()
                    Text(prefs.networkStats.sessionUploaded)
                }
            } header: {
                Text("Details")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Network")
    }
}

// MARK: - Appearance Settings

struct AppearanceSettingsView: View {
    @ObservedObject private var prefs = PreferencesManager.shared

    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Theme")
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
                    Spacer()
                    Picker("", selection: $prefs.preferences.density) {
                        ForEach(Density.allCases, id: \.self) { density in
                            Text(density.rawValue.capitalized).tag(density)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 240)
                }
            } header: {
                Text("Visual Style")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Appearance")
    }
}

// MARK: - Notifications Settings

struct NotificationsSettingsView: View {
    @ObservedObject private var prefs = PreferencesManager.shared

    var body: some View {
        Form {
            Section {
                Toggle("Enable Notifications", isOn: $prefs.preferences.notificationsEnabled)
                    .toggleStyle(.switch)

                Toggle("Speed Drop Alert", isOn: $prefs.preferences.speedAlertEnabled)
                    .toggleStyle(.switch)
                    .disabled(!prefs.preferences.notificationsEnabled)

                Toggle("VPN Disconnect Alert", isOn: $prefs.preferences.vpnAlertEnabled)
                    .toggleStyle(.switch)
                    .disabled(!prefs.preferences.notificationsEnabled)

                Toggle("Daily Summary", isOn: $prefs.preferences.dailySummaryEnabled)
                    .toggleStyle(.switch)
                    .disabled(!prefs.preferences.notificationsEnabled)
            } header: {
                Text("Alerts")
            } footer: {
                Text("Notifications appear in the macOS notification center when enabled.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Notifications")
    }
}

// MARK: - Automation Settings

struct AutomationSettingsView: View {
    @ObservedObject private var prefs = PreferencesManager.shared
    @State private var showWebhookHelp = false

    var body: some View {
        Form {
            Section {
                Toggle("Shortcuts Integration", isOn: $prefs.preferences.shortcutsEnabled)
                    .toggleStyle(.switch)
                    .disabled(!prefs.preferences.automationEnabled)

                Toggle("Webhook Notifications", isOn: $prefs.preferences.automationEnabled)
                    .toggleStyle(.switch)
            } header: {
                Text("Integrations")
            }

            if prefs.preferences.automationEnabled {
                Section {
                    HStack {
                        Text("Webhook URL")
                        Spacer()
                        TextField("https://...", text: $prefs.preferences.webhookURL)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 300)
                    }

                    Button("Test Webhook") {
                        testWebhook()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                } header: {
                    Text("Webhook")
                } footer: {
                    if showWebhookHelp {
                        Text("POSTs a JSON speed event to your webhook on every significant speed drop.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Automation")
    }

    private func testWebhook() {
        let payload = [
            "app": "mac-xbar",
            "event": "test",
            "timestamp": Date().timeIntervalSince1970
        ] as [String: Any]

        guard let url = URL(string: prefs.preferences.webhookURL),
              let body = try? JSONSerialization.data(withJSONObject: payload) else {
                showWebhookHelp = true
                return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        URLSession.shared.dataTask(with: request).resume()
        showWebhookHelp = true
    }
}

// MARK: - Advanced Settings

struct AdvancedSettingsView: View {
    @State private var showResetAlert = false

    var body: some View {
        Form {
            Section {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Export Settings")
                        Text("Save your configuration to a file")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Export...") {
                        exportSettings()
                    }
                }

                HStack {
                    VStack(alignment: .leading) {
                        Text("Import Settings")
                        Text("Load configuration from a file")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Import...") {
                        importSettings()
                    }
                }
            } header: {
                Text("Data Management")
            }

            Section {
                Button("Reset All Settings", role: .destructive) {
                    showResetAlert = true
                }
                .alert("Reset All Settings?", isPresented: $showResetAlert) {
                    Button("Cancel", role: .cancel) {}
                    Button("Reset", role: .destructive) {
                        PreferencesManager.shared.reset()
                    }
                } message: {
                    Text("This will reset all settings to their defaults. This cannot be undone.")
                }
            } header: {
                Text("Danger Zone")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Advanced")
    }

    private func exportSettings() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "mac-xbar-settings.json"
        panel.begin { result in
            guard result == .OK, let url = panel.url else { return }
            let prefs = PreferencesManager.shared.preferences
            if let data = try? JSONEncoder().encode(prefs) {
                try? data.write(to: url)
            }
        }
    }

    private func importSettings() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.begin { result in
            guard result == .OK, let url = panel.url else { return }
            if let data = try? Data(contentsOf: url),
               let prefs = try? JSONDecoder().decode(AppPreferences.self, from: data) {
                PreferencesManager.shared.preferences = prefs
            }
        }
    }
}

// MARK: - About Settings
