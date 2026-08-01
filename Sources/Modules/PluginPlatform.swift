import Foundation

public protocol Plugin: AnyObject, Identifiable {
    associatedtype ID: Hashable = String

    var id: ID { get }
    var name: String { get }
    var version: String { get }
    var type: PluginType { get }
    var sandboxed: Bool { get }
    var signed: Bool { get }
    var permissions: [PluginPermission] { get }
    var state: PluginState { get }

    func execute() async throws -> PluginOutput
    func reload() async throws
    func uninstall() async throws
}

public enum PluginType: String, Codable, CaseIterable {
    case nativeSwift
    case script
    case binary
}

public enum PluginState: Codable {
    case installed
    case enabled
    case disabled
    case error(String)
}

public enum PluginPermission: String, Codable, CaseIterable {
    case network
    case filesystem
    case shell
    case clipboard
    case keyboard
    case accessibility
    case camera
    case microphone
}

public struct PluginOutput: Equatable {
    public let items: [MenuItem]
    public let error: Error?
    public let timestamp: Date

    public init(items: [MenuItem] = [], error: Error? = nil) {
        self.items = items
        self.error = error
        self.timestamp = Date()
    }
}

public final class PluginRuntime {
    public static let shared = PluginRuntime()

    private var plugins: [String: any Plugin] = [:]
    private let lock = NSLock()

    public var registeredPlugins: [any Plugin] {
        lock.lock()
        defer { lock.unlock() }
        return Array(plugins.values)
    }

    public func register<P: Plugin>(_ plugin: P) {
        lock.lock()
        defer { lock.unlock() }
        plugins[plugin.id] = plugin
    }

    public func unregister(id: String) {
        lock.lock()
        defer { lock.unlock() }
        plugins.removeValue(forKey: id)
    }

    public func plugin(withID id: String) -> any Plugin? {
        lock.lock()
        defer { lock.unlock() }
        return plugins[id]
    }

    public func executePlugin(id: String) async throws -> PluginOutput {
        guard let plugin = plugin(withID: id) else {
            throw MacXbarError.moduleNotFound(id)
        }
        return try await plugin.execute()
    }

    public func reloadPlugin(id: String) async throws {
        guard let plugin = plugin(withID: id) else {
            throw MacXbarError.moduleNotFound(id)
        }
        try await plugin.reload()
    }

    public func enablePlugin(id: String) {
        guard let plugin = plugin(withID: id) else { return }
        // Plugin state management
    }

    public func disablePlugin(id: String) {
        guard let plugin = plugin(withID: id) else { return }
        // Plugin state management
    }

    public func validatePermissions(_ plugin: any Plugin) -> [PluginPermission] {
        plugin.permissions
    }

    public func checkSandboxCompliance(_ plugin: any Plugin) -> Bool {
        plugin.sandboxed
    }

    public func checkSignature(_ plugin: any Plugin) -> Bool {
        plugin.signed
    }
}