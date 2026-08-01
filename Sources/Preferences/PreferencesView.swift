import SwiftUI

public struct PreferencesView: View {
    @ObservedObject private var prefs = PreferencesManager.shared

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Section("Appearance") {
                Picker("Theme", selection: Binding(
                    get: { prefs.preferences.theme },
                    set: { prefs.update { $0.theme = $0 } }
                )) {
                    ForEach(Theme.allCases, id: \.self) { theme in
                        Text(theme.rawValue.capitalized).tag(theme)
                    }
                }

                Toggle("Compact Mode", isOn: Binding(
                    get: { prefs.preferences.compactMode },
                    set: { prefs.update { $0.compactMode = $0 } }
                ))
            }

            Section("Modules") {
                Toggle("Show Disabled Modules", isOn: Binding(
                    get: { prefs.preferences.showDisabledModules },
                    set: { prefs.update { $0.showDisabledModules = $0 } }
                ))

                ForEach(prefs.preferences.moduleConfigs) { config in
                    ModuleConfigRow(config: config)
                }
            }

            Section("General") {
                HStack {
                    Text("Update Interval (seconds)")
                    Spacer()
                    TextField("60", text: Binding(
                        get: { String(Int(prefs.preferences.updateInterval)) },
                        set: { prefs.update { $0.updateInterval = Double($0) ?? 60 } }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                }

                Toggle("Launch at Login", isOn: Binding(
                    get: { prefs.preferences.launchAtLogin },
                    set: { prefs.update { $0.launchAtLogin = $0 } }
                ))

                Toggle("Analytics", isOn: Binding(
                    get: { prefs.preferences.analyticsEnabled },
                    set: { prefs.update { $0.analyticsEnabled = $0 } }
                ))
            }
        }
        .frame(width: 400)
        .padding()
    }
}

private struct ModuleConfigRow: View {
    let config: ModuleConfig

    var body: some View {
        HStack {
            Text(config.name)
            Spacer()
            Toggle("Enabled", isOn: Binding(
                get: { config.enabled },
                set: { _ in }
            ))
        }
    }
}