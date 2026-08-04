import SwiftUI

struct AnalyticsDashboardView: View {
    @EnvironmentObject private var networkStore: NetworkStatsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let summary = networkStore.todaySummary {
                todaySummarySection(summary)
            }

            SectionHeader(title: "Speed (last 60 samples)", icon: "chart.line.uptrend.xyaxis")
            speedChart

            SectionHeader(title: "Insights", icon: "brain.head.profile")
            insightsList
        }
    }

    private func todaySummarySection(_ summary: DailySummary) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionHeader(title: "Today Summary", icon: "chart.bar.fill")

            HStack {
                StatCard(
                    title: "Peak Down",
                    value: DashboardFormatter.speed(summary.peakDownload),
                    subtitle: "Fastest download",
                    icon: "arrow.down.circle.fill",
                    color: .green
                )
                StatCard(
                    title: "Peak Up",
                    value: DashboardFormatter.speed(summary.peakUpload),
                    subtitle: "Fastest upload",
                    icon: "arrow.up.circle.fill",
                    color: .orange
                )
            }
            HStack {
                StatCard(
                    title: "Avg Latency",
                    value: String(format: "%.0f ms", summary.avgLatency),
                    subtitle: "\(summary.sampleCount) samples",
                    icon: "clock.fill",
                    color: .blue
                )
                StatCard(
                    title: "Down",
                    value: DashboardFormatter.bytes(summary.totalDownload),
                    subtitle: "Avg \(DashboardFormatter.speed(summary.avgDownload))",
                    icon: "arrow.down",
                    color: .indigo
                )
            }
        }
    }

    private var speedChart: some View {
        let samples = networkStore.recentSamples
        return Group {
            if samples.count >= 2 {
                VStack(alignment: .leading, spacing: 4) {
                    Sparkline(values: samples.map { $0.download })
                        .frame(height: 60)
                    HStack {
                        Text(DashboardFormatter.shortTime(samples.first?.timestamp ?? Date()))
                        Spacer()
                        Text("Max \(DashboardFormatter.speed(samples.map { $0.download }.max() ?? 0))")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(DashboardFormatter.shortTime(samples.last?.timestamp ?? Date()))
                    }
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
                }
            } else {
                Text("Not enough data yet. Keep monitoring to build a chart.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 10)
            }
        }
    }

    @ViewBuilder
    private var insightsList: some View {
        let insights = networkStore.insights
        if insights.isEmpty {
            Text("No insights recorded yet.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .padding(.vertical, 4)
        } else {
            ForEach(insights.reversed(), id: \.id) { insight in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: insight.icon)
                        .font(.system(size: 11))
                        .foregroundColor(severityColor(insight.severity))
                        .frame(width: 16)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(insight.title)
                            .font(.system(size: 12, weight: .medium))
                        Text(insight.detail)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        Text(DashboardFormatter.shortTime(insight.timestamp))
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                            .monospacedDigit()
                    }
                    Spacer()
                }
                .padding(.vertical, 3)
            }
        }
    }

    private func severityColor(_ severity: InsightSeverity) -> Color {
        switch severity {
        case .info: return .blue
        case .warning: return .orange
        case .critical: return .red
        }
    }
}
