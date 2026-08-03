import Foundation
import SystemConfiguration
import Network

public protocol NetworkSpeedObserver: AnyObject {
    func networkModule(_ module: NetworkModule, didUpdateSpeed download: Double, upload: Double, downloadFormatted: String, uploadFormatted: String)
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

    private var previousRxBytes: UInt64 = 0
    private var previousTxBytes: UInt64 = 0
    private var previousSpeedTimestamp: Date = Date()
    private var sessionRxBytes: UInt64 = 0
    private var sessionTxBytes: UInt64 = 0

    private var cachedLatency: Double = 0
    private var cachedPublicIP: String?
    private var cachedInterfaceName: String = ""

    public struct BandwidthSample {
        public let uploadSpeed: Double
        public let downloadSpeed: Double
        public let timestamp: Date
    }

    public struct NetworkStatus {
        public let isConnected: Bool
        public let interfaceType: String
        public let interfaceName: String
        public let uploadSpeed: Double
        public let downloadSpeed: Double
        public let latency: Double
        public let publicIP: String?
        public let isVPNActive: Bool
        public let sessionDownloaded: UInt64
        public let sessionUploaded: UInt64
    }

    public func initialize() async throws {
        monitor.pathUpdateHandler = { [weak self] path in
            self?.currentPath = path
        }
        monitor.start(queue: DispatchQueue.global(qos: .utility))

        let initial = getInterfaceStats()
        previousRxBytes = initial.rxBytes
        previousTxBytes = initial.txBytes
        previousSpeedTimestamp = Date()

        startSpeedTimer()
        startLatencyPolling()
    }

    public func refresh() async throws -> ModuleOutput {
        let status = buildStatus()
        let items = buildMenuItems(from: status)
        return ModuleOutput(items: items, source: id)
    }

    public func invalidate() {
        monitor.cancel()
        speedTimer?.cancel()
        speedTimer = nil
        latencyTimer?.cancel()
        latencyTimer = nil
    }

    public func setEnabled(_ enabled: Bool) {
        if enabled {
            monitor.start(queue: DispatchQueue.global(qos: .utility))
            startSpeedTimer()
        } else {
            monitor.cancel()
            speedTimer?.cancel()
            speedTimer = nil
            latencyTimer?.cancel()
            latencyTimer = nil
        }
    }

    // MARK: - Speed Timer (1-second)

    private func startSpeedTimer() {
        guard speedTimer == nil else { return }
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .utility))
        timer.schedule(deadline: .now(), repeating: 1.0)
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

        sessionRxBytes += rxDelta
        sessionTxBytes += txDelta

        previousRxBytes = stats.rxBytes
        previousTxBytes = stats.txBytes
        previousSpeedTimestamp = now

        let dlFormatted = formatSpeedShort(dlSpeed)
        let ulFormatted = formatSpeedShort(ulSpeed)

        speedObserver?.networkModule(self, didUpdateSpeed: dlSpeed, upload: ulSpeed, downloadFormatted: dlFormatted, uploadFormatted: ulFormatted)
    }

    // MARK: - Latency Polling (every 5 seconds)

    private func startLatencyPolling() {
        guard latencyTimer == nil else { return }
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .utility))
        timer.schedule(deadline: .now(), repeating: 5.0)
        timer.setEventHandler { [weak self] in
            Task { [weak self] in
                guard let self = self else { return }
                self.cachedLatency = await self.measureLatency()
            }
        }
        timer.resume()
        latencyTimer = timer

        Task { [weak self] in
            guard let self = self else { return }
            self.cachedLatency = await self.measureLatency()
            self.cachedPublicIP = await self.fetchPublicIP()
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

    // MARK: - Status

    private func buildStatus() -> NetworkStatus {
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

        let stats = getInterfaceStats()
        let elapsed = Date().timeIntervalSince(previousSpeedTimestamp)
        let dlSpeed = elapsed > 0 ? Double(Int64(stats.rxBytes) &- Int64(previousRxBytes)) / elapsed : 0
        let ulSpeed = elapsed > 0 ? Double(Int64(stats.txBytes) &- Int64(previousTxBytes)) / elapsed : 0

        return NetworkStatus(
            isConnected: isConnected,
            interfaceType: interfaceType,
            interfaceName: cachedInterfaceName,
            uploadSpeed: ulSpeed,
            downloadSpeed: dlSpeed,
            latency: cachedLatency,
            publicIP: cachedPublicIP,
            isVPNActive: currentPath?.isConstrained ?? false,
            sessionDownloaded: sessionRxBytes,
            sessionUploaded: sessionTxBytes
        )
    }

    // MARK: - Menu Items

    private func buildMenuItems(from status: NetworkStatus) -> [MenuItem] {
        var items: [MenuItem] = []

        items.append(MenuItem(
            title: status.isConnected ? "Connected" : "Disconnected",
            icon: status.isConnected ? "wifi" : "wifi.slash",
            badge: status.interfaceType,
            order: 0,
            metadata: ["section": "network_header"]
        ))

        items.append(MenuItem(
            title: "Download: \(formatSpeed(status.downloadSpeed))",
            icon: "arrow.down.circle.fill",
            color: "#34C759",
            order: 10,
            metadata: ["section": "network_speed", "direction": "download"]
        ))

        items.append(MenuItem(
            title: "Upload: \(formatSpeed(status.uploadSpeed))",
            icon: "arrow.up.circle.fill",
            color: "#FF9500",
            order: 11,
            metadata: ["section": "network_speed", "direction": "upload"]
        ))

        items.append(MenuItem(title: "", isSeparator: true, order: 20))

        items.append(MenuItem(
            title: "Latency: \(String(format: "%.0f", status.latency)) ms",
            icon: "clock.fill",
            color: "#007AFF",
            order: 30,
            metadata: ["section": "network_detail"]
        ))

        if let ip = status.publicIP {
            items.append(MenuItem(
                title: "Public IP: \(ip)",
                icon: "globe",
                order: 40,
                metadata: ["section": "network_detail"]
            ))
        }

        items.append(MenuItem(title: "", isSeparator: true, order: 60))

        items.append(MenuItem(
            title: "Session: ↓\(formatBytes(status.sessionDownloaded)) ↑\(formatBytes(status.sessionUploaded))",
            icon: "arrow.triangle.2.circlepath",
            order: 70,
            metadata: ["section": "network_session"]
        ))

        return items
    }

    // MARK: - Formatting

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

    func formatSpeedShort(_ bytesPerSecond: Double) -> String {
        if bytesPerSecond < 1024 {
            return String(format: "%.0fB", bytesPerSecond)
        } else if bytesPerSecond < 1024 * 1024 {
            return String(format: "%.1fK", bytesPerSecond / 1024)
        } else if bytesPerSecond < 1024 * 1024 * 1024 {
            return String(format: "%.1fM", bytesPerSecond / (1024 * 1024))
        } else {
            return String(format: "%.2fG", bytesPerSecond / (1024 * 1024 * 1024))
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

    // MARK: - Latency (real TCP connect)

    private func measureLatency() async -> Double {
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
