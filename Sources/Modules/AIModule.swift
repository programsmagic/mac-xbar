import Foundation

public struct Insight: Identifiable, Codable {
    public let id: UUID
    public let timestamp: Date
    public let type: InsightType
    public let title: String
    public let detail: String
    public let severity: InsightSeverity
    public let icon: String

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        type: InsightType,
        title: String,
        detail: String,
        severity: InsightSeverity,
        icon: String
    ) {
        self.id = id
        self.timestamp = timestamp
        self.type = type
        self.title = title
        self.detail = detail
        self.severity = severity
        self.icon = icon
    }
}

public enum InsightType: String, Codable, CaseIterable {
    case speedDrop
    case vpnDisconnect
    case highUpload
    case weakSignal
    case dnsSlow
    case batteryDrain
    case networkAnomaly
    case dailySummary
}

public enum InsightSeverity: String, Codable {
    case info
    case warning
    case critical
}

public final class AIModule: Module {
    public let id: ModuleID = "ai"
    public var name: String = "AI Insights"
    public var config: ModuleConfig = ModuleConfig(
        id: "ai",
        name: "AI Insights",
        enabled: true,
        refreshInterval: 300.0
    )
    public var state: ModuleState = .active

    private let storage = Storage.shared
    private var insights: [Insight] = []
    private var previousDownload: Double = 0
    private var previousUpload: Double = 0
    private var averageDownload: Double = 0
    private var sampleCount: Int = 0
    private let storageKey = "ai_insights"
    private var saveTimer: Timer?
    private let saveDebounce: TimeInterval = 60

    public func initialize() async throws {
        loadInsights()
    }

    public func refresh() async throws -> ModuleOutput {
        let items = buildMenuItems()
        return ModuleOutput(items: items, source: id)
    }

    public func invalidate() {
        saveTimer?.invalidate()
        saveInsights()
    }

    public func setEnabled(_ enabled: Bool) {
        if enabled {
            loadInsights()
        }
    }

    public func analyzeSpeed(download: Double, upload: Double, latency: Double, rssi: Int?) {
        sampleCount += 1
        averageDownload = ((averageDownload * Double(sampleCount - 1)) + download) / Double(sampleCount)

        previousDownload = download
        previousUpload = upload

        guard PreferencesManager.shared.preferences.notificationsEnabled else {
            saveInsights()
            return
        }

        if sampleCount > 10 {
            if download < averageDownload * 0.5 && averageDownload > 1024 * 1024 {
                addInsight(
                    type: .speedDrop,
                    title: "Speed Drop Detected",
                    detail: "Download speed dropped to \(formatSpeed(download)) (avg: \(formatSpeed(averageDownload)))",
                    severity: .warning,
                    icon: "arrow.down.circle.fill"
                )
            }

            if upload > download * 10 && upload > 1024 * 1024 {
                addInsight(
                    type: .highUpload,
                    title: "High Upload Detected",
                    detail: "Upload (\(formatSpeed(upload))) is significantly higher than download. Possible cloud sync.",
                    severity: .info,
                    icon: "arrow.up.circle.fill"
                )
            }
        }

        if let rssi = rssi, rssi < -75 {
            addInsight(
                type: .weakSignal,
                title: "Weak Wi-Fi Signal",
                detail: "RSSI is \(rssi) dBm. Consider moving closer to your router.",
                severity: .warning,
                icon: "wifi.exclamationmark"
            )
        }

        if latency > 200 {
            addInsight(
                type: .dnsSlow,
                title: "High Latency Detected",
                detail: "Latency is \(String(format: "%.0f", latency)) ms. Network may be congested.",
                severity: .warning,
                icon: "clock.fill"
            )
        }

        previousDownload = download
        previousUpload = upload
        scheduleSave()
    }

