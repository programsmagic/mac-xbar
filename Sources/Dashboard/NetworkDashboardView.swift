import SwiftUI

struct NetworkDashboardView: View {
    @EnvironmentObject private var systemStore: SystemStatsStore
    @EnvironmentObject private var networkStore: NetworkStatsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let intel = networkStore.intelligence {
                liveSpeedSection(intel)
                healthSection(intel)
                usageSection(intel)
                connectionSection
                timelineSection(intel)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)
            }
        }
    }

    // MARK: - Live Speed

    private func liveSpeedSection(_ intel: NetworkModule.NetworkIntelligence) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionHeader(title: "Live Speed", icon: "speedometer")

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    SpeedView(download: intel.download, upload: intel.upload, valueSize: 17)
                    Text("Download · Upload")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
                Spacer()
            }

            SpeedBarsView(download: intel.download, upload: intel.upload)

            Sparkline(values: networkStore.recentSamples.map { $0.download })
                .frame(height: 36)
        }
    }

    // MARK: - Health

    private func healthSection(_ intel: NetworkModule.NetworkIntelligence) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionHeader(title: "Internet Health", icon: "heart.fill")

            HStack {
                MetricRow(
                    icon: "heart.fill",
                    label: "Health",
                    value: "\(intel.healthScore)/100",
                    color: healthColor(intel.healthScore)
                )
                MetricRow(
                    icon: "clock.fill",
                    label: "Ping",
                    value: intel.latency >= 0 ? String(format: "%.0f ms", intel.latency) : "—"
                )
                MetricRow(
                    icon: "waveform.path.ecg",
                    label: "Jitter",
                    value: String(format: "%.1f ms", intel.jitter)
                )
            }
            HStack {
                MetricRow(
                    icon: "exclamationmark.triangle.fill",
                    label: "Packet Loss",
                    value: String(format: "%.1f%%", intel.packetLoss),
                    color: intel.packetLoss > 2 ? .red : .green
                )
                MetricRow(
                    icon: "arrow.up.right.circle",
                    label: "Public IP",
                    value: intel.publicIP ?? "—"
                )
            }
        }
    }

    // MARK: - Usage

    private func usageSection(_ intel: NetworkModule.NetworkIntelligence) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionHeader(title: "Usage", icon: "arrow.triangle.2.circlepath")

            HStack {
                StatCard(
                    title: "Today",
                    value: "↓ \(DashboardFormatter.bytes(intel.todayDownload))",
                    subtitle: "↑ \(DashboardFormatter.bytes(intel.todayUpload))",
                    icon: "calendar",
                    color: .blue
                )
                StatCard(
                    title: "Session",
                    value: "↓ \(DashboardFormatter.bytes(intel.sessionDownload))",
                    subtitle: "↑ \(DashboardFormatter.bytes(intel.sessionUpload))",
                    icon: "timer",
                    color: .indigo
                )
            }
            HStack {
                StatCard(
                    title: "Peak DL",
                    value: DashboardFormatter.speed(intel.peakDownload),
                    subtitle: "Highest download speed",
                    icon: "arrow.down.circle",
                    color: .green
                )
                StatCard(
                    title: "Peak UL",
                    value: DashboardFormatter.speed(intel.peakUpload),
                    subtitle: "Highest upload speed",
                    icon: "arrow.up.circle",
                    color: .orange
                )
            }
        }
    }

    // MARK: - Connection

    private var connectionSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionHeader(title: "Connection", icon: "network")

            if let net = systemStore.metrics?.network {
                MetricRow(icon: "wifi", label: "Interface", value: net.interfaceType)
                MetricRow(icon: "dot.radiowaves.left.and.right", label: "SSID", value: net.ssid ?? "—")
                if let rssi = net.rssi {
                    MetricRow(
                        icon: rssi > -65 ? "signal" : "wifi.exclamationmark",
                        label: "Signal",
                        value: "\(rssi) dBm",
                        color: rssi > -65 ? .green : .orange
                    )
                }
                MetricRow(icon: "network", label: "Local IP", value: net.localIP ?? "—")
                MetricRow(icon: "globe", label: "Public IP", value: networkStore.publicIP ?? networkStore.intelligence?.publicIP ?? "—")
            }
        }
    }

    // MARK: - Timeline

    private func timelineSection(_ intel: NetworkModule.NetworkIntelligence) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionHeader(title: "Timeline", icon: "clock.arrow.circlepath")

            let events = intel.timeline.suffix(5).reversed()
            if intel.timeline.isEmpty {
                Text("No connection events recorded.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(events), id: \.timestamp) { event in
                    HStack(spacing: 8) {
                        Image(systemName: timelineIcon(event.type))
                            .font(.system(size: 10))
                            .foregroundColor(timelineColor(event.type))
                            .frame(width: 14)
                        Text(event.detail)
                            .font(.system(size: 11))
                        Spacer()
                        Text(DashboardFormatter.shortTime(event.timestamp))
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                            .monospacedDigit()
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private func timelineIcon(_ type: NetworkModule.ConnectionEvent.EventType) -> String {
        switch type {
        case .connected: return "wifi"
        case .disconnected: return "wifi.slash"
        case .interfaceChanged: return "arrow.triangle.swap"
        case .vpnConnected: return "lock.fill"
        case .vpnDisconnected: return "lock.open"
        case .speedAlert: return "exclamationmark.triangle.fill"
        }
    }

    private func timelineColor(_ type: NetworkModule.ConnectionEvent.EventType) -> Color {
        switch type {
        case .connected: return .green
        case .disconnected: return .red
        case .vpnConnected: return .blue
        case .vpnDisconnected: return .orange
        default: return .secondary
        }
    }

    private func healthColor(_ score: Int) -> Color {
        if score >= 80 { return .green }
        if score >= 50 { return .orange }
        return .red
    }
}
