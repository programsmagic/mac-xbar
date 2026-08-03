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
    private var networkModule: NetworkModule?

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
        Task { @MainActor in
            await refreshModule(moduleID)
        }
    }

    nonisolated func schedulerDidTick(_ scheduler: Scheduler) {
        Task { @MainActor in
            await refreshAllModules()
        }
    }

    private func setupStatusItem() {
        menuEngine?.theme = PreferencesManager.shared.preferences.theme
        menuEngine?.density = PreferencesManager.shared.preferences.density
        menuEngine?.fixedWidth = PreferencesManager.shared.preferences.fixedWidth
        menuEngine?.setIcon(NSImage(systemSymbolName: "network", accessibilityDescription: nil))
        menuEngine?.setTitle("")
    }

    private func syncPreferences() {
        let prefs = PreferencesManager.shared.preferences
        menuEngine?.theme = prefs.theme
        menuEngine?.density = prefs.density
        menuEngine?.fixedWidth = prefs.fixedWidth
    }

    private func startModules() async {
        guard let manager = moduleManager else { return }
        registerBuiltInModules(manager: manager)
        for module in manager.registeredModules {
            guard module.config.enabled else { continue }
            do {
                try await module.initialize()
                if let net = module as? NetworkModule {
                    networkModule = net
                    net.speedObserver = self
                }
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

// MARK: - MenuEngineDelegate

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
}

// MARK: - NetworkSpeedObserver

extension AppDelegate: NetworkSpeedObserver {
    nonisolated func networkModule(_ module: NetworkModule, didUpdateSpeed download: Double, upload: Double, downloadFormatted: String, uploadFormatted: String) {
        let title = "\u{2193}\(downloadFormatted) \u{00B7} \u{2191}\(uploadFormatted)"
        Task { @MainActor in
            menuEngine?.setTitle(title)
            PreferencesManager.shared.updateNetworkStats(
                downloadSpeed: downloadFormatted,
                uploadSpeed: uploadFormatted,
                interface: "",
                isConnected: true
            )
        }
    }
}

// MARK: - Module Refresh

extension AppDelegate {
    private func refreshAllModules() async {
        guard let manager = moduleManager else { return }
        var allItems: [MenuItem] = []

        for module in manager.registeredModules {
            guard module.config.enabled else { continue }
            do {
                let output = try await module.refresh()
                Renderer.shared.render(output: output)
                allItems.append(contentsOf: output.items)
            } catch {
                Renderer.shared.render(error: error, for: module.id)
            }
        }

        menuEngine?.update(items: allItems.sorted { $0.order < $1.order })
    }

    private func refreshModule(_ moduleID: String) async {
        guard let manager = moduleManager,
              let module = manager.registeredModules.first(where: { $0.id == moduleID }),
              module.config.enabled else { return }
        do {
            let output = try await module.refresh()
            Renderer.shared.render(output: output)
            menuEngine?.update(items: await collectAllMenuItems())
        } catch {
            Renderer.shared.render(error: error, for: moduleID)
        }
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

// MARK: - Settings Window

struct SettingsWindow: Scene {
    var body: some Scene {
        Window("mac-xbar Settings", id: "settings") {
            PreferencesView()
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 420, height: 600)
    }
}
