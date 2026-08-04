import Foundation
import SystemConfiguration
import Network
import IOKit

public protocol NetworkSpeedObserver: AnyObject {
    func networkModule(_ module: NetworkModule, didUpdateSpeed download: Double, upload: Double, downloadFormatted: String, uploadFormatted: String)
    func networkModule(_ module: NetworkModule, didUpdateIntelligence intelligence: NetworkModule.NetworkIntelligence)
}

public final class NetworkModule: Module {
    public let id: ModuleID = "network"
    public var name: String = "Network"
    public var config: ModuleConfig = ModuleConfig(
        id: "network",
        name: "Network",
        enabled: true,
        refreshInterval: 1.0
    )
    public var state: ModuleState = .active

    public weak var speedObserver: NetworkSpeedObserver?

    private let monitor = NWPathMonitor()
    private var currentPath: NWPath?
    private var speedTimer: DispatchSourceTimer?
    private var latencyTimer: DispatchSourceTimer?
    private var intelligenceTimer: DispatchSourceTimer?

    private var previousRxBytes: UInt64 = 0
    private var previousTxBytes: UInt64 = 0
    private var previousSpeedTimestamp: Date = Date()
    private var sessionRxBytes: UInt64 = 0
    private var sessionTxBytes: UInt64 = 0
    private var peakDownload: Double = 0
    private var peakUpload: Double = 0

    private var cachedLatency: Double = 0
    private var cachedJitter: Double = 0
    private var cachedPacketLoss: Double = 0
    private var cachedPublicIP: String?
    private var cachedLocalIP: String = ""
    private var cachedIPv6: String?
    private var cachedInterfaceName: String = ""
    private var cachedWifiRSSI: Int?

    private var dlHistory: [Double] = []
    private var ulHistory: [Double] = []
    private let maxHistory = 3

    private var smoothedDL: Double = 0
    private var smoothedUL: Double = 0

    private var timeline: [ConnectionEvent] = []
    private let maxTimeline = 100

    private var todayRxBytes: UInt64 = 0
    private var todayTxBytes: UInt64 = 0
    private var lastDayReset: Date = Calendar.current.startOfDay(for: Date())

    public struct ConnectionEvent: Codable, Sendable {
        public let timestamp: Date
        public let type: EventType
        public let detail: String

        public enum EventType: String, Codable, Sendable {
            case connected, disconnected, interfaceChanged, vpnConnected, vpnDisconnected, speedAlert
        }
    }

    public struct NetworkIntelligence: Sendable {
        public var download: Double
        public var upload: Double
        public var peakDownload: Double
        public var peakUpload: Double
        public var sessionDownload: UInt64
        public var sessionUpload: UInt64
        public var todayDownload: UInt64
        public var todayUpload: UInt64
        public var latency: Double
        public var jitter: Double
        public var packetLoss: Double
        public var healthScore: Int
        public var publicIP: String?
        public var localIP: String
        public var ipv6: String?
        public var wifiRSSI: Int?
        public var interfaceType: String
        public var interfaceName: String
        public var isConnected: Bool
        public var isVPN: Bool
        public var timeline: [ConnectionEvent]
    }

    public func initialize() async throws {
        monitor.pathUpdateHandler = { [weak self] path in
            self?.handlePathUpdate(path)
        }
        monitor.start(queue: DispatchQueue.global(qos: .utility))

        let initial = getInterfaceStats()
        previousRxBytes = initial.rxBytes
        previousTxBytes = initial.txBytes
        previousSpeedTimestamp = Date()

        startSpeedTimer()
        startLatencyPolling()
        startIntelligencePolling()
        startDailyReset()

        cachedLocalIP = getLocalIP()
    }

    public func refresh() async throws -> ModuleOutput {
        let intelligence = buildIntelligence()
        let items = buildMenuItems(from: intelligence)
        return ModuleOutput(items: items, source: id)
    }

    public func invalidate() {
        monitor.cancel()
        speedTimer?.cancel()
        speedTimer = nil
        latencyTimer?.cancel()
        latencyTimer = nil
        intelligenceTimer?.cancel()
        intelligenceTimer = nil
    }

    public func currentIntelligence() -> NetworkIntelligence {
        buildIntelligence()
    }

