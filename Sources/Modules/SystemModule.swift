import Foundation
import AppKit
import IOKit.ps
import IOKit

public final class SystemModule: Module {
    public let id: ModuleID = "system"
    public var name: String = "System"
    public var config: ModuleConfig = ModuleConfig(
        id: "system",
        name: "System",
        enabled: true,
        refreshInterval: 60.0
    )
    public var state: ModuleState = .active

    public struct SystemStatus {
        public let cpuUsage: Double
        public let memoryUsed: Int64
        public let memoryTotal: Int64
        public let diskUsed: Int64
        public let diskTotal: Int64
        public let batteryLevel: Double?
        public let batteryCharging: Bool
        public let temperature: Double?
        public let fanSpeed: Int?
        public let uptime: TimeInterval
        public let sleepStats: SleepStats
    }

    public struct SleepStats {
        public let sleepCount: Int
        public let sleepDuration: TimeInterval
        public let lastSleep: Date?
    }

    public func initialize() async throws {
        // System module initialization
    }

    public func refresh() async throws -> ModuleOutput {
        let status = await collectStatus()
        let items = buildMenuItems(from: status)
        return ModuleOutput(items: items, source: id)
    }

    public func invalidate() {}

    public func setEnabled(_ enabled: Bool) {
        state = enabled ? .active : .paused
    }

    private func collectStatus() async -> SystemStatus {
        let cpuUsage = processCPUUsage()
        let memoryInfo = processMemoryInfo()
        let diskInfo = processDiskInfo()
        let batteryInfo = processBatteryInfo()
        let uptime = processUptime()
        let sleepStats = processSleepStats()
        let temperature = processTemperature()
        let fanSpeed = processFanSpeed()

        return SystemStatus(
            cpuUsage: cpuUsage,
            memoryUsed: memoryInfo.used,
            memoryTotal: memoryInfo.total,
            diskUsed: diskInfo.used,
            diskTotal: diskInfo.total,
            batteryLevel: batteryInfo.level,
            batteryCharging: batteryInfo.charging,
            temperature: temperature,
            fanSpeed: fanSpeed,
            uptime: uptime,
            sleepStats: sleepStats
        )
    }

    private func buildMenuItems(from status: SystemStatus) -> [MenuItem] {
        var items: [MenuItem] = []

        items.append(MenuItem(
            title: "CPU: \(String(format: "%.1f", status.cpuUsage))%",
            icon: "cpu",
            badge: status.cpuUsage > 80 ? "High" : nil,
            color: status.cpuUsage > 80 ? "#FF3B30" : nil,
            order: 0
        ))

        let memPercent = status.memoryTotal > 0 ? Double(status.memoryUsed) / Double(status.memoryTotal) * 100 : 0
        items.append(MenuItem(
            title: "Memory: \(formatBytes(status.memoryUsed)) / \(formatBytes(status.memoryTotal))",
            icon: "memorychip",
            badge: String(format: "%.0f%%", memPercent),
            color: memPercent > 80 ? "#FF3B30" : nil,
            order: 1
        ))

        let diskPercent = status.diskTotal > 0 ? Double(status.diskUsed) / Double(status.diskTotal) * 100 : 0
        items.append(MenuItem(
            title: "Disk: \(formatBytes(status.diskUsed)) / \(formatBytes(status.diskTotal))",
            icon: "externaldrive",
            badge: String(format: "%.0f%%", diskPercent),
            color: diskPercent > 90 ? "#FF3B30" : nil,
            order: 2
        ))

        if let batteryLevel = status.batteryLevel {
            items.append(MenuItem(
                title: "Battery: \(String(format: "%.0f", batteryLevel * 100))%",
                icon: status.batteryCharging ? "battery.charging" : "battery",
                badge: batteryLevel < 0.2 ? "Low" : nil,
                color: batteryLevel < 0.2 ? "#FF3B30" : nil,
                order: 3
            ))
        }

        if let temperature = status.temperature {
            items.append(MenuItem(
                title: "Temperature: \(String(format: "%.0f", temperature))°C",
                icon: "thermometer",
                color: temperature > 80 ? "#FF3B30" : nil,
                order: 4
            ))
        }

        if let fanSpeed = status.fanSpeed {
            items.append(MenuItem(
                title: "Fan: \(fanSpeed) RPM",
                icon: "fan",
                order: 5
            ))
        }

        items.append(MenuItem(
            title: "Uptime: \(formatUptime(status.uptime))",
            icon: "clock",
            order: 6
        ))

        items.append(MenuItem(
            title: "Sleeps: \(status.sleepStats.sleepCount) | Last: \(status.sleepStats.lastSleep.map { formatDate($0) } ?? "N/A")",
            icon: "moon",
            order: 7
        ))

        return items
    }

