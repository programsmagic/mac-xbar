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

                Picker("Density", selection: $prefs.preferences.density) {
                    ForEach(Density.allCases, id: \.self) { density in
                        Text(density.rawValue.capitalized).tag(density)
                    }
                }

                Toggle("Compact Mode", isOn: $prefs.preferences.compactMode)
            }

            Section("Menu Bar") {
                Toggle("Show Arrows", isOn: $prefs.preferences.showArrows)
                Toggle("Show Units", isOn: $prefs.preferences.showUnits)
                Toggle("Fixed Width", isOn: $prefs.preferences.fixedWidth)
            }

            Section("Modules") {
                Toggle("Show Disabled Modules", isOn: $prefs.preferences.showDisabledModules)

                ForEach(prefs.preferences.moduleConfigs, id: \.id) { config in
                    ModuleConfigRow(config: config)
                }
            }

            Section("General") {
                HStack {
                    Text("Update Interval (seconds)")
                    Spacer()
                    TextField("60", text: Binding(
                        get: { String(Int(prefs.preferences.updateInterval)) },
                        set: { newValue in
                        prefs.update { $0.updateInterval = Double(newValue) ?? 60 }
                    }
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