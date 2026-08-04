import SwiftUI

struct UpdateSettingsView: View {
    @State private var autoCheckEnabled: Bool
    @State private var channel: UpdateChannel
    @State private var isChecking = false
    @State private var update: AppUpdate?
    @State private var lastCheckedText: String
    @State private var isDownloading = false
    @State private var showReleaseNotes = false

    init() {
        let checker = UpdateChecker.shared
        _autoCheckEnabled = State(initialValue: checker.autoChecksEnabled)
        _channel = State(initialValue: checker.channel)
        _lastCheckedText = State(initialValue: Self.lastCheckedText(from: checker.lastCheckDate()))
    }

    var body: some View {
        Form {
            Section {
                Toggle("Automatically check for updates", isOn: $autoCheckEnabled)
                    .onChange(of: autoCheckEnabled) { _, newValue in
                        UpdateChecker.shared.autoChecksEnabled = newValue
                        if !newValue {
                            update = nil
                        }
                    }

                Picker("Update Channel", selection: $channel) {
                    ForEach(UpdateChannel.allCases, id: \.self) { ch in
                        Text(ch.displayName).tag(ch)
                    }
                }
                .onChange(of: channel) { _, newValue in
                    UpdateChecker.shared.channel = newValue
                    update = nil
                }

                if channel == .beta {
                    Text("Beta builds may be less stable. You'll see prereleases and stable releases.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Preferences")
            }

            Section {
                HStack {
                    Text("Last Checked")
                    Spacer()
                    Text(lastCheckedText)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Current Version")
                    Spacer()
                    Text(currentVersionString)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    if isChecking {
                        Text("Checking for updates...")
                        Spacer()
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text(update == nil ? "No updates available" : "Update available")
                        Spacer()
                        Button("Check Now") {
                            checkForUpdates()
                        }
                    }
                }
            } header: {
                Text("Status")
            }

            if let update {
                Section {
                    HStack {
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundColor(.green)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Version \(update.version)\(update.isPrerelease ? " (Beta)" : "")")
                                .font(.headline)
                            Text("Published \(update.publishedAt.formatted(date: .abbreviated, time: .omitted))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if let size = update.downloadSize {
                                Text("\(ByteCountFormatter.string(fromByteCount: size, countStyle: .file)) download")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                    }

                    DisclosureGroup(isExpanded: $showReleaseNotes) {
                        ScrollView {
                            Text(update.releaseNotes)
                                .font(.system(size: 11))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxHeight: 160)
                    } label: {
                        Text("Release Notes")
                            .font(.subheadline)
                    }

                    HStack {
                        Spacer()
                        Button("Download") {
                            download(update)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } header: {
                    Text("Available Update")
                }
            }

            Section {
                Text("Updates are downloaded from the GitHub releases page and opened in your browser.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Link("View Releases on GitHub", destination: URL(string: "https://github.com/programsmagic/mac-xbar/releases")!)
            } header: {
                Text("About")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Updates")
    }

    private var currentVersionString: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "3.0.0"
    }

    private static func lastCheckedText(from date: Date?) -> String {
        guard let date else { return "Never" }
        return date.formatted(date: .abbreviated, time: .shortened)
    }

    private func checkForUpdates() {
        isChecking = true
        Task {
            let result = await UpdateChecker.shared.checkForUpdate()
            await MainActor.run {
                isChecking = false
                update = result
                lastCheckedText = Self.lastCheckedText(from: UpdateChecker.shared.lastCheckDate())
            }
        }
    }

    private func download(_ update: AppUpdate) {
        isDownloading = true
        UpdateChecker.shared.openDownloadPage(update)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isDownloading = false
        }
    }
}
