import Foundation

public struct SpeedSample: Codable, Identifiable {
    public let id: UUID
    public let timestamp: Date
    public let download: Double
    public let upload: Double
    public let latency: Double
    public let interface: String

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        download: Double,
        upload: Double,
        latency: Double,
        interface: String = ""
    ) {
        self.id = id
        self.timestamp = timestamp
        self.download = download
        self.upload = upload
        self.latency = latency
        self.interface = interface
    }
}

public struct DailySummary: Codable {
    public let date: Date
    public var peakDownload: Double
    public var peakUpload: Double
    public var totalDownload: UInt64
    public var totalUpload: UInt64
    public var avgLatency: Double
    public var sampleCount: Int
    public var downtime: TimeInterval

    public init(date: Date = Date()) {
        self.date = date
        self.peakDownload = 0
        self.peakUpload = 0
        self.totalDownload = 0
        self.totalUpload = 0
        self.avgLatency = 0
        self.sampleCount = 0
        self.downtime = 0
    }

    public var avgDownload: Double {
        guard sampleCount > 0 else { return 0 }
        return Double(totalDownload) / Double(sampleCount)
    }

    public var avgUpload: Double {
        guard sampleCount > 0 else { return 0 }
        return Double(totalUpload) / Double(sampleCount)
    }
}

public final class HistoryModule: Module {
    public let id: ModuleID = "history"
    public var name: String = "Speed History"
    public var config: ModuleConfig = ModuleConfig(
        id: "history",
        name: "Speed History",
        enabled: true,
        refreshInterval: 60.0
    )
    public var state: ModuleState = .active

    private let storage = Storage.shared
    private var currentSamples: [SpeedSample] = []
    private var todaySummary: DailySummary?
    private let maxSamplesPerDay = 1440
    private let storageKey = "speed_history"
    private var saveTimer: Timer?
    private let saveDebounce: TimeInterval = 60

    public func initialize() async throws {
        loadTodayData()
    }

    public func refresh() async throws -> ModuleOutput {
        let items = buildMenuItems()
        return ModuleOutput(items: items, source: id)
    }

    public func invalidate() {
        saveTimer?.invalidate()
        if !currentSamples.isEmpty {
            saveTodayData()
        }
    }

    public func setEnabled(_ enabled: Bool) {
        if enabled {
            loadTodayData()
        }
    }

    public func recordSample(download: Double, upload: Double, latency: Double, interface: String = "") {
        let sample = SpeedSample(
            download: download,
            upload: upload,
            latency: latency,
            interface: interface
        )
        currentSamples.append(sample)

        if currentSamples.count > maxSamplesPerDay {
            currentSamples.removeFirst()
        }

        updateSummary(with: sample)
        scheduleSave()
    }

    public func getRecentSamples(count: Int = 60) -> [SpeedSample] {
        Array(currentSamples.suffix(count))
    }

    public func getTodaySummary() -> DailySummary {
        todaySummary ?? DailySummary()
    }

    public func getSpeedChart(width: Int = 20) -> String {
        let samples = getRecentSamples(count: width)
        guard !samples.isEmpty else { return "" }

        let maxSpeed = samples.map { max($0.download, $0.upload) }.max() ?? 1
        let chars = ["▁", "▂", "▃", "▄", "▅", "▆", "▇", "█"]

        var chart = ""
        for sample in samples {
            let normalized = maxSpeed > 0 ? sample.download / maxSpeed : 0
            let index = min(Int(normalized * Double(chars.count)), chars.count - 1)
            chart += chars[index]
        }
        return chart
    }

    // MARK: - Private

    private func scheduleSave() {
        saveTimer?.invalidate()
        saveTimer = Timer.scheduledTimer(withTimeInterval: saveDebounce, repeats: false) { [weak self] _ in
            self?.saveTodayData()
        }
    }

    private func updateSummary(with sample: SpeedSample) {
        var summary = todaySummary ?? DailySummary(date: Calendar.current.startOfDay(for: Date()))

        summary.peakDownload = max(summary.peakDownload, sample.download)
        summary.peakUpload = max(summary.peakUpload, sample.upload)
        summary.totalDownload += UInt64(sample.download)
        summary.totalUpload += UInt64(sample.upload)

        let totalCount = Double(summary.sampleCount + 1)
        summary.avgLatency = (summary.avgLatency * Double(summary.sampleCount) + sample.latency) / totalCount
        summary.sampleCount += 1

        if sample.download < 1 && sample.upload < 1 {
            summary.downtime += 1.0
        }

        todaySummary = summary
    }

    private func loadTodayData() {
        let calendar = Calendar.current
        let todayKey = "\(storageKey)_\(calendar.component(.year, from: Date()))_\(calendar.component(.month, from: Date()))_\(calendar.component(.day, from: Date()))"

        if let samples = try? storage.load([SpeedSample].self, forKey: todayKey) {
            currentSamples = samples
        }

        if let summary = try? storage.load(DailySummary.self, forKey: "\(todayKey)_summary") {
            todaySummary = summary
        }
    }

    private func saveTodayData() {
        let calendar = Calendar.current
        let todayKey = "\(storageKey)_\(calendar.component(.year, from: Date()))_\(calendar.component(.month, from: Date()))_\(calendar.component(.day, from: Date()))"

        try? storage.save(currentSamples, forKey: todayKey)
        if let summary = todaySummary {
            try? storage.save(summary, forKey: "\(todayKey)_summary")
        }
    }

    private func buildMenuItems() -> [MenuItem] {
        var items: [MenuItem] = []
        let summary = getTodaySummary()

        items.append(MenuItem(title: "", isSeparator: true, order: 67))

        items.append(MenuItem(
            title: "History",
            icon: "chart.line.uptrend.xyaxis",
            order: 68,
            metadata: ["section": "history_header"]
        ))

        let chart = getSpeedChart(width: 20)
        if !chart.isEmpty {
            items.append(MenuItem(
                title: chart,
                icon: "chart.xyaxis.line",
                order: 69,
                metadata: ["section": "history_chart"]
            ))
        }

        items.append(MenuItem(
            title: "Peak: ↓\(formatSpeed(summary.peakDownload)) ↑\(formatSpeed(summary.peakUpload))",
            icon: "arrow.up.right.and.arrow.down.left",
            order: 70,
            metadata: ["section": "history_peak"]
        ))

        items.append(MenuItem(
            title: "Samples: \(summary.sampleCount)",
            icon: "chart.bar",
            order: 71,
            metadata: ["section": "history_count"]
        ))

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
