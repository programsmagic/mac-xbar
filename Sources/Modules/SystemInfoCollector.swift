import Foundation
import AppKit
import IOKit
import IOKit.ps
import SystemConfiguration

public struct SystemMetrics: Sendable {
    public struct CPU: Sendable {
        public let overallUsage: Double
        public let perCoreUsage: [Double]
        public let coreCount: Int
        public let activeCores: Int
        public let modelName: String
    }

    public struct Memory: Sendable {
        public var used: Int64
        public var total: Int64
        public var free: Int64
        public var active: Int64
        public var inactive: Int64
        public var wired: Int64
        public var compressed: Int64
        public var swapUsed: Int64
        public var swapTotal: Int64
        public var pressure: String

        public var usedPercent: Double {
            total > 0 ? Double(used) / Double(total) * 100 : 0
        }
    }

    public struct DiskVolume: Sendable {
        public let name: String
        public let used: Int64
        public let total: Int64
        public let isRoot: Bool

        public var usedPercent: Double {
            total > 0 ? Double(used) / Double(total) * 100 : 0
        }
    }

    public struct Battery: Sendable {
        public let level: Double?
        public let charging: Bool
        public let cycleCount: Int?
        public let condition: String?
        public let temperature: Double?
        public let isPresent: Bool
    }

    public struct GPU: Sendable {
        public let model: String?
        public let vram: Int64?
        public let vendor: String?
    }

    public struct Network: Sendable {
        public let isConnected: Bool
        public let interfaceType: String
        public let interfaceName: String
        public let ssid: String?
        public let rssi: Int?
        public let channel: String?
        public let localIP: String?
        public let macAddress: String?
    }

    public struct System: Sendable {
        public let osVersion: String
        public let buildNumber: String
        public let chipName: String
        public let modelIdentifier: String
        public let physicalMemory: Int64
        public let uptime: TimeInterval
        public let thermalState: String
        public let serialNumber: String?
    }

    public let cpu: CPU
    public let memory: Memory
    public let diskVolumes: [DiskVolume]
    public let battery: Battery
    public let gpu: GPU
    public let network: Network
    public let system: System
}

public final class SystemInfoCollector {
    public static let shared = SystemInfoCollector()

    private var prevIdle: [UInt64] = []
    private var prevTotal: [UInt64] = []

    private init() {}

    public func collectAll() -> SystemMetrics {
        SystemMetrics(
            cpu: collectCPU(),
            memory: collectMemory(),
            diskVolumes: collectDisk(),
            battery: collectBattery(),
            gpu: collectGPU(),
            network: collectNetwork(),
            system: collectSystem()
        )
    }

    // MARK: - CPU

    private func collectCPU() -> SystemMetrics.CPU {
        let modelName = sysctlString("machdep.cpu.brand_string")
        let activeCount = ProcessInfo.processInfo.activeProcessorCount
        let totalCount = ProcessInfo.processInfo.processorCount

        var usage: [Double] = []
        var overall: Double = 0

        var processorCount = natural_t()
        var infoCount = mach_msg_type_number_t()
        var processorInfoArray: processor_info_array_t?

        let result = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &processorCount,
            &processorInfoArray,
            &infoCount
        )

        if result == KERN_SUCCESS, let infoArray = processorInfoArray {
            infoArray.withMemoryRebound(to: processor_cpu_load_info.self, capacity: Int(infoCount)) { cpuInfoPtr in
                if prevIdle.count != Int(processorCount) {
                    prevIdle = Array(repeating: 0, count: Int(processorCount))
                    prevTotal = Array(repeating: 0, count: Int(processorCount))
                }
                for i in 0..<Int(processorCount) {
                    let info = cpuInfoPtr[i]
                    let user = UInt64(info.cpu_ticks.0)
                    let system = UInt64(info.cpu_ticks.1)
                    let idle = UInt64(info.cpu_ticks.2)
                    let nice = UInt64(info.cpu_ticks.3)
                    let total = user + system + idle + nice

                    if prevTotal[i] == 0 {
                        usage.append(0)
                    } else {
                        let deltaTotal = total - prevTotal[i]
                        let deltaIdle = idle - prevIdle[i]
                        if deltaTotal > 0 {
                            let coreUsage = Double(deltaTotal - deltaIdle) / Double(deltaTotal) * 100
                            usage.append(min(100, max(0, coreUsage)))
                        } else {
                            usage.append(0)
                        }
                    }

                    prevIdle[i] = idle
                    prevTotal[i] = total
                }
            }

            vm_deallocate(
                mach_task_self_,
                vm_address_t(UInt(bitPattern: infoArray)),
                vm_size_t(Int(infoCount) * MemoryLayout<integer_t>.stride)
            )
        }

