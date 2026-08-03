import Foundation
import os.log
import SystemConfiguration
#if canImport(Darwin)
import Darwin
#endif

public final class DiagnosticsCollector {
    static let log = OSLog(subsystem: "com.macxbar.app", category: "diagnostics")

    static func collectAll() async -> [DiagnosticEntry] {
        var entries: [DiagnosticEntry] = []
        entries.append(contentsOf: collectSystemInfo())
        entries.append(contentsOf: collectMemoryInfo())
        entries.append(contentsOf: collectDiskInfo())
        entries.append(contentsOf: collectNetworkInfo())
        entries.append(contentsOf: collectAppInfo())
        return entries
    }

    private static func collectSystemInfo() -> [DiagnosticEntry] {
        var entries: [DiagnosticEntry] = []
        entries.append(DiagnosticEntry(
            name: "macOS Version",
            value: ProcessInfo.processInfo.operatingSystemVersionString,
            status: .ok
        ))
        entries.append(DiagnosticEntry(
            name: "Architecture",
            value: architectureString(),
            status: .ok
        ))
        entries.append(DiagnosticEntry(
            name: "CPU Count",
            value: "\(ProcessInfo.processInfo.processorCount)",
            status: .ok
        ))
        entries.append(DiagnosticEntry(
            name: "Memory (Physical)",
            value: formatBytes(Int64(ProcessInfo.processInfo.physicalMemory)),
            status: .ok
        ))
        return entries
    }

    private static func architectureString() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machine = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: Int(64)) {
                String(cString: $0)
            }
        }
        return machine
    }

    private static func collectMemoryInfo() -> [DiagnosticEntry] {
        var entries: [DiagnosticEntry] = []
        var taskInfo = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &taskInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        if result == KERN_SUCCESS {
            entries.append(DiagnosticEntry(
                name: "Memory (App)",
                value: formatBytes(Int64(taskInfo.resident_size)),
                status: .ok
            ))
        }
        return entries
    }

    private static func collectDiskInfo() -> [DiagnosticEntry] {
        var entries: [DiagnosticEntry] = []
        let attrs = try? FileManager.default.attributesOfFileSystem(forPath: "/")
        if let total = attrs?[.systemSize] as? Int64,
           let free = attrs?[.systemFreeSize] as? Int64 {
            entries.append(DiagnosticEntry(
                name: "Disk (Total)",
                value: formatBytes(total),
                status: .ok
            ))
            entries.append(DiagnosticEntry(
                name: "Disk (Free)",
                value: formatBytes(free),
                status: free < total / 10 ? .warning : .ok
            ))
        }
        return entries
    }

    private static func collectNetworkInfo() -> [DiagnosticEntry] {
        var entries: [DiagnosticEntry] = []
        let isConnected = isNetworkAvailable()
        entries.append(DiagnosticEntry(
            name: "Network",
            value: isConnected ? "Connected" : "Disconnected",
            status: isConnected ? .ok : .error
        ))
        return entries
    }

    private static func isNetworkAvailable() -> Bool {
        var zeroAddress = sockaddr_in()
        zeroAddress.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        zeroAddress.sin_family = sa_family_t(AF_INET)
        let defaultRouteReachability = withUnsafePointer(to: &zeroAddress) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                SCNetworkReachabilityCreateWithAddress(nil, $0)
            }
        }
        var flags = SCNetworkReachabilityFlags()
        guard let reachability = defaultRouteReachability,
              SCNetworkReachabilityGetFlags(reachability, &flags) else {
            return false
        }
        return flags.contains(.reachable) && !flags.contains(.connectionRequired)
    }

    private static func collectAppInfo() -> [DiagnosticEntry] {
        var entries: [DiagnosticEntry] = []
        entries.append(DiagnosticEntry(
            name: "App Version",
            value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
            status: .ok
        ))
        entries.append(DiagnosticEntry(
            name: "Build Number",
            value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown",
            status: .ok
        ))
        return entries
    }

    private static func formatBytes(_ bytes: Int64) -> String {
        if bytes < 1024 { return "\(bytes) B" }
        if bytes < 1024 * 1024 { return String(format: "%.1f KB", Double(bytes) / 1024) }
        if bytes < 1024 * 1024 * 1024 { return String(format: "%.1f MB", Double(bytes) / (1024 * 1024)) }
        return String(format: "%.1f GB", Double(bytes) / (1024 * 1024 * 1024))
    }
}