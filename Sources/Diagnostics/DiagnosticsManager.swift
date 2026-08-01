import Foundation
import os.log

public final class DiagnosticsManager {
    public static let shared = DiagnosticsManager()

    public private(set) var diagnostics: [DiagnosticEntry] = []
    private let log = OSLog(subsystem: "com.macxbar.app", category: "diagnostics")

    private init() {}

    public func collect() async {
        os_log("Collecting diagnostics", log: log, type: .info)
        diagnostics = await DiagnosticsCollector.collectAll()
        os_log("Collected %{public}d diagnostic entries", log: log, type: .info, diagnostics.count)
    }

    public func exportJSON() -> String {
        let entries = diagnostics.map { entry in
            "{\n      \"name\": \"\(entry.name)\",\n      \"value\": \"\(entry.value)\",\n      \"status\": \"\(entry.status.rawValue)\"\n    }"
        }.joined(separator: ",\n")
        return "[\n  \(entries)\n]"
    }

    public func clear() {
        diagnostics = []
    }
}

public struct DiagnosticEntry: Identifiable, Equatable {
    public let id = UUID()
    public let name: String
    public let value: String
    public let status: DiagnosticStatus
}

public enum DiagnosticStatus: String, Codable, Equatable {
    case ok
    case warning
    case error
    case unknown
}