    public func setEnabled(_ enabled: Bool) {
        if enabled {
            monitor.start(queue: DispatchQueue.global(qos: .utility))
            startSpeedTimer()
            startLatencyPolling()
            startIntelligencePolling()
        } else {
            monitor.cancel()
            speedTimer?.cancel()
            speedTimer = nil
            latencyTimer?.cancel()
            latencyTimer = nil
            intelligenceTimer?.cancel()
            intelligenceTimer = nil
        }
    }

    // MARK: - Path Monitoring

    private func handlePathUpdate(_ path: NWPath) {
        let oldStatus = currentPath?.status
        currentPath = path
        let newStatus = path.status

        if oldStatus != newStatus {
            if newStatus == .satisfied {
                addTimelineEvent(type: .connected, detail: "Network available")
            } else {
                addTimelineEvent(type: .disconnected, detail: "Network unavailable")
            }
        }

        cachedLocalIP = getLocalIP()
        cachedWifiRSSI = getWifiRSSI()
    }

    // MARK: - Speed Timer (adaptive 1s -> 3s)

    private var speedTickInterval: Double = 1.0
    private var flatTickCount: Int = 0

    private func startSpeedTimer() {
        guard speedTimer == nil else { return }
        scheduleSpeedTimer(interval: speedTickInterval)
    }