    private func processCPUUsage() -> Double {
        var cpuInfo: host_cpu_load_info_data_t = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &cpuInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }
        let total = cpuInfo.cpu_ticks.0 + cpuInfo.cpu_ticks.1 + cpuInfo.cpu_ticks.2 + cpuInfo.cpu_ticks.3
        let idle = cpuInfo.cpu_ticks.3
        return total > 0 ? Double(total - idle) / Double(total) * 100 : 0
    }

    private func processMemoryInfo() -> (used: Int64, total: Int64) {
        var size = mach_msg_type_number_t(MemoryLayout<vm_statistics_data_t>.size / MemoryLayout<integer_t>.size)
        var vmStat = vm_statistics_data_t()
        let result = withUnsafeMutablePointer(to: &vmStat) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(size)) {
                host_statistics(mach_host_self(), HOST_VM_INFO, $0, &size)
            }
        }
        guard result == KERN_SUCCESS else { return (0, 0) }
        let pageSize = Int64(vm_page_size)
        let used = Int64(vmStat.active_count + vmStat.inactive_count + vmStat.wire_count) * pageSize
        let total = Int64(vmStat.free_count + vmStat.active_count + vmStat.inactive_count + vmStat.wire_count) * pageSize
        return (used, total)
    }

    private func processDiskInfo() -> (used: Int64, total: Int64) {
        let attrs = try? FileManager.default.attributesOfFileSystem(forPath: "/")
        let total = attrs?[.systemSize] as? Int64 ?? 0
        let free = attrs?[.systemFreeSize] as? Int64 ?? 0
        return (total - free, total)
    }

    private func processBatteryInfo() -> (level: Double?, charging: Bool) {
        return (nil, false)
    }

    private func processTemperature() -> Double? {
        var temp: Double?
        let matching = IOServiceMatching("IOHIDevice")
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else { return nil }
        defer { IOObjectRelease(iterator) }
        let service = IOIteratorNext(iterator)
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }
        var props: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS else { return nil }
        guard let dictionary = props?.takeRetainedValue() as? [String: Any] else { return nil }
        if let tempVal = dictionary["Temperature"] as? Double {
            temp = tempVal
        }
        return temp
    }

    private func processFanSpeed() -> Int? {
        let matching = IOServiceMatching("IOHIDevice")
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else { return nil }
        defer { IOObjectRelease(iterator) }
        var fanSpeed: Int?
        var service = IOIteratorNext(iterator)
        while service != 0 {
            defer { IOObjectRelease(service) }
            var props: Unmanaged<CFMutableDictionary>?
            guard IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS else {
                service = IOIteratorNext(iterator)
                continue
            }
            guard let dictionary = props?.takeRetainedValue() as? [String: Any] else {
                service = IOIteratorNext(iterator)
                continue
            }
            if let speed = dictionary["FanSpeed"] as? Int {
                fanSpeed = speed
                break
            }
            service = IOIteratorNext(iterator)
        }
        return fanSpeed
    }

    private func processUptime() -> TimeInterval {
        var bootTime = timeval()
        var size = MemoryLayout<timeval>.size
        var mib = [CTL_KERN, KERN_BOOTTIME]
        guard sysctl(&mib, 2, &bootTime, &size, nil, 0) == 0 else { return 0 }
        return Date().timeIntervalSince(Date(timeIntervalSince1970: TimeInterval(bootTime.tv_sec)))
    }

    private func processSleepStats() -> SleepStats {
        return SleepStats(sleepCount: 0, sleepDuration: 0, lastSleep: nil)
    }

    private func formatBytes(_ bytes: Int64) -> String {
        if bytes < 1024 { return "\(bytes) B" }
        if bytes < 1024 * 1024 { return String(format: "%.1f KB", Double(bytes) / 1024) }
        if bytes < 1024 * 1024 * 1024 { return String(format: "%.1f MB", Double(bytes) / (1024 * 1024)) }
        return String(format: "%.1f GB", Double(bytes) / (1024 * 1024 * 1024))
    }

    private func formatUptime(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}