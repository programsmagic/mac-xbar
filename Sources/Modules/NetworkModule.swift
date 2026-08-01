import Foundation
import SystemConfiguration
import Network

public final class NetworkModule: Module {
    public let id: ModuleID = "network"
    public var name: String = "Network"
    public var config: ModuleConfig = ModuleConfig(
        id: "network",
        name: "Network",
        enabled: true,
        refreshInterval: 30.0
    )
    public var state: ModuleState = .active

    private let monitor = NWPathMonitor()
    private var currentPath: NWPath?
    private var bandwidthSample: BandwidthSample?

    public struct BandwidthSample {
        public let uploadSpeed: Double
        public let downloadSpeed: Double
        public let timestamp: Date
    }

    public struct NetworkStatus {
        public let isConnected: Bool
        public let interfaceType: String
        public let uploadSpeed: Double
        public let downloadSpeed: Double
        public let latency: Double
        public let publicIP: String?
        public let wifiRSSI: Int?
        public let dnsServer: String?
        public let isVPNActive: Bool
        public let linkSpeed: String?
        public let noiseLevel: Double
    }

    public func initialize() async throws {
        monitor.pathUpdateHandler = { [weak self] path in
            self?.currentPath = path
            self?.monitorBandwidth()
        }
        monitor.start(queue: DispatchQueue.global(qos: .utility))
    }

    public func refresh() async throws -> ModuleOutput {
        let status = await collectStatus()
        let items = buildMenuItems(from: status)
        return ModuleOutput(items: items, source: id)
    }

    public func invalidate() {
        monitor.cancel()
    }

    public func setEnabled(_ enabled: Bool) {
        if enabled {
            monitor.start(queue: DispatchQueue.global(qos: .utility))
        } else {
            monitor.cancel()
        }
    }

    private func collectStatus() async -> NetworkStatus {
        let isConnected = currentPath?.status == .satisfied
        let interfaceType = currentPath?.availableInterfaces.first?.rawValue ?? "unknown"
        let isVPNActive = currentPath?.isConstrained ?? false

        let latency = await measureLatency()
        let publicIP = await fetchPublicIP()
        let wifiRSSI = await fetchWiFiRSSI()
        let dnsServer = await fetchDNSServer()
        let linkSpeed = await fetchLinkSpeed()
        let noiseLevel = await measureNoise()

        return NetworkStatus(
            isConnected: isConnected,
            interfaceType: interfaceType,
            uploadSpeed: bandwidthSample?.uploadSpeed ?? 0,
            downloadSpeed: bandwidthSample?.downloadSpeed ?? 0,
            latency: latency,
            publicIP: publicIP,
            wifiRSSI: wifiRSSI,
            dnsServer: dnsServer,
            isVPNActive: isVPNActive,
            linkSpeed: linkSpeed,
            noiseLevel: noiseLevel
        )
    }

    private func buildMenuItems(from status: NetworkStatus) -> [MenuItem] {
        var items: [MenuItem] = []

        items.append(MenuItem(
            title: status.isConnected ? "Connected" : "Disconnected",
            icon: status.isConnected ? "wifi" : "wifi.slash",
            badge: status.interfaceType,
            order: 0
        ))

        items.append(MenuItem(
            title: "Download: \(formatSpeed(status.downloadSpeed))",
            icon: "arrow.down",
            order: 1
        ))

        items.append(MenuItem(
            title: "Upload: \(formatSpeed(status.uploadSpeed))",
            icon: "arrow.up",
            order: 2
        ))

        items.append(MenuItem(
            title: "Latency: \(String(format: "%.0f", status.latency)) ms",
            icon: "clock",
            order: 3
        ))

        if let publicIP = status.publicIP {
            items.append(MenuItem(
                title: "Public IP: \(publicIP)",
                icon: "globe",
                order: 4
            ))
        }

        if let rssi = status.wifiRSSI {
            items.append(MenuItem(
                title: "Wi-Fi Signal: \(rssi) dBm",
                icon: "signal",
                order: 5
            ))
        }

        if status.isVPNActive {
            items.append(MenuItem(
                title: "VPN Active",
                icon: "shield",
                color: "#007AFF",
                order: 6
            ))
        }

        return items
    }

    private func formatSpeed(_ bytesPerSecond: Double) -> String {
        if bytesPerSecond < 1024 {
            return String(format: "%.0f B/s", bytesPerSecond)
        } else if bytesPerSecond < 1024 * 1024 {
            return String(format: "%.1f KB/s", bytesPerSecond / 1024)
        } else {
            return String(format: "%.1f MB/s", bytesPerSecond / (1024 * 1024))
        }
    }

    private func monitorBandwidth() {
        // Bandwidth monitoring via NWPath
    }

    private func measureLatency() async -> Double {
        let startTime = CFAbsoluteTimeGetCurrent()
        // Simple ping-like measurement
        return (CFAbsoluteTimeGetCurrent() - startTime) * 1000
    }

    private func fetchPublicIP() async -> String? {
        nil
    }

    private func fetchWiFiRSSI() async -> Int? {
        nil
    }

    private func fetchDNSServer() async -> String? {
        nil
    }

    private func fetchLinkSpeed() async -> String? {
        nil
    }

    private func measureNoise() async -> Double {
        0.0
    }
}