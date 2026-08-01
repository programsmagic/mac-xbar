import Foundation
import os.log

public final class PerformanceModule {
    public static let shared = PerformanceModule()

    public struct PerformanceMetrics {
        public let idleMemoryMB: Double
        public let idleCPUPercent: Double
        public let startupTimeMs: Double
        public let energyImpact: Double
        public let menuUpdateLatencyMs: Double
        public let activeTimers: Int
        public let cacheHitRate: Double
    }

    private let log = OSLog(subsystem: "com.macxbar.app", category: "performance")
    private var memoryBudgetMB: Double = 10.0
    private var cpuBudgetPercent: Double = 0.1
    private var startupTimestamp: Date?
    private var adaptivePollingEnabled: Bool = true
    private var suspendedModules: Set<String> = []

    public var isAdaptivePollingEnabled: Bool {
        get { adaptivePollingEnabled }
        set { adaptivePollingEnabled = newValue }
    }

    public var memoryBudget: Double {
        get { memoryBudgetMB }
        set { memoryBudgetMB = newValue }
    }

    public var cpuBudget: Double {
        get { cpuBudgetPercent }
        set { cpuBudgetPercent = newValue }
    }

    public func recordStartup() {
        startupTimestamp = Date()
        os_log("App startup recorded", log: log, type: .info)
    }

    public var startupTimeMs: Double {
        guard let start = startupTimestamp else { return 0 }
        return Date().timeIntervalSince(start) * 1000
    }

    public func checkMemoryBudget() -> Bool {
        let currentMemory = getCurrentMemoryUsageMB()
        let withinBudget = currentMemory < memoryBudgetMB
        if !withinBudget {
            os_log("Memory budget exceeded: %.1f MB (limit: %.1f MB)", log: log, type: .fault, currentMemory, memoryBudgetMB)
        }
        return withinBudget
    }

    public func checkCPUBudget() -> Bool {
        let currentCPU = getCurrentCPUUsage()
        let withinBudget = currentCPU < cpuBudgetPercent
        if !withinBudget {
            os_log("CPU budget exceeded: %.2f%% (limit: %.2f%%)", log: log, type: .fault, currentCPU, cpuBudgetPercent)
        }
        return withinBudget
    }

    public func suspendInactiveModule(_ moduleID: String) {
        suspendedModules.insert(moduleID)
        os_log("Suspended inactive module %{public}@", log: log, type: .info, moduleID)
    }

    public func resumeModule(_ moduleID: String) {
        suspendedModules.remove(moduleID)
        os_log("Resumed module %{public}@", log: log, type: .info, moduleID)
    }

    public func isModuleSuspended(_ moduleID: String) -> Bool {
        suspendedModules.contains(moduleID)
    }

    public func suspendAllInactiveModules(activeModuleIDs: Set<String>) {
        for moduleID in suspendedModules {
            if !activeModuleIDs.contains(moduleID) {
                // Already suspended
            }
        }
    }

    public func updateAdaptivePolling() {
        guard adaptivePollingEnabled else { return }
        let memoryPressure = getMemoryPressure()
        switch memoryPressure {
        case .critical:
            Scheduler.shared.invalidateAll()
            os_log("Adaptive polling: all timers paused due to critical memory pressure", log: log, type: .fault)
        case .warning:
            for (_, timer) in Scheduler.shared.timers {
                timer.suspend()
            }
            os_log("Adaptive polling: timers suspended due to warning memory pressure", log: log, type: .fault)
        case .normal:
            for (moduleID, _) in Scheduler.shared.timers {
                Scheduler.shared.resume(moduleID: moduleID)
            }
            os_log("Adaptive polling: timers resumed", log: log, type: .info)
        @unknown default:
            break
        }
    }

    public func recordMenuUpdateLatency(_ latencyMs: Double) {
        os_log("Menu update latency: %{public}f ms", log: log, type: .debug, latencyMs)
    }

    public func getDiagnostics() -> PerformanceMetrics {
        PerformanceMetrics(
            idleMemoryMB: getCurrentMemoryUsageMB(),
            idleCPUPercent: getCurrentCPUUsage(),
            startupTimeMs: startupTimeMs,
            energyImpact: getEnergyImpact(),
            menuUpdateLatencyMs: 0,
            activeTimers: Scheduler.shared.activeCount(),
            cacheHitRate: 0
        )
    }

    private func getCurrentMemoryUsageMB() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }
        return Double(info.resident_size) / (1024 * 1024)
    }

    private func getCurrentCPUUsage() -> Double {
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

    private func getEnergyImpact() -> Double {
        let process = ProcessInfo.processInfo
        return process.energyImpact
    }

    private func getMemoryPressure() -> MemoryPressureLevel {
        let pressure = ProcessInfo.processInfo.physicalMemory
        let used = getCurrentMemoryUsageMB() * 1024 * 1024
        let ratio = used / Double(pressure)
        switch ratio {
        case 0.9...: return .critical
        case 0.7...0.9: return .warning
        default: return .normal
        }
    }

    private enum MemoryPressureLevel {
        case normal
        case warning
        case critical
    }
}