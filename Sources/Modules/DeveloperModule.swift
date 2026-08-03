import Foundation
import AppKit

public final class DeveloperModule: Module {
    public let id: ModuleID = "developer"
    public var name: String = "Developer"
    public var config: ModuleConfig = ModuleConfig(
        id: "developer",
        name: "Developer",
        enabled: true,
        refreshInterval: 120.0
    )
    public var state: ModuleState = .active

    public struct DeveloperStatus {
        public let gitBranch: String?
        public let gitStatus: String?
        public let dockerStatus: String?
        public let kubernetesContext: String?
        public let vpnActive: Bool
        public let localServers: [LocalServer]
        public let clipboardHistory: [String]
        public let jsonFormatterAvailable: Bool
        public let uuid: String
    }

    public struct LocalServer {
        public let name: String
        public let port: Int
        public let status: String
    }

    public func initialize() async throws {
        // Developer module initialization
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

    private func collectStatus() async -> DeveloperStatus {
        let gitInfo = await fetchGitInfo()
        let dockerInfo = await fetchDockerStatus()
        let k8sInfo = await fetchKubernetesContext()
        let vpnInfo = await detectVPN()
        let servers = await scanLocalServers()
        let clipboard = fetchClipboardHistory()
        let uuid = generateUUID()

        return DeveloperStatus(
            gitBranch: gitInfo.branch,
            gitStatus: gitInfo.status,
            dockerStatus: dockerInfo,
            kubernetesContext: k8sInfo,
            vpnActive: vpnInfo,
            localServers: servers,
            clipboardHistory: clipboard,
            jsonFormatterAvailable: true,
            uuid: uuid
        )
    }

    private func buildMenuItems(from status: DeveloperStatus) -> [MenuItem] {
        var items: [MenuItem] = []

        if let branch = status.gitBranch {
            items.append(MenuItem(
                title: "Git: \(branch)",
                icon: "branch",
                badge: status.gitStatus,
                order: 0
            ))
        }

        items.append(MenuItem(
            title: "Docker: \(status.dockerStatus ?? "Not running")",
            icon: "shippingbox",
            color: status.dockerStatus != nil ? "#2496ED" : nil,
            order: 1
        ))

        if let k8s = status.kubernetesContext {
            items.append(MenuItem(
                title: "K8s: \(k8s)",
                icon: "cloud",
                order: 2
            ))
        }

        if status.vpnActive {
            items.append(MenuItem(
                title: "VPN Active",
                icon: "shield",
                color: "#007AFF",
                order: 3
            ))
        }

        for server in status.localServers {
            items.append(MenuItem(
                title: "\(server.name):\(server.port) - \(server.status)",
                icon: "server.rack",
                color: server.status == "up" ? "#34C759" : "#FF3B30",
                order: 4 + (status.localServers.firstIndex(where: { $0.name == server.name }) ?? 0)
            ))
        }

        items.append(MenuItem(
            title: "UUID: \(status.uuid.prefix(8))...",
            icon: "key",
            order: 99
        ))

        return items
    }

    private func fetchGitInfo() async -> (branch: String?, status: String?) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        task.arguments = ["rev-parse", "--abbrev-ref", "HEAD"]
        let pipe = Pipe()
        task.standardOutput = pipe
        do {
            try task.run()
            task.waitUntilExit()
            let output = pipe.fileHandleForReading.readDataToEndOfFile()
            let branch = String(data: output, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            return (branch, nil)
        } catch {
            return (nil, nil)
        }
    }

    private func fetchDockerStatus() async -> String? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/docker")
        task.arguments = ["info", "--format", "{{.ServerVersion}}"]
        let pipe = Pipe()
        task.standardOutput = pipe
        do {
            try task.run()
            task.waitUntilExit()
            let output = pipe.fileHandleForReading.readDataToEndOfFile()
            let version = String(data: output, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            return version
        } catch {
            return nil
        }
    }

    private func fetchKubernetesContext() async -> String? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/local/bin/kubectl")
        task.arguments = ["config", "current-context"]
        let pipe = Pipe()
        task.standardOutput = pipe
        do {
            try task.run()
            task.waitUntilExit()
            let output = pipe.fileHandleForReading.readDataToEndOfFile()
            let context = String(data: output, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            return context
        } catch {
            return nil
        }
    }

    private func detectVPN() async -> Bool {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/sbin/ifconfig")
        task.arguments = ["-l"]
        let pipe = Pipe()
        task.standardOutput = pipe
        do {
            try task.run()
            task.waitUntilExit()
            let output = pipe.fileHandleForReading.readDataToEndOfFile()
            let interfaces = String(data: output, encoding: .utf8)?.components(separatedBy: .whitespaces) ?? []
            return interfaces.contains { $0.hasPrefix("utun") || $0.hasPrefix("ppp") }
        } catch {
            return false
        }
    }

    private func scanLocalServers() async -> [LocalServer] {
        var servers: [LocalServer] = []
        let commonPorts = [3000, 8080, 8000, 5000, 9000, 3001, 8888, 4000]
        for port in commonPorts {
            let socket = socket(AF_INET, SOCK_STREAM, 0)
            var addr = sockaddr_in()
            addr.sin_len = __uint8_t(MemoryLayout<sockaddr_in>.size)
            addr.sin_family = sa_family_t(AF_INET)
            addr.sin_port = in_port_t(port).bigEndian
            addr.sin_addr.s_addr = inet_addr("127.0.0.1")
            let result = withUnsafePointer(to: &addr) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    connect(socket, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
            if result == 0 {
                servers.append(LocalServer(name: "localhost", port: port, status: "up"))
            }
            close(socket)
        }
        return servers
    }

    private func fetchClipboardHistory() -> [String] {
        return []
    }

    private func generateUUID() -> String {
        UUID().uuidString
    }
}