import Foundation
import os.log
import Network
import IOKit
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
        entries.append(contentsOf: collectBatteryInfo())
        entries.append(contentsOf: collectGPUInfo())
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
        entries.append(DiagnosticEntry(
            name: "Thermal State",
            value: thermalStateString(),
            status: thermalStateStatus()
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

    private static func thermalStateString() -> String {
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: return "Normal"
        case .fair: return "Fair"
        case .serious: return "Serious"
        case .critical: return "Critical"
        @unknown default: return "Unknown"
        }
    }

    private static func thermalStateStatus() -> DiagnosticStatus {
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: return .ok
        case .fair: return .ok
        case .serious: return .warning
        case .critical: return .error
        @unknown default: return .ok
        }
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
                status: taskInfo.resident_size > 50 * 1024 * 1024 ? .warning : .ok
            ))
        }

        let memory = SystemInfoCollector.shared.collectMemory()
        entries.append(DiagnosticEntry(
            name: "Memory Used",
            value: "\(formatBytes(memory.used)) / \(formatBytes(memory.total)) (\(Int(memory.usedPercent))%)",
            status: memory.usedPercent > 90 ? .error : (memory.usedPercent > 75 ? .warning : .ok)
        ))
        entries.append(DiagnosticEntry(
            name: "Memory Pressure",
            value: memory.pressure,
            status: memory.pressure == "Critical" ? .error : (memory.pressure == "High" ? .warning : .ok)
        ))
        if memory.swapTotal > 0 {
            entries.append(DiagnosticEntry(
                name: "Swap Used",
                value: "\(formatBytes(memory.swapUsed)) / \(formatBytes(memory.swapTotal))",
                status: memory.swapUsed > memory.swapTotal / 2 ? .warning : .ok
            ))
        }
        return entries
    }

    private static func collectDiskInfo() -> [DiagnosticEntry] {
        var entries: [DiagnosticEntry] = []
        for volume in SystemInfoCollector.shared.collectDisk() {
            entries.append(DiagnosticEntry(
                name: volume.isRoot ? "Disk (\(volume.name))" : "Volume (\(volume.name))",
                value: "\(formatBytes(volume.used)) used / \(formatBytes(volume.total)) total (\(Int(volume.usedPercent))%)",
                status: volume.usedPercent > 90 ? .warning : .ok
            ))
        }
        return entries
    }

    private static func collectBatteryInfo() -> [DiagnosticEntry] {
        var entries: [DiagnosticEntry] = []

        let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [Any] ?? []

        for source in sources {
            if let desc = IOPSGetPowerSourceDescription(snapshot, source as CFTypeRef)?.takeUnretainedValue() as? [String: Any] {
                if let currentCapacity = desc[kIOPSCurrentCapacityKey] as? Int,
                   let maxCapacity = desc[kIOPSMaxCapacityKey] as? Int,
                   let isCharging = desc[kIOPSIsChargingKey] as? Bool,
                   let name = desc[kIOPSTypeKey] as? String {

                    let percentage = maxCapacity > 0 ? (Double(currentCapacity) / Double(maxCapacity)) * 100 : 0
                    entries.append(DiagnosticEntry(
                        name: "Battery (\(name))",
                        value: "\(Int(percentage))% \(isCharging ? "(Charging)" : "")",
                        status: percentage < 20 ? .warning : .ok
                    ))
                }
            }
        }

        if let cycleCount = getBatteryCycleCount() {
            entries.append(DiagnosticEntry(
                name: "Battery Cycles",
                value: "\(cycleCount)",
                status: cycleCount > 800 ? .warning : .ok
            ))
        }

        if let condition = getBatteryCondition() {
            entries.append(DiagnosticEntry(
                name: "Battery Condition",
                value: condition,
                status: condition == "Normal" ? .ok : .warning
            ))
        }

        return entries
    }

    private static func getBatteryCycleCount() -> Int? {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOPMPowerSource"), &iterator) == KERN_SUCCESS else {
            return nil
        }
        defer { IOObjectRelease(iterator) }

        var service = IOIteratorNext(iterator)
        while service != 0 {
            defer { IOObjectRelease(service) }

            if let cycleCount = IORegistryEntryCreateCFProperty(service, "CycleCount" as CFString, nil, 0)?.takeRetainedValue() as? Int {
                return cycleCount
            }
            service = IOIteratorNext(iterator)
        }
        return nil
    }

    private static func getBatteryCondition() -> String? {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOPMPowerSource"), &iterator) == KERN_SUCCESS else {
            return nil
        }
        defer { IOObjectRelease(iterator) }

        var service = IOIteratorNext(iterator)
        while service != 0 {
            defer { IOObjectRelease(service) }

            if let condition = IORegistryEntryCreateCFProperty(service, "BatteryCondition" as CFString, nil, 0)?.takeRetainedValue() as? Int {
                switch condition {
                case 0: return "Poor"
                case 1: return "Normal"
                case 2: return "Good"
                default: return "Unknown"
                }
            }
            service = IOIteratorNext(iterator)
        }
        return nil
    }

    private static func collectGPUInfo() -> [DiagnosticEntry] {
        var entries: [DiagnosticEntry] = []

        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("AGDC"), &iterator) == KERN_SUCCESS else {
            return entries
        }
        defer { IOObjectRelease(iterator) }

        var service = IOIteratorNext(iterator)
        while service != 0 {
            defer { IOObjectRelease(service) }

            if let vram = IORegistryEntryCreateCFProperty(service, "VRAM" as CFString, nil, 0)?.takeRetainedValue() as? UInt64 {
                entries.append(DiagnosticEntry(
                    name: "GPU VRAM",
                    value: formatBytes(Int64(vram)),
                    status: .ok
                ))
            }

            if let model = IORegistryEntryCreateCFProperty(service, "model" as CFString, nil, 0)?.takeRetainedValue() as? Data,
               let modelString = String(data: model, encoding: .utf8) {
                entries.append(DiagnosticEntry(
                    name: "GPU Model",
                    value: modelString,
                    status: .ok
                ))
            }

            service = IOIteratorNext(iterator)
        }

        return entries
    }

    private static func collectNetworkInfo() -> [DiagnosticEntry] {
        var entries: [DiagnosticEntry] = []
        let network = SystemInfoCollector.shared.collectNetwork()
        entries.append(DiagnosticEntry(
            name: "Network",
            value: network.isConnected ? "Connected" : "Disconnected",
            status: network.isConnected ? .ok : .error
        ))
        entries.append(DiagnosticEntry(
            name: "Interface",
            value: network.interfaceName.isEmpty ? network.interfaceType : "\(network.interfaceType) (\(network.interfaceName))",
            status: .ok
        ))
        if let ssid = network.ssid {
            entries.append(DiagnosticEntry(name: "Wi-Fi Network", value: ssid, status: .ok))
        }
        if let rssi = network.rssi {
            entries.append(DiagnosticEntry(
                name: "Wi-Fi Signal",
                value: "\(rssi) dBm",
                status: rssi > -65 ? .ok : .warning
            ))
        }
        if let ip = network.localIP {
            entries.append(DiagnosticEntry(name: "Local IP", value: ip, status: .ok))
        }
        return entries
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
