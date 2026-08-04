import Foundation
import Network
import AppKit

public final class QuickActionsModule: Module {
    public let id: ModuleID = "quick_actions"
    public var name: String = "Quick Actions"
    public var config: ModuleConfig = ModuleConfig(
        id: "quick_actions",
        name: "Quick Actions",
        enabled: true,
        refreshInterval: 300.0
    )
    public var state: ModuleState = .active

    private var isSpeedTestRunning = false
    public private(set) var lastKnownPublicIP: String?

    public var isRunningSpeedTest: Bool { isSpeedTestRunning }

    public func initialize() async throws {}

    public func refresh() async throws -> ModuleOutput {
        let items = buildMenuItems()
        return ModuleOutput(items: items, source: id)
    }

    public func invalidate() {}

    public func setEnabled(_ enabled: Bool) {}

    public func executeAction(_ action: QuickAction) async {
        switch action {
        case .speedTest:
            await runSpeedTest()
        case .flushDNS:
            flushDNS()
        case .restartWiFi:
            restartWiFi()
        case .copyIP:
            await copyPublicIP()
        case .openRouter:
            openRouter()
        case .exportReport:
            exportReport()
        }
    }

    // MARK: - Actions

    private func runSpeedTest() async {
        isSpeedTestRunning = true
        defer { isSpeedTestRunning = false }

        let host = NWEndpoint.Host("speed.cloudflare.com")
        let port = NWEndpoint.Port("443")!
        let connection = NWConnection(host: host, port: port, using: .tls)

        let start = CFAbsoluteTimeGetCurrent()

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            nonisolated(unsafe) var completed = false

            connection.stateUpdateHandler = { state in
                guard !completed else { return }
                switch state {
                case .ready:
                    completed = true
                    let latency = (CFAbsoluteTimeGetCurrent() - start) * 1000
                    connection.cancel()
                    Task { @MainActor in
                        self.showNotification(title: "Speed Test Complete", body: "Latency: \(String(format: "%.0f", latency)) ms")
                    }
                    continuation.resume()
                case .failed:
                    if !completed {
                        completed = true
                        Task { @MainActor in
                            self.showNotification(title: "Speed Test Failed", body: "Could not connect to test server")
                        }
                        continuation.resume()
                    }
                default:
                    break
                }
            }

            connection.start(queue: .global())

            DispatchQueue.global().asyncAfter(deadline: .now() + 10) {
                if !completed {
                    completed = true
                    connection.cancel()
                    Task { @MainActor in
                        self.showNotification(title: "Speed Test Timeout", body: "Test timed out after 10 seconds")
                    }
                    continuation.resume()
                }
            }
        }
    }

    private func flushDNS() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c", "dscacheutil -flushcache && sudo killall -HUP mDNSResponder"]
        try? task.run()

        showNotification(title: "DNS Flushed", body: "DNS cache has been cleared")
    }

    private func restartWiFi() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c", "networksetup -setairportpower en0 off && sleep 2 && networksetup -setairportpower en0 on"]
        try? task.run()

        showNotification(title: "Wi-Fi Restarted", body: "Wi-Fi has been toggled off and on")
    }

    private func copyPublicIP() async {
        guard let url = URL(string: "https://api.ipify.org?format=json") else { return }

        if let (data, _) = try? await URLSession.shared.data(from: url),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let ip = json["ip"] as? String {
            lastKnownPublicIP = ip
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(ip, forType: .string)
            showNotification(title: "IP Copied", body: "Public IP \(ip) copied to clipboard")
        }
    }

    private func openRouter() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c", "route -n get default | grep gateway | awk '{print $2}'"]
        let pipe = Pipe()
        task.standardOutput = pipe
        try? task.run()
        task.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let gw = String(data: data, encoding: .utf8) {
            let gateway = gw.trimmingCharacters(in: .whitespacesAndNewlines)
            if let url = URL(string: "http://\(gateway)") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    private func exportReport() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "mac-xbar-report-\(formatDate(Date())).json"
        panel.begin { result in
            guard result == .OK, let url = panel.url else { return }

        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "3.0.0"
        let report: [String: Any] = [
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "version": appVersion,
                "modules": [
                    "network": PreferencesManager.shared.networkStats.downloadSpeed,
                    "uptime": ProcessInfo.processInfo.systemUptime
                ]
            ]

            if let data = try? JSONSerialization.data(withJSONObject: report, options: .prettyPrinted) {
                try? data.write(to: url)
            }
        }
    }

    private func showNotification(title: String, body: String) {
        let notification = NSUserNotification()
        notification.title = title
        notification.informativeText = body
        notification.soundName = nil
        NSUserNotificationCenter.default.deliver(notification)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func buildMenuItems() -> [MenuItem] {
        var items: [MenuItem] = []

        items.append(MenuItem(title: "", isSeparator: true, order: 55))

        items.append(MenuItem(
            title: "Quick Actions",
            icon: "bolt.fill",
            order: 60,
            metadata: ["section": "actions_header"]
        ))

        items.append(MenuItem(
            title: isSpeedTestRunning ? "Running Speed Test..." : "Run Speed Test",
            icon: "speedometer",
            action: .custom("speedTest"),
            order: 61,
            metadata: ["section": "action"]
        ))

        items.append(MenuItem(
            title: "Flush DNS Cache",
            icon: "trash",
            action: .custom("flushDNS"),
            order: 62,
            metadata: ["section": "action"]
        ))

        items.append(MenuItem(
            title: "Restart Wi-Fi",
            icon: "wifi",
            action: .custom("restartWiFi"),
            order: 63,
            metadata: ["section": "action"]
        ))

        items.append(MenuItem(
            title: "Copy Public IP",
            icon: "doc.on.doc",
            action: .custom("copyIP"),
            order: 64,
            metadata: ["section": "action"]
        ))

        items.append(MenuItem(
            title: "Open Router Admin",
            icon: "network",
            action: .custom("openRouter"),
            order: 65,
            metadata: ["section": "action"]
        ))

        items.append(MenuItem(
            title: "Export Report",
            icon: "square.and.arrow.up",
            action: .custom("exportReport"),
            order: 66,
            metadata: ["section": "action"]
        ))

        return items
    }
}

public enum QuickAction: String, CaseIterable {
    case speedTest
    case flushDNS
    case restartWiFi
    case copyIP
    case openRouter
    case exportReport
}
