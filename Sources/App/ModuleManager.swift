import Foundation

public final class ModuleManager {
    public static let shared = ModuleManager()

    private var modules: [String: any Module] = [:]
    private let lock = NSLock()

    public var registeredModules: [any Module] {
        lock.lock()
        defer { lock.unlock() }
        return Array(modules.values)
    }

    public func register<M: Module>(_ module: M) {
        lock.lock()
        defer { lock.unlock() }
        modules[module.id] = module
        Logger.shared.info("Registered module: \(module.id)")
    }

    public func module(withID id: String) -> any Module? {
        lock.lock()
        defer { lock.unlock() }
        return modules[id]
    }

    public func unregister(id: String) {
        lock.lock()
        defer { lock.unlock() }
        modules[id]?.invalidate()
        modules.removeValue(forKey: id)
    }

    public func toggleModule(_ id: String) {
        guard let module = module(withID: id) else { return }
        let newState = !module.config.enabled
        module.setEnabled(newState)
        module.config.enabled = newState
        try? PreferencesManager.shared.update { prefs in
            if let index = prefs.moduleConfigs.firstIndex(where: { $0.id == id }) {
                prefs.moduleConfigs[index].enabled = newState
            }
        }
    }

    public func executeCustomAction(_ identifier: String) {
        Logger.shared.info("Executing custom action: \(identifier)")
    }

    public func invalidateAll() {
        lock.lock()
        defer { lock.unlock() }
        for (_, module) in modules {
            module.invalidate()
        }
        modules.removeAll()
    }

    public func refreshAll() async {
        for module in registeredModules {
            guard module.config.enabled else { continue }
            do {
                let output = try await module.refresh()
                Renderer.shared.render(output: output)
            } catch {
                Renderer.shared.render(error: error, for: module.id)
            }
        }
    }
}