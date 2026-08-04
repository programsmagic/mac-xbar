import SwiftUI

struct AboutSettingsView: View {
    @State private var showDiagnostics = false
    @State private var diagnostics: [DiagnosticEntry] = []
    @State private var isCollecting = false

    var body: some View {
        Form {
            Section {
                HStack(spacing: 14) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 72, height: 72)
                        .cornerRadius(12)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("mac-xbar")
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text("The modern operating system dashboard for macOS")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("Version \(versionString) (\(buildString))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 8)
            }

            Section {
                HStack {
                    Text("System")
                    Spacer()
                    Text(systemSummary)
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }

                HStack {
                    Text("Diagnostics")
                    Spacer()
                    if isCollecting {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Button("Generate Report") {
                            collectDiagnostics()
                        }
                    }
                }

                if showDiagnostics {
                    DiagnosticsReportView(entries: diagnostics)
                }
            } header: {
                Text("System Report")
            }

            Section {
                Link("GitHub Repository", destination: URL(string: "https://github.com/programsmagic/mac-xbar")!)
                Link("Report an Issue", destination: URL(string: "https://github.com/programsmagic/mac-xbar/issues")!)
                Link("Release Notes", destination: URL(string: "https://github.com/programsmagic/mac-xbar/releases")!)
            } header: {
                Text("Links")
            }

            Section {
                Text("Built with SwiftUI and AppKit. Privacy-first and local-first — no account required, no data leaves your Mac.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("© 2026 mac-xbar contributors")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Credits")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("About")
    }

    private var versionString: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "3.0.0"
    }

    private var buildString: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    private var systemSummary: String {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return "macOS \(version.majorVersion).\(version.minorVersion).\(version.patchVersion) · \(architectureString)"
    }

    private var architectureString: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machine = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: Int(64)) {
                String(cString: $0)
            }
        }
        return machine
    }

    private func collectDiagnostics() {
        isCollecting = true
        showDiagnostics = true
        Task {
            let entries = await DiagnosticsCollector.collectAll()
            await MainActor.run {
                diagnostics = entries
                isCollecting = false
            }
        }
    }
}

struct DiagnosticsReportView: View {
    let entries: [DiagnosticEntry]
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(reportText)
                .font(.system(size: 10, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(Color.primary.opacity(0.04))
                .cornerRadius(6)

            HStack {
                Spacer()
                Button {
                    copyReport()
                } label: {
                    Label(copied ? "Copied" : "Copy Report", systemImage: copied ? "checkmark" : "doc.on.doc")
                }
                .disabled(copied)
            }
        }
    }

    private var reportText: String {
        var lines: [String] = []
        lines.append("mac-xbar Diagnostics Report")
        lines.append("Generated: \(Date().formatted(date: .abbreviated, time: .standard))")
        lines.append("")
        for entry in entries {
            let icon: String
            switch entry.status {
            case .ok: icon = "OK"
            case .warning: icon = "!"
            case .error: icon = "X"
            case .unknown: icon = "?"
            }
            lines.append("[\(icon)] \(entry.name): \(entry.value)")
        }
        return lines.joined(separator: "\n")
    }

    private func copyReport() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(reportText, forType: .string)
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            copied = false
        }
    }
}
