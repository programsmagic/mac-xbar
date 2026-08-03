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
final class AppDelegate: NSObject, NSApplicationDelegate, SchedulerDelegate {
    var menuEngine: MenuEngine?
    var scheduler: Scheduler?
    var moduleManager: ModuleManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Logger.shared.info("mac-xbar launching")

        menuEngine = MenuEngine()
        menuEngine?.delegate = self

        scheduler = Scheduler()
        scheduler?.delegate = self

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

    nonisolated func scheduler(_ scheduler: Scheduler, didFireForModule moduleID: String) {
        Task { await refreshAllModules() }
    }

    nonisolated func schedulerDidTick(_ scheduler: Scheduler) {
        Task { await refreshAllModules() }
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

@MainActor
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
        var networkSpeed: (download: String, upload: String)?
        for module in manager.registeredModules {
            guard module.config.enabled else { continue }
            do {
                let output = try await module.refresh()
                Renderer.shared.render(output: output)
                if module.id == "network" {
                    networkSpeed = extractNetworkSpeed(from: output.items)
                }
            } catch {
                Renderer.shared.render(error: error, for: module.id)
            }
        }
        if let speed = networkSpeed {
            menuEngine?.setTitle("↓\(speed.download) ↑\(speed.upload)")
        }
        menuEngine?.update(items: await collectAllMenuItems())
    }

    private func extractNetworkSpeed(from items: [MenuItem]) -> (String, String)? {
        var download: String?
        var upload: String?
        for item in items {
            if item.title.hasPrefix("↓") {
                download = item.title.dropFirst().trimmingCharacters(in: .whitespaces)
            } else if item.title.hasPrefix("↑") {
                upload = item.title.dropFirst().trimmingCharacters(in: .whitespaces)
            }
        }
        guard let dl = download, let ul = upload else { return nil }
        return (dl, ul)
    }

    private func collectAllMenuItems() async -> [MenuItem] {
        guard let manager = moduleManager else { return [] }
        var allItems: [MenuItem] = []
        for module in manager.registeredModules {
            guard module.config.enabled else { continue }
            do {
                let output = try await module.refresh()
                allItems.append(contentsOf: output.items)
            } catch {
                continue
            }
        }
        return allItems.sorted { $0.order < $1.order }
    }
}

struct SettingsWindow: Scene {
    var body: some Scene {
        Window("mac-xbar Settings", id: "settings") {
            PreferencesView()
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 400, height: 500)
    }
}