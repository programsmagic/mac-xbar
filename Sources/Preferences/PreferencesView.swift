import SwiftUI

public struct PreferencesView: View {
    @ObservedObject private var prefs = PreferencesManager.shared

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Section("Appearance") {
                Picker("Theme", selection: $prefs.preferences.theme) {
                    ForEach(Theme.allCases, id: \.self) { theme in
                        Text(theme.rawValue.capitalized).tag(theme)
                    }
                }

                Toggle("Compact Mode", isOn: $prefs.preferences.compactMode)
            }

            Section("Modules") {
                Toggle("Show Disabled Modules", isOn: $prefs.preferences.showDisabledModules)

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

                Toggle("Launch at Login", isOn: $prefs.preferences.launchAtLogin)

                Toggle("Analytics", isOn: $prefs.preferences.analyticsEnabled)
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
            Toggle("Enabled", isOn: .constant(config.enabled))
        }
    }
}