    public func generateDailySummary(totalDownload: UInt64, totalUpload: UInt64, peakDownload: Double, peakUpload: Double) {
        let summary = Insight(
            type: .dailySummary,
            title: "Daily Summary",
            detail: "Total: ↓\(formatBytes(totalDownload)) ↑\(formatBytes(totalUpload))\nPeak: ↓\(formatSpeed(peakDownload)) ↑\(formatSpeed(peakUpload))",
            severity: .info,
            icon: "chart.bar.fill"
        )
        insights.append(summary)
        saveInsights()
    }

    public func getRecentInsights(count: Int = 10) -> [Insight] {
        Array(insights.suffix(count))
    }

    public func clearOldInsights(olderThan days: Int = 7) {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        insights = insights.filter { $0.timestamp > cutoff }
        saveInsights()
    }

    // MARK: - Private

    private func scheduleSave() {
        saveTimer?.invalidate()
        saveTimer = Timer.scheduledTimer(withTimeInterval: saveDebounce, repeats: false) { [weak self] _ in
            self?.saveInsights()
        }
    }

    private func addInsight(type: InsightType, title: String, detail: String, severity: InsightSeverity, icon: String) {
        let recentSimilar = insights.filter {
            $0.type == type && Date().timeIntervalSince($0.timestamp) < 300
        }
        guard recentSimilar.isEmpty else { return }

        let insight = Insight(
            type: type,
            title: title,
            detail: detail,
            severity: severity,
            icon: icon
        )
        insights.append(insight)

        if insights.count > 100 {
            insights.removeFirst()
        }
    }

    private func loadInsights() {
        if let loaded = try? storage.load([Insight].self, forKey: storageKey) {
            insights = loaded
        }
    }

    private func saveInsights() {
        try? storage.save(insights, forKey: storageKey)
    }

    private func buildMenuItems() -> [MenuItem] {
        var items: [MenuItem] = []
        let recent = getRecentInsights(count: 5)

        items.append(MenuItem(title: "", isSeparator: true, order: 72))

        items.append(MenuItem(
            title: "AI Insights",
            icon: "brain.head.profile",
            order: 73,
            metadata: ["section": "ai_header"]
        ))

        if recent.isEmpty {
            items.append(MenuItem(
                title: "No insights yet",
                icon: "checkmark.circle",
                color: "#34C759",
                order: 74,
                metadata: ["section": "ai_empty"]
            ))
        } else {
            for (index, insight) in recent.enumerated() {
                let color: String = {
                    switch insight.severity {
                    case .info: return "#007AFF"
                    case .warning: return "#FF9500"
                    case .critical: return "#FF3B30"
                    }
                }()

                items.append(MenuItem(
                    title: insight.title,
                    icon: insight.icon,
                    color: color,
                    order: 74 + index,
                    metadata: ["section": "ai_insight"]
                ))
            }
        }

        return items
    }

    private func formatSpeed(_ bytesPerSecond: Double) -> String {
        if bytesPerSecond < 1024 {
            return String(format: "%.0f B/s", bytesPerSecond)
        } else if bytesPerSecond < 1024 * 1024 {
            return String(format: "%.1f KB/s", bytesPerSecond / 1024)
        } else if bytesPerSecond < 1024 * 1024 * 1024 {
            return String(format: "%.1f MB/s", bytesPerSecond / (1024 * 1024))
        } else {
            return String(format: "%.2f GB/s", bytesPerSecond / (1024 * 1024 * 1024))
        }
    }

    private func formatBytes(_ bytes: UInt64) -> String {
        if bytes < 1024 {
            return "\(bytes) B"
        } else if bytes < 1024 * 1024 {
            return String(format: "%.1f KB", Double(bytes) / 1024)
        } else if bytes < 1024 * 1024 * 1024 {
            return String(format: "%.1f MB", Double(bytes) / (1024 * 1024))
        } else {
            return String(format: "%.2f GB", Double(bytes) / (1024 * 1024 * 1024))
        }
    }
}
