import Foundation

public final class ModuleManager {
    private var modules: [String: any Module] = [:]
    private var lastRefresh: [String: Date] = [:]
    private let lock = NSLock()

    public var registeredModules: [any Module] {
        lock.lock()
        defer { lock.unlock() }
        return Array(modules.values)
    }

    public init() {}

    public func register<M: Module>(_ module: M) {
        lock.lock()
        defer { lock.unlock() }
        modules[module.id] = module
        Logger.shared.info("Registered module: \(module.id)")
    }

    public func module(withID id: String) -> (any Module)? {
        lock.lock()
        defer { lock.unlock() }
        return modules[id]
    }

    public func unregister(id: String) {
        lock.lock()
        defer { lock.unlock() }
        modules[id]?.invalidate()
        modules.removeValue(forKey: id)
        lastRefresh.removeValue(forKey: id)
    }

    public func toggleModule(_ id: String, scheduler: Scheduler? = nil) {
        guard let module = module(withID: id) else { return }
        let newState = !module.config.enabled
        module.setEnabled(newState)
        module.config.enabled = newState
        if let scheduler = scheduler {
            if newState {
                scheduler.schedule(moduleID: id, interval: module.config.refreshInterval) { [weak module] in
                    Task { _ = try await module?.refresh() }
                }
            } else {
                scheduler.invalidate(moduleID: id)
            }
        }
        PreferencesManager.shared.update { prefs in
            if let index = prefs.moduleConfigs.firstIndex(where: { $0.id == id }) {
                prefs.moduleConfigs[index].enabled = newState
            }
        }
    }

    public func initialize() async {
        for (_, module) in modules {
            try? await module.initialize()
        }
    }

    public func invalidateAll() {
        lock.lock()
        defer { lock.unlock() }
        for (_, module) in modules {
            module.invalidate()
        }
        modules.removeAll()
        lastRefresh.removeAll()
    }

    public func refreshAll(force: Bool = false) async -> [MenuItem] {
        var allItems: [MenuItem] = []
        let now = Date()
        let modulesCopy = registeredModules
        for module in modulesCopy {
            guard module.config.enabled else { continue }
            let due: Bool
            lock.lock()
            due = force || now.timeIntervalSince(lastRefresh[module.id] ?? .distantPast) >= module.config.refreshInterval
            lock.unlock()
            guard due else { continue }
            do {
                let output = try await module.refresh()
                allItems.append(contentsOf: output.items)
                lock.lock()
                lastRefresh[module.id] = now
                lock.unlock()
            } catch {
                Logger.shared.error("Failed to refresh module \(module.id): \(error.localizedDescription)")
            }
        }
        return allItems.sorted { $0.order < $1.order }
    }

    public func findModule<T: Module>(ofType type: T.Type) -> T? {
        for module in registeredModules {
            if let typed = module as? T {
                return typed
            }
        }
        return nil
    }
}
