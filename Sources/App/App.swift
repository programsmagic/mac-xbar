import AppKit
import SwiftUI

@main
struct mac_xbarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        SettingsWindow()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    var menuEngine: MenuEngine?
    var scheduler: Scheduler?
    var moduleManager: ModuleManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Logger.shared.info("mac-xbar launching")

        menuEngine = MenuEngine()
        menuEngine?.delegate = appDelegate

        scheduler = Scheduler()
        scheduler?.delegate = appDelegate

        moduleManager = ModuleManager()
        Task {
            await moduleManager?.initialize()
            await startModules()
        }

        setupStatusItem()
    }

    func applicationWillTerminate(_ notification: Notification) {
        Logger.shared.info("mac-xbar terminating")
        scheduler?.invalidateAll()
        moduleManager?.invalidateAll()
    }

    private func setupStatusItem() {
        menuEngine?.setTitle("")
        menuEngine?.setIcon(NSImage(systemSymbolName: "terminal", accessibilityDescription: nil))
    }

    private func startModules() async {
        guard let manager = moduleManager else { return }
        registerBuiltInModules(manager: manager)
        for module in manager.registeredModules {
            guard module.config.enabled else { continue }
            do {
                try await module.initialize()
                scheduler?.schedule(
                    moduleID: module.id,
                    interval: module.config.refreshInterval
                ) { [weak module] in
                    Task {
                        do {
                            let output = try await module?.refresh() ?? ModuleOutput(source: module?.id ?? "")
                            Renderer.shared.render(output: output)
                        } catch {
                            Renderer.shared.render(error: error, for: module?.id ?? "")
                        }
                    }
                }
            } catch {
                Logger.shared.error("Failed to initialize module \(module.id): \(error.localizedDescription)")
            }
        }
        PerformanceModule.shared.recordStartup()
    }

    private func registerBuiltInModules(manager: ModuleManager) {
        manager.register(NetworkModule())
        manager.register(SystemModule())
        manager.register(DeveloperModule())
        manager.register(ProductivityModule())
        Logger.shared.info("All built-in modules registered")
    }
}

extension AppDelegate: MenuEngineDelegate {
    func menuEngine(_ engine: MenuEngine, didSelectItem item: MenuItem) {
        guard let action = item.action else { return }
        handleAction(action)
    }

    func menuEngineWillOpen(_ engine: MenuEngine) {
        Task {
            await refreshAllModules()
        }
    }

    func menuEngineDidClose(_ engine: MenuEngine) {}

    private func handleAction(_ action: MenuItemAction) {
        switch action {
        case .url(let urlString):
            if let url = URL(string: urlString) {
                NSWorkspace.shared.open(url)
            }
        case .shell(let command):
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/bin/sh")
            task.arguments = ["-c", command]
            try? task.run()
        case .refresh:
            Task { await refreshAllModules() }
        case .toggle(let moduleID):
            moduleManager?.toggleModule(moduleID)
        case .custom(let identifier):
            moduleManager?.executeCustomAction(identifier)
        case .none:
            break
        }
    }

    private func refreshAllModules() async {
        guard let manager = moduleManager else { return }
        for module in manager.registeredModules {
            guard module.config.enabled else { continue }
            do {
                let output = try await module.refresh()
                Renderer.shared.render(output: output)
            } catch {
                Renderer.shared.render(error: error, for: module.id)
            }
        }
        menuEngine?.update(items: collectAllMenuItems())
    }

    private func collectAllMenuItems() -> [MenuItem] {
        guard let manager = moduleManager else { return [] }
        return manager.registeredModules
            .filter { $0.config.enabled }
            .flatMap { module in
                guard let output = try? module.refresh() else { return [] }
                return output.items
            }
            .sorted { $0.order < $1.order }
    }
}

final class SettingsWindow: Scene {
    var body: some Scene {
        Window("mac-xbar Settings", id: "settings") {
            PreferencesView()
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 400, height: 500)
    }
}