        overall = usage.isEmpty ? 0 : usage.reduce(0, +) / Double(usage.count)

        return SystemMetrics.CPU(
            overallUsage: overall,
            perCoreUsage: usage,
            coreCount: totalCount,
            activeCores: activeCount,
            modelName: modelName
        )
    }

    // MARK: - Memory

    public func collectMemory() -> SystemMetrics.Memory {
        var pageSize: vm_size_t = 0
        host_page_size(mach_host_self(), &pageSize)

        var stats64 = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)

        let result = withUnsafeMutablePointer(to: &stats64) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }

        let page = Int64(pageSize)
        var memory = SystemMetrics.Memory(
            used: 0,
            total: Int64(ProcessInfo.processInfo.physicalMemory),
            free: 0,
            active: 0,
            inactive: 0,
            wired: 0,
            compressed: 0,
            swapUsed: 0,
            swapTotal: 0,
            pressure: "Unknown"
        )

        if result == KERN_SUCCESS {
            let free = Int64(stats64.free_count) * page
            let active = Int64(stats64.active_count) * page
            let inactive = Int64(stats64.inactive_count) * page
            let wired = Int64(stats64.wire_count) * page
            let compressed = Int64(stats64.compressor_page_count) * page

            memory.free = free
            memory.active = active
            memory.inactive = inactive
            memory.wired = wired
            memory.compressed = compressed
            memory.used = active + wired + compressed
        }

        let (swapUsed, swapTotal) = collectSwapInfo()
        memory.swapUsed = swapUsed
        memory.swapTotal = swapTotal

        memory.pressure = memoryPressureString(used: memory.used, total: memory.total)
        return memory
    }

    private func collectSwapInfo() -> (used: Int64, total: Int64) {
        var xswUsage = xsw_usage()
        var size = MemoryLayout<xsw_usage>.size

        var mib: [Int32] = [CTL_VM, VM_SWAPUSAGE]
        var used: Int64 = 0
        var total: Int64 = 0

        if sysctl(&mib, 2, &xswUsage, &size, nil, 0) == 0 {
            used = Int64(xswUsage.xsu_used)
            total = Int64(xswUsage.xsu_total)
        }
        return (used, total)
    }

    private func memoryPressureString(used: Int64, total: Int64) -> String {
        guard total > 0 else { return "Unknown" }
        let percent = Double(used) / Double(total)
        if percent > 0.9 { return "Critical" }
        if percent > 0.75 { return "High" }
        if percent > 0.5 { return "Elevated" }
        return "Normal"
    }

    // MARK: - Disk

    public func collectDisk() -> [SystemMetrics.DiskVolume] {
        var volumes: [SystemMetrics.DiskVolume] = []
        let keys: [URLResourceKey] = [.volumeNameKey, .volumeTotalCapacityKey, .volumeAvailableCapacityKey]

        if let urls = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: keys, options: [.skipHiddenVolumes]) {
            for url in urls {
                if let values = try? url.resourceValues(forKeys: Set(keys)) {
                    let total = Int64(values.volumeTotalCapacity ?? 0)
                    let available = Int64(values.volumeAvailableCapacity ?? 0)
                    let isRoot = url.path == "/"
                    let name = values.volumeName ?? url.lastPathComponent

                    volumes.append(SystemMetrics.DiskVolume(
                        name: name,
                        used: total - available,
                        total: total,
                        isRoot: isRoot
                    ))
                }
            }
        }

        if volumes.isEmpty {
            let attrs = try? FileManager.default.attributesOfFileSystem(forPath: "/")
            let total = attrs?[.systemSize] as? Int64 ?? 0
            let free = attrs?[.systemFreeSize] as? Int64 ?? 0
            volumes.append(SystemMetrics.DiskVolume(
                name: "Macintosh HD",
                used: total - free,
                total: total,
                isRoot: true
            ))
        }

        return volumes.sorted { $0.isRoot && !$1.isRoot }
    }

    // MARK: - Battery

    public func collectBattery() -> SystemMetrics.Battery {
        var level: Double?
        var charging = false
        var isPresent = false

        let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue()
        guard let powerSourcesSnapshot = snapshot else {
            return SystemMetrics.Battery(level: nil, charging: false, cycleCount: nil, condition: nil, temperature: nil, isPresent: false)
        }

        if let sources = IOPSCopyPowerSourcesList(powerSourcesSnapshot)?.takeRetainedValue() as? [CFTypeRef] {
            for source in sources {
                if let description = IOPSGetPowerSourceDescription(powerSourcesSnapshot, source)?.takeUnretainedValue() as? [String: Any] {
                    if let currentCapacity = description[kIOPSCurrentCapacityKey] as? Int,
                       let maxCapacity = description[kIOPSMaxCapacityKey] as? Int, maxCapacity > 0 {
                        level = Double(currentCapacity) / Double(maxCapacity)
                        isPresent = true
                    }
                    if let isCharging = description[kIOPSIsChargingKey] as? Bool {
                        charging = isCharging
                    }
                }
            }
        }

        let cycleCount = ioregistryIntValue(for: "CycleCount", in: "IOPMPowerSource")
        let condition = batteryConditionString()
        let temperature = batteryTemperature()

        return SystemMetrics.Battery(
            level: level,
            charging: charging,
            cycleCount: cycleCount,
            condition: condition,
            temperature: temperature,
            isPresent: isPresent
        )
    }

    private func batteryConditionString() -> String? {
        guard let raw = ioregistryIntValue(for: "BatteryCondition", in: "IOPMPowerSource") else { return nil }
        switch raw {
        case 0: return "Poor"
        case 1: return "Normal"
        case 2: return "Good"
        case 3: return "Fair"
        default: return "Unknown"
        }
    }

    private func batteryTemperature() -> Double? {
        guard let raw = ioregistryIntValue(for: "Temperature", in: "IOPMPowerSource") else { return nil }
        return Double(raw) / 100.0
    }

    private func ioregistryIntValue(for key: String, in serviceName: String) -> Int? {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching(serviceName), &iterator) == KERN_SUCCESS else {
            return nil
        }
        defer { IOObjectRelease(iterator) }

        var service = IOIteratorNext(iterator)
        while service != 0 {
            defer { IOObjectRelease(service) }
            if let value = IORegistryEntryCreateCFProperty(service, key as CFString, nil, 0)?.takeRetainedValue() as? Int {
                return value
            }
            if let value = IORegistryEntryCreateCFProperty(service, key as CFString, nil, 0)?.takeRetainedValue() as? NSNumber {
                return value.intValue
            }
            service = IOIteratorNext(iterator)
        }
        return nil
    }

    // MARK: - GPU

    private func collectGPU() -> SystemMetrics.GPU {
        var model: String?
        var vram: Int64?
        var vendor: String?

        var iterator: io_iterator_t = 0
        if IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("AGDC"), &iterator) == KERN_SUCCESS {
            defer { IOObjectRelease(iterator) }
            var service = IOIteratorNext(iterator)
            while service != 0 {
                defer { IOObjectRelease(service) }
                if let modelData = IORegistryEntryCreateCFProperty(service, "model" as CFString, nil, 0)?.takeRetainedValue() as? Data {
                    model = String(data: modelData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                if let vramValue = IORegistryEntryCreateCFProperty(service, "VRAM" as CFString, nil, 0)?.takeRetainedValue() as? UInt64 {
                    vram = Int64(vramValue)
                }
                if let vendorData = IORegistryEntryCreateCFProperty(service, "vendor-id" as CFString, nil, 0)?.takeRetainedValue() as? Data {
                    vendor = String(data: vendorData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                service = IOIteratorNext(iterator)
            }
        }

        if model == nil {
            var accelIterator: io_iterator_t = 0
            if IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOAccelerator"), &accelIterator) == KERN_SUCCESS {
                defer { IOObjectRelease(accelIterator) }
                var service = IOIteratorNext(accelIterator)
                while service != 0 {
                    defer { IOObjectRelease(service) }
                    let className = String(cString: object_getClassName(service))
                    if className.hasPrefix("AGX") || className.hasPrefix("Intel") {
                        let cleaned = className
                            .replacingOccurrences(of: "AGXAccelerator", with: "")
                            .replacingOccurrences(of: "AGX", with: "")
                            .replacingOccurrences(of: "IntelAccelerator", with: "Intel")
                        if !cleaned.isEmpty {
                            model = "\(cleaned) GPU"
                            break
                        }
                    }
                    service = IOIteratorNext(accelIterator)
                }
            }
        }

        if model == nil {
            let chip = sysctlString("machdep.cpu.brand_string")
            if chip.contains("Apple M") {
                model = "\(chip) GPU"
            }
        }

        return SystemMetrics.GPU(model: model, vram: vram, vendor: vendor)
    }

    // MARK: - Network

    public func collectNetwork() -> SystemMetrics.Network {
        let interfaceName = primaryInterfaceName()
        let localIP = ipAddress(forInterface: interfaceName)

        return SystemMetrics.Network(
            isConnected: isNetworkConnected(),
            interfaceType: interfaceTypeName(interfaceName),
            interfaceName: interfaceName,
            ssid: currentSSID(),
            rssi: currentRSSI(),
            channel: currentChannel(),
            localIP: localIP,
            macAddress: macAddress(forInterface: interfaceName)
        )
    }

    private func isNetworkConnected() -> Bool {
        let monitor = NetworkReachabilityMonitor()
        return monitor.isConnected
    }

    private func primaryInterfaceName() -> String {
        var ifap: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifap) == 0, let firstAddr = ifap else { return "" }
        defer { freeifaddrs(ifap) }

        var ptr: UnsafeMutablePointer<ifaddrs> = firstAddr
        var primary: String = ""

        while true {
            let flags = ptr.pointee.ifa_flags
            let name = String(cString: ptr.pointee.ifa_name)
            let isUp = (flags & UInt32(IFF_UP)) != 0
            let isLoopback = (flags & UInt32(IFF_LOOPBACK)) != 0
            let isP2P = (flags & UInt32(IFF_POINTOPOINT)) != 0

            if isUp && !isLoopback && !isP2P && ptr.pointee.ifa_addr?.pointee.sa_family == UInt8(AF_INET) {
                if primary.isEmpty {
                    primary = name
                }
            }

            guard let next = ptr.pointee.ifa_next else { break }
            ptr = next
        }
        return primary
    }

    private func ipAddress(forInterface interface: String) -> String? {
        var ifap: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifap) == 0, let firstAddr = ifap else { return nil }
        defer { freeifaddrs(ifap) }

        var ptr: UnsafeMutablePointer<ifaddrs> = firstAddr
        while true {
            let name = String(cString: ptr.pointee.ifa_name)
            if name == interface, let addr = ptr.pointee.ifa_addr, addr.pointee.sa_family == UInt8(AF_INET) {
                var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                getnameinfo(addr, socklen_t(addr.pointee.sa_len), &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST)
                return String(cString: hostname)
            }
            guard let next = ptr.pointee.ifa_next else { break }
            ptr = next
        }
        return nil
    }

    private func macAddress(forInterface interface: String) -> String? {
        var ifap: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifap) == 0, let firstAddr = ifap else { return nil }
        defer { freeifaddrs(ifap) }

        var ptr: UnsafeMutablePointer<ifaddrs> = firstAddr
        while true {
            let name = String(cString: ptr.pointee.ifa_name)
            if name == interface, let addr = ptr.pointee.ifa_addr, addr.pointee.sa_family == UInt8(AF_LINK) {
                var sockaddrDl = sockaddr_dl()
                withUnsafePointer(to: &addr.pointee) { src in
                    src.withMemoryRebound(to: sockaddr_dl.self, capacity: 1) { dlPtr in
                        sockaddrDl = dlPtr.pointee
                    }
                }

                let byteCount = Int(sockaddrDl.sdl_alen)
                let nameLen = Int(sockaddrDl.sdl_nlen)
                if byteCount > 0 {
                    let headerSize = 8
                    var mac = ""
                    withUnsafePointer(to: &sockaddrDl) { p in
                        p.withMemoryRebound(to: UInt8.self, capacity: MemoryLayout<sockaddr_dl>.size) { bytes in
                            for i in 0..<byteCount {
                                mac += String(format: "%02x:", bytes[headerSize + nameLen + i])
                            }
                        }
                    }
                    return String(mac.dropLast())
                }
            }
            guard let next = ptr.pointee.ifa_next else { break }
            ptr = next
        }
        return nil
    }

    private func interfaceTypeName(_ interface: String) -> String {
        if interface.hasPrefix("en") { return "Wi-Fi" }
        if interface.hasPrefix("utun") || interface.hasPrefix("ipsec") || interface.hasPrefix("ppp") { return "VPN" }
        if interface.hasPrefix("awdl") { return "AirDrop" }
        if interface.hasPrefix("bridge") { return "Bridge" }
        return interface.isEmpty ? "Unknown" : "Ethernet"
    }

    private func currentSSID() -> String? {
        guard let service = wifiService() else { return nil }
        defer { IOObjectRelease(service) }
        if let ssidData = IORegistryEntryCreateCFProperty(service, "SSID" as CFString, nil, 0)?.takeRetainedValue() as? Data {
            return String(data: ssidData, encoding: .utf8)
        }
        if let ssidString = IORegistryEntryCreateCFProperty(service, "SSID" as CFString, nil, 0)?.takeRetainedValue() as? String {
            return ssidString
        }
        return nil
    }

    private func currentRSSI() -> Int? {
        guard let service = wifiService() else { return nil }
        defer { IOObjectRelease(service) }
        if let rssi = IORegistryEntryCreateCFProperty(service, "RSSI" as CFString, nil, 0)?.takeRetainedValue() as? Int {
            return rssi
        }
        if let rssiNumber = IORegistryEntryCreateCFProperty(service, "RSSI" as CFString, nil, 0)?.takeRetainedValue() as? NSNumber {
            return rssiNumber.intValue
        }
        return nil
    }

    private func currentChannel() -> String? {
        guard let service = wifiService() else { return nil }
        defer { IOObjectRelease(service) }
        if let channel = IORegistryEntryCreateCFProperty(service, "CHANNEL" as CFString, nil, 0)?.takeRetainedValue() as? Int {
            return "\(channel)"
        }
        return nil
    }

    private func wifiService() -> io_object_t? {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IO80211Interface"), &iterator) == KERN_SUCCESS else {
            return nil
        }
        defer { IOObjectRelease(iterator) }
        return IOIteratorNext(iterator)
    }

    // MARK: - System

    private func collectSystem() -> SystemMetrics.System {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        let versionString = "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
        let buildNumber = sysctlString("kern.osversion")
        let chipName = sysctlString("machdep.cpu.brand_string")
        let modelIdentifier = sysctlString("hw.model")
        let serialNumber = ioregistrySerialNumber()

        var bootTime = timeval()
        var size = MemoryLayout<timeval>.size
        var mib: [Int32] = [CTL_KERN, KERN_BOOTTIME]
        var uptime: TimeInterval = 0
        if sysctl(&mib, 2, &bootTime, &size, nil, 0) == 0 {
            uptime = Date().timeIntervalSince(Date(timeIntervalSince1970: TimeInterval(bootTime.tv_sec)))
        }

        let thermalState: String
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: thermalState = "Normal"
        case .fair: thermalState = "Fair"
        case .serious: thermalState = "Serious"
        case .critical: thermalState = "Critical"
        @unknown default: thermalState = "Unknown"
        }

        return SystemMetrics.System(
            osVersion: versionString,
            buildNumber: buildNumber,
            chipName: chipName,
            modelIdentifier: modelIdentifier,
            physicalMemory: Int64(ProcessInfo.processInfo.physicalMemory),
            uptime: uptime,
            thermalState: thermalState,
            serialNumber: serialNumber
        )
    }

    private func sysctlString(_ name: String) -> String {
        var size = 0
        sysctlbyname(name, nil, &size, nil, 0)
        guard size > 0 else { return "" }
        var value = [CChar](repeating: 0, count: size)
        sysctlbyname(name, &value, &size, nil, 0)
        return String(cString: value)
    }

    private func ioregistrySerialNumber() -> String? {
        let platformExpert = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPlatformExpertDevice"))
        guard platformExpert != 0 else { return nil }
        defer { IOObjectRelease(platformExpert) }
        if let serial = IORegistryEntryCreateCFProperty(platformExpert, kIOPlatformSerialNumberKey as CFString, nil, 0)?.takeRetainedValue() as? String {
            return serial
        }
        return nil
    }
}

// MARK: - Reachability

private final class NetworkReachabilityMonitor {
    var isConnected: Bool = false

    init() {
        var zeroAddress = sockaddr()
        zeroAddress.sa_len = UInt8(MemoryLayout<sockaddr>.size)
        zeroAddress.sa_family = sa_family_t(AF_INET)

        guard let reachability = withUnsafePointer(to: &zeroAddress, {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { ptr in
                SCNetworkReachabilityCreateWithAddress(nil, ptr)
            }
        }) else { return }

        var flags = SCNetworkReachabilityFlags()
        if SCNetworkReachabilityGetFlags(reachability, &flags) {
            let isReachable = flags.contains(.reachable)
            let needsConnection = flags.contains(.connectionRequired)
            isConnected = isReachable && !needsConnection
        }
    }
}
