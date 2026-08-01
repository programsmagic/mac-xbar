import Foundation
import os.log

public final class Diagnostics {
    public static let shared = Diagnostics()

    private let log = OSLog(subsystem: "com.macxbar.app", category: "diagnostics")
    private var metrics: [String: MetricSnapshot] = [:]

    public struct MetricSnapshot: Codable {
        public let name: String
        public let value: Double
        public let unit: String
        public let timestamp: Date

        public init(name: String, value: Double, unit: String, timestamp: Date = Date()) {
            self.name = name
            self.value = value
            self.unit = unit
            self.timestamp = timestamp
        }
    }

    public func record(name: String, value: Double, unit: String) {
        let snapshot = MetricSnapshot(name: name, value: value, unit: unit)
        metrics[name] = snapshot
        os_log("Metric: %{public}@ = %{public}f %{public}@", log: log, type: .info, name, value, unit)
    }

    public func snapshot(name: String) -> MetricSnapshot? {
        metrics[name]
    }

    public func allSnapshots() -> [MetricSnapshot] {
        Array(metrics.values).sorted { $0.timestamp > $1.timestamp }
    }

    public func report() -> String {
        let snapshots = allSnapshots()
        return snapshots.map { "\($0.name): \($0.value) \($0.unit)" }.joined(separator: "\n")
    }
}