    private func scheduleSpeedTimer(interval: Double) {
        speedTimer?.cancel()
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .utility))
        timer.schedule(deadline: .now() + interval, repeating: interval, leeway: .milliseconds(100))
        timer.setEventHandler { [weak self] in
            self?.tickSpeed()
        }
        timer.resume()
        speedTimer = timer
    }

    private func tickSpeed() {
        let stats = getInterfaceStats()
        let now = Date()
        let elapsed = now.timeIntervalSince(previousSpeedTimestamp)
        guard elapsed > 0.5 else { return }

        let rxDelta = UInt64(Int64(stats.rxBytes) &- Int64(previousRxBytes))
        let txDelta = UInt64(Int64(stats.txBytes) &- Int64(previousTxBytes))

        let dlSpeed = Double(rxDelta) / elapsed
        let ulSpeed = Double(txDelta) / elapsed

        previousRxBytes = stats.rxBytes
        previousTxBytes = stats.txBytes
        previousSpeedTimestamp = now

        dlHistory.append(dlSpeed)
        ulHistory.append(ulSpeed)
        if dlHistory.count > maxHistory { dlHistory.removeFirst() }
        if ulHistory.count > maxHistory { ulHistory.removeFirst() }

        smoothedDL = dlHistory.reduce(0, +) / Double(dlHistory.count)
        smoothedUL = ulHistory.reduce(0, +) / Double(ulHistory.count)

        if smoothedDL > peakDownload { peakDownload = smoothedDL }
        if smoothedUL > peakUpload { peakUpload = smoothedUL }

        sessionRxBytes += rxDelta
        sessionTxBytes += txDelta
        todayRxBytes += rxDelta
        todayTxBytes += txDelta

        let dlFormatted = formatSpeedShort(smoothedDL)
        let ulFormatted = formatSpeedShort(smoothedUL)

        updateAdaptiveTickRate()

        speedObserver?.networkModule(self, didUpdateSpeed: smoothedDL, upload: smoothedUL, downloadFormatted: dlFormatted, uploadFormatted: ulFormatted)
    }

    private func updateAdaptiveTickRate() {
        let active = smoothedDL > 64 * 1024 || smoothedUL > 64 * 1024
        if active {
            flatTickCount = 0
            if speedTickInterval != 1.0 {
                speedTickInterval = 1.0
                scheduleSpeedTimer(interval: 1.0)
            }
        } else {
            flatTickCount += 1
            if flatTickCount >= 4 && speedTickInterval != 3.0 {
                speedTickInterval = 3.0
                scheduleSpeedTimer(interval: 3.0)
            }
        }
    }

    // MARK: - Latency Polling (every 5 seconds)

    private func startLatencyPolling() {
        guard latencyTimer == nil else { return }
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .utility))
        timer.schedule(deadline: .now(), repeating: 5.0, leeway: .milliseconds(500))
        timer.setEventHandler { [weak self] in
            Task { [weak self] in
                guard let self = self else { return }
                let (latency, jitter, loss) = await self.measureNetworkQuality()
                self.cachedLatency = latency
                self.cachedJitter = jitter
                self.cachedPacketLoss = loss
            }
        }
        timer.resume()
        latencyTimer = timer

        Task { [weak self] in
            guard let self = self else { return }
            let (latency, jitter, loss) = await self.measureNetworkQuality()
            self.cachedLatency = latency
            self.cachedJitter = jitter
            self.cachedPacketLoss = loss
            self.cachedPublicIP = await self.fetchPublicIP()
        }
    }

    // MARK: - Intelligence Polling (every 30 seconds)

    private func startIntelligencePolling() {
        guard intelligenceTimer == nil else { return }
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .utility))
        timer.schedule(deadline: .now(), repeating: 30.0, leeway: .milliseconds(1000))
        timer.setEventHandler { [weak self] in
            guard let self = self else { return }
            let intelligence = self.buildIntelligence()
            self.speedObserver?.networkModule(self, didUpdateIntelligence: intelligence)
        }
        timer.resume()
        intelligenceTimer = timer
    }

    // MARK: - Daily Reset

    private func startDailyReset() {
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .utility))
        timer.schedule(deadline: .now(), repeating: 3600.0, leeway: .milliseconds(5000))
        timer.setEventHandler { [weak self] in
            guard let self = self else { return }
            let now = Date()
            if !Calendar.current.isDate(self.lastDayReset, inSameDayAs: now) {
                self.todayRxBytes = 0
                self.todayTxBytes = 0
                self.lastDayReset = Calendar.current.startOfDay(for: now)
            }
        }
        timer.resume()
    }

    // MARK: - Network Quality Measurement

    private func measureNetworkQuality() async -> (latency: Double, jitter: Double, packetLoss: Double) {
        let samples = 5
        var latencies: [Double] = []
        var failures = 0

        for _ in 0..<samples {
            let latency = await measureSingleLatency()
            if latency >= 0 {
                latencies.append(latency)
            } else {
                failures += 1
            }
            if samples > 1 {
                try? await Task.sleep(nanoseconds: 200_000_000)
            }
        }

        let avgLatency = latencies.isEmpty ? -1 : latencies.reduce(0, +) / Double(latencies.count)

        var jitter: Double = 0
        if latencies.count >= 2 {
            let mean = avgLatency
            let variance = latencies.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(latencies.count)
            jitter = sqrt(variance)
        }

        let packetLoss = Double(failures) / Double(samples) * 100.0

        return (avgLatency, jitter, packetLoss)
    }

    private func measureSingleLatency() async -> Double {
        let host = NWEndpoint.Host("1.1.1.1")
        let port = NWEndpoint.Port("80")!
        let connection = NWConnection(host: host, port: port, using: .tcp)

        return await withCheckedContinuation { continuation in
            nonisolated(unsafe) var resumed = false
            let start = CFAbsoluteTimeGetCurrent()

            connection.stateUpdateHandler = { state in
                guard !resumed else { return }
                switch state {
                case .ready:
                    resumed = true
                    let latency = (CFAbsoluteTimeGetCurrent() - start) * 1000
                    connection.cancel()
                    continuation.resume(returning: latency)
                case .failed, .cancelled:
                    if !resumed {
                        resumed = true
                        continuation.resume(returning: -1)
                    }
                default:
                    break
                }
            }

            connection.start(queue: .global())

            DispatchQueue.global().asyncAfter(deadline: .now() + 3) {
                if !resumed {
                    resumed = true
                    connection.cancel()
                    continuation.resume(returning: -1)
                }
            }
        }
    }

    // MARK: - Health Score

    private func calculateHealthScore() -> Int {
        var score = 100

        if cachedLatency > 0 {
            if cachedLatency < 20 { score -= 0 }
            else if cachedLatency < 50 { score -= 5 }
            else if cachedLatency < 100 { score -= 15 }
            else if cachedLatency < 200 { score -= 30 }
            else { score -= 50 }
        }

        if cachedJitter > 0 {
            if cachedJitter < 5 { score -= 0 }
            else if cachedJitter < 15 { score -= 5 }
            else if cachedJitter < 30 { score -= 15 }
            else { score -= 25 }
        }

        if cachedPacketLoss > 0 {
            if cachedPacketLoss < 1 { score -= 5 }
            else if cachedPacketLoss < 5 { score -= 20 }
            else { score -= 40 }
        }

        if let rssi = cachedWifiRSSI {
            if rssi > -50 { score -= 0 }
            else if rssi > -65 { score -= 5 }
            else if rssi > -75 { score -= 15 }
            else { score -= 30 }
        }

        return max(0, min(100, score))
    }

    // MARK: - Timeline

    private func addTimelineEvent(type: ConnectionEvent.EventType, detail: String) {
        let event = ConnectionEvent(timestamp: Date(), type: type, detail: detail)
        timeline.append(event)
        if timeline.count > maxTimeline {
            timeline.removeFirst()
        }
    }

    // MARK: - sysctl Network Stats

    private struct InterfaceStats {
        var rxBytes: UInt64
        var txBytes: UInt64
    }

    private func getInterfaceStats() -> InterfaceStats {
        var totalRx: UInt64 = 0
        var totalTx: UInt64 = 0

        var ifap: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifap) == 0, let firstAddr = ifap else {
            return InterfaceStats(rxBytes: 0, txBytes: 0)
        }
        defer { freeifaddrs(ifap) }

        var ptr: UnsafeMutablePointer<ifaddrs> = firstAddr
        while true {
            let flags = ptr.pointee.ifa_flags
            let name = String(cString: ptr.pointee.ifa_name)

            let isUp = (flags & UInt32(IFF_UP)) != 0
            let isLoopback = (flags & UInt32(IFF_LOOPBACK)) != 0
            let isP2P = (flags & UInt32(IFF_POINTOPOINT)) != 0

            if isUp && !isLoopback && !isP2P {
                if let data = ptr.pointee.ifa_data {
                    let ifData = data.assumingMemoryBound(to: if_data.self)
                    totalRx += UInt64(ifData.pointee.ifi_ibytes)
                    totalTx += UInt64(ifData.pointee.ifi_obytes)
                    if cachedInterfaceName.isEmpty {
                        cachedInterfaceName = name
                    }
                }
            }

            guard let next = ptr.pointee.ifa_next else { break }
            ptr = next
        }

        return InterfaceStats(rxBytes: totalRx, txBytes: totalTx)
    }

    // MARK: - Local IP

    private func getLocalIP() -> String {
        var ifap: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifap) == 0, let firstAddr = ifap else { return "" }
        defer { freeifaddrs(ifap) }

        var ptr: UnsafeMutablePointer<ifaddrs> = firstAddr
        while true {
            let flags = ptr.pointee.ifa_flags
            let name = String(cString: ptr.pointee.ifa_name)
            let isUp = (flags & UInt32(IFF_UP)) != 0
            let isLoopback = (flags & UInt32(IFF_LOOPBACK)) != 0

            if isUp && !isLoopback && !cachedInterfaceName.isEmpty && name == cachedInterfaceName {
                let addr = ptr.pointee.ifa_addr
                if addr?.pointee.sa_family == UInt8(AF_INET) {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(addr, socklen_t(addr!.pointee.sa_len), &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST)
                    return String(cString: hostname)
                }
            }

            guard let next = ptr.pointee.ifa_next else { break }
            ptr = next
        }
        return ""
    }

    // MARK: - Wi-Fi RSSI (IOKit)

    private func getWifiRSSI() -> Int? {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IO80211Interface"), &iterator) == KERN_SUCCESS else {
            return nil
        }
        defer { IOObjectRelease(iterator) }

        var service = IOIteratorNext(iterator)
        while service != 0 {
            defer { IOObjectRelease(service) }

            if let rssi = IORegistryEntryCreateCFProperty(service, "RSSI" as CFString, nil, 0)?.takeRetainedValue() as? Int {
                return rssi
            }
            service = IOIteratorNext(iterator)
        }
        return nil
    }

    // MARK: - Intelligence

    private func buildIntelligence() -> NetworkIntelligence {
        let isConnected = currentPath?.status == .satisfied
        let interfaceType: String = {
            guard let iface = currentPath?.availableInterfaces.first else { return "none" }
            switch iface.type {
            case .wifi: return "Wi-Fi"
            case .cellular: return "Cellular"
            case .wiredEthernet: return "Ethernet"
            case .loopback: return "Loopback"
            case .other: return "Other"
            @unknown default: return "Unknown"
            }
        }()

        return NetworkIntelligence(
            download: smoothedDL,
            upload: smoothedUL,
            peakDownload: peakDownload,
            peakUpload: peakUpload,
            sessionDownload: sessionRxBytes,
            sessionUpload: sessionTxBytes,
            todayDownload: todayRxBytes,
            todayUpload: todayTxBytes,
            latency: cachedLatency,
            jitter: cachedJitter,
            packetLoss: cachedPacketLoss,
            healthScore: calculateHealthScore(),
            publicIP: cachedPublicIP,
            localIP: cachedLocalIP,
            ipv6: cachedIPv6,
            wifiRSSI: cachedWifiRSSI,
            interfaceType: interfaceType,
            interfaceName: cachedInterfaceName,
            isConnected: isConnected,
            isVPN: currentPath?.isExpensive ?? false,
            timeline: timeline
        )
    }

    // MARK: - Menu Items

    private func buildMenuItems(from intel: NetworkIntelligence) -> [MenuItem] {
        var items: [MenuItem] = []

        // Section 1: Live Speed
        items.append(MenuItem(
            title: "Live Speed",
            icon: "speedometer",
            order: 0,
            metadata: ["section": "live_speed_header"]
        ))

        items.append(MenuItem(
            title: "↓ \(formatSpeed(intel.download))",
            icon: "arrow.down.circle.fill",
            color: "#34C759",
            order: 1,
            metadata: ["section": "live_speed"]
        ))

        items.append(MenuItem(
            title: "↑ \(formatSpeed(intel.upload))",
            icon: "arrow.up.circle.fill",
            color: "#FF9500",
            order: 2,
            metadata: ["section": "live_speed"]
        ))

        // Section 2: Internet Health
        items.append(MenuItem(title: "", isSeparator: true, order: 5))

        items.append(MenuItem(
            title: "Internet Health",
            icon: "heart.fill",
            order: 10,
            metadata: ["section": "health_header"]
        ))

        let healthColor: String = {
            switch intel.healthScore {
            case 80...100: return "#34C759"
            case 50..<80: return "#FF9500"
            default: return "#FF3B30"
            }
        }()
        let healthLabel: String = {
            switch intel.healthScore {
            case 80...100: return "Excellent"
            case 50..<80: return "Fair"
            default: return "Poor"
            }
        }()
        items.append(MenuItem(
            title: "\(healthLabel) (\(intel.healthScore)/100)",
            icon: "heart.fill",
            color: healthColor,
            order: 11,
            metadata: ["section": "health"]
        ))

        items.append(MenuItem(
            title: "Ping: \(String(format: "%.0f", intel.latency)) ms",
            icon: "clock.fill",
            color: "#007AFF",
            order: 12,
            metadata: ["section": "health"]
        ))

        if intel.jitter > 0 {
            items.append(MenuItem(
                title: "Jitter: \(String(format: "%.1f", intel.jitter)) ms",
                icon: "waveform.path.ecg",
                order: 13,
                metadata: ["section": "health"]
            ))
        }

        if intel.packetLoss > 0 {
            items.append(MenuItem(
                title: "Packet Loss: \(String(format: "%.1f", intel.packetLoss))%",
                icon: "exclamationmark.triangle.fill",
                color: intel.packetLoss > 5 ? "#FF3B30" : "#FF9500",
                order: 14,
                metadata: ["section": "health"]
            ))
        }

        // Section 3: Today Usage
        items.append(MenuItem(title: "", isSeparator: true, order: 15))

        items.append(MenuItem(
            title: "Today Usage",
            icon: "calendar",
            order: 20,
            metadata: ["section": "today_header"]
        ))

        items.append(MenuItem(
            title: "↓ \(formatBytes(intel.todayDownload))  ↑ \(formatBytes(intel.todayUpload))",
            icon: "arrow.triangle.2.circlepath",
            order: 21,
            metadata: ["section": "today"]
        ))

        // Section 4: Session Usage
        items.append(MenuItem(title: "", isSeparator: true, order: 25))

        items.append(MenuItem(
            title: "Session Usage",
            icon: "timer",
            order: 30,
            metadata: ["section": "session_header"]
        ))

        items.append(MenuItem(
            title: "↓ \(formatBytes(intel.sessionDownload))  ↑ \(formatBytes(intel.sessionUpload))",
            icon: "arrow.triangle.2.circlepath",
            order: 31,
            metadata: ["section": "session"]
        ))

        items.append(MenuItem(
            title: "Peak: ↓\(formatSpeed(intel.peakDownload)) ↑\(formatSpeed(intel.peakUpload))",
            icon: "arrow.up.right.and.arrow.down.left",
            order: 32,
            metadata: ["section": "session"]
        ))

        // Section 5: Timeline
        items.append(MenuItem(title: "", isSeparator: true, order: 35))

        items.append(MenuItem(
            title: "Timeline",
            icon: "chart.line.uptrend.xyaxis",
            order: 40,
            metadata: ["section": "timeline_header"]
        ))

        let recentEvents = intel.timeline.suffix(3)
        if recentEvents.isEmpty {
            items.append(MenuItem(
                title: "No events",
                icon: "checkmark.circle",
                color: "#34C759",
                order: 41,
                metadata: ["section": "timeline"]
            ))
        } else {
            for event in recentEvents {
                let icon: String = {
                    switch event.type {
                    case .connected: return "wifi"
                    case .disconnected: return "wifi.slash"
                    case .interfaceChanged: return "arrow.triangle.swap"
                    case .vpnConnected: return "lock.fill"
                    case .vpnDisconnected: return "lock.open"
                    case .speedAlert: return "exclamationmark.triangle.fill"
                    }
                }()
                items.append(MenuItem(
                    title: event.detail,
                    icon: icon,
                    order: 41,
                    metadata: ["section": "timeline"]
                ))
            }
        }

        // Section 6: Diagnostics
        items.append(MenuItem(title: "", isSeparator: true, order: 45))

        items.append(MenuItem(
            title: "Diagnostics",
            icon: "stethoscope",
            order: 50,
            metadata: ["section": "diagnostics_header"]
        ))

        if let ip = intel.publicIP {
            items.append(MenuItem(
                title: "Public IP: \(ip)",
                icon: "globe",
                order: 51,
                metadata: ["section": "diagnostics"]
            ))
        }

        if !intel.localIP.isEmpty {
            items.append(MenuItem(
                title: "Local IP: \(intel.localIP)",
                icon: "network",
                order: 52,
                metadata: ["section": "diagnostics"]
            ))
        }

        if intel.interfaceType == "Wi-Fi" {
            if let rssi = intel.wifiRSSI {
                let signalIcon: String = {
                    if rssi > -50 { return "wifi" }
                    else if rssi > -65 { return "wifi" }
                    else if rssi > -75 { return "wifi" }
                    else { return "wifi.exclamationmark" }
                }()
                items.append(MenuItem(
                    title: "Signal: \(rssi) dBm",
                    icon: signalIcon,
                    order: 53,
                    metadata: ["section": "diagnostics"]
                ))
            }
        }

        items.append(MenuItem(
            title: "Interface: \(intel.interfaceType)",
            icon: "network",
            order: 54,
            metadata: ["section": "diagnostics"]
        ))

        items.append(MenuItem(
            title: "Status: \(intel.isConnected ? "Connected" : "Disconnected")",
            icon: intel.isConnected ? "checkmark.circle.fill" : "xmark.circle.fill",
            color: intel.isConnected ? "#34C759" : "#FF3B30",
            order: 55,
            metadata: ["section": "diagnostics"]
        ))

        // Sections 7 & 8: Quick Actions and Modules are added by other modules

        return items
    }

    // MARK: - Formatting

    func formatSpeed(_ bytesPerSecond: Double) -> String {
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

    func formatSpeedShort(_ bytesPerSecond: Double) -> String {
        let speed = bytesPerSecond
        if speed < 1 {
            return "\u{2014}"
        } else if speed < 1024 {
            return String(format: "%4.0f B", speed)
        } else if speed < 1024 * 1024 {
            let kb = speed / 1024
            return kb < 10 ? String(format: "%5.1f KB", kb) : String(format: "%4.0f KB", kb)
        } else if speed < 1024 * 1024 * 1024 {
            let mb = speed / (1024 * 1024)
            return mb < 10 ? String(format: "%5.1f MB", mb) : String(format: "%4.0f MB", mb)
        } else {
            let gb = speed / (1024 * 1024 * 1024)
            return String(format: "%4.2f GB", gb)
        }
    }

    func formatBytes(_ bytes: UInt64) -> String {
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

    // MARK: - Public IP

    private func fetchPublicIP() async -> String? {
        await withCheckedContinuation { continuation in
            guard let url = URL(string: "https://api.ipify.org?format=json") else {
                continuation.resume(returning: nil)
                return
            }
            let task = URLSession.shared.dataTask(with: url) { data, _, _ in
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let ip = json["ip"] as? String else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: ip)
            }
            task.resume()

            DispatchQueue.global().asyncAfter(deadline: .now() + 5) {
                task.cancel()
            }
        }
    }
}
