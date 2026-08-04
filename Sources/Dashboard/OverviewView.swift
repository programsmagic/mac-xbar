import SwiftUI

struct OverviewView: View {
    @EnvironmentObject private var systemStore: SystemStatsStore
    @EnvironmentObject private var networkStore: NetworkStatsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            networkHero
            Divider()
                .padding(.vertical, 6)

            if let metrics = systemStore.metrics {
                systemSnapshot(metrics)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            }

            SectionHeader(title: "AI Insights", icon: "brain.head.profile")
            insightsList
        }
    }

    private var networkHero: some View {
        let intel = networkStore.intelligence
        let down = intel?.download ?? 0
        let up = intel?.upload ?? 0
        let ping = intel?.latency ?? 0
        let pingText = ping >= 0 ? "\(Int(ping)) ms" : "—"

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                GaugeCircle(
                    value: Double(intel?.healthScore ?? 0) / 100.0,
                    color: healthColor(intel?.healthScore ?? 0)
                )

                VStack(alignment: .leading, spacing: 6) {
                    SpeedView(download: down, upload: up, valueSize: 17)

                    HStack(spacing: 5) {
                        Image(systemName: intel?.isConnected == true ? "wifi" : "wifi.slash")
                            .font(.system(size: 10, weight: .semibold))
                        Text(intel?.interfaceType ?? "—")
                            .font(.system(size: 10, weight: .medium))
                        Circle()
                            .fill(intel?.isConnected == true ? Color.green : Color.gray)
                            .frame(width: 3, height: 3)
                        Text("Ping \(pingText)")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.primary.opacity(0.06), in: Capsule())
                }

                Spacer()
            }

            SpeedBarsView(download: down, upload: up)

            HStack(spacing: 6) {
                Image(systemName: "globe")
                    .font(.system(size: 11))
                    .foregroundColor(.blue)
                Text("Public IP")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                if let ip = networkStore.publicIP {
                    Text(ip)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .monospacedDigit()
                    Button {
                        copyToClipboard(ip)
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
                    .help("Copy Public IP")
                } else {
                    Text("Detecting…")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                    ProgressView()
                        .controlSize(.mini)
                }
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(8)
        }
        .padding(12)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 14))
        .help(heroTooltip(down: down, up: up, ping: ping, pingText: pingText, intel: intel))
    }

    private func heroTooltip(down: Double, up: Double, ping: Double, pingText: String, intel: NetworkModule.NetworkIntelligence?) -> String {
        """
        Download: \(DashboardFormatter.speed(down))
        Upload: \(DashboardFormatter.speed(up))
        Ping: \(pingText)
        Health: \(intel?.healthScore ?? 0)/100
        Interface: \(intel?.interfaceType ?? "—")\(intel?.isConnected == true ? " · Connected" : "")
        Public IP: \(networkStore.publicIP ?? "Detecting…")
        """
    }

    private func healthColor(_ score: Int) -> Color {
        if score >= 80 { return .green }
        if score >= 50 { return .orange }
        return .red
    }

    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    @ViewBuilder
    private func systemSnapshot(_ metrics: SystemMetrics) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            StatCard(
                title: "CPU",
                value: DashboardFormatter.percent(metrics.cpu.overallUsage),
                subtitle: "\(metrics.cpu.activeCores) active cores",
                icon: "cpu",
                color: .blue
            )
            StatCard(
                title: "Memory",
                value: DashboardFormatter.percent(metrics.memory.usedPercent),
                subtitle: "\(DashboardFormatter.bytes(metrics.memory.used)) of \(DashboardFormatter.bytes(metrics.memory.total))",
                icon: "memorychip",
                color: .purple
            )
            StatCard(
                title: "Disk",
                value: DashboardFormatter.percent(metrics.diskVolumes.first?.usedPercent ?? 0),
                subtitle: metrics.diskVolumes.first.map { "\(DashboardFormatter.bytes($0.total - $0.used)) free" } ?? "—",
                icon: "internaldrive",
                color: .teal
            )
            StatCard(
                title: "Uptime",
                value: DashboardFormatter.timeInterval(metrics.system.uptime),
                subtitle: metrics.system.chipName,
                icon: "clock.arrow.circlepath",
                color: .indigo
            )
        }
    }

    @ViewBuilder
    private var insightsList: some View {
        let insights = networkStore.insights
        if insights.isEmpty {
            Text("No insights yet. Keep monitoring to receive smart alerts.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .padding(.vertical, 4)
        } else {
            ForEach(insights.suffix(3).reversed(), id: \.id) { insight in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: insight.icon)
                        .font(.system(size: 11))
                        .foregroundColor(insightColor(insight.severity))
                        .frame(width: 16)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(insight.title)
                            .font(.system(size: 12, weight: .medium))
                        Text(insight.detail)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    Spacer()
                }
                .padding(.vertical, 3)
            }
        }
    }

    private func insightColor(_ severity: InsightSeverity) -> Color {
        switch severity {
        case .info: return .blue
        case .warning: return .orange
        case .critical: return .red
        }
    }
}
